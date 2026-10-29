import SwiftUI
import UniformTypeIdentifiers

struct GenerationBridgeView:View {
    @EnvironmentObject var model:EditorModel
    @Environment(\.dismiss) var dismiss
    let from:UUID
    let to:UUID
    let duration:Double
    let imported:(GeneratedBridgeAsset)->Void
    @State private var preset:GenerationPreset = .smokeDrift
    @State private var prompt=GenerationPreset.smokeDrift.suggestedPrompt
    @State private var jobURL:URL?
    @State private var importer=false
    @State private var working=false
    @State private var error:String?
    @State private var task:Task<Void,Never>?
    var body:some View {
        Form {
            Section("Local generation on your Mac") {
                Text("Generate a new video between two endpoint images using the free Mac companion. This device does not run the video model. No VN account or credits are used.")
                Text("آزمایشی روی مک: این بخش ترنزیشن‌های پرمیوم VN را داخل آیپد اجرا نمی‌کند. گزینه‌های زیر دستورهای پیشنهادی‌اند و کیفیت همهٔ آن‌ها تأیید نشده است.").font(.caption).foregroundStyle(.secondary)
                Text("Experimental: generated motion and identity need visual review. These presets are independent prompts, not verified copies of VN effects.").font(.caption).foregroundStyle(.secondary)
            }
            Section("1 · Prepare two frames") {
                Picker("Intended effect",selection:$preset){ForEach(GenerationPreset.allCases,id:\.self){Text($0.title).tag($0)}}
                TextEditor(text:$prompt).frame(minHeight:110).accessibilityLabel("Generation prompt")
                Text(String(format:"Existing overlap: %.2f s. The job contains only the two rendered endpoint images and your prompt.",duration)).font(.caption)
                Button("Prepare generation request",systemImage:"photo.stack"){run{
                    jobURL=try await model.prepareGenerationJob(from:from,to:to,preset:preset,prompt:prompt,duration:duration)
                }}.disabled(working)
                if let jobURL{ShareLink(item:jobURL){Label("Save or share request to Mac",systemImage:"square.and.arrow.up")}}
            }
            Section("2 · Render, then import") {
                Text("Run the FrameCut companion on your Mac with this request. It writes an MP4. Move that movie back to Files, then import it here. No automatic cloud upload occurs.").font(.subheadline)
                Text("Use Import rendered bridge in the bottom bar to choose the MP4.").font(.caption)
                Text("Import prepares a draft. Use Apply in the transition editor to save it, or Cancel to keep the film unchanged. Regenerate after changing the source clips or their color.").font(.caption).foregroundStyle(.secondary)
            }
            if working{ProgressView("Preparing…");Button("Cancel operation"){task?.cancel()}}
            if let error{Text(error).foregroundStyle(.red)}
        }.navigationTitle("AI bridge · پل مولد").navigationBarTitleDisplayMode(.inline)
            .toolbar{ToolbarItem(placement:.bottomBar){Button("Import rendered bridge",systemImage:"film.stack"){importer=true}.disabled(working)}}
            .onChange(of:preset){_,value in prompt=value.suggestedPrompt;jobURL=nil}
            .fileImporter(isPresented:$importer,allowedContentTypes:[.movie]){result in
                switch result {
                case .success(let url):run{let asset=try await model.prepareGeneratedBridgeImport(url);imported(asset);dismiss()}
                case .failure(let e):error=e.localizedDescription
                }
            }
            .onDisappear{task?.cancel()}
    }
    private func run(_ operation:@escaping @MainActor () async throws->Void){
        task?.cancel();working=true;error=nil
        task=Task{@MainActor in
            defer{working=false}
            do{try await operation()}catch is CancellationError{}catch{self.error=error.localizedDescription}
        }
    }
}
