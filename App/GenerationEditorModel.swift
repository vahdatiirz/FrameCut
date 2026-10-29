import Foundation
import AVFoundation
import UIKit

extension EditorModel {
    func prepareGenerationJob(from:UUID,to:UUID,preset:GenerationPreset,prompt:String,duration:Double) async throws->URL {
        let snapshot=project
        guard let index=snapshot.clips.firstIndex(where:{$0.id==to}),index>0,snapshot.clips[index-1].id==from else{throw EditError.invalidProject}
        let a=snapshot.clips[index-1],b=snapshot.clips[index],overlap=min(duration,a.duration/2,b.duration/2)
        let size:CGSize=snapshot.canvas == .portrait ? CGSize(width:288,height:512) : snapshot.canvas == .square ? CGSize(width:384,height:384) : CGSize(width:512,height:288)
        func endpoint(_ clip:Clip,at seconds:Double) async throws->Data {
            var single=Project();single.canvas=snapshot.canvas;single.clips=[clip]
            let rendered=try await MediaEngine.build(single,mediaRoot:mediaRoot,size:size)
            let generator=AVAssetImageGenerator(asset:rendered.composition);generator.videoComposition=rendered.videoComposition
            generator.requestedTimeToleranceBefore = .zero;generator.requestedTimeToleranceAfter = .zero
            let result=try await generator.image(at:CMTime(seconds:seconds,preferredTimescale:600000))
            try Task.checkCancellation()
            guard let png=UIImage(cgImage:result.image).pngData() else{throw EditError.invalidProject}
            return png
        }
        let first=try await endpoint(a,at:max(0,a.duration-overlap)),last=try await endpoint(b,at:min(b.duration-0.001,overlap))
        let frames=min(97,max(17,Int(ceil(overlap*24/8))*8+1))
        let job=GenerationJob(from:from,to:to,preset:preset,prompt:prompt,width:Int(size.width),height:Int(size.height),numFrames:frames,seed:42,transitionDuration:overlap,firstFrame:first,lastFrame:last)
        try job.validate();try Task.checkCancellation();guard project==snapshot else{throw EditError.invalidProject}
        let folder=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("Generation Jobs",isDirectory:true)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let url=folder.appendingPathComponent("FrameCut-Job-\(job.jobID.uuidString).json")
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys];try encoder.encode(job).write(to:url,options:.atomic)
        return url
    }
    /// Prepare a draft import. The project changes only after the parent editor's Apply.
    func prepareGeneratedBridgeImport(_ url:URL) async throws->GeneratedBridgeAsset {
        let snapshot=project,file=try copyMedia(url)
        do {
            let asset=AVURLAsset(url:mediaRoot.appendingPathComponent(file))
            guard try await !asset.loadTracks(withMediaType:.video).isEmpty else{throw EditError.missingVideo}
            let length=try await asset.load(.duration).seconds
            try Task.checkCancellation();guard project==snapshot else{throw EditError.invalidProject}
            let value=GeneratedBridgeAsset(filename:file,sourceDuration:length,jobID:UUID());try value.validate();return value
        }catch{try? FileManager.default.removeItem(at:mediaRoot.appendingPathComponent(file));throw error}
    }
}
