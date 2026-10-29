import Foundation
import ImageIO

/// A baked video asset, rendered externally. Metadata alone does not prove AI provenance.
public struct GeneratedBridgeAsset:Codable,Equatable {
    public var filename:String
    public var sourceDuration:Double
    public var jobID:UUID
    public init(filename:String,sourceDuration:Double,jobID:UUID){self.filename=filename;self.sourceDuration=sourceDuration;self.jobID=jobID}
    public func validate() throws {
        guard !filename.isEmpty,filename==URL(fileURLWithPath:filename).lastPathComponent,
              ["mov","mp4","m4v"].contains(URL(fileURLWithPath:filename).pathExtension.lowercased()),
              sourceDuration.isFinite,(0.1...10).contains(sourceDuration) else{throw EditError.invalidProject}
    }
}
extension Project {
    /// Attach a baked video to the same overlap, preserving the timing of every other track.
    public mutating func attachGeneratedBridge(from:UUID,to:UUID,asset:GeneratedBridgeAsset,duration:Double) throws {
        try asset.validate()
        guard zip(clips,clips.dropFirst()).contains(where:{$0.0.id==from && $0.1.id==to}) else{throw EditError.invalidProject}
        var candidate=self
        var edge=candidate.transitions?.first{$0.from==from && $0.to==to} ?? ClipTransition(from:from,to:to,duration:duration)
        edge.duration=duration;edge.generatedBridge=asset;try edge.validate()
        candidate.transitions=candidate.transitions?.filter{$0.to != to} ?? []
        candidate.transitions?.append(edge);try candidate.validate();self=candidate
    }
}

public enum GenerationPreset:String,Codable,CaseIterable {case custom,zoomIn,zoomOut,push,pull,flyThrough,orbit,smartMove,styleMorph,moneyVeil,slideLeft,slideRight,confetti,goldConfetti,rise,dive,smokeDrift}
public struct GenerationJob:Codable,Equatable {
    public var schemaVersion=1
    public var jobID=UUID()
    public var fromClipID:UUID
    public var toClipID:UUID
    public var preset:GenerationPreset
    public var prompt:String
    public var width:Int
    public var height:Int
    public var numFrames:Int
    public var framesPerSecond=24
    public var seed:UInt32
    public var transitionDuration:Double
    public var firstFramePNG:Data
    public var lastFramePNG:Data
    public init(from:UUID,to:UUID,preset:GenerationPreset,prompt:String,width:Int,height:Int,numFrames:Int,seed:UInt32,transitionDuration:Double,firstFrame:Data,lastFrame:Data){self.fromClipID=from;self.toClipID=to;self.preset=preset;self.prompt=prompt;self.width=width;self.height=height;self.numFrames=numFrames;self.seed=seed;self.transitionDuration=transitionDuration;self.firstFramePNG=firstFrame;self.lastFramePNG=lastFrame}
    public func validate() throws {
        guard schemaVersion==1,fromClipID != toClipID,prompt.count<=2000,!prompt.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,
              (64...768).contains(width),(64...768).contains(height),width%32==0,height%32==0,
              (17...97).contains(numFrames),(numFrames-1)%8==0,framesPerSecond==24,
              transitionDuration.isFinite,(0.05...5).contains(transitionDuration) else{throw EditError.invalidProject}
        let signature=Data([137,80,78,71,13,10,26,10])
        for data in [firstFramePNG,lastFramePNG] {
            guard data.count<=3_000_000,data.starts(with:signature),let source=CGImageSourceCreateWithData(data as CFData,nil),
                  let props=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
                  (props[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue==width,
                  (props[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue==height,
                  CGImageSourceCreateImageAtIndex(source,0,nil) != nil else{throw EditError.invalidProject}
        }
    }
}
