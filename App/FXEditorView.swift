import SwiftUI
import CoreImage

struct FXEditorView:View {
    @Environment(\.dismiss) var dismiss
    let frame:CGImage?
    let clipEffects:ClipEffects
    let lut:CubeLUT?
    let canApply:Bool
    let save:([VisualFX])->Void
    @State private var items:[VisualFX]
    @State private var category="All"
    @State private var previewTime=0.5
    @State private var rendered:UIImage?
    @State private var error:String?
    private static let context=CIContext()
    init(frame:CGImage?,effects:ClipEffects,lut:CubeLUT?,canApply:Bool=true,initialKind:VisualFXKind?=nil,save:@escaping([VisualFX])->Void){self.frame=frame;clipEffects=effects;self.lut=lut;self.canApply=canApply;self.save=save;var initial=effects.visualFX ?? [];if let initialKind,initial.count<4{initial.append(VisualFX(kind:initialKind))};_items=State(initialValue:initial)}
    private var key:String{let encoder=JSONEncoder();encoder.outputFormatting = .sortedKeys;return ((try? encoder.encode(items).base64EncodedString()) ?? "")+String(previewTime)+String(describing:frame)}
    var body:some View {
        NavigationStack{
            ScrollView{
                VStack(alignment:.leading,spacing:18){
                    if let rendered{Image(uiImage:rendered).resizable().scaledToFit().frame(maxHeight:230).frame(maxWidth:.infinity).background(.black).clipShape(RoundedRectangle(cornerRadius:14))}
                    else{Text("Sample preview is loading or unavailable. You can still browse the FX library.").frame(maxWidth:.infinity,minHeight:120)}
                    if !canApply{Label("Sample preview only · add a clip to apply FX",systemImage:"photo").font(.subheadline)}
                    Text("Preview position: \(Int(previewTime*100))% of clip").font(.caption)
                    Slider(value:$previewTime,in:0...0.999).accessibilityLabel("FX preview position")
                    Text("12 local effects. Add up to four, set their strength and timing, then Apply. The image above previews one source frame; return to the editor to play the actual video.").font(.subheadline).foregroundStyle(.secondary)
                    Picker("FX category",selection:$category){ForEach(["All","Light","Blur","Mosaic","Stylize","Geometry"],id:\.self){Text($0).tag($0)}}
                    LazyVGrid(columns:[GridItem(.adaptive(minimum:140))],spacing:10){
                        ForEach(VisualFXKind.allCases.filter{category=="All" || $0.category==category}){kind in
                            Button{items.append(VisualFX(kind:kind));error=nil}label:{Label(kind.label,systemImage:"sparkles").frame(maxWidth:.infinity,minHeight:44)}.buttonStyle(.bordered).disabled(items.count>=4)
                        }
                    }
                    if items.isEmpty{Text("No FX applied. Choose an effect above.").foregroundStyle(.secondary)}
                    ForEach($items){$fx in
                        VStack(alignment:.leading,spacing:10){
                            HStack{Text(fx.kind.label).font(.headline);Spacer();Button("Remove",role:.destructive){items.removeAll{$0.id==fx.id}}}
                            Text("Strength: \(Int(fx.amount*100))%").font(.caption)
                            Slider(value:$fx.amount,in:0...1).accessibilityLabel(fx.kind.label+" strength")
                            Text("Start: \(Int(visible(fx.start,fx:fx)*100))%  ·  End: \(Int(visible(fx.end,fx:fx)*100))%").font(.caption.monospaced())
                            Slider(value:timeBinding($fx,leading:true),in:0...1).accessibilityLabel(fx.kind.label+" start")
                            Slider(value:timeBinding($fx,leading:false),in:0...1).accessibilityLabel(fx.kind.label+" end")
                            if fx.domainStart != 0 || fx.domainEnd != 1{Text("Timing is preserved from the original clip. Reapply to cover this entire split.").font(.caption).foregroundStyle(.secondary);Button("Reapply to this clip"){let kind=fx.kind,amount=fx.amount;fx=VisualFX(kind:kind);fx.amount=amount}}
                        }.padding().background(.white.opacity(0.06),in:RoundedRectangle(cornerRadius:14))
                    }
                    if let error{Text(error).foregroundStyle(.red)}
                }.padding(20)
            }.navigationTitle("FX · video effects").navigationBarTitleDisplayMode(.inline)
                .toolbar{
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){if canApply{Button("Apply"){do{try items.forEach{try $0.validate()};save(items);dismiss()}catch{self.error="Choose an end later than the start for every effect."}}}else{Button("Done"){dismiss()}}}
                }
        }.preferredColorScheme(.dark)
            .task(id:key){
                try? await Task.sleep(nanoseconds:80_000_000);guard !Task.isCancelled,let frame else{return}
                let input=ColorPipeline.apply(CIImage(cgImage:frame),effects:clipEffects,lut:lut)
                let image=VisualFXPipeline.apply(input,effects:items,progress:previewTime)
                if let cg=Self.context.createCGImage(image,from:image.extent){rendered=UIImage(cgImage:cg)}
            }
    }
    private func visible(_ value:Double,fx:VisualFX)->Double{max(0,min(1,(value-fx.domainStart)/(fx.domainEnd-fx.domainStart)))}
    private func timeBinding(_ fx:Binding<VisualFX>,leading:Bool)->Binding<Double>{Binding(get:{visible(leading ? fx.wrappedValue.start : fx.wrappedValue.end,fx:fx.wrappedValue)},set:{value in let v=fx.wrappedValue.domainStart+value*(fx.wrappedValue.domainEnd-fx.wrappedValue.domainStart);if leading{fx.wrappedValue.start=max(0,min(1,v))}else{fx.wrappedValue.end=max(0,min(1,v))}})}
}
