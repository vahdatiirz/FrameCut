import Foundation
import AVFoundation
import CoreGraphics
import CoreText

@main struct GenerateSamples {
    static func main() async throws {
        let root = URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        for scene in 0..<2 {
            let url=root.appendingPathComponent(scene == 0 ? "Dawn.mov" : "Dusk.mov")
            if FileManager.default.fileExists(atPath:url.path) { continue }
            let writer=try AVAssetWriter(url:url,fileType:.mov)
            let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:640,AVVideoHeightKey:360])
            let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:640,kCVPixelBufferHeightKey as String:360])
            writer.add(input); guard writer.startWriting() else { throw writer.error! }; writer.startSession(atSourceTime:.zero)
            for frame in 0..<90 {
                while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds:1_000_000) }
                var pixel:CVPixelBuffer?;CVPixelBufferCreate(kCFAllocatorDefault,640,360,kCVPixelFormatType_32ARGB,nil,&pixel)
                let buffer=pixel!;CVPixelBufferLockBaseAddress(buffer,[])
                let c=CGContext(data:CVPixelBufferGetBaseAddress(buffer),width:640,height:360,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(buffer),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue)!
                let colors=scene == 0 ? [CGColor(red:0.13,green:0.35,blue:0.40,alpha:1),CGColor(red:0.87,green:0.77,blue:0.52,alpha:1)] : [CGColor(red:0.13,green:0.12,blue:0.35,alpha:1),CGColor(red:0.86,green:0.44,blue:0.40,alpha:1)]
                let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors as CFArray,locations:[0,1])!
                c.drawLinearGradient(gradient,start:CGPoint(x:0,y:360),end:CGPoint(x:640,y:0),options:[])
                c.setFillColor(CGColor(red:1,green:0.88,blue:0.62,alpha:1));c.fillEllipse(in:CGRect(x:430-Double(frame)*0.35,y:180+Double(frame)*0.15,width:70,height:70))
                for ridge in 0..<3 {
                    c.setFillColor(CGColor(red:0.05+Double(ridge)*0.025,green:0.16+Double(ridge)*0.025,blue:0.21+Double(ridge)*0.025,alpha:1))
                    c.beginPath();c.move(to:CGPoint(x:0,y:0));c.addLine(to:CGPoint(x:0,y:60+ridge*25))
                    for x in stride(from:0,through:640,by:8) { let y=Double(80+ridge*36)+sin(Double(x)/80+Double(ridge)*2+Double(frame)/400)*36; c.addLine(to:CGPoint(x:Double(x),y:y)) }
                    c.addLine(to:CGPoint(x:640,y:0));c.closePath();c.fillPath()
                }
                let text=scene == 0 ? "01 / DAWN" : "02 / DUSK"
                let attributes:[NSAttributedString.Key:Any]=[NSAttributedString.Key(kCTFontAttributeName as String):CTFontCreateWithName("HelveticaNeue-Medium" as CFString,17,nil),NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(gray:1,alpha:0.85)]
                let line=CTLineCreateWithAttributedString(NSAttributedString(string:text,attributes:attributes));c.textPosition=CGPoint(x:30,y:320);CTLineDraw(line,c)
                CVPixelBufferUnlockBaseAddress(buffer,[])
                guard adaptor.append(buffer,withPresentationTime:CMTime(value:Int64(frame),timescale:30)) else { throw writer.error! }
            }
            input.markAsFinished();await writer.finishWriting();guard writer.status == .completed else {throw writer.error!}
        }
        let audio=root.appendingPathComponent("Atmosphere.caf")
        if !FileManager.default.fileExists(atPath:audio.path) {
            let format=AVAudioFormat(standardFormatWithSampleRate:44100,channels:1)!
            let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:264600)!;buffer.frameLength=264600
            for i in 0..<Int(buffer.frameLength) { let t=Double(i)/44100;let fade=min(1,min(t/0.4,(6-t)/0.5)); buffer.floatChannelData![0][i]=Float((sin(t*220*2*Double.pi)+sin(t*330*2*Double.pi))*0.07*fade) }
            let file=try AVAudioFile(forWriting:audio,settings:format.settings);try file.write(from:buffer)
        }
        print("Generated 2 original 3-second videos and 6-second audio")
    }
}
