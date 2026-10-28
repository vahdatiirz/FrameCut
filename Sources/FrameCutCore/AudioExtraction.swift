import Foundation
import AVFoundation

extension MediaEngine {
    /// Exports the edited audio mix with silence preserved, so recognition timestamps match the film.
    public static func exportAudio(_ project:Project,mediaRoot:URL,to url:URL) async throws {
        let timeline=try await build(project,mediaRoot:mediaRoot,size:CGSize(width:320,height:180))
        let tracks=try await timeline.composition.loadTracks(withMediaType:.audio)
        guard !tracks.isEmpty else{throw EditError.missingAudio}
        let reader=try AVAssetReader(asset:timeline.composition)
        let output=AVAssetReaderAudioMixOutput(audioTracks:tracks,audioSettings:[AVFormatIDKey:kAudioFormatLinearPCM,AVSampleRateKey:16000,AVNumberOfChannelsKey:1,AVLinearPCMBitDepthKey:32,AVLinearPCMIsFloatKey:true,AVLinearPCMIsBigEndianKey:false,AVLinearPCMIsNonInterleaved:false])
        output.audioMix=timeline.audioMix;output.alwaysCopiesSampleData=false
        guard reader.canAdd(output) else{throw EditError.invalidProject};reader.add(output)
        let format=AVAudioFormat(standardFormatWithSampleRate:16000,channels:1)!
        let file=try AVAudioFile(forWriting:url,settings:format.settings)
        let total=Int64(ceil(project.duration*16000))
        func silence(until end:Int64) throws {
            while file.framePosition<end{
                let count=AVAudioFrameCount(min(4096,end-file.framePosition))
                guard let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:count),let samples=buffer.floatChannelData?[0] else{throw EditError.invalidProject}
                buffer.frameLength=count;samples.initialize(repeating:0,count:Int(count));try file.write(from:buffer)
            }
        }
        do{
            guard reader.startReading() else{throw reader.error ?? EditError.invalidProject}
            while let sample=output.copyNextSampleBuffer(){
                try Task.checkCancellation()
                guard let block=CMSampleBufferGetDataBuffer(sample) else{throw EditError.invalidProject}
                let at=max(0,Int64((CMSampleBufferGetPresentationTimeStamp(sample).seconds*16000).rounded()))
                try silence(until:min(at,total))
                let skip=max(0,file.framePosition-at)
                let count=min(Int64(CMSampleBufferGetNumSamples(sample))-skip,total-file.framePosition)
                guard count>0 else{continue}
                guard let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:AVAudioFrameCount(count)),let samples=buffer.floatChannelData?[0] else{throw EditError.invalidProject}
                buffer.frameLength=AVAudioFrameCount(count)
                guard CMBlockBufferCopyDataBytes(block,atOffset:Int(skip)*4,dataLength:Int(count)*4,destination:samples)==kCMBlockBufferNoErr else{throw EditError.invalidProject}
                try file.write(from:buffer)
            }
            guard reader.status == .completed else{throw reader.error ?? EditError.invalidProject}
            try silence(until:total)
        }catch{reader.cancelReading();try? FileManager.default.removeItem(at:url);throw error}
    }
}
