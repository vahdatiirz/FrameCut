import XCTest
import AVFoundation
import CoreImage
@testable import FrameCutCore

final class AtmosphereExportTests:XCTestCase {
    func testThreeAtmosphereEffectsSurviveRealExportAndFullDecode() async throws {
        let samples=URL(fileURLWithPath:#filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Samples")
        let explicit=ProcessInfo.processInfo.environment["FRAMECUT_APPROVAL_OUTPUT"]
        let output=explicit.map{URL(fileURLWithPath:$0)} ?? FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        defer{if explicit==nil{try? FileManager.default.removeItem(at:output)}}
        let size=explicit==nil ? CGSize(width:320,height:180) : CGSize(width:1280,height:720)
        var reports:[[String:Any]]=[]
        for style in [TransitionStyle.dissolve,.smokeDrift,.confetti,.goldConfetti] {
            var p=Project();p.name="Atmosphere approval: "+style.title
            p.clips=[Clip(filename:"Dawn.mov",name:"Dawn",duration:3),Clip(filename:"Dusk.mov",name:"Dusk",duration:3)]
            try p.setTransition(from:p.clips[0].id,to:p.clips[1].id,style:style,duration:1.4)
            let url=output.appendingPathComponent(style.rawValue+".mp4"),started=Date()
            if FileManager.default.fileExists(atPath:url.path){try FileManager.default.removeItem(at:url)}
            let diagnostic=try await MediaEngine.build(p,mediaRoot:samples,size:size)
            let valid=try await diagnostic.videoComposition.isValid(for:diagnostic.composition,timeRange:CMTimeRange(start:.zero,duration:diagnostic.composition.duration),validationDelegate:nil)
            XCTAssertTrue(valid,"Fractional overlaps must not leave sub-frame gaps in composition instructions")
            XCTAssertEqual(CMTimeCompare(CMTimeRangeGetEnd(try XCTUnwrap(diagnostic.videoComposition.instructions.last).timeRange),diagnostic.composition.duration),0)
            do{try await MediaEngine.export(p,mediaRoot:samples,to:url,size:size)}catch{XCTFail("Export \(style): \(error as NSError)");throw error}
            let asset=AVURLAsset(url:url),duration=try await asset.load(.duration).seconds
            XCTAssertEqual(duration,4.6,accuracy:0.04)
            let tracks=try await asset.loadTracks(withMediaType:.video)
            let track=try XCTUnwrap(tracks.first)
            let reader=try AVAssetReader(asset:asset),frames=AVAssetReaderTrackOutput(track:track,outputSettings:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA])
            reader.add(frames);XCTAssertTrue(reader.startReading());var count=0
            while let sample=frames.copyNextSampleBuffer(){XCTAssertNotNil(CMSampleBufferGetImageBuffer(sample));count+=1}
            XCTAssertEqual(reader.status,.completed);XCTAssertEqual(count,138)
            let generator=AVAssetImageGenerator(asset:asset)
            generator.requestedTimeToleranceBefore = .zero;generator.requestedTimeToleranceAfter = .zero
            let middle=try await generator.image(at:CMTime(seconds:2.3,preferredTimescale:600)).image
            try CIContext().writePNGRepresentation(of:CIImage(cgImage:middle),to:output.appendingPathComponent(style.rawValue+"-middle.png"),format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB())
            reports.append(["effect":style.rawValue,"duration":duration,"decodedFrames":count,"renderSeconds":Date().timeIntervalSince(started),"renderOrigin":"Mac core integration test, not simulator or iPad","visualApproval":"pending"])
        }
        try JSONSerialization.data(withJSONObject:reports,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("renders.json"))
    }
}
