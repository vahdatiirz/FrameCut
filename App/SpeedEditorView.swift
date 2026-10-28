import SwiftUI

struct SpeedEditorView:View {
    @Environment(\.dismiss) var dismiss
    @State private var speed:Double
    @State private var curve:SpeedCurve
    @State private var enabled:Bool
    @State private var error:String?
    let save:(Double,SpeedCurve?)->Void
    init(clip:Clip,save:@escaping(Double,SpeedCurve?)->Void){_speed=State(initialValue:clip.speed);_curve=State(initialValue:clip.speedCurve ?? SpeedCurve(points:[SpeedPoint(position:0,speed:1),SpeedPoint(position:1,speed:1)]));_enabled=State(initialValue:clip.speedCurve != nil);self.save=save}
    var body:some View {
        NavigationStack {
            Form {
                Section("Playback rate"){
                    LabeledContent("Constant speed"){TextField("Speed",value:$speed,format:.number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)}
                    Text("0.1× to 100×. Curve values multiply the constant speed.").font(.caption).foregroundStyle(.secondary)
                    Toggle("Speed curve",isOn:$enabled)
                }
                if enabled{
                    Section("Curve"){
                        Menu("Choose a preset"){ForEach(Array(SpeedCurve.presets.enumerated()),id:\.offset){_,preset in Button(preset.0){curve=preset.1}}}
                        Text("Positions run from 0 at the source in-point to 1 at the out-point. Rate changes are linear between points. Frame interpolation is not applied.").font(.caption).foregroundStyle(.secondary)
                        if curve.domainStart != nil{Text("This split clip retains the original ramp. Choose a preset to start a new curve.").font(.caption).foregroundStyle(.orange)}
                        ForEach($curve.points){$point in
                            VStack(alignment:.leading){
                                LabeledContent("Position (0–1)"){TextField("Position",value:$point.position,format:.number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)}
                                LabeledContent("Rate"){TextField("Rate",value:$point.speed,format:.number).keyboardType(.decimalPad).multilineTextAlignment(.trailing)}
                                if point.position != 0 && point.position != 1{Button("Remove point",role:.destructive){curve.points.removeAll{$0.id==point.id}}}
                            }
                        }
                        Button("Add point"){curve.points.append(SpeedPoint(position:0.5,speed:1))}.disabled(curve.points.count>=64)
                    }
                }
                if let error{Text(error).foregroundStyle(.red)}
            }.navigationTitle("Speed & curves").navigationBarTitleDisplayMode(.inline)
                .toolbar{
                    ToolbarItem(placement:.cancellationAction){Button("Cancel"){dismiss()}}
                    ToolbarItem(placement:.confirmationAction){Button("Save"){
                        do{guard speed.isFinite,(0.1...100).contains(speed) else{throw EditError.invalidSpeed};if enabled{curve.points.sort{$0.position<$1.position};try curve.validate()};save(speed,enabled ? curve : nil);dismiss()}catch{self.error=error.localizedDescription}
                    }}
                }
        }
    }
}
