import SwiftUI
import UniformTypeIdentifiers

struct CaptionEditorView:View {
    @EnvironmentObject var model:EditorModel
    @State private var draft:TextCue?
    @State private var importing=false
    @State private var subtitleURL:URL?
    @State private var language=""
    private var cues:[TextCue] {model.project.captions ?? []}
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Every word, on time.").font(.title.bold())
            Text("Add independent timed titles, or import an SRT subtitle file. Captions are saved with your film and burned into the exported video.").foregroundStyle(.secondary)
            GroupBox("Offline speech captions"){
                VStack(alignment:.leading,spacing:12){
                    Text("Whisper Tiny is included with FrameCut. Speech is processed on this device with no account or subscription. Review the generated text and timing before sharing.").font(.caption).foregroundStyle(.secondary)
                    Picker("Spoken language",selection:$language){ForEach(["Auto-detect|","Persian|fa","English|en","Arabic|ar","Turkish|tr","French|fr","German|de","Spanish|es","Italian|it","Portuguese|pt","Russian|ru","Hindi|hi","Urdu|ur","Chinese|zh","Japanese|ja","Korean|ko"],id:\.self){item in let fields=item.components(separatedBy:"|");Text(fields[0]).tag(fields[1])}}
                    Button("Generate offline captions",systemImage:"waveform.badge.magnifyingglass"){model.startCaptions(language:language.isEmpty ? nil : language)}.buttonStyle(.borderedProminent).disabled(model.busy || model.project.clips.isEmpty)
                    if model.canCancelOperation{HStack{ProgressView();Text(model.busyLabel).font(.caption);Button("Cancel"){model.cancelOperation()}}}
                }.frame(maxWidth:.infinity,alignment:.leading)
            }
            HStack {
                Button("Add text",systemImage:"plus") {
                    let t=max(0,min(model.player.currentTime().seconds.isFinite ? model.player.currentTime().seconds : 0,max(0,model.project.duration-0.1)))
                    var next=TextCue(text:"",start:t,end:min(model.project.duration,t+3));if next.end<=next.start{next.end=t+3};draft=next
                }.buttonStyle(.borderedProminent)
                Button("Import SRT",systemImage:"square.and.arrow.down"){importing=true}.buttonStyle(.bordered)
                Button("Prepare SRT",systemImage:"doc.text"){prepareSRT()}.disabled(cues.isEmpty).buttonStyle(.bordered)
            }
            if let subtitleURL {ShareLink("Share subtitle file",item:subtitleURL)}
            if cues.isEmpty {ContentUnavailableView("No timed text yet",systemImage:"captions.bubble",description:Text("Use Add text or import subtitles."))}
            ForEach(cues.sorted{$0.start < $1.start}){cue in
                HStack(alignment:.top) {
                    Button{draft=cue}label:{VStack(alignment:.leading,spacing:6){Text(cue.text).lineLimit(3).foregroundStyle(.primary);Text(String(format:"%.3f – %.3f s · %@",cue.start,cue.end,cue.style.position.rawValue)).font(.caption.monospaced()).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading)}.buttonStyle(.plain)
                    Button("Delete",systemImage:"trash",role:.destructive){model.update{$0.captions?.removeAll{$0.id==cue.id}}}.labelStyle(.iconOnly)
                }.padding(14).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:14))
            }
        }
        .fileImporter(isPresented:$importing,allowedContentTypes:[UTType(filenameExtension:"srt") ?? .plainText,.plainText],allowsMultipleSelection:false){result in
            do {
                guard let url=try result.get().first else{return}
                let access=url.startAccessingSecurityScopedResource();defer{if access{url.stopAccessingSecurityScopedResource()}}
                let imported=try SubtitleFile.parse(String(contentsOf:url,encoding:.utf8))
                model.update{p in p.captions=(p.captions ?? [])+imported}
            }catch{model.message="Subtitle import failed: "+error.localizedDescription}
        }
        .sheet(item:$draft){cue in
            CaptionDraftView(cue:cue,duration:model.project.duration){updated in
                model.update{p in var values=p.captions ?? [];if let i=values.firstIndex(where:{$0.id==updated.id}){values[i]=updated}else{values.append(updated)};p.captions=values}
            }
        }
        .onChange(of:model.project.captions){_,_ in subtitleURL=nil}
    }
    private func prepareSRT(){
        do{let url=FileManager.default.temporaryDirectory.appendingPathComponent("FrameCut-\(UUID().uuidString).srt");try SubtitleFile.encode(cues.sorted{$0.start<$1.start}).write(to:url,atomically:true,encoding:.utf8);subtitleURL=url}
        catch{model.message=error.localizedDescription}
    }
}
private struct CaptionDraftView:View {
    @Environment(\.dismiss) var dismiss
    @State var cue:TextCue
    let duration:Double
    let save:(TextCue)->Void
    @State private var error:String?
    var body:some View {
        NavigationStack {
            Form {
                Section("Wording"){TextEditor(text:$cue.text).frame(minHeight:110)}
                Section("Timing in seconds"){
                    LabeledContent("Start"){TextField("Start",value:$cue.start,format:.number.precision(.fractionLength(3))).keyboardType(.decimalPad).multilineTextAlignment(.trailing)}
                    LabeledContent("End"){TextField("End",value:$cue.end,format:.number.precision(.fractionLength(3))).keyboardType(.decimalPad).multilineTextAlignment(.trailing)}
                    if cue.end>duration{Text("Text after the film ends will not appear in video export.").font(.caption).foregroundStyle(.orange)}
                }
                Section("Style"){
                    Picker("Font",selection:Binding(get:{cue.style.font},set:{cue.style.font=$0;cue.style.fontFilename=nil;cue.style.fontPostScriptName=nil})){ForEach(TitleFont.allCases,id:\.self){Text($0.rawValue.capitalized).tag($0)}}
                    FontImportButton{file,name in cue.style.fontFilename=file;cue.style.fontPostScriptName=name}
                    if let name=cue.style.fontPostScriptName{Text("Imported font: "+name).font(.caption).foregroundStyle(.secondary)}
                    Picker("Position",selection:$cue.style.position){ForEach(TitlePosition.allCases,id:\.self){Text($0.rawValue.capitalized).tag($0)}}
                    Picker("Color",selection:$cue.style.ink){ForEach(Ink.allCases,id:\.self){Text($0.rawValue.capitalized).tag($0)}}
                    Toggle("Background plate",isOn:$cue.style.boxed)
                    LabeledContent("Size"){Slider(value:$cue.style.titleScale,in:0.5...2)}
                }
                if let error{Text(error).foregroundStyle(.red)}
            }.navigationTitle("Timed text").navigationBarTitleDisplayMode(.inline)
                .toolbar{
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Save"){
                        do{cue.words=cue.words?.compactMap{word in let a=max(cue.start,word.start),b=min(cue.end,word.end);return b>a ? CaptionWord(text:word.text,start:a,end:b) : nil};try cue.validate();save(cue);dismiss()}catch{self.error=error.localizedDescription}
                    }}
                }
                .onChange(of:cue.text){_,_ in cue.words=nil}
        }
    }
}
