import SwiftUI
import CoreImage

struct LookPreviewView:View {
    let source:CGImage?
    let effects:ClipEffects
    let lut:CubeLUT?
    let sample:Bool
    @State private var original=false
    @State private var rendered:UIImage?
    private static let context=CIContext()
    private var key:String{let e=JSONEncoder();e.outputFormatting = .sortedKeys;return ((try? e.encode(effects).base64EncodedString()) ?? "")+String(original)+String(describing:source)}
    var body:some View {
        VStack(spacing:7){
            HStack{Text(original ? "Original" : effects.look.label).font(.headline);if sample{Text("نمونه / Sample").font(.caption).foregroundStyle(.secondary)};Spacer();Toggle("Before",isOn:$original).font(.caption).fixedSize()}
            if let rendered{Image(uiImage:rendered).resizable().scaledToFit().frame(height:170).frame(maxWidth:.infinity).background(.black).clipShape(RoundedRectangle(cornerRadius:12))}
            else{ProgressView("Loading preview…").frame(maxWidth:.infinity,minHeight:100)}
            Text(sample ? "انتخاب Look، همین تصویر نمونه را تغییر می‌دهد؛ برای اعمال روی فیلم، ابتدا رسانه اضافه کن." : "Selected look preview · play the editor to review the whole film.").font(.caption).foregroundStyle(.secondary)
        }.padding(.horizontal,22).padding(.vertical,10)
            .onChange(of:effects.look){_,_ in original=false}
            .task(id:key){
                guard let source else{return}
                let input=CIImage(cgImage:source)
                let output=original ? input : ColorPipeline.apply(input,effects:effects,lut:lut)
                if let cg=Self.context.createCGImage(output,from:output.extent){rendered=UIImage(cgImage:cg)}
            }
    }
}
