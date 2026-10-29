import SwiftUI
import AVKit
import UniformTypeIdentifiers
import PhotosUI
import CoreTransferable

struct EditorView: View {
    @EnvironmentObject var model: EditorModel
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var importer = false
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var musicImport = false
    @State private var replaceImport=false
    @State private var library = false
    @State private var kitRoute:StudioTab?
    @State private var titleSheet = false
    @State private var speedSheet = false
    private struct TransitionTarget:Identifiable {let from:UUID;let to:UUID;var id:UUID{to}}
    @State private var transitionTarget:TransitionTarget?
    @State private var draftTitle = ""
    @State private var draftName = ""
    @State private var playhead: Double = 0
    @State private var playing = false
    @State private var scrubbing = false
    @State private var trimStart = 0.0
    @State private var trimEnd = 1.0
    private let mint = Color(red:0.68,green:0.96,blue:0.35)
    private let panel = Color(red:0.10,green:0.12,blue:0.14)
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing:0) {
                header
                if geometry.size.width > 800 {
                    HStack(alignment:.top,spacing:0) {
                        VStack(spacing:12) { preview; transport.fixedSize(horizontal:false,vertical:true) }.padding(24).frame(maxWidth:.infinity)
                        ScrollView { inspector }.frame(width:310).background(panel)
                    }.frame(maxHeight:.infinity)
                    timeline.frame(height:250)
                } else {
                    preview.frame(height:max(130,geometry.size.height*0.30)).padding(.horizontal,16).padding(.top,12)
                    transport.fixedSize(horizontal:false,vertical:true).padding(.horizontal,18).padding(.vertical,8)
                    timeline.frame(height:250).clipped()
                    ScrollView { inspector }.frame(maxHeight:.infinity).background(panel)
                }
            }.background(Color(red:0.045,green:0.055,blue:0.065))
        }
        .tint(mint)
        .task(id:model.revision) { syncTrim(); await model.preview(); playing = false; let t=model.player.currentTime().seconds;playhead=t.isFinite ? t : 0 }
        .onChange(of:photoSelection) { _,items in
            guard !items.isEmpty else { return }
            Task {
                model.busy = true
                var urls: [URL] = []
                defer { model.busy = false; photoSelection = []; for url in urls { try? FileManager.default.removeItem(at:url) } }
                do {
                    for item in items { if let movie = try await item.loadTransferable(type:ImportedMovie.self) { urls.append(movie.url) } }
                    if urls.isEmpty { throw EditError.missingVideo }
                    await model.importFiles(urls,music:false)
                } catch { model.message = error.localizedDescription }
            }
        }
        .onChange(of:model.selected) { _,_ in syncTrim() }
        .onChange(of:model.revision) { _,_ in syncTrim() }
        .onReceive(Timer.publish(every:0.15,on:.main,in:.common).autoconnect()) { _ in
            let t = model.player.currentTime().seconds
            if t.isFinite && !scrubbing { playhead = t }; playing = model.player.rate > 0
        }
        .fileImporter(isPresented:$importer,allowedContentTypes:musicImport ? [.audio] : [.movie,.image],allowsMultipleSelection:!musicImport && !replaceImport) { result in
            switch result {case .success(let urls):Task{if replaceImport,let url=urls.first{await model.replaceClip(with:url)}else{await model.importFiles(urls,music:musicImport)};replaceImport=false};case .failure(let error):replaceImport=false;model.message=error.localizedDescription}
        }
        .sheet(isPresented:$library) { StudioView(initialTab:.projects).environmentObject(model) }
        .sheet(item:$kitRoute) { route in StudioView(initialTab:route).environmentObject(model) }
        .sheet(isPresented:$titleSheet) { titleEditor }
        .sheet(isPresented:$speedSheet){if let i=model.selectedIndex {SpeedEditorView(clip:model.project.clips[i]){speed,curve in model.updateClip{$0.speed=speed;$0.speedCurve=curve}}}}
        .sheet(item:$transitionTarget){target in
            if let from=model.project.clips.first(where:{$0.id==target.from}),let to=model.project.clips.first(where:{$0.id==target.to}) {
                TransitionEditorView(from:from.id,to:to.id,current:model.project.transitions?.first{$0.from==from.id && $0.to==to.id},limit:min(from.duration,to.duration)/2){edge,all in
                    model.update{p in
                        if let edge,let asset=edge.generatedBridge{try p.attachGeneratedBridge(from:from.id,to:to.id,asset:asset,duration:edge.duration)}
                        else{try p.setTransition(from:from.id,to:to.id,style:edge?.style,duration:edge?.duration ?? 0.5,applyToAll:all)}
                    }
                }.environmentObject(model)
            }
        }
        .alert("FrameCut",isPresented:Binding(get:{model.message != nil},set:{if !$0 { model.message = nil }})) { Button("OK") { model.message = nil } } message: { Text(model.message ?? "") }
        .overlay { if model.busy || model.exporting { ZStack { Color.black.opacity(0.65).ignoresSafeArea(); VStack(spacing:16) { ProgressView(); Text(model.exporting ? "Rendering your film…" : model.busyLabel);if model.canCancelOperation{Button("Cancel"){model.cancelOperation()}}; if model.exporting { Text("Keep FrameCut open until export finishes.").font(.caption).foregroundStyle(.secondary) } }.padding(30).background(panel,in:RoundedRectangle(cornerRadius:20)) } } }
    }
    private func openSelectedTransition(){
        guard model.project.clips.count>1 else{return}
        let i=max(1,model.selectedIndex ?? 1)
        transitionTarget=TransitionTarget(from:model.project.clips[i-1].id,to:model.project.clips[i].id)
    }
    private var header: some View {
        HStack(spacing:12) {
            Button { library = true } label: { Image(systemName:"square.grid.2x2").font(.title3) }.accessibilityLabel("Projects")
            VStack(alignment:.leading,spacing:3) { Text("FRAMECUT").font(.system(size:12,weight:.heavy,design:.monospaced)).tracking(3).foregroundStyle(mint); Text(model.project.name).font(.subheadline).lineLimit(1) }
            Spacer()
            Button { kitRoute = .guide } label:{Image(systemName:"questionmark.circle")}.accessibilityLabel("Tools and help")
            Button { model.undo() } label: { Image(systemName:"arrow.uturn.backward") }.disabled(!model.history.canUndo).accessibilityLabel("Undo")
            Button { model.redo() } label: { Image(systemName:"arrow.uturn.forward") }.disabled(!model.history.canRedo).accessibilityLabel("Redo")
            Button { kitRoute = .export } label: { Label("Export",systemImage:"arrow.up.right").font(.subheadline.bold()).padding(.horizontal,12).padding(.vertical,10).background(mint,in:Capsule()).foregroundStyle(.black) }.disabled(model.project.clips.isEmpty || model.exporting)
        }.padding(18).background(panel)
    }
    private var preview: some View {
        ZStack(alignment:.bottom) {
            RoundedRectangle(cornerRadius:16).fill(.black)
            if model.project.clips.isEmpty {
                VStack(spacing:18) {
                    Image(systemName:"viewfinder").font(.system(size:46,weight:.ultraLight)).foregroundStyle(mint)
                    Text("Every story starts\nwith a first frame.").font(.system(size:27,weight:.semibold)).multilineTextAlignment(.center)
                    Text("Import photos or videos to start your film").foregroundStyle(.secondary).font(.subheadline)
                    PhotosPicker(selection:$photoSelection,maxSelectionCount:20,matching:.any(of:[.images,.videos])) { Label("Choose photos & videos",systemImage:"plus").bold().padding(13).background(mint,in:Capsule()).foregroundStyle(.black) }
                    Button("Import from Files") { musicImport=false;importer=true }.font(.caption)
                    Button("فیلم نمونه را امتحان کن · Try sample film"){Task{await model.openSampleFilm()}}.font(.subheadline).disabled(model.busy)
                }.frame(maxWidth:.infinity,maxHeight:.infinity)
            } else {
                VideoPlayer(player:model.player).clipShape(RoundedRectangle(cornerRadius:16))
                if model.previewLoading { ProgressView("Preparing preview…").frame(maxWidth:.infinity,maxHeight:.infinity) }
            }
        }.aspectRatio(CGFloat(model.project.canvas.width)/CGFloat(model.project.canvas.height),contentMode:.fit).frame(maxWidth:.infinity,maxHeight:.infinity)
    }
    private var transport: some View {
        VStack(spacing:4) {
            HStack {
                Text(clock(playhead)).font(.system(.caption,design:.monospaced)).foregroundStyle(mint)
                Slider(value:Binding(get:{min(playhead,max(model.project.duration,0.01))},set:{playhead=$0;model.player.seek(to:CMTime(seconds:$0,preferredTimescale:600),toleranceBefore:.zero,toleranceAfter:.zero)}),in:0...max(model.project.duration,0.01),onEditingChanged:{editing in scrubbing=editing;if editing {model.player.pause()} }).accessibilityLabel("Playhead")
                Text(clock(model.project.duration)).font(.system(.caption,design:.monospaced)).foregroundStyle(.secondary)
            }
            HStack(spacing:25) {
                Button { model.player.seek(to:.zero) } label: { Image(systemName:"backward.end.fill") }.accessibilityLabel("Go to start")
                Button { scrubbing=false;if playing { model.player.pause() } else { if playhead >= model.project.duration-0.1 { model.player.seek(to:.zero) }; model.player.play() } } label: { Image(systemName:playing ? "pause.fill" : "play.fill").font(.title2).frame(width:40,height:40) }.disabled(model.project.clips.isEmpty || model.previewLoading).accessibilityLabel(playing ? "Pause" : "Play")
                Button { model.split(at:playhead) } label: { Image(systemName:"scissors") }.disabled(model.selected == nil).accessibilityLabel("Split at playhead")
            }
        }
    }
    private var timeline: some View {
        TimelinePanel(playhead:$playhead,scrubbing:$scrubbing,photos:$photoSelection,importFiles:{musicImport=false;replaceImport=false;importer=true},openStudio:{kitRoute=$0},openTransition:{from,to in transitionTarget=TransitionTarget(from:from,to:to)})
    }
    private var inspector: some View {
        VStack(alignment:.leading,spacing:20) {
            HStack{
                Text("THE EDIT DESK").font(.system(size:10,weight:.bold,design:.monospaced)).tracking(2).foregroundStyle(mint)
                Spacer()
                Text("\(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "") · \(Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? "")").font(.caption2.monospaced()).foregroundStyle(.secondary).accessibilityLabel("App version and build")
            }
            LazyVGrid(columns:[GridItem(.flexible()),GridItem(.flexible())],spacing:10) {
                Button {kitRoute = .templates} label:{Label("Templates",systemImage:"square.stack.3d.up")}
                Button {kitRoute = .looks} label:{Label("Looks",systemImage:"camera.filters")}
                Button {kitRoute = .fx} label:{Label("FX",systemImage:"sparkles")}
                Button {speedSheet=true} label:{Label("Speed",systemImage:"speedometer")}.disabled(model.selectedIndex==nil)
                Button {openSelectedTransition()} label:{Label("Transitions",systemImage:"rectangle.on.rectangle.angled")}.disabled(model.project.clips.count<2)
                Button {kitRoute = .layers} label:{Label("Keyframes",systemImage:"diamond")}.disabled(model.selectedIndex==nil)
                Button { draftTitle=model.project.title;draftName=model.project.name;titleSheet=true } label: { Label("Title",systemImage:"textformat") }
                Button { kitRoute = .audio } label: { Label("Audio",systemImage:"waveform") }
                Button {kitRoute = .layers} label:{Label("Layers",systemImage:"rectangle.on.rectangle")}
                Button {kitRoute = .captions} label:{Label("Captions",systemImage:"captions.bubble")}
            }.font(.subheadline).buttonStyle(.bordered)
            Picker("Canvas",selection:Binding(get:{model.project.canvas},set:{value in model.update{$0.canvas=value}})) { ForEach(Canvas.allCases,id:\.self) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
            if let i=model.selectedIndex {
                let clip=model.project.clips[i]
                Text(clip.name).font(.headline).lineLimit(1)
                HStack{
                    Button("Duplicate",systemImage:"plus.square.on.square"){model.duplicateClip()}
                    Button("Replace",systemImage:"arrow.triangle.2.circlepath"){musicImport=false;replaceImport=true;importer=true}
                }.buttonStyle(.bordered)
                Menu("Clip tools"){
                    Button("Reverse video · silent"){Task{await model.reverseClip()}}
                    Button("Freeze frame · 3 seconds"){Task{await model.freeze(at:playhead)}}
                    Button("Extract source frame as PNG"){Task{await model.extractStill(at:playhead)}}
                    Button("Keyframes"){kitRoute = .layers}
                }
                if let still=model.exportedStill{ShareLink("Share source frame",item:still)}
                VStack(alignment:.leading,spacing:8) {
                    Text(String(format:"IN  %.2fs",trimStart)).font(.caption.monospaced())
                    Slider(value:$trimStart,in:0...max(0.001,clip.sourceDuration-0.1),onEditingChanged:{editing in if !editing { model.updateClip{try $0.trim(start:trimStart,end:trimEnd)};syncTrim() }}).accessibilityLabel("Trim start")
                    Text(String(format:"OUT  %.2fs",trimEnd)).font(.caption.monospaced())
                    Slider(value:$trimEnd,in:0.1...max(0.101,clip.sourceDuration),onEditingChanged:{editing in if !editing { model.updateClip{try $0.trim(start:trimStart,end:trimEnd)};syncTrim() }}).accessibilityLabel("Trim end")
                }
                HStack {
                    Button {model.updateEffects{$0.quarterTurns=($0.quarterTurns+1)%4}} label:{Label("Rotate",systemImage:"rotate.right")}
                    Button {model.updateEffects{$0.mirrored.toggle()}} label:{Label("Mirror",systemImage:"arrow.left.and.right.righttriangle.left.righttriangle.right")}
                }.buttonStyle(.bordered)
                Picker("Framing",selection:Binding(get:{(clip.effects ?? ClipEffects()).fit},set:{v in model.updateEffects{$0.fit=v}})) {ForEach(FrameFit.allCases,id:\.self){Text($0.rawValue.capitalized).tag($0)}}.pickerStyle(.segmented)
                Button("Incoming transition",systemImage:"rectangle.on.rectangle.angled"){openSelectedTransition()}.disabled(i==0)
                Picker("Clip fade",selection:Binding(get:{(clip.effects ?? ClipEffects()).cutStyle},set:{v in model.updateEffects{$0.cutStyle=v}})) {ForEach(CutStyle.allCases,id:\.self){Text($0.label).tag($0)}}
                Button {kitRoute = .looks} label:{Label("Color & adjustments",systemImage:"slider.horizontal.3")}
                Button{speedSheet=true}label:{Label(clip.speedCurve == nil ? String(format:"Speed %.2g×",clip.speed) : "Speed curve active",systemImage:"speedometer")}.buttonStyle(.bordered)
                HStack { Image(systemName:"speaker.wave.2"); Slider(value:Binding(get:{clip.volume},set:{value in model.updateClip{$0.volume=value}}),in:0...1).accessibilityLabel("Clip volume"); Text("\(Int(clip.volume*100))%").font(.caption.monospaced()) }
                HStack { Button {model.move(-1)} label:{Image(systemName:"arrow.left")}.disabled(i==0).accessibilityLabel("Move clip earlier"); Button {model.move(1)} label:{Image(systemName:"arrow.right")}.disabled(i==model.project.clips.count-1).accessibilityLabel("Move clip later"); Spacer(); Button(role:.destructive) {model.deleteClip()} label:{Label("Remove",systemImage:"trash")} }.buttonStyle(.bordered)
            } else { Text("Select a clip to trim, change speed or adjust its sound.").font(.subheadline).foregroundStyle(.secondary) }
            if model.project.musicFilename != nil {
                Divider(); Text("MUSIC LEVEL").font(.caption2.monospaced())
                Slider(value:Binding(get:{model.project.musicVolume},set:{value in model.update{$0.musicVolume=value}}),in:0...1).accessibilityLabel("Music volume")
                Button("Remove music",role:.destructive) { model.update{$0.musicFilename=nil} }.font(.caption)
            }
            if let output=model.exported { Divider(); ShareLink(item:output) { Label("Share exported film",systemImage:"square.and.arrow.up").font(.headline) }; Text("MP4 · \(model.project.renderWidth) × \(model.project.renderHeight)").font(.caption).foregroundStyle(.secondary) }
        }.padding(20).frame(maxWidth:.infinity,alignment:.leading)
    }
    private var titleEditor: some View {
        NavigationStack { Form { TextField("Film name",text:$draftName); Section("Title overlay · displayed throughout the film") {TextField("Your title",text:$draftTitle,axis:.vertical)} }.navigationTitle("Make it yours").toolbar {ToolbarItem(placement:.cancellationAction){Button("Cancel"){titleSheet=false}};ToolbarItem(placement:.confirmationAction){Button("Save"){model.update{$0.title=draftTitle;$0.name=draftName.isEmpty ? "Untitled film" : draftName};titleSheet=false}}} }
    }
    private func syncTrim() { if let i=model.selectedIndex {trimStart=model.project.clips[i].start;trimEnd=model.project.clips[i].end} }
    private func clock(_ t:Double) -> String {let n=Int(max(0,t.isFinite ? t : 0));return String(format:"%02d:%02d",n/60,n%60)}
}

private struct ImportedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType:.movie) { received in
            let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at:received.file,to:url)
            return ImportedMovie(url:url)
        }
        FileRepresentation(importedContentType:.image) { received in
            let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(received.file.pathExtension)
            try FileManager.default.copyItem(at:received.file,to:url)
            return ImportedMovie(url:url)
        }
    }
}
