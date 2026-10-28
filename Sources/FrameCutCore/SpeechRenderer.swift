import Foundation
import AVFoundation

@MainActor public enum SpeechRenderer {
    public static func render(_ text:String,voiceIdentifier:String?,rate:Float,to url:URL) async throws {
        guard !text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,text.count<=10000,rate.isFinite,
              (AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate).contains(rate) else{throw EditError.invalidProject}
        let voice=voiceIdentifier.flatMap{AVSpeechSynthesisVoice(identifier:$0)} ?? AVSpeechSynthesisVoice(language:"en-US")
        guard let voice else{throw EditError.missingAudio}
        let synthesizer=AVSpeechSynthesizer(),sink=SpeechAudioSink(url:url)
        let utterance=AVSpeechUtterance(string:text);utterance.voice=voice;utterance.rate=rate
        do{
            try Task.checkCancellation()
            try await withTaskCancellationHandler(operation:{
                try await withCheckedThrowingContinuation{continuation in
                    sink.begin(continuation)
                    synthesizer.write(utterance){buffer in sink.consume(buffer)}
                }
            },onCancel:{sink.cancel();Task{@MainActor in synthesizer.stopSpeaking(at:.immediate)}})
        }catch{synthesizer.stopSpeaking(at:.immediate);try? FileManager.default.removeItem(at:url);throw error}
    }
}
private final class SpeechAudioSink:@unchecked Sendable {
    private let lock=NSLock()
    private let url:URL
    private var file:AVAudioFile?
    private var continuation:CheckedContinuation<Void,Error>?
    private var outcome:Result<Void,Error>?
    init(url:URL){self.url=url}
    func begin(_ continuation:CheckedContinuation<Void,Error>){
        lock.lock()
        if let outcome{lock.unlock();continuation.resume(with:outcome)}else{self.continuation=continuation;lock.unlock()}
    }
    func cancel(){complete(.failure(CancellationError()))}
    func consume(_ buffer:AVAudioBuffer){
        lock.lock()
        guard outcome==nil else{lock.unlock();return}
        guard let pcm=buffer as? AVAudioPCMBuffer else{lock.unlock();complete(.failure(EditError.missingAudio));return}
        if pcm.frameLength==0{
            let hasAudio=(file?.length ?? 0)>0;lock.unlock();complete(hasAudio ? .success(()) : .failure(EditError.missingAudio));return
        }
        do{if file==nil{file=try AVAudioFile(forWriting:url,settings:pcm.format.settings,commonFormat:pcm.format.commonFormat,interleaved:pcm.format.isInterleaved)};try file?.write(from:pcm);lock.unlock()}
        catch{lock.unlock();complete(.failure(error))}
    }
    private func complete(_ result:Result<Void,Error>){
        lock.lock();guard outcome==nil else{lock.unlock();return}
        outcome=result;file=nil;let waiting=continuation;continuation=nil;lock.unlock();waiting?.resume(with:result)
    }
}
