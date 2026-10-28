import SwiftUI
import AVFoundation
import PhotosUI

struct TimelinePanel:View {
    @EnvironmentObject var model:EditorModel
    @Binding var playhead:Double
    @Binding var scrubbing:Bool
    @Binding var photos:[PhotosPickerItem]
    let importFiles:()->Void
    let openStudio:(StudioTab)->Void
    @State private var zoom:Double=4
    @State private var viewport:CGRect = .zero
    private let mint=Color(red:0.68,green:0.96,blue:0.35)
    private var scale:Double{30*zoom}
    private var textLanes:TimelineLaneLayout{TimelineLaneLayout(regions:(model.project.captions ?? []).map{($0.id,$0.start,$0.end-$0.start)})}
    private var soundLanes:TimelineLaneLayout{TimelineLaneLayout(regions:(model.project.audioRegions ?? []).map{($0.id,$0.timelineStart,$0.duration)},reservedLanes:model.project.musicFilename == nil ? 0 : 1)}
    private var layerLanes:TimelineLaneLayout{TimelineLaneLayout(regions:(model.project.overlays ?? []).map{($0.id,$0.timelineStart,$0.clip.duration)})}
    private var audioY:Double{92+Double(textLanes.count)*30}
    private var layerY:Double{audioY+Double(soundLanes.count)*30}
    private var timelineHeight:Double{layerY+Double(layerLanes.count)*30+4}
    var body:some View {
        GeometryReader{geometry in
            let width=max(1,geometry.size.width-62)
            let window=viewport.width>0 ? viewport : CGRect(x:0,y:0,width:width,height:190)
            let contentWidth=max(width,model.project.duration*scale+48)
            VStack(spacing:8){
                HStack(spacing:12){
                    Text("TIMELINE").font(.caption2.monospaced().bold()).foregroundStyle(.secondary)
                    Spacer()
                    Button{zoom=max(1,zoom/1.5)}label:{Image(systemName:"minus.magnifyingglass")}.accessibilityLabel("Zoom timeline out")
                    Slider(value:$zoom,in:1...30).frame(maxWidth:130).accessibilityLabel("Timeline zoom")
                    Text(String(format:"%.1f×",zoom)).font(.caption.monospaced()).frame(width:42)
                    Button{zoom=min(30,zoom*1.5)}label:{Image(systemName:"plus.magnifyingglass")}.accessibilityLabel("Zoom timeline in")
                    Menu{
                        PhotosPicker(selection:$photos,maxSelectionCount:20,matching:.any(of:[.images,.videos])){Label("Photo Library",systemImage:"photo.on.rectangle")}
                        Button("Files",action:importFiles)
                    }label:{Image(systemName:"plus.circle.fill").font(.title3)}.accessibilityLabel("Import media")
                }
                ScrollView(.vertical){HStack(alignment:.top,spacing:6){
                    VStack(spacing:0){
                        Color.clear.frame(height:22)
                        trackLabel("Video",icon:"film",height:70){openStudio(.projects)}
                        trackLabel("Text",icon:"captions.bubble",height:Double(textLanes.count)*30){openStudio(.captions)}
                        trackLabel("Audio",icon:"waveform",height:Double(soundLanes.count)*30){openStudio(.audio)}
                        trackLabel("Layers",icon:"rectangle.on.rectangle",height:Double(layerLanes.count)*30){openStudio(.layers)}
                    }.frame(width:44)
                    ScrollView(.horizontal){
                        ZStack(alignment:.topLeading){
                            RoundedRectangle(cornerRadius:5).fill(.white.opacity(0.025)).frame(width:contentWidth,height:68).offset(y:22)
                            ForEach(0..<(textLanes.count+soundLanes.count+layerLanes.count),id:\.self){row in RoundedRectangle(cornerRadius:5).fill(.white.opacity(0.025)).frame(width:contentWidth,height:28).offset(y:92+Double(row)*30)}
                            ruler(width:contentWidth,window:window)
                            clips(window:window)
                            captionRegions(window:window)
                            audioRegions(window:window)
                            overlayRegions(window:window)
                            Rectangle().fill(mint).frame(width:2,height:timelineHeight-3).offset(x:max(0,playhead*scale)).allowsHitTesting(false)
                        }.frame(width:contentWidth,height:timelineHeight,alignment:.topLeading).coordinateSpace(name:"filmTimeline")
                    }
                    .onScrollGeometryChange(for:CGRect.self){$0.visibleRect}action:{_,rect in viewport=rect}
                    .scrollIndicators(.visible)
                }}
            }.padding(12)
        }.background(Color(red:0.075,green:0.09,blue:0.10))
    }
    private func trackLabel(_ name:String,icon:String,height:Double,action:@escaping()->Void)->some View {
        Button(action:action){VStack(spacing:3){Image(systemName:icon);Text(name).font(.system(size:8,weight:.semibold))}.frame(width:42,height:height)}.buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Open \(name) tools")
    }
    private func ruler(width:Double,window:CGRect)->some View {
        let step:Double=scale>=300 ? 0.1 : scale>=100 ? 0.5 : 1
        let first=max(0,Int(floor(window.minX/scale/step))-1)
        let last=max(first,Int(ceil((window.maxX+80)/scale/step)))
        return ZStack(alignment:.topLeading){
            Rectangle().fill(.white.opacity(0.02)).frame(width:width,height:22)
            ForEach(first...last,id:\.self){i in
                let time=Double(i)*step
                VStack(spacing:0){Text(String(format:step<1 ? "%.1f" : "%.0f",time)).font(.system(size:8,design:.monospaced)).foregroundStyle(.secondary);Rectangle().fill(.gray.opacity(0.4)).frame(width:1,height:5)}.offset(x:time*scale,y:0)
            }
        }.frame(width:width,height:22).contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance:0,coordinateSpace:.named("filmTimeline")).onChanged{value in
                scrubbing=true;model.player.pause();seek(value.location.x/scale)
            }.onEnded{value in seek(value.location.x/scale);scrubbing=false})
            .accessibilityElement(children:.ignore).accessibilityLabel("Timeline ruler. Drag to seek.")
    }
    private func seek(_ seconds:Double){
        playhead=max(0,min(model.project.duration,seconds))
        model.player.seek(to:CMTime(seconds:playhead,preferredTimescale:600000),toleranceBefore:.zero,toleranceAfter:.zero)
        let placements=model.project.placements
        if let i=placements.indices.last(where:{playhead>=placements[$0].start && playhead<placements[$0].start+placements[$0].duration}){model.selected=model.project.clips[i].id}
    }
    private func visible(_ start:Double,_ duration:Double,window:CGRect)->Bool {start*scale+duration*scale>=window.minX-200 && start*scale<=window.maxX+200}
    private func clipped(_ start:Double,_ duration:Double,window:CGRect)->(x:Double,width:Double){
        let left=max(start*scale,max(0,window.minX-200)),right=min((start+duration)*scale,window.maxX+200)
        return(left,max(2,right-left))
    }
    private func clips(window:CGRect)->some View {
        let placements=model.project.placements
        return ForEach(Array(model.project.clips.enumerated()),id:\.element.id){i,clip in
            let start=placements[i].start
            if visible(start,clip.duration,window:window){
                let rect=clipped(start,clip.duration,window:window)
                TimelineClipCell(clip:clip,mediaRoot:model.mediaRoot,width:rect.width,scale:scale,selected:clip.id==model.selected,leftHandle:rect.x<=start*scale+0.01,rightHandle:rect.x+rect.width>=(start+clip.duration)*scale-0.01,select:{
                    model.selected=clip.id;playhead=start;model.player.seek(to:CMTime(seconds:start,preferredTimescale:600000))
                },commit:{candidate in
                    model.selected=clip.id;model.update{p in guard let index=p.clips.firstIndex(where:{$0.id==clip.id}) else{return};p.clips[index]=candidate}
                })
                .offset(x:rect.x,y:24)
                .draggable(clip.id.uuidString)
                .dropDestination(for:String.self){values,_ in
                    guard let value=values.first,let id=UUID(uuidString:value),model.project.clips.contains(where:{$0.id==id}) else{return false}
                    model.update{try $0.moveClip(id,before:clip.id)};model.selected=id;return true
                }
            }
        }
    }
    private func captionRegions(window:CGRect)->some View {
        ForEach(model.project.captions ?? []){cue in
            if visible(cue.start,cue.end-cue.start,window:window){
                let rect=clipped(cue.start,cue.end-cue.start,window:window)
                TimelineRegionCell(label:cue.text,color:.purple,width:rect.width,scale:scale,open:{openStudio(.captions)}){delta in
                    model.update{p in if let i=p.captions?.firstIndex(where:{$0.id==cue.id}){try p.captions?[i].shift(by:max(-cue.start,delta))}}
                }.offset(x:rect.x,y:94+Double(textLanes.lanes[cue.id] ?? 0)*30)
            }
        }
    }
    private func audioRegions(window:CGRect)->some View {
        ZStack(alignment:.topLeading){
            if model.project.musicFilename != nil{
                let rect=clipped(0,model.project.duration,window:window)
                TimelineRegionCell(label:"Background music",color:.green,width:rect.width,scale:scale,open:{openStudio(.audio)},move:{_ in}).offset(x:rect.x,y:audioY+2)
            }
            ForEach(model.project.audioRegions ?? []){region in
                if visible(region.timelineStart,region.duration,window:window){
                    let rect=clipped(region.timelineStart,region.duration,window:window)
                    TimelineRegionCell(label:region.name,color:.green,width:rect.width,scale:scale,open:{openStudio(.audio)}){delta in model.update{p in if let i=p.audioRegions?.firstIndex(where:{$0.id==region.id}){p.audioRegions?[i].timelineStart=max(0,region.timelineStart+delta)}}}.offset(x:rect.x,y:audioY+2+Double(soundLanes.lanes[region.id] ?? 0)*30)
                }
            }
        }
    }
    private func overlayRegions(window:CGRect)->some View {
        ForEach(model.project.overlays ?? []){layer in
            if visible(layer.timelineStart,layer.clip.duration,window:window){
                let rect=clipped(layer.timelineStart,layer.clip.duration,window:window)
                TimelineRegionCell(label:layer.clip.name,color:.orange,width:rect.width,scale:scale,open:{openStudio(.layers)}){delta in model.update{p in if let i=p.overlays?.firstIndex(where:{$0.id==layer.id}){p.overlays?[i].timelineStart=max(0,layer.timelineStart+delta)}}}.offset(x:rect.x,y:layerY+2+Double(layerLanes.lanes[layer.id] ?? 0)*30)
            }
        }
    }
}
private struct TimelineClipCell:View {
    let clip:Clip
    let mediaRoot:URL
    let width:Double
    let scale:Double
    let selected:Bool
    let leftHandle:Bool
    let rightHandle:Bool
    let select:()->Void
    let commit:(Clip)->Void
    @State private var thumbnail:UIImage?
    @State private var draft:Clip?
    private var value:Clip{draft ?? clip}
    var body:some View {
        ZStack(alignment:.leading){
            RoundedRectangle(cornerRadius:7).fill(selected ? Color.green.opacity(0.24) : .white.opacity(0.09))
            if width>45{
                HStack(spacing:8){
                    if let thumbnail{Image(uiImage:thumbnail).resizable().scaledToFill().frame(width:min(58,width/3),height:60).clipped().clipShape(RoundedRectangle(cornerRadius:5))}
                    if width>110{VStack(alignment:.leading,spacing:5){Text(clip.name).font(.caption.bold()).lineLimit(1);Text(String(format:"%.2fs · %.2g×",value.duration,clip.speed)).font(.system(size:9,design:.monospaced)).foregroundStyle(.secondary);if draft != nil{Text(String(format:"%.2f → %.2f",value.start,value.end)).font(.system(size:8,design:.monospaced))}}}
                    Spacer(minLength:0)
                }.padding(.horizontal,12)
            }
            RoundedRectangle(cornerRadius:7).stroke(selected ? .green : .white.opacity(0.12),lineWidth:selected ? 2 : 1)
            if selected{
                HStack{
                    if leftHandle{handle(leading:true)}
                    Spacer(minLength:0)
                    if rightHandle{handle(leading:false)}
                }
            }
        }.frame(width:width,height:64).contentShape(Rectangle()).onTapGesture(perform:select)
            .accessibilityElement(children:.combine).accessibilityLabel("\(clip.name), \(String(format:"%.2f",clip.duration)) seconds")
            .task(id:clip.filename+String(clip.start)){
                let generator=AVAssetImageGenerator(asset:AVURLAsset(url:mediaRoot.appendingPathComponent(clip.filename)));generator.appliesPreferredTrackTransform=true;generator.maximumSize=CGSize(width:128,height:90)
                do{let result=try await generator.image(at:CMTime(seconds:clip.start,preferredTimescale:600));try Task.checkCancellation();thumbnail=UIImage(cgImage:result.image)}catch{thumbnail=nil}
            }
    }
    private func handle(leading:Bool)->some View {
        RoundedRectangle(cornerRadius:3).fill(.green).frame(width:11,height:54).overlay(Rectangle().fill(.black.opacity(0.6)).frame(width:2,height:17))
            .highPriorityGesture(DragGesture(minimumDistance:2).onChanged{gesture in
                let delta=gesture.translation.width/scale
                draft=try? clip.applyingTimelineTrim(leadingOutputDelta:leading ? delta : 0,trailingOutputDelta:leading ? 0 : delta)
            }.onEnded{_ in if let draft{commit(draft)};draft=nil})
            .accessibilityLabel(leading ? "Trim clip start" : "Trim clip end")
    }
}
private struct TimelineRegionCell:View {
    let label:String
    let color:Color
    let width:Double
    let scale:Double
    let open:()->Void
    let move:(Double)->Void
    @GestureState private var translation:Double=0
    var body:some View {
        RoundedRectangle(cornerRadius:5).fill(color.opacity(0.25)).overlay(alignment:.leading){if width>25{Text(label).font(.system(size:9,weight:.medium)).lineLimit(1).padding(.horizontal,7)}}
            .overlay(RoundedRectangle(cornerRadius:5).stroke(color.opacity(0.6)))
            .frame(width:width,height:25).offset(x:translation).contentShape(Rectangle()).onTapGesture(perform:open)
            .gesture(DragGesture(minimumDistance:5).updating($translation){value,state,_ in state=value.translation.width}.onEnded{value in move((value.translation.width/scale*30).rounded()/30)})
            .accessibilityLabel(label)
    }
}
