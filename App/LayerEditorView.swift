import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct LayerEditorView:View {
    @EnvironmentObject var model:EditorModel
    @State private var importing=false
    @State private var loading=false
    @State private var draft:OverlayLayer?
    @State private var motion=false
    var body:some View {
        VStack(alignment:.leading,spacing:18) {
            Text("More than one frame.").font(.title.bold())
            Text("Overlay videos, photos and transparent PNG stickers with independent timing, framing, opacity and masks. Layers lower in this list appear above earlier layers.").foregroundStyle(.secondary)
            HStack{
                Button("Add overlay",systemImage:"rectangle.on.rectangle"){importing=true}.buttonStyle(.borderedProminent).disabled(loading || model.project.clips.isEmpty)
                Button("Animate selected clip",systemImage:"diamond"){motion=true}.buttonStyle(.bordered).disabled(model.selectedIndex==nil)
            }
            if loading{ProgressView("Importing overlay…")}
            ForEach(model.project.overlays ?? []){layer in
                HStack{
                    Button{draft=layer}label:{VStack(alignment:.leading,spacing:5){Text(layer.clip.name).font(.headline);Text(String(format:"%.2f – %.2f s · %@",layer.timelineStart,layer.timelineStart+layer.clip.duration,layer.mask.rawValue)).font(.caption.monospaced()).foregroundStyle(.secondary)}.frame(maxWidth:.infinity,alignment:.leading)}.buttonStyle(.plain)
                    Button("Bring forward",systemImage:"square.2.layers.3d.top.filled"){model.update{p in if let i=p.overlays?.firstIndex(where:{$0.id==layer.id}),i<(p.overlays?.count ?? 0)-1{p.overlays?.swapAt(i,i+1)}}}.labelStyle(.iconOnly)
                    Button("Delete",systemImage:"trash",role:.destructive){model.update{$0.overlays?.removeAll{$0.id==layer.id}}}.labelStyle(.iconOnly)
                }.padding(14).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:14))
            }
        }
        .fileImporter(isPresented:$importing,allowedContentTypes:[.movie,.image],allowsMultipleSelection:false){result in
            Task{
                loading=true;defer{loading=false}
                var copied:String?
                do{
                    guard let url=try result.get().first else{return}
                    let name=try model.copyMedia(url);copied=name
                    let asset=AVURLAsset(url:model.mediaRoot.appendingPathComponent(name))
                    let still=UTType(filenameExtension:url.pathExtension)?.conforms(to:.image) == true
                    let length:Double
                    if still{length=3}else{guard try await !asset.loadTracks(withMediaType:.video).isEmpty else{throw EditError.missingVideo};length=try await asset.load(.duration).seconds}
                    let clip=Clip(filename:name,name:url.deletingPathExtension().lastPathComponent,duration:length)
                    var layer=OverlayLayer(clip:clip);layer.isStill=still;let t=model.player.currentTime().seconds;layer.timelineStart=max(0,min(t.isFinite ? t : 0,max(0,model.project.duration-0.1)))
                    try layer.validate();model.update{$0.overlays=($0.overlays ?? [])+[layer]};draft=layer
                }catch{if let copied{try? FileManager.default.removeItem(at:model.mediaRoot.appendingPathComponent(copied))};model.message="Overlay import failed: "+error.localizedDescription}
            }
        }
        .sheet(item:$draft){layer in LayerDraftView(layer:layer){value in model.update{p in if let i=p.overlays?.firstIndex(where:{$0.id==value.id}){p.overlays?[i]=value}}}}
        .sheet(isPresented:$motion){if let i=model.selectedIndex {MotionEditorView(track:model.project.clips[i].motion){value in model.updateClip{$0.motion=value}}}}
    }
}
private struct LayerDraftView:View {
    @Environment(\.dismiss) var dismiss
    @State var layer:OverlayLayer
    let save:(OverlayLayer)->Void
    @State private var error:String?
    @State private var motion=false
    var body:some View {
        NavigationStack {
            Form {
                Section("Timing"){
                    numeric("Place at",value:$layer.timelineStart)
                    numeric("Source in",value:$layer.clip.start)
                    if layer.isStill == true{LabeledContent("Photo duration"){TextField("Duration",value:Binding(get:{layer.clip.end},set:{layer.clip.end=$0;layer.clip.sourceDuration=$0}),format:.number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)}}else{numeric("Source out",value:$layer.clip.end)}
                    numeric("Speed",value:$layer.clip.speed)
                }
                Section("Layout"){
                    slider("Horizontal position",value:$layer.centerX,range:0...1)
                    slider("Vertical position",value:$layer.centerY,range:0...1)
                    slider("Width",value:$layer.width,range:0.05...2)
                    slider("Height",value:$layer.height,range:0.05...2)
                    slider("Opacity",value:$layer.opacity,range:0...1)
                    Picker("Mask",selection:$layer.mask){ForEach(LayerMask.allCases,id:\.self){Text($0.rawValue).tag($0)}}
                    Picker("Frame",selection:Binding(get:{(layer.clip.effects ?? ClipEffects()).fit},set:{v in var e=layer.clip.effects ?? ClipEffects();e.fit=v;layer.clip.effects=e})){ForEach(FrameFit.allCases,id:\.self){Text($0.rawValue.capitalized).tag($0)}}
                }
                Section("Movement & sound"){
                    Button("Edit keyframes"){motion=true}
                    slider("Overlay audio",value:$layer.clip.volume,range:0...1)
                }
                if let error{Text(error).foregroundStyle(.red)}
            }.navigationTitle(layer.clip.name).navigationBarTitleDisplayMode(.inline)
                .toolbar{
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Save"){do{try layer.validate();save(layer);dismiss()}catch{self.error=error.localizedDescription}}}
                }
                .sheet(isPresented:$motion){MotionEditorView(track:layer.clip.motion){layer.clip.motion=$0}}
        }
    }
    private func numeric(_ name:String,value:Binding<Double>)->some View {LabeledContent(name){TextField(name,value:value,format:.number.precision(.fractionLength(3))).keyboardType(.decimalPad).multilineTextAlignment(.trailing)}}
    private func slider(_ name:String,value:Binding<Double>,range:ClosedRange<Double>)->some View {VStack(alignment:.leading){Text(name).font(.subheadline);Slider(value:value,in:range)}}
}

