import SwiftUI
import AVFoundation
import AVKit
import UniformTypeIdentifiers
import OSLog

@MainActor final class EditorModel: ObservableObject {
    @Published var project = Project()
    @Published var projects: [Project] = []
    @Published var selected: UUID?
    @Published var player = AVPlayer()
    @Published var message: String?
    @Published var busy = false
    @Published var busyLabel="Importing media…"
    @Published var canCancelOperation=false
    @Published var exporting = false
    @Published var exported: URL?
    @Published var exportedStill:URL?
    @Published var revision = 0
    @Published var previewLoading = false
    private let log = Logger(subsystem:"com.alivahdati.framecut",category:"Editor")
    private var statusObservation: NSKeyValueObservation?
    private let speech=OfflineSpeechEngine()
    private var operationTask:Task<Void,Never>?
    @Published var history = History()
    let mediaRoot: URL
    let store: ProjectStore
    init() {
        let root = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("FrameCut",isDirectory:true)
        mediaRoot = root.appendingPathComponent("Media",isDirectory:true)
        do {
            try FileManager.default.createDirectory(at:mediaRoot,withIntermediateDirectories:true)
            store = try ProjectStore(root:root.appendingPathComponent("Projects"))
            do {
                projects = try store.all()
                if let first = projects.first { project = first; selected = first.clips.first?.id }
            } catch { message = "Saved projects could not be loaded: " + error.localizedDescription }
        } catch { fatalError("Cannot open app storage: \(error.localizedDescription)") }
    }
    var selectedIndex: Int? { project.clips.firstIndex { $0.id == selected } }
    func update(_ edit: (inout Project) throws -> Void) {
        do {
            var next = project; try edit(&next);next.removeInactiveTransitions();try next.validate()
            guard next != project else { return }
            try store.save(next)
            history.record(project); project = next; exported = nil; revision += 1; refreshProjects()
        } catch { message = error.localizedDescription }
    }
    func updateClip(_ edit: (inout Clip) throws -> Void) {
        guard let i = selectedIndex else { return }; update { try edit(&$0.clips[i]) }
    }
    func updateEffects(_ edit:(inout ClipEffects)->Void) {
        updateClip { clip in var e=clip.effects ?? ClipEffects();edit(&e);clip.effects=e }
    }
    func applyTemplate(_ recipe:EditTemplate) {
        update { try recipe.apply(to:&$0) };selected=project.clips.first?.id
    }
    func refreshProjects() { do { projects = try store.all() } catch { message = error.localizedDescription } }
    func newProject() {
        let next = Project()
        do { try store.save(next);player.pause();player.replaceCurrentItem(with:nil);project = next; exported = nil; selected = nil; history = History(); revision += 1; refreshProjects() }
        catch { message = error.localizedDescription }
    }
    func open(_ value: Project) {player.pause();player.replaceCurrentItem(with:nil);project = value; exported = nil; selected = value.clips.first?.id; history = History(); revision += 1 }
    func undo() { var h = history; if let p = h.undo(project) { do { try store.save(p); history = h; project = p; exported = nil; revision += 1; refreshProjects() } catch { message = error.localizedDescription } } }
    func redo() { var h = history; if let p = h.redo(project) { do { try store.save(p); history = h; project = p; exported = nil; revision += 1; refreshProjects() } catch { message = error.localizedDescription } } }
    func copyMedia(_ url: URL) throws -> String {
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let filename = UUID().uuidString + "." + url.pathExtension
        try FileManager.default.copyItem(at:url,to:mediaRoot.appendingPathComponent(filename)); return filename
    }
    func importFiles(_ urls: [URL], music: Bool) async {
        busyLabel="Importing media…"
        busy = true; defer { busy = false }
        do {
            if music, let url = urls.first {
                let filename = try copyMedia(url)
                let asset = AVURLAsset(url:mediaRoot.appendingPathComponent(filename))
                guard try await !asset.loadTracks(withMediaType:.audio).isEmpty else { throw EditError.invalidProject }
                update { $0.musicFilename = filename }; return
            }
            var clips: [Clip] = []
            for url in urls {
                var filename = try copyMedia(url)
                if UTType(filenameExtension:url.pathExtension)?.conforms(to:.image) == true {
                    let photo=mediaRoot.appendingPathComponent(filename)
                    filename=UUID().uuidString+".mov"
                    try await MediaPreprocessor.stillMovie(imageURL:photo,to:mediaRoot.appendingPathComponent(filename))
                }
                let asset = AVURLAsset(url:mediaRoot.appendingPathComponent(filename))
                guard try await !asset.loadTracks(withMediaType:.video).isEmpty else { throw EditError.missingVideo }
                let duration = try await asset.load(.duration)
                let clip = Clip(filename:filename,name:url.deletingPathExtension().lastPathComponent,duration:duration.seconds)
                try clip.validate(); clips.append(clip)
            }
            if let id=project.style?.templateID,let recipe=EditTemplate.all.first(where:{$0.id==id}) {
                var incoming=project;incoming.clips=clips;try recipe.apply(to:&incoming);clips=incoming.clips
            }
            update { $0.clips.append(contentsOf:clips) }; selected = clips.first?.id
        } catch { message = "Import failed: " + error.localizedDescription }
    }
    func split(at seconds: Double) {
        guard let i = selectedIndex else { return }
        update { p in
            let elapsed = p.clipStart(at:i)
            let (a,b) = try p.clips[i].split(at:seconds-elapsed)
            if let next=p.clips.indices.contains(i+1) ? p.clips[i+1].id : nil,let edge=p.transitions?.firstIndex(where:{$0.from==a.id && $0.to==next}){p.transitions?[edge].from=b.id}
            p.clips.replaceSubrange(i...i,with:[a,b])
        }
    }
    func move(_ delta: Int) { guard let i = selectedIndex, project.clips.indices.contains(i+delta) else { return }; update { $0.clips.swapAt(i,i+delta) } }
    func duplicateClip(){guard let i=selectedIndex else{return};var copy=project.clips[i];copy.id=UUID();copy.name += " copy";update{$0.clips.insert(copy,at:i+1)};selected=copy.id}
    func startCaptions(language:String?){
        guard !busy,operationTask==nil else{return}
        canCancelOperation=true
        operationTask=Task{await generateCaptions(language:language);canCancelOperation=false;operationTask=nil}
    }
    func cancelOperation(){operationTask?.cancel();busyLabel="Cancelling…"}
    private func generateCaptions(language:String?) async {
        let before=project
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".caf")
        busy=true;busyLabel="Preparing film audio…"
        defer{busy=false;try? FileManager.default.removeItem(at:url)}
        do{
            try await MediaEngine.exportAudio(before,mediaRoot:mediaRoot,to:url)
            try Task.checkCancellation();busyLabel="Transcribing on this device…"
            let cues=try await speech.transcribe(audio:url,language:language,duration:before.duration)
            try Task.checkCancellation();guard project==before else{throw EditError.invalidProject}
            update{$0.captions=($0.captions ?? [])+cues}
        }catch is CancellationError{}catch{message="Caption generation failed: "+error.localizedDescription}
    }
    func reverseClip() async {
        guard let i=selectedIndex,!busy else{return}
        let before=project,clip=project.clips[i],filename=UUID().uuidString+".mov"
        let output=mediaRoot.appendingPathComponent(filename)
        busyLabel="Reversing video…";busy=true;defer{busy=false}
        do{
            try await MediaPreprocessor.reverse(input:mediaRoot.appendingPathComponent(clip.filename),start:clip.start,end:clip.end,to:output)
            guard project==before else{throw EditError.invalidProject}
            update{p in var reversed=clip;reversed.filename=filename;reversed.name += " reversed";reversed.sourceDuration=clip.end-clip.start;reversed.start=0;reversed.end=reversed.sourceDuration;reversed.volume=0;p.clips[i]=reversed}
        }catch{try? FileManager.default.removeItem(at:output);message=error.localizedDescription}
    }
    private func sourceTime(_ seconds:Double,clip:Clip,index:Int) throws -> Double {
        let elapsed=project.clipStart(at:index)
        let relative=seconds-elapsed
        guard relative>=0,relative<=clip.duration else{throw EditError.invalidRange}
        let fraction=clip.speedCurve?.sourceFraction(forOutputFraction:relative/clip.duration) ?? relative/clip.duration
        return min(clip.end-0.00001,clip.start+fraction*(clip.end-clip.start))
    }
    func extractStill(at seconds:Double) async {
        guard let i=selectedIndex,!busy else{return};let clip=project.clips[i]
        busyLabel="Extracting source frame…";busy=true;defer{busy=false}
        do{let t=try sourceTime(seconds,clip:clip,index:i);let url=FileManager.default.temporaryDirectory.appendingPathComponent("FrameCut-\(UUID().uuidString).png");try await MediaPreprocessor.extractStill(input:mediaRoot.appendingPathComponent(clip.filename),at:t,to:url);exportedStill=url}
        catch{message=error.localizedDescription}
    }
    func freeze(at seconds:Double) async {
        guard let i=selectedIndex,!busy else{return};let clip=project.clips[i],before=project
        busyLabel="Creating freeze frame…";busy=true;defer{busy=false}
        let filename=UUID().uuidString+".mov",output:URL
        output=mediaRoot.appendingPathComponent(filename)
        do{
            let t=try sourceTime(seconds,clip:clip,index:i)
            try await MediaPreprocessor.freeze(input:mediaRoot.appendingPathComponent(clip.filename),at:t,to:output)
            guard project==before else{throw EditError.invalidProject}
            var still=Clip(filename:filename,name:clip.name+" freeze",duration:3);still.effects=clip.effects;still.volume=0
            update{p in
                if t-clip.start<0.1{p.clips.insert(still,at:i)}
                else if clip.end-t<0.1{p.clips.insert(still,at:i+1)}
                else{let relative=seconds-p.clipStart(at:i);let (a,b)=try clip.split(at:relative);p.clips.replaceSubrange(i...i,with:[a,still,b])}
            };selected=still.id
        }catch{try? FileManager.default.removeItem(at:output);message=error.localizedDescription}
    }
    func replaceClip(with url:URL) async {
        guard let i=selectedIndex,!busy else{return};let before=project
        busy=true;defer{busy=false}
        do{
            var file=try copyMedia(url)
            if UTType(filenameExtension:url.pathExtension)?.conforms(to:.image)==true{let original=mediaRoot.appendingPathComponent(file);file=UUID().uuidString+".mov";try await MediaPreprocessor.stillMovie(imageURL:original,to:mediaRoot.appendingPathComponent(file))}
            let asset=AVURLAsset(url:mediaRoot.appendingPathComponent(file))
            guard try await !asset.loadTracks(withMediaType:.video).isEmpty else{throw EditError.missingVideo}
            let length=try await asset.load(.duration).seconds
            guard project==before else{throw EditError.invalidProject}
            update{p in var clip=p.clips[i];clip.filename=file;clip.name=url.deletingPathExtension().lastPathComponent;clip.sourceDuration=length;clip.start=min(clip.start,max(0,length-0.1));clip.end=min(length,max(clip.start+0.1,clip.end));p.clips[i]=clip}
        }catch{message="Replace failed: "+error.localizedDescription}
    }
    func deleteClip() { guard let i = selectedIndex else { return }; update { $0.clips.remove(at:i) }; selected = project.clips.first?.id }
    func preview() async {
        let currentTime=player.currentTime().seconds
        player.pause()
        previewLoading = true; defer { previewLoading = false }
        log.info("Building preview with \(self.project.clips.count) clips")
        guard !project.clips.isEmpty else { player.replaceCurrentItem(with:nil); return }
        do {
            let timeline = try await MediaEngine.build(project,mediaRoot:mediaRoot,size:CGSize(width:project.canvas.width/2,height:project.canvas.height/2),titleOverlay:true)
            try Task.checkCancellation()
            let item = AVPlayerItem(asset:timeline.composition); item.videoComposition = timeline.videoComposition; item.audioMix = timeline.audioMix
            statusObservation = item.observe(\.status,options:[.initial,.new]) { [weak self] item,_ in
                let status=item.status.rawValue; let error=item.error?.localizedDescription
                Task { @MainActor [weak self] in
                    self?.log.info("Preview status: \(status), error: \(error ?? "none")")
                    if let error { self?.message="Preview failed: " + error }
                }
            }
            player.replaceCurrentItem(with:item)
            let seconds=max(0,min(project.duration,currentTime.isFinite ? currentTime : 0))
            await withCheckedContinuation{(continuation:CheckedContinuation<Void,Never>) in
                player.seek(to:CMTime(seconds:seconds,preferredTimescale:600000),toleranceBefore:.zero,toleranceAfter:.zero){_ in continuation.resume()}
            }
            log.info("Preview item installed")
        } catch is CancellationError {} catch { message = error.localizedDescription }
    }
    func export() async {
        guard !exporting else { return }
        exporting = true; exported = nil; player.pause(); defer { exporting = false }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("FrameCut-" + UUID().uuidString + ".mp4")
        do { try await MediaEngine.export(project,mediaRoot:mediaRoot,to:url); exported = url }
        catch { message = "Export failed: " + error.localizedDescription }
    }
}
