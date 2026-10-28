import Foundation

public enum EditError: Error, LocalizedError {
    case invalidRange, invalidSpeed, noClips, invalidProject, missingVideo,missingAudio
    public var errorDescription: String? {
        switch self {
        case .invalidRange: return "Choose a valid range inside the clip (at least 0.1 seconds)."
        case .invalidSpeed: return "Speed must be between 0.1× and 100×, with ordered curve points from 0 to 1."
        case .noClips: return "Add a video before exporting."
        case .invalidProject: return "This project is invalid or uses an unsupported version."
        case .missingVideo: return "The selected file has no readable video track."
        case .missingAudio:return "This film has no audio to transcribe. Add a video with sound or an audio region."
        }
    }
}
public enum Canvas: String, Codable, CaseIterable { case landscape, portrait, square
    public var width: Int { self == .landscape ? 1920 : 1080 }
    public var height: Int { self == .portrait ? 1920 : 1080 }
    public var label: String { self == .landscape ? "16:9" : self == .portrait ? "9:16" : "1:1" }
}
public struct Clip: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var filename: String
    public var name: String
    public var sourceDuration: Double
    public var start: Double = 0
    public var end: Double
    public var effects: ClipEffects?
    public var motion: MotionTrack?
    public var speedCurve: SpeedCurve?
    public var speed: Double = 1
    public var volume: Double = 1
    public var duration: Double { (end - start) / speed * (speedCurve?.integral() ?? 1) }
    public init(filename: String, name: String, duration: Double) {
        self.filename = filename; self.name = name; sourceDuration = duration; end = duration
    }
    public mutating func trim(start: Double, end: Double) throws {
        try validate()
        var candidate = self; candidate.start = start; candidate.end = end
        try candidate.validate()
        guard start != self.start || end != self.end else{return}
        let a=(start-self.start)/(self.end-self.start),b=(end-self.start)/(self.end-self.start)
        if let speedCurve{candidate.speedCurve=speedCurve.resized(from:a,to:b)}
        if let motion,a>=0,b<=1{
            let total=speedCurve?.integral() ?? 1
            let first=(speedCurve?.integral(to:a) ?? a)/total,last=(speedCurve?.integral(to:b) ?? b)/total
            candidate.motion=motion.segment(from:first,to:last)
        }
        try candidate.validate();self = candidate
    }
    public func applyingTimelineTrim(leadingOutputDelta:Double=0,trailingOutputDelta:Double=0,snap:Double=0.05) throws -> Clip {
        try validate()
        guard leadingOutputDelta.isFinite,trailingOutputDelta.isFinite,snap.isFinite,snap>0,snap<=1 else{throw EditError.invalidRange}
        let span=end-start
        func source(_ seconds:Double)->Double {
            if let speedCurve{
                let fraction=speedCurve.sourceFraction(forElapsedOutput:seconds,sourceDuration:span,baseSpeed:speed,bounds:(-start/span)...((sourceDuration-start)/span))
                return start+fraction*span
            }
            return start+seconds*speed
        }
        let newStart=leadingOutputDelta==0 ? start : min(end-0.1,max(0,(source(leadingOutputDelta)/snap).rounded()*snap))
        let newEnd=trailingOutputDelta==0 ? end : max(start+0.1,min(sourceDuration,(source(duration+trailingOutputDelta)/snap).rounded()*snap))
        var result=self;try result.trim(start:newStart,end:newEnd);return result
    }
    public func split(at outputTime: Double) throws -> (Clip, Clip) {
        try validate()
        guard outputTime.isFinite, outputTime > 0, outputTime < duration else { throw EditError.invalidRange }
        var left = self; var right = self
        let sourceFraction=speedCurve?.sourceFraction(forOutputFraction:outputTime/duration) ?? outputTime/duration
        left.end = start + sourceFraction*(end-start); right.start = left.end; right.id = UUID()
        if let speedCurve{left.speedCurve=speedCurve.segment(from:0,to:sourceFraction);right.speedCurve=speedCurve.segment(from:sourceFraction,to:1)}
        if let motion {let fraction=outputTime/duration;left.motion=motion.segment(from:0,to:fraction);right.motion=motion.segment(from:fraction,to:1)}
        try left.validate(); try right.validate(); return (left, right)
    }
    public func validate() throws {
        try effects?.validate()
        try motion?.validate()
        try speedCurve?.validate()
        guard start.isFinite, end.isFinite, sourceDuration.isFinite, start >= 0, end <= sourceDuration + 0.001, end - start >= 0.1-1e-8 else { throw EditError.invalidRange }
        guard speed.isFinite, (0.1...100).contains(speed) else { throw EditError.invalidSpeed }
        guard volume.isFinite, (0...1).contains(volume), filename == URL(fileURLWithPath: filename).lastPathComponent, !filename.isEmpty else { throw EditError.invalidProject }
    }
}
public struct Project: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var version = 1
    public var name = "Untitled film"
    public var clips: [Clip] = []
    public var canvas: Canvas = .landscape
    public var style: ProjectStyle?
    public var captions: [TextCue]?
    public var audioRegions: [AudioRegion]?
    public var overlays: [OverlayLayer]?
    public var transitions:[ClipTransition]?
    public var title = ""
    public var musicFilename: String?
    public var musicVolume: Double = 0.5
    public var renderWidth:Int {
        let edge=(style ?? ProjectStyle()).resolution.shortEdge
        return canvas == .landscape ? edge*16/9 : edge
    }
    public var renderHeight:Int {
        let edge=(style ?? ProjectStyle()).resolution.shortEdge
        return canvas == .portrait ? edge*16/9 : edge
    }
    public var duration: Double {placements.last.map{$0.start+$0.duration} ?? 0}
    public init() {}
    public func validate() throws {
        try style?.validate()
        if let captions {
            guard Set(captions.map(\.id)).count == captions.count else { throw EditError.invalidProject }
            try captions.forEach { try $0.validate() }
        }
        if let audioRegions {
            guard Set(audioRegions.map(\.id)).count == audioRegions.count else { throw EditError.invalidProject }
            try audioRegions.forEach { try $0.validate() }
        }
        if let overlays {
            guard Set(overlays.map(\.id)).count == overlays.count else { throw EditError.invalidProject }
            try overlays.forEach {try $0.validate()}
        }
        if let transitions {
            let pairs=Set(zip(clips,clips.dropFirst()).map{$0.id.uuidString+$1.id.uuidString})
            guard Set(transitions.map(\.to)).count==transitions.count else{throw EditError.invalidProject}
            for transition in transitions{try transition.validate();guard pairs.contains(transition.from.uuidString+transition.to.uuidString) else{throw EditError.invalidProject}}
        }
        guard version == 1, musicVolume.isFinite, (0...1).contains(musicVolume), Set(clips.map(\.id)).count == clips.count else { throw EditError.invalidProject }
        if let musicFilename, musicFilename != URL(fileURLWithPath: musicFilename).lastPathComponent { throw EditError.invalidProject }
        try clips.forEach { try $0.validate() }
    }
}
public struct History {
    private var past: [Project] = []
    private var future: [Project] = []
    public init() {}
    public var canUndo: Bool { !past.isEmpty }
    public var canRedo: Bool { !future.isEmpty }
    public mutating func record(_ value: Project) { past.append(value); if past.count > 100 { past.removeFirst() }; future.removeAll() }
    public mutating func undo(_ current: Project) -> Project? { guard let p = past.popLast() else { return nil }; future.append(current); return p }
    public mutating func redo(_ current: Project) -> Project? { guard let p = future.popLast() else { return nil }; past.append(current); return p }
}
public struct ProjectStore {
    public let root: URL
    public init(root: URL) throws { self.root = root; try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true) }
    public func save(_ project: Project) throws { try project.validate(); try JSONEncoder().encode(project).write(to: root.appendingPathComponent(project.id.uuidString + ".json"), options: .atomic) }
    public func load(_ id: UUID) throws -> Project { let p = try JSONDecoder().decode(Project.self, from: Data(contentsOf: root.appendingPathComponent(id.uuidString + ".json"))); try p.validate(); return p }
    public func all() throws -> [Project] { try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }.map { url in let p = try JSONDecoder().decode(Project.self, from: Data(contentsOf: url)); try p.validate(); return p }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending } }
}
