import Foundation
import AVFoundation

enum MediaExporter {
    static func write(_ timeline:RenderedTimeline,style:ProjectStyle,to url:URL) async throws {
        let reader=try AVAssetReader(asset:timeline.composition)
        let writer=try AVAssetWriter(url:url,fileType:.mp4)
        let size=timeline.videoComposition.renderSize
        let videoTracks=try await timeline.composition.loadTracks(withMediaType:.video)
        let video=AVAssetReaderVideoCompositionOutput(videoTracks:videoTracks,videoSettings:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA])
        video.videoComposition=timeline.videoComposition;video.alwaysCopiesSampleData=false
        guard reader.canAdd(video) else{throw EditError.invalidProject};reader.add(video)
        let automatic=Double(size.width*size.height)*Double(style.fps)*0.12
        let bitrate=style.bitRateMbps.map{$0*1_000_000} ?? max(2_000_000,min(100_000_000,automatic))
        let videoInput=AVAssetWriterInput(mediaType:.video,outputSettings:[
            AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:Int(size.width),AVVideoHeightKey:Int(size.height),
            AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:Int(bitrate),AVVideoExpectedSourceFrameRateKey:style.fps,AVVideoProfileLevelKey:AVVideoProfileLevelH264HighAutoLevel]])
        videoInput.expectsMediaDataInRealTime=false
        guard writer.canAdd(videoInput) else{throw EditError.invalidProject};writer.add(videoInput)
        var audioPair:(AVAssetReaderAudioMixOutput,AVAssetWriterInput)?
        let audioTracks=try await timeline.composition.loadTracks(withMediaType:.audio)
        if !audioTracks.isEmpty {
            let audio=AVAssetReaderAudioMixOutput(audioTracks:audioTracks,audioSettings:[AVFormatIDKey:kAudioFormatLinearPCM,AVSampleRateKey:44100,AVNumberOfChannelsKey:2,AVLinearPCMBitDepthKey:16,AVLinearPCMIsFloatKey:false,AVLinearPCMIsBigEndianKey:false,AVLinearPCMIsNonInterleaved:false])
            audio.audioMix=timeline.audioMix;audio.alwaysCopiesSampleData=false
            let input=AVAssetWriterInput(mediaType:.audio,outputSettings:[AVFormatIDKey:kAudioFormatMPEG4AAC,AVSampleRateKey:44100,AVNumberOfChannelsKey:2,AVEncoderBitRateKey:192000])
            guard reader.canAdd(audio),writer.canAdd(input) else{throw EditError.invalidProject}
            reader.add(audio);writer.add(input);audioPair=(audio,input)
        }
        do {
            guard writer.startWriting() else{throw writer.error ?? EditError.invalidProject}
            writer.startSession(atSourceTime:.zero)
            guard reader.startReading() else{throw reader.error ?? EditError.invalidProject}
            try await withThrowingTaskGroup(of:Void.self){group in
                group.addTask{try await pump(video,into:videoInput,reader:reader,writer:writer)}
                if let (audio,input)=audioPair{group.addTask{try await pump(audio,into:input,reader:reader,writer:writer)}}
                while let _=try await group.next() {}
            }
            guard reader.status == .completed else{throw reader.error ?? EditError.invalidProject}
            writer.endSession(atSourceTime:timeline.composition.duration)
            await writer.finishWriting()
            guard writer.status == .completed else{throw writer.error ?? EditError.invalidProject}
        }catch{reader.cancelReading();writer.cancelWriting();try? FileManager.default.removeItem(at:url);throw error}
    }
    private static func pump(_ output:AVAssetReaderOutput,into input:AVAssetWriterInput,reader:AVAssetReader,writer:AVAssetWriter) async throws {
        while true {
            try Task.checkCancellation()
            guard reader.status != .failed,reader.status != .cancelled else{throw reader.error ?? EditError.invalidProject}
            guard writer.status == .writing else{throw writer.error ?? EditError.invalidProject}
            if !input.isReadyForMoreMediaData{try await Task.sleep(nanoseconds:1_000_000);continue}
            let sample=autoreleasepool{output.copyNextSampleBuffer()}
            guard let sample else{
                guard reader.status != .failed else{throw reader.error ?? EditError.invalidProject}
                input.markAsFinished();return
            }
            guard input.append(sample) else{throw writer.error ?? EditError.invalidProject}
        }
    }
}
