import Foundation
import AVFoundation
import ImageIO
@main struct RenderSample {
    static func main() async throws {
        let root=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        let project=try JSONDecoder().decode(Project.self,from:Data(contentsOf:root.appendingPathComponent("DemoProject.json")))
        let output=URL(fileURLWithPath:CommandLine.arguments[2])
        try await MediaEngine.export(project,mediaRoot:root,to:output)
        let asset=AVURLAsset(url:output)
        let duration=try await asset.load(.duration)
        let videos=try await asset.loadTracks(withMediaType:.video);let audios=try await asset.loadTracks(withMediaType:.audio)
        print("Rendered \(duration.seconds) seconds; video tracks=\(videos.count); audio tracks=\(audios.count)")
        let generator=AVAssetImageGenerator(asset:asset);generator.appliesPreferredTrackTransform=true
        let frame=try await generator.image(at:CMTime(seconds:1,preferredTimescale:600)).image
        let dest=CGImageDestinationCreateWithURL(output.deletingPathExtension().appendingPathExtension("png") as CFURL,"public.png" as CFString,1,nil)!
        CGImageDestinationAddImage(dest,frame,nil);CGImageDestinationFinalize(dest)
    }
}
