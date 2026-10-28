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
            stage="Edited film export";report()
            var style=ProjectStyle();style.resolution = .hd720;style.fps=30;p.style=style
            if p.clips.count>1{p.transitions=[ClipTransition(from:p.clips[0].id,to:p.clips[1].id,duration:0.4)]}
            var effects=ClipEffects();effects.look = .chrome;p.clips[0].effects=effects
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
            passed("Edited film export","720p30 with audio, captions, motion, overlay, transition and persisted project")
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
