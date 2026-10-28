import SwiftUI
@main struct FrameCutApp: App {
    @StateObject private var model = EditorModel()
    var body: some Scene { WindowGroup { EditorView().environmentObject(model).preferredColorScheme(.dark).task{
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--framecut-smoke-test"){
            model.busyLabel="Running device checks with synthetic media…";model.busy=true
            await DeviceSmokeCheck.run();model.busy=false
        }
        #endif
    } } }
}
