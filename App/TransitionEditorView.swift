import SwiftUI

struct TransitionEditorView:View {
    @Environment(\.dismiss) var dismiss
    @State private var enabled:Bool
    @State private var transition:ClipTransition
    @State private var error:String?
    let limit:Double
    let save:(ClipTransition?)->Void
    init(from:UUID,to:UUID,current:ClipTransition?,limit:Double,save:@escaping(ClipTransition?)->Void){_enabled=State(initialValue:current != nil);_transition=State(initialValue:current ?? ClipTransition(from:from,to:to,duration:0.5));self.limit=limit;self.save=save}
    var body:some View {
        NavigationStack {
            Form {
                Section("Between clips"){
                    Toggle("Enable transition",isOn:$enabled)
                    if enabled{
                        Picker("Style",selection:$transition.style){ForEach(TransitionStyle.allCases,id:\.self){Text($0.rawValue.replacingOccurrences(of:"([a-z])([A-Z])",with:"$1 $2",options:.regularExpression).capitalized).tag($0)}}
                        LabeledContent("Duration in seconds"){TextField("Duration",value:$transition.duration,format:.number.precision(.fractionLength(3))).keyboardType(.decimalPad).multilineTextAlignment(.trailing)}
                        Text(String(format:"Effective overlap: %.3f seconds",min(limit,max(0,transition.duration)))).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Transitions overlap two playing clips, shortening the film. The overlap is limited to half of each neighboring clip so that three clips never collide. Clip audio crossfades during the overlap.").font(.caption).foregroundStyle(.secondary)
                }
                if let error{Text(error).foregroundStyle(.red)}
            }.navigationTitle("Incoming transition").navigationBarTitleDisplayMode(.inline)
                .toolbar{
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Save"){do{if enabled{try transition.validate()};save(enabled ? transition : nil);dismiss()}catch{self.error=error.localizedDescription}}}
                }
        }
    }
}
