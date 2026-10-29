import SwiftUI
import AVKit

struct TransitionEditorView:View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var model:EditorModel
    @State private var enabled=true
    @State private var transition:ClipTransition
    @State private var error:String?
    @State private var category="Basic"
    @State private var applyToAll=false
    @State private var player=AVPlayer()
    @State private var previewStart=0.0
    @State private var previewEnd=0.0
    @State private var preparing=false
    @State private var importedDrafts:[String]=[]
    let limit:Double
    let save:(ClipTransition?,Bool)->Void
    init(from:UUID,to:UUID,current:ClipTransition?,limit:Double,save:@escaping(ClipTransition?,Bool)->Void){
        let edge=current ?? ClipTransition(from:from,to:to,duration:min(0.5,max(0.05,limit)))
        _transition=State(initialValue:edge);_category=State(initialValue:edge.style.category);self.limit=limit;self.save=save
    }
    private var previewKey:String {"\(enabled)-\(transition.style.rawValue)-\(transition.duration)-\(transition.generatedBridge?.filename ?? "native")"}
    var body:some View {
        NavigationStack {
            VStack(spacing:0){
                ZStack {
                    VideoPlayer(player:player).frame(height:160)
                    if preparing{ProgressView().padding().background(.ultraThinMaterial,in:Capsule())}
                }
                Form {
                    Section {
                        NavigationLink {
                            GenerationBridgeView(from:transition.from,to:transition.to,duration:min(limit,transition.duration)){asset in
                                importedDrafts.append(asset.filename);transition.generatedBridge=asset;enabled=true;applyToAll=false
                            }.environmentObject(model)
                        }label:{Label("AI bridge · Generate / import",systemImage:"sparkles.tv")}
                        if transition.generatedBridge != nil{Text("Generated video draft · Apply saves it. Choose a native style to replace it.").font(.caption)}
                    }
                    Section("Between clips") {
                        Toggle("Enable transition",isOn:$enabled)
                        if enabled {
                            LabeledContent("Duration",value:String(format:"%.2f s",transition.duration))
                            Slider(value:$transition.duration,in:0.05...5,step:0.05).accessibilityLabel("Transition duration").disabled(transition.generatedBridge != nil)
                            Text(String(format:"Effective overlap: %.2f seconds",min(limit,transition.duration))).font(.caption).foregroundStyle(.secondary)
                            Toggle("Apply to all clip boundaries",isOn:$applyToAll).disabled(transition.generatedBridge != nil)
                            Picker("Category",selection:$category){ForEach(["Basic","Motion","Matte","Effects"],id:\.self){Text($0)}}.pickerStyle(.segmented)
                            if category == "Effects"{Text("نمونه‌های آمادهٔ محلی برای بررسی ظاهر · Independent visual effects, not VN cloud generation").font(.caption).foregroundStyle(.secondary)}
                            LazyVGrid(columns:[GridItem(.adaptive(minimum:110))],spacing:8){
                                ForEach(TransitionStyle.allCases.filter{$0.category==category},id:\.self){style in
                                    Button{transition.style=style;transition.generatedBridge=nil}label:{
                                        HStack{Text(style.title).font(.subheadline);if transition.style==style && transition.generatedBridge == nil{Image(systemName:"checkmark.circle.fill")}}
                                            .frame(maxWidth:.infinity,minHeight:44).padding(.horizontal,6)
                                            .background(transition.style==style && transition.generatedBridge == nil ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08),in:RoundedRectangle(cornerRadius:8))
                                    }.buttonStyle(.plain).accessibilityLabel("Transition \(style.title)").accessibilityAddTraits(transition.style==style && transition.generatedBridge == nil ? .isSelected : [])
                                }
                            }

                        }
                        if !enabled{Toggle("Remove from all clip boundaries",isOn:$applyToAll)}
                    }
                    Section {
                        Text("Choose a style to preview the two playing clips. Apply saves it; Cancel keeps your film unchanged. Disable to remove the transition.")
                        Text("Overlaps shorten the film and crossfade clip audio. Each overlap is capped at half of each neighboring clip. All styles run locally without credits.")
                    }.font(.caption).foregroundStyle(.secondary)
                    if let error{Text(error).foregroundStyle(.red)}
                }
            }.navigationTitle("Between-clip transition").navigationBarTitleDisplayMode(.inline)
                .toolbar{
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Apply"){do{if enabled{try transition.validate()};save(enabled ? transition : nil,applyToAll);dismiss()}catch{self.error=error.localizedDescription}}}
                }
                .task(id:previewKey){await preview()}
                .onReceive(Timer.publish(every:0.1,on:.main,in:.common).autoconnect()){_ in
                    if previewEnd>previewStart,player.currentTime().seconds>=previewEnd {player.seek(to:CMTime(seconds:previewStart,preferredTimescale:600),toleranceBefore:.zero,toleranceAfter:.zero);player.play()}
                }
                .onDisappear{player.pause();player.replaceCurrentItem(with:nil)}
                .presentationDetents([.large])
        }.onDisappear{
            for file in importedDrafts where !(model.project.transitions ?? []).contains(where:{$0.generatedBridge?.filename==file}){try? FileManager.default.removeItem(at:model.mediaRoot.appendingPathComponent(file))}
        }
    }
    @MainActor private func preview() async {
        preparing=true;player.pause()
        defer{preparing=false}
        do {
            try await Task.sleep(for:.milliseconds(200));try Task.checkCancellation()
            var candidate=model.project
            if enabled,let asset=transition.generatedBridge{try candidate.attachGeneratedBridge(from:transition.from,to:transition.to,asset:asset,duration:transition.duration)}
            else{try candidate.setTransition(from:transition.from,to:transition.to,style:enabled ? transition.style : nil,duration:transition.duration)}
            guard let index=candidate.clips.firstIndex(where:{$0.id==transition.to}) else{return}
            let ratio=Double(candidate.renderHeight)/Double(candidate.renderWidth)
            let rendered=try await MediaEngine.build(candidate,mediaRoot:model.mediaRoot,size:CGSize(width:640,height:(640*ratio/2).rounded()*2))
            try Task.checkCancellation()
            let item=AVPlayerItem(asset:rendered.composition);item.videoComposition=rendered.videoComposition;item.audioMix=rendered.audioMix
            let placement=candidate.placements[index]
            previewStart=max(0,placement.start-0.5);previewEnd=min(candidate.duration,placement.start+placement.incomingDuration+0.7)
            player.replaceCurrentItem(with:item);await player.seek(to:CMTime(seconds:previewStart,preferredTimescale:600),toleranceBefore:.zero,toleranceAfter:.zero);player.play();error=nil
        }catch is CancellationError{}catch{self.error="Preview: \(error.localizedDescription)"}
    }
}
