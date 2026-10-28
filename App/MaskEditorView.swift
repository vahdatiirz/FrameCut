import SwiftUI
import CoreImage

struct MaskEditorView:View {
    @Environment(\.dismiss) var dismiss
    @State private var enabled:Bool
    @State private var mask:MaskSpec
    @State private var regions:[PrivacyRegion]
    @State private var error:String?
    let save:(MaskSpec?,[PrivacyRegion])->Void
    init(effects:ClipEffects,save:@escaping(MaskSpec?,[PrivacyRegion])->Void){_enabled=State(initialValue:effects.mask != nil);_mask=State(initialValue:effects.mask ?? MaskSpec());_regions=State(initialValue:effects.privacyRegions ?? []);self.save=save}
    var body:some View {
        NavigationStack {
            Form {
                Section("Clip mask"){
                    Toggle("Enable mask",isOn:$enabled)
                    if enabled{MaskPreview(spec:mask);MaskControls(spec:$mask)}
                }
                Section("Privacy regions"){
                    Text("Blur or mosaic selected areas. Regions stay attached to this clip’s frame and move with its motion keyframes.").font(.caption).foregroundStyle(.secondary)
                    Button("Add privacy region",systemImage:"plus"){regions.append(PrivacyRegion())}.disabled(regions.count>=64)
                }
                ForEach($regions){$region in
                    Section("Region"){
                        Picker("Effect",selection:$region.style){Text("Soft blur").tag(PrivacyStyle.blur);Text("Square mosaic").tag(PrivacyStyle.pixelate);Text("Hexagon mosaic").tag(PrivacyStyle.hexagon)}
                        LabeledContent("Strength"){Slider(value:$region.amount,in:0.01...1)}
                        MaskPreview(spec:region.mask)
                        MaskControls(spec:$region.mask)
                        Button("Remove region",role:.destructive){regions.removeAll{$0.id==region.id}}
                    }
                }
                if let error{Text(error).foregroundStyle(.red)}
            }.navigationTitle("Masks & privacy").navigationBarTitleDisplayMode(.inline)
                .toolbar{
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Save"){do{if enabled{try mask.validate()};try regions.forEach{try $0.validate()};save(enabled ? mask : nil,regions);dismiss()}catch{self.error=error.localizedDescription}}}
                }
        }
    }
}
private struct MaskControls:View {
    @Binding var spec:MaskSpec
    var body:some View {
        Picker("Shape",selection:$spec.shape){ForEach(MaskShape.allCases,id:\.self){Text($0.rawValue.replacingOccurrences(of:"([a-z])([A-Z0-9])",with:"$1 $2",options:.regularExpression).capitalized).tag($0)}}
        control("Horizontal position",value:$spec.centerX,range:0...1)
        control("Vertical position",value:$spec.centerY,range:0...1)
        control("Width",value:$spec.width,range:0.01...2)
        control("Height",value:$spec.height,range:0.01...2)
        control("Rotation",value:$spec.rotation,range:-180...180)
        control("Feather",value:$spec.feather,range:0...0.2)
        Toggle("Invert mask",isOn:$spec.inverted)
        if spec.shape == .custom{
            Text("Custom polygon · points run from 0 to 1, measured from the top left.").font(.caption).foregroundStyle(.secondary)
            ForEach($spec.points){$point in
                HStack{
                    TextField("X",value:$point.x,format:.number).keyboardType(.decimalPad)
                    TextField("Y",value:$point.y,format:.number).keyboardType(.decimalPad)
                    Button("Remove point",systemImage:"minus.circle",role:.destructive){spec.points.removeAll{$0.id==point.id}}.labelStyle(.iconOnly)
                }
            }
            Button("Add point"){spec.points.append(MaskPoint(x:0.5,y:0.5))}.disabled(spec.points.count>=64)
        }
    }
    private func control(_ title:String,value:Binding<Double>,range:ClosedRange<Double>)->some View {
        VStack(alignment:.leading,spacing:4){HStack{Text(title);Spacer();Text(String(format:"%.2f",value.wrappedValue)).font(.caption.monospaced()).foregroundStyle(.secondary)};Slider(value:value,in:range).accessibilityLabel(title)}
    }
}
private struct MaskPreview:View {
    let spec:MaskSpec
    @State private var image:CGImage?
    var body:some View {
        Group{if let image{Image(decorative:image,scale:1).resizable().scaledToFit()}else{Color.black}}
            .frame(height:145).frame(maxWidth:.infinity).background(.black,in:RoundedRectangle(cornerRadius:12))
            .task(id:spec){
                let bounds=CGRect(x:0,y:0,width:320,height:180)
                if let mask=PixelEffects.mask(spec,bounds:bounds){image=CIContext().createCGImage(mask,from:bounds)}else{image=nil}
            }
    }
}
