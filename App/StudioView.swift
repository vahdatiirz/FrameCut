import SwiftUI
import AVFoundation
import CoreImage
import UniformTypeIdentifiers

enum StudioTab:String,CaseIterable,Identifiable { case guide="Tools & help",projects="Projects",templates="Templates",looks="Looks",text="Text",captions="Captions",audio="Audio",layers="Layers",export="Export"
    var id:String{rawValue}
    var icon:String { switch self {case .guide:return "questionmark.circle";case .projects:return "square.grid.2x2";case .templates:return "square.stack.3d.up";case .looks:return "camera.filters";case .text:return "textformat";case .captions:return "captions.bubble";case .audio:return "waveform";case .layers:return "rectangle.on.rectangle";case .export:return "square.and.arrow.up"} }
}
struct StudioView:View {
    @EnvironmentObject var model:EditorModel
    @Environment(\.dismiss) var dismiss
    @State private var tab:StudioTab
    @State private var category="All"
    @State private var search=""
    @State private var draftTitle=""
    @State private var sourceFrame:CGImage?
    @State private var confirmRecipe:EditTemplate?
    @State private var lutImport=false
    @State private var maskSheet=false
    private let accent=Color(red:0.68,green:0.96,blue:0.35)
    init(initialTab:StudioTab) { _tab=State(initialValue:initialTab) }
    private var clip:Clip? {model.selectedIndex.map{model.project.clips[$0]}}
    private var effects:ClipEffects {clip?.effects ?? ClipEffects()}
    private var style:ProjectStyle {model.project.style ?? ProjectStyle()}
    var body:some View {
        NavigationStack {
            VStack(spacing:0) {
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:8) {ForEach(StudioTab.allCases,id:\.self){item in
                        Button {tab=item} label:{Label(item.rawValue,systemImage:item.icon).font(.subheadline.bold()).padding(.horizontal,15).padding(.vertical,12).background(tab==item ? accent : Color.white.opacity(0.06),in:Capsule()).foregroundStyle(tab==item ? .black : .white)}
                    }}.padding(16)
                }
                Divider()
                ScrollView {
                    VStack(alignment:.leading,spacing:22) {
                        switch tab {
                        case .guide:ToolGuideView(tab:$tab)
                        case .projects:projects
                        case .templates:templates
                        case .looks:looks
                        case .text:textSettings
                        case .captions:CaptionEditorView()
                        case .audio:AudioEditorView()
                        case .layers:LayerEditorView()
                        case .export:exportSettings
                        }
                    }.padding(22).frame(maxWidth:1000,alignment:.leading).frame(maxWidth:.infinity)
                }
            }.background(Color(red:0.06,green:0.075,blue:0.085))
            .navigationTitle(tab == .projects ? "Your studio" : "Creation Kit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {ToolbarItem(placement:.confirmationAction){Button("Done"){dismiss()}}}
        }
        .tint(accent)
        .onAppear {draftTitle=model.project.title}
        .task(id:clip?.filename) {
            sourceFrame=nil
            guard let clip else{return}
            let generator=AVAssetImageGenerator(asset:AVURLAsset(url:model.mediaRoot.appendingPathComponent(clip.filename)))
            generator.appliesPreferredTrackTransform=true;generator.maximumSize=CGSize(width:360,height:240)
            do {let result=try await generator.image(at:CMTime(seconds:clip.start,preferredTimescale:600));sourceFrame=result.image} catch {}
        }
        .confirmationDialog("Apply this template?",isPresented:Binding(get:{confirmRecipe != nil},set:{if !$0{confirmRecipe=nil}}),titleVisibility:.visible) {
            Button("Apply to current film") {if let recipe=confirmRecipe {model.applyTemplate(recipe)};confirmRecipe=nil;dismiss()}
            Button("Cancel",role:.cancel){confirmRecipe=nil}
        } message:{Text("Changes clip timing, speed, look, cut treatment and title styling. Your media stays intact. Undo is available in the editor.")}
        .presentationDetents([.large])
        .sheet(isPresented:$maskSheet){MaskEditorView(effects:effects){mask,regions in model.updateEffects{$0.mask=mask;$0.privacyRegions=regions}}}
        .fileImporter(isPresented:$lutImport,allowedContentTypes:[UTType(filenameExtension:"cube") ?? .plainText,.plainText],allowsMultipleSelection:false){result in
            var copied:String?
            do{guard let url=try result.get().first,model.selectedIndex != nil else{return};let file=try model.copyMedia(url);copied=file;_ = try CubeLUT.parse(String(contentsOf:model.mediaRoot.appendingPathComponent(file),encoding:.utf8));model.updateEffects{$0.lutFilename=file}}
            catch{if let copied{try? FileManager.default.removeItem(at:model.mediaRoot.appendingPathComponent(copied))};model.message="LUT import failed: "+error.localizedDescription}
        }
    }
    private var projects:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Make something worth watching.").font(.largeTitle.bold())
            HStack {
                Button {model.newProject();dismiss()} label:{Label("New film",systemImage:"plus").font(.headline).padding(18).background(accent,in:RoundedRectangle(cornerRadius:16)).foregroundStyle(.black)}
                Button {tab = .templates} label:{Label("Start with a template",systemImage:"square.stack.3d.up").font(.headline)}.buttonStyle(.bordered)
            }
            Text("RECENT FILMS").font(.caption.monospaced()).foregroundStyle(.secondary)
            NavigationLink("About FrameCut & open-source notices"){FrameCutAboutView()}.font(.caption)
            if model.projects.isEmpty {Text("Your saved films will appear here.").foregroundStyle(.secondary)}
            ForEach(model.projects){p in
                Button {model.open(p);dismiss()} label:{
                    HStack(spacing:18) {Image(systemName:"film.stack").font(.title).frame(width:64,height:64).background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:14));VStack(alignment:.leading,spacing:5){Text(p.name).font(.headline);Text("\(p.clips.count) clips · \(Int(p.duration)) sec · \(p.canvas.label)").font(.caption).foregroundStyle(.secondary)};Spacer();Image(systemName:"chevron.right")}.foregroundStyle(.white).padding(12).background(.white.opacity(0.04),in:RoundedRectangle(cornerRadius:18))
                }.buttonStyle(.plain)
            }
        }
    }
    private var templates:some View {
        VStack(alignment:.leading,spacing:16) {
            Text("A starting point. Your story.").font(.title.bold())
            Text("12 original editing recipes. Each applies real clip timing, color, framing and title style. You can customize every setting afterward.").font(.subheadline).foregroundStyle(.secondary)
            TextField("Search templates",text:$search).textFieldStyle(.roundedBorder)
            Picker("Category",selection:$category){ForEach(["All","Film","Travel","Social","Lifestyle","Business"],id:\.self){Text($0).tag($0)}}.pickerStyle(.menu)
            LazyVGrid(columns:[GridItem(.adaptive(minimum:210),spacing:16)],spacing:16) {
                ForEach(EditTemplate.all.filter{(category=="All" || $0.category==category) && (search.isEmpty || $0.name.localizedCaseInsensitiveContains(search))}) {recipe in
                    Button {confirmRecipe=recipe} label:{
                        VStack(alignment:.leading,spacing:12) {
                            ZStack {
                                LinearGradient(colors:recipe.ink == .amber ? [.brown,.black] : recipe.category=="Social" ? [.indigo,.black] : [.teal,.black],startPoint:.topLeading,endPoint:.bottomTrailing)
                                VStack(spacing:8) {Image(systemName:recipe.canvas == .portrait ? "rectangle.portrait" : "rectangle").font(.system(size:36,weight:.ultraLight));Text(recipe.caption).font(recipe.font == .editorial ? .system(.headline,design:.serif) : .headline).multilineTextAlignment(.center).lineLimit(2)}.padding().foregroundStyle(ink(recipe.ink))
                            }.frame(height:145).clipShape(RoundedRectangle(cornerRadius:14))
                            Text(recipe.name).font(.headline).foregroundStyle(.white)
                            Text("\(recipe.canvas.label) · \(recipe.look.label) · \(String(format:"%.1f",recipe.clipSeconds))s cuts").font(.caption).foregroundStyle(.secondary)
                            HStack{Text(recipe.category).font(.caption2);Spacer();Label("Apply",systemImage:"arrow.up.right").font(.caption.bold())}.foregroundStyle(accent)
                        }.padding(12).background(.white.opacity(0.045),in:RoundedRectangle(cornerRadius:20))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
    private var looks:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("Color your story.").font(.title.bold())
            if clip == nil {Text("Add and select a clip first. Looks and adjustments apply to the selected clip.").foregroundStyle(.secondary)}
            else {
                Text("Selected: \(clip!.name)").font(.subheadline).foregroundStyle(.secondary)
                HStack{
                    Button("Import .cube LUT",systemImage:"square.and.arrow.down"){lutImport=true}.buttonStyle(.bordered)
                    if effects.lutFilename != nil{Button("Remove custom LUT",role:.destructive){model.updateEffects{$0.lutFilename=nil}}}
                }
                Button("Masks & privacy",systemImage:"circle.lefthalf.filled"){maskSheet=true}.buttonStyle(.bordered)
                LazyVGrid(columns:[GridItem(.adaptive(minimum:120),spacing:12)],spacing:12){ForEach(Look.allCases){look in
                    Button {model.updateEffects{$0.look=look}} label:{LookCard(look:look,source:sourceFrame,selected:effects.look==look)}.buttonStyle(.plain)
                }}
                AdjustmentSlider(name:"Look intensity",value:effectBinding(\.intensity),range:0...1)
                Divider()
                AdjustmentSlider(name:"Brightness",value:effectBinding(\.brightness),range:-0.5...0.5)
                AdjustmentSlider(name:"Contrast",value:effectBinding(\.contrast),range:0.5...2)
                AdjustmentSlider(name:"Saturation",value:effectBinding(\.saturation),range:0...2)
                AdjustmentSlider(name:"Exposure",value:effectBinding(\.exposure),range:-2...2)
                AdjustmentSlider(name:"Warmth",value:effectBinding(\.warmth),range:-1...1)
                Button("Reset color & LUT"){model.updateEffects{$0.resetColor()}}.buttonStyle(.bordered)
                Text("Changes appear in the editor preview and are included in export. Slider changes commit when you lift your finger.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    private var textSettings:some View {
        VStack(alignment:.leading,spacing:20) {
            Text("Give it a voice.").font(.title.bold())
            TextField("Title wording",text:$draftTitle,axis:.vertical).textFieldStyle(.roundedBorder)
            Button("Save wording"){model.update{$0.title=draftTitle}}.buttonStyle(.borderedProminent)
            Picker("Font",selection:Binding(get:{style.font},set:{v in model.update{var s=$0.style ?? ProjectStyle();s.font=v;s.fontFilename=nil;s.fontPostScriptName=nil;$0.style=s}})){ForEach(TitleFont.allCases,id:\.self){Text($0.rawValue.capitalized).tag($0)}}.pickerStyle(.segmented)
            FontImportButton{file,name in model.update{var s=$0.style ?? ProjectStyle();s.fontFilename=file;s.fontPostScriptName=name;$0.style=s}}
            if let name=style.fontPostScriptName{Text("Imported font: "+name).font(.caption).foregroundStyle(.secondary)}
            Picker("Position",selection:styleBinding(\.position)){ForEach(TitlePosition.allCases,id:\.self){Text($0.rawValue.capitalized).tag($0)}}.pickerStyle(.segmented)
            HStack{Text("Color");Spacer();ForEach(Ink.allCases,id:\.self){v in Button{model.update{var s=$0.style ?? ProjectStyle();s.ink=v;$0.style=s}} label:{Circle().fill(ink(v)).frame(width:34,height:34).overlay(Circle().stroke(style.ink==v ? accent : .gray,lineWidth:style.ink==v ? 3 : 1))}.accessibilityLabel(v.rawValue)}}
            Toggle("Background plate",isOn:styleBinding(\.boxed))
            AdjustmentSlider(name:"Title size",value:styleBinding(\.titleScale),range:0.5...2)
            Button("Edit timed titles and subtitles"){tab = .captions}.buttonStyle(.bordered)
        }
    }
    private var exportSettings:some View {
        VStack(alignment:.leading,spacing:22) {
            Text("Ready for the world.").font(.title.bold())
            Picker("Resolution",selection:styleBinding(\.resolution)){ForEach(ExportSize.allCases,id:\.self){Text($0.label).tag($0)}}.pickerStyle(.segmented)
            Picker("Frame rate",selection:styleBinding(\.fps)){ForEach([24,25,30,50,60],id:\.self){Text("\($0) fps").tag($0)}}.pickerStyle(.segmented)
            Picker("Bit rate",selection:styleBinding(\.bitRateMbps)){
                Text("Automatic").tag(Optional<Double>.none)
                ForEach([4.0,8,16,32,64,100],id:\.self){Text("\(Int($0)) Mbps").tag(Optional($0))}
            }
            Text("\(model.project.renderWidth) × \(model.project.renderHeight) · \(style.fps) fps · MP4").font(.headline)
            Text("4K and higher frame rates need more storage and rendering time. This exports SDR video. A higher output frame rate repeats source frames when needed; motion interpolation is a separate feature.").font(.subheadline).foregroundStyle(.secondary)
            Button {dismiss();Task{await model.export()}} label:{Label("Export film",systemImage:"arrow.up.right").font(.headline)}.buttonStyle(.borderedProminent).disabled(model.project.clips.isEmpty)
        }
    }
    private func effectBinding(_ key:WritableKeyPath<ClipEffects,Double>)->Binding<Double>{Binding(get:{effects[keyPath:key]},set:{v in model.updateEffects{$0[keyPath:key]=v}})}
    private func styleBinding<T>(_ key:WritableKeyPath<ProjectStyle,T>)->Binding<T>{Binding(get:{style[keyPath:key]},set:{v in model.update{var s=$0.style ?? ProjectStyle();s[keyPath:key]=v;$0.style=s}})}
    private func ink(_ v:Ink)->Color{let c=v.rgb;return Color(red:c.0,green:c.1,blue:c.2)}
}
private struct FrameCutAboutView:View {
    private let documents=["Argmax-MIT.txt","Argmax-Third-Party-Notices.txt","OpenAI-Whisper-MIT.txt","OpenAI-Tokenizer-Apache-2.0.txt","Model-origin.txt"]
    var body:some View {
        ScrollView{
            VStack(alignment:.leading,spacing:22){
                Text("FRAMECUT").font(.largeTitle.bold())
                Text("Version \(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "") · Independent video editor for iPhone and iPad.").foregroundStyle(.secondary)
                Text("Offline captions use the multilingual Whisper Tiny model. Text to speech uses voices available on your device.")
                ForEach(documents,id:\.self){name in
                    DisclosureGroup(name){Text(contents(name)).font(.caption.monospaced()).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)}
                }
            }.padding(22)
        }.navigationTitle("About FrameCut").navigationBarTitleDisplayMode(.inline)
    }
    private func contents(_ name:String)->String {guard let url=Bundle.main.resourceURL?.appendingPathComponent("Licenses").appendingPathComponent(name),let text=try? String(contentsOf:url,encoding:.utf8) else{return "License file is unavailable in this build."};return text}
}
private struct AdjustmentSlider:View {
    let name:String
    @Binding var value:Double
    let range:ClosedRange<Double>
    @State private var draft:Double=0
    var body:some View {
        VStack(alignment:.leading,spacing:5){HStack{Text(name);Spacer();Text(String(format:"%.2f",draft)).font(.caption.monospaced()).foregroundStyle(.secondary)};Slider(value:$draft,in:range,onEditingChanged:{editing in if !editing{value=draft}}).accessibilityLabel(name)}
            .onAppear{draft=value}.onChange(of:value){_,v in draft=v}
    }
}
private struct LookCard:View {
    let look:Look
    let source:CGImage?
    let selected:Bool
    @State private var rendered:UIImage?
    var body:some View {
        VStack(alignment:.leading,spacing:8){
            if let rendered {Image(uiImage:rendered).resizable().scaledToFill().frame(height:88).clipped()}
            else {Rectangle().fill(.gray.opacity(0.2)).frame(height:88).overlay(Image(systemName:"camera.filters").font(.title).foregroundStyle(.secondary))}
            Text(look.label).font(.caption.bold()).padding(.horizontal,8).padding(.bottom,8)
        }.background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:12)).clipShape(RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(selected ? Color.green : .clear,lineWidth:2))
        .task(id:source.map{String(describing:$0)}) {
            guard let source else{return};var e=ClipEffects();e.look=look
            let input=CIImage(cgImage:source);let output=ColorPipeline.apply(input,effects:e)
            if let cg=CIContext().createCGImage(output,from:output.extent){rendered=UIImage(cgImage:cg)}
        }
    }
}
