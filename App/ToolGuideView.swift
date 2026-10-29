import SwiftUI

/// Task-first entry points reuse the existing editor panels and editing session.
struct ToolGuideView:View {
    @EnvironmentObject var model:EditorModel
    @Binding var tab:StudioTab
    @State private var query=""
    private struct Entry:Identifiable {
        let title:String
        let detail:String
        let keywords:String
        let destination:StudioTab
        let needsClip:Bool
        var id:String{title}
    }
    private let entries:[Entry]=[
        .init(title:"Start a film",detail:"Create a project, then choose photos or videos in the editor.",keywords:"import files new شروع عکس ویدئو پروژه",destination:.projects,needsClip:false),
        .init(title:"Apply an editing template",detail:"Choose a recipe for timing, color and titles. Review before applying; Undo restores your edit.",keywords:"recipe قالب تمپلیت",destination:.templates,needsClip:true),
        .init(title:"Change color and filters",detail:"Select a clip, compare looks, adjust their strength or import a .cube LUT.",keywords:"look brightness saturation exposure رنگ فیلتر نور",destination:.looks,needsClip:false),
        .init(title:"Blur or hide a region",detail:"Open Masks & privacy in Looks. Position a blur, mosaic or shape over the selected clip.",keywords:"mask mosaic privacy blur ماسک محو سانسور",destination:.looks,needsClip:true),
        .init(title:"Add timed video FX",detail:"Open FX, browse 12 local effects, set strength and start/end, then Apply. Return to the editor to play the result.",keywords:"fx effect blur bloom mosaic افکت جلوه محو",destination:.fx,needsClip:false),
        .init(title:"Write a title",detail:"Add the film title, then choose font, size, position and background.",keywords:"font text title متن عنوان فونت",destination:.text,needsClip:true),
        .init(title:"Add timed subtitles",detail:"Create a cue or import SRT. Set when it appears and disappears, then preview it.",keywords:"captions subtitle srt زیرنویس زمان متن",destination:.captions,needsClip:true),
        .init(title:"Generate subtitles offline",detail:"In Captions, choose the spoken language and generate. Review names and timing before export.",keywords:"whisper speech auto caption گفتار خودکار آفلاین",destination:.captions,needsClip:true),
        .init(title:"Add music or narration",detail:"Import audio, place it on the timeline, set volume and fade its edges.",keywords:"sound music voice fade audio صدا آهنگ موسیقی",destination:.audio,needsClip:true),
        .init(title:"Turn text into speech",detail:"In Audio, create narration using a voice installed on your device. Listen and adjust timing.",keywords:"tts speech narration گویندگی متن صدا",destination:.audio,needsClip:true),
        .init(title:"Put an image over a video",detail:"In Layers, import a photo, PNG or movie. Adjust position, size, opacity and start time.",keywords:"overlay sticker picture pip تصویر لایه استیکر",destination:.layers,needsClip:true),
        .init(title:"Animate a clip or layer",detail:"In Layers, open Motion for the selected item. Pick one of 19 original motions, then edit its keyframes.",keywords:"keyframe motion animation zoom fade حرکت انیمیشن کی فریم",destination:.layers,needsClip:true),
        .init(title:"Choose export quality",detail:"Choose resolution, frame rate and bitrate. Tap Export film below the quality settings to save the finished movie.",keywords:"save export 4k fps bitrate ذخیره خروجی کیفیت",destination:.export,needsClip:true)
    ]
    private var results:[Entry]{
        let terms=query.split(whereSeparator:{$0.isWhitespace}).map(String.init)
        return entries.filter{entry in terms.allSatisfy{term in (entry.title+" "+entry.detail+" "+entry.keywords).localizedCaseInsensitiveContains(term)}}
    }
    var body:some View {
        VStack(alignment:.leading,spacing:18){
            Text("What would you like to make?").font(.title.bold())
            Text("Start simple: import → arrange → add text and sound → preview → export. You can undo changes from the editor.").foregroundStyle(.secondary)
            TextField("Find a tool · جستجوی ابزار",text:$query).textFieldStyle(.roundedBorder).accessibilityLabel("Find a tool")
            if model.project.clips.isEmpty{Label("Add your first photo or video in the editor to unlock editing tools.",systemImage:"photo.on.rectangle").font(.subheadline).foregroundStyle(.secondary)}
            if results.isEmpty{Text("No matching tool. Try color, subtitles, music or export.").foregroundStyle(.secondary)}
            ForEach(results){entry in
                Button{tab=entry.destination}label:{
                    HStack(alignment:.top,spacing:14){
                        Image(systemName:entry.destination.icon).font(.title3).frame(width:30)
                        VStack(alignment:.leading,spacing:7){Text(entry.title).font(.headline);Text(entry.detail).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.leading)}
                        Spacer(minLength:0);Image(systemName:"chevron.right").font(.caption)
                    }.frame(maxWidth:.infinity,alignment:.leading).padding(16).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:16))
                }.buttonStyle(.plain).disabled(entry.needsClip && model.project.clips.isEmpty)
            }
            VStack(alignment:.leading,spacing:8){
                Text("Trim, split, speed and transitions").font(.headline)
                Text("Close this panel to use the timeline. Select a clip, drag its green edges to trim, or place the playhead and tap scissors to split. Speed is in the clip inspector; tap the + between two clips to preview a transition, adjust its duration, or apply it to every boundary. Clip tools includes reverse, freeze and frame extraction.").font(.subheadline).foregroundStyle(.secondary)
            }.padding(16).background(.white.opacity(0.05),in:RoundedRectangle(cornerRadius:16))
        }
    }
}
