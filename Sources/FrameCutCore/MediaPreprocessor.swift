import Foundation
import AVFoundation
import CoreImage

public enum MediaPreprocessor {
    public static func extractStill(input:URL,at seconds:Double,to output:URL) async throws {
        let image=try await frame(input:input,at:seconds)
        try CIContext().writePNGRepresentation(of:CIImage(cgImage:image),to:output,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!)
    }
    public static func freeze(input:URL,at seconds:Double,duration:Double=3,to output:URL) async throws {
        let png=output.deletingLastPathComponent().appendingPathComponent(UUID().uuidString+".png")
        defer{try? FileManager.default.removeItem(at:png)}
        try await extractStill(input:input,at:seconds,to:png)
        try await stillMovie(imageURL:png,duration:duration,to:output)
    }
    private static func frame(input:URL,at seconds:Double) async throws -> CGImage {
        guard seconds.isFinite,seconds>=0 else{throw EditError.invalidRange}
        let generator=AVAssetImageGenerator(asset:AVURLAsset(url:input));generator.appliesPreferredTrackTransform=true
        generator.maximumSize=CGSize(width:3840,height:3840);generator.requestedTimeToleranceBefore = .zero;generator.requestedTimeToleranceAfter = .zero
        return try await generator.image(at:CMTime(seconds:seconds,preferredTimescale:600000)).image
    }
    /// Reverses the selected source range into an independent silent SDR video; original media is retained.
    public static func reverse(input:URL,start:Double,end:Double,to output:URL) async throws {
        let asset=AVURLAsset(url:input)
        guard let source=try await asset.loadTracks(withMediaType:.video).first else{throw EditError.missingVideo}
        let duration=try await asset.load(.duration).seconds
        guard start.isFinite,end.isFinite,start>=0,end<=duration+0.001,end-start>=0.1 else{throw EditError.invalidRange}
        let rate=try await source.load(.nominalFrameRate)
        let fps=min(60,max(1,Int(rate.isFinite ? rate.rounded() : 30)))
        let generator=AVAssetImageGenerator(asset:asset);generator.appliesPreferredTrackTransform=true;generator.maximumSize=CGSize(width:3840,height:3840)
        generator.requestedTimeToleranceBefore = .zero;generator.requestedTimeToleranceAfter = .zero
        let first=try await generator.image(at:CMTime(seconds:max(start,end-1/Double(fps)),preferredTimescale:600000)).image
        let width=max(2,first.width/2*2),height=max(2,first.height/2*2)
        let bounds=CGRect(x:0,y:0,width:width,height:height),context=CIContext()
        let writer=try AVAssetWriter(url:output,fileType:.mov)
        let writerInput=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:width,AVVideoHeightKey:height])
        let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:writerInput,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height])
        guard writer.canAdd(writerInput) else{throw EditError.invalidProject};writer.add(writerInput)
        do{
            guard writer.startWriting() else{throw writer.error ?? EditError.invalidProject};writer.startSession(atSourceTime:.zero)
            for i in 0..<Int(ceil((end-start)*Double(fps))){
                try Task.checkCancellation()
                while !writerInput.isReadyForMoreMediaData{try Task.checkCancellation();guard writer.status == .writing else{throw writer.error ?? EditError.invalidProject};try await Task.sleep(nanoseconds:1_000_000)}
                let second=max(start,end-Double(i+1)/Double(fps))
                let cg=i==0 ? first : try await generator.image(at:CMTime(seconds:second,preferredTimescale:600000)).image
                let image=CIImage(cgImage:cg).transformed(by:CGAffineTransform(scaleX:Double(width)/Double(cg.width),y:Double(height)/Double(cg.height)))
                var pixel:CVPixelBuffer?
                guard CVPixelBufferCreate(kCFAllocatorDefault,width,height,kCVPixelFormatType_32BGRA,nil,&pixel)==kCVReturnSuccess,let pixel else{throw EditError.invalidProject}
                context.render(image,to:pixel,bounds:bounds,colorSpace:CGColorSpaceCreateDeviceRGB())
                guard adaptor.append(pixel,withPresentationTime:CMTime(value:Int64(i),timescale:Int32(fps))) else{throw writer.error ?? EditError.invalidProject}
            }
            writer.endSession(atSourceTime:CMTime(seconds:end-start,preferredTimescale:600000));writerInput.markAsFinished();await writer.finishWriting()
            guard writer.status == .completed else{throw writer.error ?? EditError.invalidProject}
        }catch{writer.cancelWriting();try? FileManager.default.removeItem(at:output);throw error}
    }
    public static func stillMovie(imageURL:URL,duration:Double=3,to output:URL) async throws {
        guard duration.isFinite,(0.1...3600).contains(duration),
              let image=CIImage(contentsOf:imageURL,options:[.applyOrientationProperty:true]),
              !image.extent.isEmpty else{throw EditError.invalidProject}
        let factor=min(1,3840/max(image.extent.width,image.extent.height))
        let width=max(2,Int(image.extent.width*factor)/2*2),height=max(2,Int(image.extent.height*factor)/2*2)
        let bounds=CGRect(x:0,y:0,width:width,height:height)
        let normalized=image.transformed(by:CGAffineTransform(translationX:-image.extent.minX,y:-image.extent.minY))
            .transformed(by:CGAffineTransform(scaleX:Double(width)/image.extent.width,y:Double(height)/image.extent.height))
            .composited(over:CIImage(color:CIColor(red:0,green:0,blue:0)).cropped(to:bounds))
        let writer=try AVAssetWriter(url:output,fileType:.mov)
        let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:width,AVVideoHeightKey:height])
        let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height])
        guard writer.canAdd(input) else{throw EditError.invalidProject};writer.add(input)
        guard writer.startWriting() else{throw writer.error ?? EditError.invalidProject}
        writer.startSession(atSourceTime:.zero)
        do{
            var buffer:CVPixelBuffer?
            guard CVPixelBufferCreate(kCFAllocatorDefault,width,height,kCVPixelFormatType_32BGRA,[kCVPixelBufferCGImageCompatibilityKey:true,kCVPixelBufferCGBitmapContextCompatibilityKey:true] as CFDictionary,&buffer)==kCVReturnSuccess,let buffer else{throw EditError.invalidProject}
            CIContext().render(normalized,to:buffer,bounds:bounds,colorSpace:CGColorSpaceCreateDeviceRGB())
            for i in 0..<Int(ceil(duration*30)){
                while !input.isReadyForMoreMediaData{try Task.checkCancellation();guard writer.status == .writing else{throw writer.error ?? EditError.invalidProject};try await Task.sleep(nanoseconds:1_000_000)}
                try Task.checkCancellation()
                guard adaptor.append(buffer,withPresentationTime:CMTime(value:Int64(i),timescale:30)) else{throw writer.error ?? EditError.invalidProject}
            }
            writer.endSession(atSourceTime:CMTime(seconds:duration,preferredTimescale:600));input.markAsFinished();await writer.finishWriting()
            guard writer.status == .completed else{throw writer.error ?? EditError.invalidProject}
        }catch{writer.cancelWriting();try? FileManager.default.removeItem(at:output);throw error}
    }
}
