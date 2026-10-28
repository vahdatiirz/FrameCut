import SwiftUI
import UniformTypeIdentifiers

struct FontImportButton:View {
    @EnvironmentObject var model:EditorModel
    let apply:(String,String)->Void
    @State private var importing=false
    @State private var pendingFile:String?
    @State private var faces:[String]=[]
    var body:some View {
        Button("Import font",systemImage:"textformat.abc"){importing=true}.buttonStyle(.bordered)
            .fileImporter(isPresented:$importing,allowedContentTypes:[.font],allowsMultipleSelection:false){result in
                var copied:String?
                do{
                    guard let url=try result.get().first else{return}
                    let file=try model.copyMedia(url);copied=file
                    let names=try FontRegistry.register(model.mediaRoot.appendingPathComponent(file))
                    if names.count==1{apply(file,names[0])}else{faces=names;pendingFile=file}
                }catch{if let copied{try? FileManager.default.removeItem(at:model.mediaRoot.appendingPathComponent(copied))};model.message="Font import failed: "+error.localizedDescription}
            }
            .confirmationDialog("Choose a font face",isPresented:Binding(get:{pendingFile != nil},set:{if !$0{pendingFile=nil}}),titleVisibility:.visible){
                ForEach(faces,id:\.self){name in Button(name){if let file=pendingFile{apply(file,name)};pendingFile=nil}}
                Button("Cancel",role:.cancel){pendingFile=nil}
            }
    }
}
