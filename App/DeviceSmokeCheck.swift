#if DEBUG
import Foundation
import AVFoundation
import CoreImage
import UIKit

/// Explicit development launch mode; fixtures and results stay outside the user's project store.
@MainActor enum DeviceSmokeCheck {
    static func run() async {
        let root=FileManager.default.urls(for:.documentDirectory,in:.userDomainMask)[0].appendingPathComponent("FrameCutVerification",isDirectory:true)
        let folder=root.appendingPathComponent(UUID().uuidString,isDirectory:true)
        var checks:[[String:Any]]=[]
        var stage="Fixture setup"
        func report(_ success:Bool?=nil){
            var data:[String:Any]=["version":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") ?? "unknown","build":Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") ?? "unknown","system":UIDevice.current.systemVersion,"deviceClass":UIDevice.current.model,"folder":folder.lastPathComponent,"stage":stage,"checks":checks]
            if let success{data["success"]=success}
            if let json=try? JSONSerialization.data(withJSONObject:data,options:[.prettyPrinted,.sortedKeys]){try? json.write(to:root.appendingPathComponent("latest.json"),options:.atomic)}
        }
        func require(_ condition:Bool,_ message:String) throws {if !condition{throw NSError(domain:"FrameCutSmoke",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
        func passed(_ name:String,_ details:String){checks.append(["name":name,"passed":true,"details":details]);stage=name;report()}
        do{
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
            guard let fixtures=Bundle.main.resourceURL?.appendingPathComponent("SmokeFixtures") else{throw EditError.invalidProject}
            for name in ["Dawn.mov","Dusk.mov","Speech.wav"]{try FileManager.default.copyItem(at:fixtures.appendingPathComponent(name),to:folder.appendingPathComponent(name))}
            var p=Project();p.name="Device verification — synthetic media"
            for name in ["Dawn.mov","Dusk.mov","Dawn.mov"]{let duration=try await AVURLAsset(url:folder.appendingPathComponent(name)).load(.duration).seconds;p.clips.append(Clip(filename:name,name:name,duration:duration))}
            let voice=try AVAudioFile(forReading:folder.appendingPathComponent("Speech.wav"))
            p.audioRegions=[AudioRegion(filename:"Speech.wav",name:"Synthetic speech",sourceDuration:Double(voice.length)/voice.processingFormat.sampleRate)]
            passed("Fixtures","Three synthetic clips and known English speech; user projects untouched")
            let sampleDraft=try SampleProject.make(first:p.clips[0],second:p.clips[1])
            let sampleStore=try ProjectStore(root:folder.appendingPathComponent("SampleDrafts"));try sampleStore.save(sampleDraft)
            try require(try sampleStore.load(sampleDraft.id)==sampleDraft && sampleDraft.clips.count==2 && sampleDraft.overlays?.count==1,"Sample draft round-trip failed")
            passed("Sample draft","Separate editable sample with two source clips and one overlay persisted successfully")
            stage="Offline captions";report()
            let audio=folder.appendingPathComponent("edited-audio.caf")
            try await MediaEngine.exportAudio(p,mediaRoot:folder,to:audio)
            let speech=OfflineSpeechEngine()
            let cues=try await speech.transcribe(audio:audio,language:"en",duration:p.duration)
            let transcript=cues.map(\.text).joined(separator:" ").lowercased()
            try require(transcript.contains("film") && transcript.contains("music"),"Unexpected generated transcript: "+transcript)
            try require(cues.contains{!($0.words ?? []).isEmpty},"Word timestamps missing")
            p.captions=cues
            passed("Offline captions","Bundled model produced timed words: "+transcript)
            stage="Offline text to speech";report()
            let narration=folder.appendingPathComponent("narration.caf")
            try await SpeechRenderer.render("FrameCut makes a short film with music and captions.",voiceIdentifier:AVSpeechSynthesisVoice(language:"en-US")?.identifier,rate:0.5,to:narration)
            let spoken=try AVAudioFile(forReading:narration)
            try require(spoken.length>10000,"Speech output is empty")
            let spokenCues=try await speech.transcribe(audio:narration,language:"en",duration:Double(spoken.length)/spoken.processingFormat.sampleRate)
            let spokenText=spokenCues.map(\.text).joined(separator:" ").lowercased()
            try require(spokenText.contains("film") && spokenText.contains("music"),"Synthesized speech failed recognition: "+spokenText)
            passed("Offline text to speech","Generated local narration and recognized its words")
            stage="Looks and FX frames";report()
            let generator=AVAssetImageGenerator(asset:AVURLAsset(url:fixtures.appendingPathComponent("Dawn.mov")))
            generator.appliesPreferredTrackTransform=true;generator.maximumSize=CGSize(width:360,height:240)
            let sample=CIImage(cgImage:try await generator.image(at:.zero).image)
            let context=CIContext()
            var golden=ClipEffects();golden.look = .golden
            try context.writePNGRepresentation(of:ColorPipeline.apply(sample,effects:golden),to:folder.appendingPathComponent("Look-Golden-preview.png"),format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB())
            for look in Look.allCases{var e=ClipEffects();e.look=look;try require(context.createCGImage(ColorPipeline.apply(sample,effects:e),from:sample.extent) != nil,"Look render failed: "+look.rawValue)}
            for kind in VisualFXKind.allCases{try require(context.createCGImage(VisualFXPipeline.apply(sample,effects:[VisualFX(kind:kind)],progress:0.5),from:sample.extent) != nil,"FX render failed: "+kind.rawValue)}
            var rgba=[UInt8](repeating:0,count:4)
            let solid=CIImage(color:CIColor(red:1,green:0,blue:0)).cropped(to:CGRect(x:0,y:0,width:160,height:90))
            context.render(VisualFXPipeline.apply(solid,effects:[VisualFX(kind:.invert)],progress:0.5),toBitmap:&rgba,rowBytes:4,bounds:CGRect(x:80,y:45,width:1,height:1),format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB())
            try require(rgba[0]<10 && rgba[1]>240 && rgba[2]>240,"FX inversion pixel mismatch")
            passed("Looks and FX frames","Bundled Dawn frame at zero loaded; 30 look choices and 12 FX rendered; Golden preview saved and inversion pixel verified")
            stage="Transition renderers";report()
            let transitionBounds=CGRect(x:0,y:0,width:160,height:90)
            let red=CIImage(color:CIColor(red:1,green:0,blue:0)).cropped(to:transitionBounds)
            let blue=CIImage(color:CIColor(red:0,green:0,blue:1)).cropped(to:transitionBounds)
            for transitionStyle in TransitionStyle.allCases {
                for t in [0.0,0.35,1.0] {
                    let frame=TransitionRenderer.render(red,to:blue,style:transitionStyle,progress:t,bounds:transitionBounds)
                    var pixel=[UInt8](repeating:0,count:4)
                    context.render(frame,toBitmap:&pixel,rowBytes:4,bounds:CGRect(x:80,y:45,width:1,height:1),format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB())
                    try require(pixel[3]==255,"Transparent transition: \(transitionStyle)")
                    if t==0{try require(pixel[0]>240 && pixel[2]<10,"Transition start mismatch")}
                    if t==1{try require(pixel[2]>240 && pixel[0]<10,"Transition end mismatch")}
                }
            }
            passed("Transition renderers","\(TransitionStyle.allCases.count) styles rendered on this device; start/end color and intermediate opacity checked")
            stage="Atmosphere film exports";report()
            for kind in [TransitionStyle.smokeDrift,.confetti,.goldConfetti] {
                var film=Project();film.clips=Array(p.clips.prefix(2))
                var profile=ProjectStyle();profile.resolution = .hd720;profile.fps=30;film.style=profile
                try film.setTransition(from:film.clips[0].id,to:film.clips[1].id,style:kind,duration:1.4)
                let output=folder.appendingPathComponent("Atmosphere-\(kind.rawValue).mp4")
                try await MediaEngine.export(film,mediaRoot:folder,to:output)
                let movie=AVURLAsset(url:output),videoTracks=try await movie.loadTracks(withMediaType:.video)
                guard let videoTrack=videoTracks.first else{throw EditError.missingVideo}
                let reader=try AVAssetReader(asset:movie)
                let frames=AVAssetReaderTrackOutput(track:videoTrack,outputSettings:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA])
                reader.add(frames);try require(reader.startReading(),"Atmosphere reader failed: \(kind)")
                var count=0
                while let sample=frames.copyNextSampleBuffer(){try require(CMSampleBufferGetImageBuffer(sample) != nil,"Missing atmosphere frame");count+=1}
                try require(reader.status == .completed && count==138,"Atmosphere decode failed: \(kind), \(count) frames")
                try require(abs((try await movie.load(.duration).seconds)-4.6)<0.04,"Atmosphere export duration mismatch")
            }
            passed("Atmosphere film exports","Smoke Drift, Confetti and Gold Confetti each exported at 720p30 with 1.4-second overlap; all 138 frames per film decoded on this device")
            stage="Edited film export";report()
            var style=ProjectStyle();style.resolution = .hd720;style.fps=30;p.style=style
            if p.clips.count>1{try p.setTransition(from:p.clips[0].id,to:p.clips[1].id,style:.circle,duration:0.4,applyToAll:true)}
            var effects=ClipEffects();effects.look = .golden;effects.visualFX=[VisualFX(kind:.bloom)];p.clips[0].effects=effects
            var a=MotionKeyframe(time:0),b=MotionKeyframe(time:1);a.scale=1;b.scale=1.1;p.clips[0].motion=MotionTrack(keyframes:[a,b])
            var overlay=OverlayLayer(clip:Clip(filename:"Dusk.mov",name:"Overlay",duration:p.clips[1].sourceDuration));overlay.timelineStart=1;overlay.opacity=0.7;overlay.mask = .circle;p.overlays=[overlay]
            let store=try ProjectStore(root:folder.appendingPathComponent("Projects"));try store.save(p);try require(try store.load(p.id)==p,"Project persistence mismatch")
            let movie=folder.appendingPathComponent("Edited.mp4")
            try await MediaEngine.export(p,mediaRoot:folder,to:movie)
            let asset=AVURLAsset(url:movie),tracks=try await AVURLAsset(url:movie).loadTracks(withMediaType:.video)
            guard let track=tracks.first else{throw EditError.missingVideo}
            let dimensions=try await track.load(.naturalSize),fps=try await track.load(.nominalFrameRate),duration=try await asset.load(.duration).seconds
            try require(dimensions.width==1280 && dimensions.height==720 && abs(fps-30)<0.1 && abs(duration-p.duration)<0.1,"Unexpected edited export metadata")
            let audioTracks=try await asset.loadTracks(withMediaType:.audio);try require(!audioTracks.isEmpty,"Missing exported audio")
            let snapshot=try await AVAssetImageGenerator(asset:asset).image(at:CMTime(seconds:1.5,preferredTimescale:600)).image
            try CIContext().writePNGRepresentation(of:CIImage(cgImage:snapshot),to:folder.appendingPathComponent("Edited-frame.png"),format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!)
            passed("Edited film export","720p30 with Golden look, Bloom FX, audio, captions, motion, overlay, transition and persisted project")
            stage="4K60 export";report()
            var fourK=Project();var clip=p.clips[0];clip.id=UUID();clip.start=0;clip.end=0.5;clip.effects=nil;clip.motion=nil;fourK.clips=[clip]
            var full=ProjectStyle();full.resolution = .ultraHD;full.fps=60;fourK.style=full
            let high=folder.appendingPathComponent("4K60.mp4");try await MediaEngine.export(fourK,mediaRoot:folder,to:high)
            let highAsset=AVURLAsset(url:high),highTracks=try await AVURLAsset(url:high).loadTracks(withMediaType:.video)
            guard let highTrack=highTracks.first else{throw EditError.missingVideo}
            let highSize=try await highTrack.load(.naturalSize),highFPS=try await highTrack.load(.nominalFrameRate)
            try require(highSize.width==3840 && highSize.height==2160 && abs(highFPS-60)<0.1,"4K60 track metadata mismatch")
            let reader=try AVAssetReader(asset:highAsset),ownTracks=try await highAsset.loadTracks(withMediaType:.video)
            guard let own=ownTracks.first else{throw EditError.missingVideo}
            let output=AVAssetReaderTrackOutput(track:own,outputSettings:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA]);reader.add(output)
            try require(reader.startReading(),"Cannot decode 4K60 output");var count=0
            while let sample=output.copyNextSampleBuffer(){try require(CMSampleBufferGetImageBuffer(sample) != nil,"Missing decoded frame");count+=1}
            try require(reader.status == .completed && count==30,"4K60 expected 30 decoded frames, got \(count)")
            passed("4K60 export","3840×2160, 60 fps, exactly 30 decoded frames in 0.5 seconds")
            stage="Complete";report(true)
        }catch{checks.append(["name":stage,"passed":false,"details":error.localizedDescription]);report(false)}
    }
}
#endif
