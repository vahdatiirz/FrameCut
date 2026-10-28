import Foundation
import WhisperKit

actor OfflineSpeechEngine {
    private var pipeline:WhisperKit?
    private let folder:URL
    init(modelFolder:URL?=nil){folder=modelFolder ?? Bundle.main.resourceURL!.appendingPathComponent("WhisperTiny",isDirectory:true)}
    func transcribe(audio:URL,language:String?,duration:Double) async throws -> [TextCue] {
        if pipeline==nil{
            for name in ["AudioEncoder.mlmodelc","TextDecoder.mlmodelc","MelSpectrogram.mlmodelc","Tokenizer/tokenizer.json","Tokenizer/tokenizer_config.json"]{
                guard FileManager.default.fileExists(atPath:folder.appendingPathComponent(name).path) else{throw OfflineSpeechError.modelMissing}
            }
            pipeline=try await WhisperKit(WhisperKitConfig(modelFolder:folder.path,tokenizerFolder:folder.appendingPathComponent("Tokenizer"),verbose:false,logLevel:.error,prewarm:false,load:true,download:false))
        }
        guard let pipeline else{throw OfflineSpeechError.modelMissing}
        let options=DecodingOptions(language:language,skipSpecialTokens:true,wordTimestamps:true,concurrentWorkerCount:1,chunkingStrategy:.vad)
        let result=try await pipeline.transcribe(audioPath:audio.path,audioInputOptions:AudioInputOptions(audioLoadingMode:.incremental),decodeOptions:options)
        var cues:[TextCue]=[]
        for segment in result.flatMap(\.segments){
            let text=segment.text.trimmingCharacters(in:.whitespacesAndNewlines)
            let start=max(0,Double(segment.start)),end=min(duration,Double(segment.end))
            guard !text.isEmpty,start.isFinite,end.isFinite,end>start else{continue}
            var cue=TextCue(text:text,start:start,end:end);cue.style.boxed=true
            cue.words=segment.words?.compactMap{word in
                let a=max(start,Double(word.start)),b=min(end,Double(word.end))
                guard a.isFinite,b.isFinite,b>a,!word.word.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{return nil}
                return CaptionWord(text:word.word,start:a,end:b)
            }
            try cue.validate();cues.append(cue)
        }
        guard !cues.isEmpty else{throw OfflineSpeechError.noSpeech}
        return cues
    }
}
enum OfflineSpeechError:Error,LocalizedError {
    case modelMissing,noSpeech
    var errorDescription:String?{switch self{case .modelMissing:return "The bundled speech model is missing. Reinstall an intact FrameCut build.";case .noSpeech:return "No clear speech was detected. Try a clip with a clear voice or select the spoken language."}}
}
