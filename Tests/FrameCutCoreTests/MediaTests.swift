import XCTest
import AVFoundation
import CoreVideo
import ImageIO
@testable import FrameCutCore
final class MediaTests: XCTestCase {
    func testSpeechAudioExtractionPreservesLeadingAndTrailingSilenceAndMixVolume() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        try await makeVideo(at:root.appendingPathComponent("a.mov"),red:true)
        let format=AVAudioFormat(standardFormatWithSampleRate:16000,channels:1)!,buffer=AVAudioPCMBuffer(pcmFormat:AVAudioFormat(standardFormatWithSampleRate:16000,channels:1)!,frameCapacity:16000)!
        buffer.frameLength=16000
        for i in 0..<16000{buffer.floatChannelData![0][i]=Float(sin(Double(i)*440*2*Double.pi/16000)*0.4)}
        try AVAudioFile(forWriting:root.appendingPathComponent("voice.caf"),settings:format.settings).write(from:buffer)
        var p=Project();p.clips=[Clip(filename:"a.mov",name:"A",duration:2)]
        var region=AudioRegion(filename:"voice.caf",name:"Voice",sourceDuration:1);region.timelineStart=0.5;region.volume=0.5;p.audioRegions=[region]
        let output=root.appendingPathComponent("speech.caf");try await MediaEngine.exportAudio(p,mediaRoot:root,to:output)
        let file=try AVAudioFile(forReading:output);XCTAssertEqual(file.length,32000);XCTAssertEqual(file.processingFormat.sampleRate,16000);XCTAssertEqual(file.processingFormat.channelCount,1)
        let audio=AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:32000)!;try file.read(into:audio)
        let samples=audio.floatChannelData![0]
        func rms(_ range:Range<Int>)->Double{sqrt(range.reduce(0.0){$0+Double(samples[$1]*samples[$1])}/Double(range.count))}
        XCTAssertLessThan(rms(1600..<4800),0.001);XCTAssertEqual(rms(12800..<16000),0.1414,accuracy:0.01);XCTAssertLessThan(rms(27200..<30400),0.001)
    }
    func testTwoSourceTransitionsBlendMovingFramesAndWipeInCorrectDirection() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        try await makeVideo(at:root.appendingPathComponent("moving.mov"),red:true,timeSwitch:true,switchFrame:45)
        try await makeVideo(at:root.appendingPathComponent("blue.mov"),red:false)
        var p=Project();p.clips=[Clip(filename:"moving.mov",name:"Moving",duration:2),Clip(filename:"blue.mov",name:"Blue",duration:2)]
        var edge=ClipTransition(from:p.clips[0].id,to:p.clips[1].id,duration:1)
        for style in TransitionStyle.allCases {
            edge.style=style;p.transitions=[edge]
            let url=root.appendingPathComponent(style.rawValue+".mp4");try await MediaEngine.export(p,mediaRoot:root,to:url,size:CGSize(width:320,height:180))
            let asset=AVURLAsset(url:url);let duration=try await asset.load(.duration);XCTAssertEqual(duration.seconds,3,accuracy:0.05)
            let generator=AVAssetImageGenerator(asset:asset);generator.requestedTimeToleranceBefore = .zero;generator.requestedTimeToleranceAfter = .zero
            let early=try await generator.image(at:CMTime(seconds:1.25,preferredTimescale:600)).image
            if style == .dissolve {
                let a=centerPixel(early).map(Int.init);XCTAssertGreaterThan(a[0],a[2]+30);XCTAssertGreaterThan(a[2],40)
                let late=try await generator.image(at:CMTime(seconds:1.75,preferredTimescale:600)).image
                let b=centerPixel(late).map(Int.init);XCTAssertGreaterThan(b[2],b[0]+100,"The outgoing source must continue playing during overlap")
            }else{
                let left=pixel(early,x:40,y:90).map(Int.init),right=pixel(early,x:280,y:90).map(Int.init)
                if style == .wipeRight || style == .slideRight{XCTAssertGreaterThan(left[2],left[0]+100);XCTAssertGreaterThan(right[0],right[2]+100)}
                else{XCTAssertGreaterThan(left[0],left[2]+100);XCTAssertGreaterThan(right[2],right[0]+100)}
            }
        }
    }
    func testReverseFreezeAndExtractUseSelectedSourceFrames() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        let input=root.appendingPathComponent("switch.mov");try await makeVideo(at:input,red:true,timeSwitch:true)
        let reversed=root.appendingPathComponent("reverse.mov");try await MediaPreprocessor.reverse(input:input,start:0,end:2,to:reversed)
        let gen=AVAssetImageGenerator(asset:AVURLAsset(url:reversed));let a=try await gen.image(at:CMTime(seconds:0.2,preferredTimescale:600)).image,b=try await gen.image(at:CMTime(seconds:1.7,preferredTimescale:600)).image
        let early=centerPixel(a).map(Int.init),late=centerPixel(b).map(Int.init)
        XCTAssertGreaterThan(early[2],early[0]+100);XCTAssertGreaterThan(late[0],late[2]+100)
        let still=root.appendingPathComponent("still.png");try await MediaPreprocessor.extractStill(input:input,at:1.5,to:still)
        let source=try XCTUnwrap(CGImageSourceCreateWithURL(still as CFURL,nil))
        let photo=CGImageSourceCreateImageAtIndex(source,0,nil)
        XCTAssertGreaterThan(centerPixel(try XCTUnwrap(photo))[2],200)
        let freeze=root.appendingPathComponent("freeze.mov");try await MediaPreprocessor.freeze(input:input,at:1.5,duration:1.2,to:freeze)
        let frozenAsset=AVURLAsset(url:freeze);let duration=try await frozenAsset.load(.duration);XCTAssertEqual(duration.seconds,1.2,accuracy:0.05)
        let frozen=AVAssetImageGenerator(asset:frozenAsset)
        for t in [0.1,1.1]{let image=try await frozen.image(at:CMTime(seconds:t,preferredTimescale:600)).image;XCTAssertGreaterThan(centerPixel(image)[2],200)}
    }
    func testFourKSixtyFPSExportHasThirtyDecodedFramesInHalfSecond() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        try await makeVideo(at:root.appendingPathComponent("a.mov"),red:true)
        var p=Project();var c=Clip(filename:"a.mov",name:"A",duration:2);c.end=0.5;p.clips=[c]
        var style=ProjectStyle();style.fps=60;style.resolution = .ultraHD;p.style=style
        let url=root.appendingPathComponent("60.mp4");try await MediaEngine.export(p,mediaRoot:root,to:url)
        let asset=AVURLAsset(url:url),tracks=try await AVURLAsset(url:url).loadTracks(withMediaType:.video)
        let track=try XCTUnwrap(tracks.first),size=try await track.load(.naturalSize),fps=try await track.load(.nominalFrameRate)
        XCTAssertEqual(size.width,3840);XCTAssertEqual(size.height,2160);XCTAssertEqual(fps,60,accuracy:0.1)
        let reader=try AVAssetReader(asset:asset)
        let ownTracks=try await asset.loadTracks(withMediaType:.video)
        let output=AVAssetReaderTrackOutput(track:try XCTUnwrap(ownTracks.first),outputSettings:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]);reader.add(output);XCTAssertTrue(reader.startReading())
        var count=0
        while let sample=output.copyNextSampleBuffer(){XCTAssertNotNil(CMSampleBufferGetImageBuffer(sample));count+=1}
        XCTAssertEqual(reader.status,.completed);XCTAssertEqual(count,30)
    }
    func testSpeedRampExportUsesIntegratedTimingAndCorrectSourceFrames() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        try await makeVideo(at:root.appendingPathComponent("switch.mov"),red:true,timeSwitch:true)
        var p=Project();var clip=Clip(filename:"switch.mov",name:"Switch",duration:2)
        clip.speedCurve=SpeedCurve(points:[SpeedPoint(position:0,speed:1),SpeedPoint(position:1,speed:2)]);p.clips=[clip]
        let url=root.appendingPathComponent("ramp.mp4");try await MediaEngine.export(p,mediaRoot:root,to:url,size:CGSize(width:320,height:180))
        let asset=AVURLAsset(url:url);let duration=try await asset.load(.duration);XCTAssertEqual(duration.seconds,2*log(2),accuracy:0.05)
        let generator=AVAssetImageGenerator(asset:asset);generator.requestedTimeToleranceBefore = .zero;generator.requestedTimeToleranceAfter = .zero
        let first=try await generator.image(at:CMTime(seconds:0.6,preferredTimescale:600)).image,last=try await generator.image(at:CMTime(seconds:1.1,preferredTimescale:600)).image
        let a=centerPixel(first).map(Int.init),b=centerPixel(last).map(Int.init)
        XCTAssertGreaterThan(a[0],a[2]+100);XCTAssertGreaterThan(b[2],b[0]+100)
    }
    func testTransparentPhotoOverlayAndStillImportPreservePixelsAndDuration() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        let context=try XCTUnwrap(CGContext(data:nil,width:160,height:90,bitsPerComponent:8,bytesPerRow:640,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red:0,green:0,blue:1,alpha:1));context.fill(CGRect(x:50,y:20,width:60,height:50))
        let image=try XCTUnwrap(context.makeImage()),png=root.appendingPathComponent("sticker.png")
        let destination=try XCTUnwrap(CGImageDestinationCreateWithURL(png as CFURL,"public.png" as CFString,1,nil));CGImageDestinationAddImage(destination,image,nil);XCTAssertTrue(CGImageDestinationFinalize(destination))
        try await makeVideo(at:root.appendingPathComponent("a.mov"),red:true)
        var p=Project();p.clips=[Clip(filename:"a.mov",name:"A",duration:2)]
        var layer=OverlayLayer(clip:Clip(filename:"sticker.png",name:"Sticker",duration:2));layer.isStill=true;layer.centerX=0.5;layer.centerY=0.5;layer.width=0.5;layer.height=0.5;p.overlays=[layer]
        let url=root.appendingPathComponent("sticker.mp4");try await MediaEngine.export(p,mediaRoot:root,to:url,size:CGSize(width:320,height:180))
        let frame=try await AVAssetImageGenerator(asset:AVURLAsset(url:url)).image(at:CMTime(seconds:1,preferredTimescale:600)).image
        let middle=centerPixel(frame).map(Int.init),transparent=pixel(frame,x:90,y:90).map(Int.init)
        XCTAssertGreaterThan(middle[2],middle[0]+100);XCTAssertGreaterThan(transparent[0],transparent[2]+100)
        let still=root.appendingPathComponent("photo.mov");try await MediaPreprocessor.stillMovie(imageURL:png,duration:1.2,to:still)
        let asset=AVURLAsset(url:still),duration=try await asset.load(.duration)
        XCTAssertEqual(duration.seconds,1.2,accuracy:0.05)
        let photo=try await AVAssetImageGenerator(asset:asset).image(at:CMTime(seconds:0.8,preferredTimescale:600)).image
        XCTAssertEqual(photo.width,160);XCTAssertEqual(photo.height,90);XCTAssertGreaterThan(centerPixel(photo)[2],200);XCTAssertLessThan(pixel(photo,x:5,y:5)[0],30)
    }
    func testOverlayTimingMaskOpacityAndMainMotionRenderActualPixels() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        try await makeVideo(at:root.appendingPathComponent("red.mov"),red:true);try await makeVideo(at:root.appendingPathComponent("blue.mov"),red:false)
        var p=Project();p.clips=[Clip(filename:"red.mov",name:"Red",duration:2)]
        var layer=OverlayLayer(clip:Clip(filename:"blue.mov",name:"Blue",duration:2));layer.clip.end=1;layer.timelineStart=0.5;layer.centerX=0.5;layer.centerY=0.5;layer.width=0.5;layer.height=0.5;layer.mask = .circle;layer.opacity=0.5;p.overlays=[layer]
        let url=root.appendingPathComponent("layers.mp4");try await MediaEngine.export(p,mediaRoot:root,to:url,size:CGSize(width:320,height:180))
        let generator=AVAssetImageGenerator(asset:AVURLAsset(url:url));generator.requestedTimeToleranceBefore = .zero;generator.requestedTimeToleranceAfter = .zero
        for t in [0.25,1.75]{let frame=try await generator.image(at:CMTime(seconds:t,preferredTimescale:600)).image;let c=centerPixel(frame).map(Int.init);XCTAssertGreaterThan(c[0],c[2]+100)}
        let frame=try await generator.image(at:CMTime(seconds:1,preferredTimescale:600)).image
        let center=centerPixel(frame).map(Int.init),corner=pixel(frame,x:85,y:50).map(Int.init)
        XCTAssertGreaterThan(center[0],70);XCTAssertGreaterThan(center[2],70);XCTAssertEqual(center[0],center[2],accuracy:20);XCTAssertGreaterThan(corner[0],corner[2]+100)
        var start=MotionKeyframe(time:0);start.x=0
        var end=MotionKeyframe(time:1);end.x=0.5;p.overlays=nil;p.clips[0].motion=MotionTrack(keyframes:[start,end])
        let motionURL=root.appendingPathComponent("motion.mp4");try await MediaEngine.export(p,mediaRoot:root,to:motionURL,size:CGSize(width:320,height:180))
        let moving=AVAssetImageGenerator(asset:AVURLAsset(url:motionURL));moving.requestedTimeToleranceBefore = .zero;moving.requestedTimeToleranceAfter = .zero
        let early=try await moving.image(at:CMTime(seconds:0.1,preferredTimescale:600)).image,late=try await moving.image(at:CMTime(seconds:1.8,preferredTimescale:600)).image
        XCTAssertGreaterThan(pixel(early,x:50,y:90)[0],180);XCTAssertLessThan(pixel(late,x:50,y:90)[0],30)
    }
    func testIndependentAudioPlacementVolumeAndFadesInDecodedOutput() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        try await makeVideo(at:root.appendingPathComponent("a.mov"),red:true)
        let format=AVAudioFormat(standardFormatWithSampleRate:44100,channels:1)!
        let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:176400)!;buffer.frameLength=176400
        for i in 0..<176400{buffer.floatChannelData![0][i]=Float(sin(Double(i)*440*2*Double.pi/44100)*0.4)}
        try AVAudioFile(forWriting:root.appendingPathComponent("tone.caf"),settings:format.settings).write(from:buffer)
        var p=Project();p.clips=[Clip(filename:"a.mov",name:"A",duration:2),Clip(filename:"a.mov",name:"B",duration:2)]
        var a=AudioRegion(filename:"tone.caf",name:"First",sourceDuration:4);a.sourceEnd=2;a.timelineStart=0.5;a.volume=0.5;a.fadeIn=0.5;a.fadeOut=0.5
        var b=AudioRegion(filename:"tone.caf",name:"Second",sourceDuration:4);b.sourceStart=1;b.sourceEnd=2;b.timelineStart=2.75;b.volume=0.25;p.audioRegions=[a,b]
        let url=root.appendingPathComponent("mix.mp4");try await MediaEngine.export(p,mediaRoot:root,to:url,size:CGSize(width:320,height:180))
        let asset=AVURLAsset(url:url)
        let reader=try AVAssetReader(asset:asset)
        let tracks=try await asset.loadTracks(withMediaType:.audio)
        let output=AVAssetReaderTrackOutput(track:try XCTUnwrap(tracks.first),outputSettings:[AVFormatIDKey:kAudioFormatLinearPCM,AVLinearPCMIsFloatKey:true,AVLinearPCMBitDepthKey:32,AVLinearPCMIsNonInterleaved:false])
        reader.add(output);XCTAssertTrue(reader.startReading())
        let windows:[ClosedRange<Double>]=[0.1...0.3,0.52...0.58,1.1...1.3,2.42...2.48,3.1...3.3,3.85...3.95]
        var sums=[Double](repeating:0,count:windows.count),counts=[Int](repeating:0,count:windows.count)
        while let sample=output.copyNextSampleBuffer(){
            let description=try XCTUnwrap(CMSampleBufferGetFormatDescription(sample));let asbd=try XCTUnwrap(CMAudioFormatDescriptionGetStreamBasicDescription(description)).pointee
            if let block=CMSampleBufferGetDataBuffer(sample){
                let length=CMBlockBufferGetDataLength(block);var values=[Float](repeating:0,count:length/4)
                let status=values.withUnsafeMutableBytes{CMBlockBufferCopyDataBytes(block,atOffset:0,dataLength:length,destination:$0.baseAddress!)};XCTAssertEqual(status,kCMBlockBufferNoErr)
                let start=CMSampleBufferGetPresentationTimeStamp(sample).seconds
                for (i,v) in values.enumerated(){let time=start+Double(i/Int(asbd.mChannelsPerFrame))/asbd.mSampleRate;for j in windows.indices where windows[j].contains(time){sums[j]+=Double(v*v);counts[j]+=1}}
            }
        }
        let rms=zip(sums,counts).map{sqrt($0.0/Double(max(1,$0.1)))}
        XCTAssertLessThan(rms[0],0.005);XCTAssertLessThan(rms[1],0.04);XCTAssertEqual(rms[2],0.1414,accuracy:0.018);XCTAssertLessThan(rms[3],0.04);XCTAssertEqual(rms[4],0.0707,accuracy:0.015);XCTAssertLessThan(rms[5],0.005)
        // The muxer may omit leading/trailing silent audio; active windows must contain decoded samples.
        XCTAssertTrue([1,2,3,4].allSatisfy{counts[$0]>100},"Decoded window counts: \(counts)");XCTAssertEqual(reader.status,.completed)
    }
    func testTimedMultilineCaptionsAppearOnlyInsideCueIncludingAcrossClipBoundary() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        try await makeVideo(at:root.appendingPathComponent("a.mov"),red:true)
        var p=Project();var clip=Clip(filename:"a.mov",name:"A",duration:2);clip.end=1;p.clips=[clip,Clip(filename:"a.mov",name:"B",duration:2)]
        var cue=TextCue(text:"Caption one\nسلام دنیا",start:0.5,end:1.5);cue.style.position = .center;p.captions=[cue]
        let url=root.appendingPathComponent("caption.mp4")
        try await MediaEngine.export(p,mediaRoot:root,to:url,size:CGSize(width:640,height:360))
        let generator=AVAssetImageGenerator(asset:AVURLAsset(url:url));generator.requestedTimeToleranceBefore = .zero;generator.requestedTimeToleranceAfter = .zero
        var counts:[Int]=[]
        for t in [0.2,0.75,1.25,1.75]{let frame=try await generator.image(at:CMTime(seconds:t,preferredTimescale:600)).image;counts.append(brightPixels(frame))}
        XCTAssertEqual(counts[0],0);XCTAssertGreaterThan(counts[1],100);XCTAssertGreaterThan(counts[2],100);XCTAssertEqual(counts[3],0)
    }
    func testRealExportHonorsTrimSpeedConcatenationAndCanvas() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try await makeVideo(at: root.appendingPathComponent("red.mov"), red: true)
        try await makeVideo(at: root.appendingPathComponent("blue.mov"), red: false)
        var p = Project(); var a = Clip(filename: "red.mov", name: "Red", duration: 2); a.start = 0.5; a.end = 1.5; a.speed = 2
        var b = Clip(filename: "blue.mov", name: "Blue", duration: 2); b.end = 1
        p.clips = [a,b]; p.title = "FrameCut"; p.canvas = .square
        let output = root.appendingPathComponent("out.mp4")
        try await MediaEngine.export(p, mediaRoot: root, to: output, size: CGSize(width: 320,height: 320))
        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration)
        XCTAssertEqual(duration.seconds, 1.5, accuracy: 0.1)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let size = try await track.load(.naturalSize)
        XCTAssertEqual(size.width,320); XCTAssertEqual(size.height,320)
        let generator = AVAssetImageGenerator(asset: asset); generator.appliesPreferredTrackTransform = true
        let first = try await generator.image(at: CMTime(seconds:0.2,preferredTimescale:600)).image
        let last = try await generator.image(at: CMTime(seconds:1.1,preferredTimescale:600)).image
        XCTAssertGreaterThan(brightPixels(first),20,"The title must be burned into the exported frames")
        let color1 = centerPixel(first); let color2 = centerPixel(last)
        XCTAssertGreaterThan(color1[0],color1[2]+100); XCTAssertGreaterThan(color2[2],color2[0]+100)
    }
    func testExportAppliesMonoFadeAndFrameRate() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer {try? FileManager.default.removeItem(at:root)}
        try await makeVideo(at:root.appendingPathComponent("a.mov"),red:true)
        var p=Project();var clip=Clip(filename:"a.mov",name:"A",duration:2)
        var e=ClipEffects();e.look = .mono;e.cutStyle = .fadeBlack;clip.effects=e;p.clips=[clip]
        var style=ProjectStyle();style.fps=24;style.resolution = .hd720;p.style=style
        let plan=try await MediaEngine.build(p,mediaRoot:root)
        XCTAssertEqual(plan.videoComposition.renderSize.width,1280);XCTAssertEqual(plan.videoComposition.renderSize.height,720)
        let url=root.appendingPathComponent("effect.mp4")
        try await MediaEngine.export(p,mediaRoot:root,to:url,size:CGSize(width:320,height:180))
        let asset=AVURLAsset(url:url);let generator=AVAssetImageGenerator(asset:asset)
        generator.requestedTimeToleranceBefore = .zero;generator.requestedTimeToleranceAfter = .zero
        let first=try await generator.image(at:.zero).image
        let middle=try await generator.image(at:CMTime(seconds:1,preferredTimescale:600)).image
        let start=centerPixel(first).map(Double.init);let mid=centerPixel(middle).map(Double.init)
        XCTAssertLessThan(start[0],30);XCTAssertGreaterThan(mid[0],40)
        XCTAssertEqual(mid[0],mid[1],accuracy:4);XCTAssertEqual(mid[1],mid[2],accuracy:4)
        let tracks=try await asset.loadTracks(withMediaType:.video)
        let fps=try await XCTUnwrap(tracks.first).load(.nominalFrameRate);XCTAssertEqual(fps,24,accuracy:0.1)
    }
    func testExportMirrorAndQuarterTurnTransformActualFrames() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        try await makeVideo(at:root.appendingPathComponent("pattern.mov"),red:true,pattern:true)
        var p=Project();p.clips=[Clip(filename:"pattern.mov",name:"Pattern",duration:2)]
        var e=ClipEffects();e.mirrored=true;p.clips[0].effects=e
        let mirrored=root.appendingPathComponent("mirror.mp4")
        try await MediaEngine.export(p,mediaRoot:root,to:mirrored,size:CGSize(width:320,height:180))
        let a=try await AVAssetImageGenerator(asset:AVURLAsset(url:mirrored)).image(at:CMTime(seconds:1,preferredTimescale:600)).image
        let left=pixel(a,x:80,y:90).map(Int.init),right=pixel(a,x:240,y:90).map(Int.init)
        XCTAssertGreaterThan(left[2],left[0]+100);XCTAssertGreaterThan(right[0],right[2]+100)
        e.mirrored=false;e.quarterTurns=1;p.clips[0].effects=e
        let rotated=root.appendingPathComponent("rotate.mp4")
        try await MediaEngine.export(p,mediaRoot:root,to:rotated,size:CGSize(width:180,height:320))
        let b=try await AVAssetImageGenerator(asset:AVURLAsset(url:rotated)).image(at:CMTime(seconds:1,preferredTimescale:600)).image
        let lower=pixel(b,x:90,y:80).map(Int.init),upper=pixel(b,x:90,y:240).map(Int.init)
        XCTAssertGreaterThan(lower[2],lower[0]+100);XCTAssertGreaterThan(upper[0],upper[2]+100)
    }
    func testFourKThirtyFPSExportProducesRequestedTrack() async throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer{try? FileManager.default.removeItem(at:root)}
        try await makeVideo(at:root.appendingPathComponent("a.mov"),red:true)
        var p=Project();var c=Clip(filename:"a.mov",name:"A",duration:2);c.end=0.5;p.clips=[c]
        var style=ProjectStyle();style.resolution = .ultraHD;style.fps=30;p.style=style
        let output=root.appendingPathComponent("4k.mp4");try await MediaEngine.export(p,mediaRoot:root,to:output)
        let asset=AVURLAsset(url:output);let tracks=try await asset.loadTracks(withMediaType:.video);let track=try XCTUnwrap(tracks.first)
        let size=try await track.load(.naturalSize);let fps=try await track.load(.nominalFrameRate)
        XCTAssertEqual(size.width,3840);XCTAssertEqual(size.height,2160);XCTAssertEqual(fps,30,accuracy:0.1)
    }
    func testEmptyTimelineFailsBeforeWriting() async throws {
        do { _ = try await MediaEngine.build(Project(), mediaRoot: FileManager.default.temporaryDirectory); XCTFail("Empty timeline accepted") }
        catch { XCTAssertTrue(error is EditError) }
    }
    func testMusicIsExportedAtRequestedVolume() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        try await makeVideo(at:root.appendingPathComponent("video.mov"),red:true)
        let format=AVAudioFormat(standardFormatWithSampleRate:44100,channels:1)!
        let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:88200)!;buffer.frameLength=88200
        for i in 0..<88200 { buffer.floatChannelData![0][i] = Float(sin(Double(i)*440*2*Double.pi/44100)*0.4) }
        let file=try AVAudioFile(forWriting:root.appendingPathComponent("tone.caf"),settings:format.settings);try file.write(from:buffer)
        var p=Project();p.clips=[Clip(filename:"video.mov",name:"Video",duration:2)];p.musicFilename="tone.caf";p.musicVolume=0.25
        let url=root.appendingPathComponent("music.mp4")
        try await MediaEngine.export(p,mediaRoot:root,to:url,size:CGSize(width:320,height:180))
        let asset=AVURLAsset(url:url);let tracks=try await asset.loadTracks(withMediaType:.audio)
        let track=try XCTUnwrap(tracks.first)
        let reader=try AVAssetReader(asset:asset)
        let output=AVAssetReaderTrackOutput(track:track,outputSettings:[AVFormatIDKey:kAudioFormatLinearPCM,AVLinearPCMIsFloatKey:true,AVLinearPCMBitDepthKey:32,AVLinearPCMIsNonInterleaved:false])
        reader.add(output);XCTAssertTrue(reader.startReading())
        var energy:Double=0;var count=0
        while let sample=output.copyNextSampleBuffer() {
            if let block=CMSampleBufferGetDataBuffer(sample) {
                let length=CMBlockBufferGetDataLength(block);var samples=[Float](repeating:0,count:length/4)
                let status=samples.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block,atOffset:0,dataLength:length,destination:$0.baseAddress!) };XCTAssertEqual(status,kCMBlockBufferNoErr)
                for value in samples {energy += Double(value*value);count += 1}
            }
        }
        XCTAssertGreaterThan(count,80000)
        XCTAssertEqual(sqrt(energy/Double(max(1,count))),0.0707,accuracy:0.015)
        XCTAssertEqual(reader.status,.completed)
    }
    private func brightPixels(_ image: CGImage) -> Int {
        let w=image.width,h=image.height
        var bytes=[UInt8](repeating:0,count:w*h*4)
        bytes.withUnsafeMutableBytes { b in
            let c=CGContext(data:b.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.draw(image,in:CGRect(x:0,y:0,width:w,height:h))
        }
        return stride(from:0,to:bytes.count,by:4).filter {bytes[$0]>210 && bytes[$0+1]>210 && bytes[$0+2]>210}.count
    }
    private func centerPixel(_ image:CGImage)->[UInt8] { pixel(image,x:image.width/2,y:image.height/2) }
    private func pixel(_ image: CGImage,x:Int,y:Int) -> [UInt8] {
        var bytes = [UInt8](repeating:0,count:4)
        bytes.withUnsafeMutableBytes { buffer in
            let c = CGContext(data:buffer.baseAddress,width:1,height:1,bitsPerComponent:8,bytesPerRow:4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.translateBy(x: -CGFloat(x), y: -CGFloat(y)); c.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
        }; return bytes
    }
    private func makeVideo(at url: URL, red: Bool, pattern:Bool=false,timeSwitch:Bool=false,switchFrame:Int=30) async throws {
        let writer = try AVAssetWriter(url:url,fileType:.mov)
        let input = AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:320,AVVideoHeightKey:180])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:320,kCVPixelBufferHeightKey as String:180])
        writer.add(input); writer.startWriting(); writer.startSession(atSourceTime:.zero)
        for i in 0..<60 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds:1_000_000) }
            var buffer: CVPixelBuffer?; CVPixelBufferCreate(kCFAllocatorDefault,320,180,kCVPixelFormatType_32ARGB,nil,&buffer)
            let b = try XCTUnwrap(buffer); CVPixelBufferLockBaseAddress(b,[])
            let data = CVPixelBufferGetBaseAddress(b)!.assumingMemoryBound(to:UInt8.self); let stride = CVPixelBufferGetBytesPerRow(b)
            for y in 0..<180 { for x in 0..<320 { let o = y*stride+x*4; let isRed=timeSwitch ? i<switchFrame : pattern ? x<160 : red;data[o]=255;data[o+1]=isRed ? 230 : 10;data[o+2]=20;data[o+3]=isRed ? 10 : 230 } }
            CVPixelBufferUnlockBaseAddress(b,[])
            XCTAssertTrue(adaptor.append(b,withPresentationTime:CMTime(value:Int64(i),timescale:30)))
        }
        input.markAsFinished(); await writer.finishWriting(); XCTAssertEqual(writer.status,.completed)
    }
}