struct MotionEditorView:View {
    @Environment(\.dismiss) var dismiss
    @State private var track:MotionTrack
    let save:(MotionTrack?)->Void
    @State private var error:String?
    init(track:MotionTrack?,save:@escaping(MotionTrack?)->Void){_track=State(initialValue:track ?? MotionTrack(keyframes:[MotionKeyframe(time:0),MotionKeyframe(time:1)]));self.save=save}
    var body:some View {
        NavigationStack {
            Form {
                Section("Animation"){
                    Text("Keyframe time runs from 0 at the clip’s start to 1 at its end. Position is relative to the frame; positive vertical values move down.").font(.caption).foregroundStyle(.secondary)
                    if track.domainStart != nil{Text("This split clip retains its original motion. Reset the animation to edit timing from this clip’s new start.").font(.caption).foregroundStyle(.orange)}
                    Menu("Start with a motion"){
                        ForEach(MotionPreset.allCases){preset in Button(preset.label){track=preset.track}}
                    }
                    Button("Reset animation"){track=MotionTrack(keyframes:[MotionKeyframe(time:0),MotionKeyframe(time:1)])}
                    Button("Remove animation",role:.destructive){save(nil);dismiss()}
                }
                ForEach($track.keyframes){$key in
                    Section(String(format:"Keyframe %.3f",key.time)){
                        field("Time (0–1)",value:$key.time)
                        field("Horizontal offset",value:$key.x)
                        field("Vertical offset",value:$key.y)
                        field("Scale",value:$key.scale)
                        field("Rotation in degrees",value:$key.rotation)
                        LabeledContent("Opacity"){Slider(value:$key.opacity,in:0...1)}
                        Picker("Curve to next key",selection:$key.curve){ForEach(MotionCurve.allCases,id:\.self){Text($0.rawValue).tag($0)}}
                        Button("Delete keyframe",role:.destructive){track.keyframes.removeAll{$0.id==key.id}}
                    }
                }
                Button("Add keyframe"){var key=track.sample(at:0.5);key.id=UUID();key.time=((track.domainStart ?? 0)+(track.domainEnd ?? 1))/2;track.keyframes.append(key)}
                if let error{Text(error).foregroundStyle(.red)}
            }.navigationTitle("Motion keyframes").navigationBarTitleDisplayMode(.inline)
                .toolbar{
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Save"){do{track.keyframes.sort{$0.time<$1.time};try track.validate();save(track);dismiss()}catch{self.error=error.localizedDescription}}}
                }
        }
    }
    private func field(_ name:String,value:Binding<Double>)->some View{LabeledContent(name){TextField(name,value:value,format:.number.precision(.fractionLength(3))).keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing)}}

}
