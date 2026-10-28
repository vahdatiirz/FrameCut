import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct AudioEditorView:View {
    @EnvironmentObject var model:EditorModel
    @State private var importing=false
    @State private var loading=false
    @State private var draft:AudioRegion?
    @State private var speechSheet=false
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Build your soundtrack.").font(.title.bold())
            Text("Layer music, voice and sound effects. Import audio files or extract the audio track from a video. Every region has its own timing and fades.").foregroundStyle(.secondary)
            Button("Import audio or video",systemImage:"waveform.badge.plus"){importing=true}.buttonStyle(.borderedProminent).disabled(loading)
            Button("Text to speech · offline",systemImage:"text.bubble"){speechSheet=true}.buttonStyle(.bordered).disabled(model.busy)
            if loading{ProgressView("Importing audio…")}
            ForEach(model.project.audioRegions ?? []){region in
                HStack {
                    Button{draft=region}label:{VStack(alignment:.leading,spacing:6){Text(region.name).font(.headline);Text(String(format:"%.2f – %.2f s · %.0f%%",region.timelineStart,region.timelineStart+region.duration,region.volume*100)).font(.caption.monospaced()).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading)}.buttonStyle(.plain)
                    Button("Duplicate",systemImage:"plus.square.on.square"){model.update{p in var copy=region;copy.id=UUID();p.audioRegions=(p.audioRegions ?? [])+[copy]}}.labelStyle(.iconOnly)
                    Button("Delete",systemImage:"trash",role:.destructive){model.update{$0.audioRegions?.removeAll{$0.id==region.id}}}.labelStyle(.iconOnly)
                }.padding(14).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:14))
            }
            if model.project.musicFilename != nil{Text("The film’s original background music remains available in the editor’s Music controls.").font(.caption).foregroundStyle(.secondary)}
        }
        .fileImporter(isPresented:$importing,allowedContentTypes:[.audio,.movie],allowsMultipleSelection:true){result in
            Task {
                loading=true;defer{loading=false}
                var copied:[String]=[]
                do {
                    var regions:[AudioRegion]=[]
                    for url in try result.get(){
                        let filename=try model.copyMedia(url);copied.append(filename)
                        let asset=AVURLAsset(url:model.mediaRoot.appendingPathComponent(filename))
                        guard try await !asset.loadTracks(withMediaType:.audio).isEmpty else{throw EditError.invalidProject}
                        let duration=try await asset.load(.duration).seconds
                        var region=AudioRegion(filename:filename,name:url.deletingPathExtension().lastPathComponent,sourceDuration:duration)
                        let time=model.player.currentTime().seconds;region.timelineStart=max(0,time.isFinite ? time : 0)
                        try region.validate();regions.append(region)
                    }
                    model.update{$0.audioRegions=($0.audioRegions ?? [])+regions}
                }catch{
                    for name in copied{try? FileManager.default.removeItem(at:model.mediaRoot.appendingPathComponent(name))}
                    model.message="Audio import failed: "+error.localizedDescription
                }
            }
        }
        .sheet(item:$draft){region in AudioDraftView(region:region,duration:model.project.duration){value in model.update{p in if let i=p.audioRegions?.firstIndex(where:{$0.id==value.id}){p.audioRegions?[i]=value}}}}
        .sheet(isPresented:$speechSheet){SpeechComposerView()}
    }
}
private struct SpeechComposerView:View {
    @EnvironmentObject var model:EditorModel
    @Environment(\.dismiss) var dismiss
    @State private var text=""
    @State private var voice=""
    @State private var rate:Double=0.5
    @State private var generating=false
    @State private var error:String?
    private var voices:[AVSpeechSynthesisVoice]{AVSpeechSynthesisVoice.speechVoices().sorted{$0.language == $1.language ? $0.name<$1.name : $0.language<$1.language}}
    var body:some View {
        NavigationStack{
            Form{
                Section("Words to voice"){
                    TextEditor(text:$text).frame(minHeight:160)
                    Text("Uses voices available on this device. Generated audio is added as an editable region at the playhead. No account, recording or cloud service is needed.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Voice"){
                    Picker("Device voice",selection:$voice){ForEach(voices,id:\.identifier){v in Text("\(v.name) · \(v.language)").tag(v.identifier)}}
                    LabeledContent("Speaking rate"){Slider(value:$rate,in:0.3...0.7)}
                }
                if generating{ProgressView("Generating voice…")}
                if let error{Text(error).foregroundStyle(.red)}
            }.navigationTitle("Text to speech").navigationBarTitleDisplayMode(.inline)
                .onAppear{if voice.isEmpty{voice=voices.first(where:{$0.language=="en-US"})?.identifier ?? voices.first?.identifier ?? ""}}
                .toolbar{
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}.disabled(generating)}
                    ToolbarItem(placement:.confirmationAction){Button("Generate") {Task{await generate()}}.disabled(generating || text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || voice.isEmpty)}
                }
        }.interactiveDismissDisabled(generating)
    }
    private func generate() async {
        generating=true;defer{generating=false}
        let filename=UUID().uuidString+".caf",before=model.project
        let url=model.mediaRoot.appendingPathComponent(filename)
        do{
            model.player.pause()
            try await SpeechRenderer.render(text,voiceIdentifier:voice,rate:Float(rate),to:url)
            let file=try AVAudioFile(forReading:url)
            var region=AudioRegion(filename:filename,name:"Narration",sourceDuration:Double(file.length)/file.processingFormat.sampleRate)
            let t=model.player.currentTime().seconds;region.timelineStart=max(0,t.isFinite ? t : 0)
            guard model.project==before else{throw EditError.invalidProject}
            try region.validate();model.update{$0.audioRegions=($0.audioRegions ?? [])+[region]};dismiss()
        }catch{try? FileManager.default.removeItem(at:url);self.error=error.localizedDescription}
    }
}
private struct AudioDraftView:View {
    @Environment(\.dismiss) var dismiss
    @State var region:AudioRegion
    let duration:Double
    let save:(AudioRegion)->Void
    @State private var error:String?
    var body:some View {
        NavigationStack {
            Form {
                Section("Audio region"){
                    TextField("Name",text:$region.name)
                    field("Place at",value:$region.timelineStart)
                    field("Source in",value:$region.sourceStart)
                    field("Source out",value:$region.sourceEnd)
                    Text(String(format:"Source length: %.3f s",region.sourceDuration)).font(.caption)
                }
                Section("Mix"){
                    LabeledContent("Volume"){Slider(value:$region.volume,in:0...1)}
                    field("Fade in",value:$region.fadeIn)
                    field("Fade out",value:$region.fadeOut)
                }
                if region.timelineStart+region.duration>duration{Text("Audio is clipped at the film’s end; it does not extend the main video track.").font(.caption).foregroundStyle(.orange)}
                if let error{Text(error).foregroundStyle(.red)}
            }.navigationTitle("Audio timing").navigationBarTitleDisplayMode(.inline)
                .toolbar{
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Save"){do{try region.validate();save(region);dismiss()}catch{self.error=error.localizedDescription}}}
                }
        }
    }
    private func field(_ name:String,value:Binding<Double>)->some View {
        LabeledContent(name){TextField(name,value:value,format:.number.precision(.fractionLength(3))).keyboardType(.decimalPad).multilineTextAlignment(.trailing)}
    }
}
