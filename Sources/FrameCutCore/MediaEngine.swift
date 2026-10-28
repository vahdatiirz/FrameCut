import Foundation
import AVFoundation
import CoreImage
import CoreGraphics
import CoreText

public struct RenderedTimeline {
    public let composition: AVMutableComposition
    public let videoComposition: AVMutableVideoComposition
    public let audioMix: AVMutableAudioMix
}
public enum MediaEngine {
    public static func build(_ project: Project, mediaRoot: URL, size: CGSize? = nil, titleOverlay: Bool = false) async throws -> RenderedTimeline {
        try project.validate()
        guard !project.clips.isEmpty else { throw EditError.noClips }
        var fonts:[String:[String]]=[:]
        for style in [project.style ?? ProjectStyle()]+(project.captions ?? []).map(\.style){
            if let file=style.fontFilename,let name=style.fontPostScriptName {
                let faces: [String]
                if let loaded=fonts[file]{faces=loaded}else{faces=try FontRegistry.register(mediaRoot.appendingPathComponent(file));fonts[file]=faces}
                guard faces.contains(name) else{throw EditError.invalidProject}
            }
        }
        let composition = AVMutableComposition()
        let renderSize = size ?? CGSize(width: project.renderWidth, height: project.renderHeight)
        var cursor = CMTime.zero
        var instructions: [FrameInstruction] = []
        let overlay = titleOverlay ? titleImage(project.title,size:renderSize,style:project.style ?? ProjectStyle()) : nil
        var audioParameters: [AVMutableAudioMixInputParameters] = []
        let placements=project.placements
        for (index,clip) in project.clips.enumerated() {
            cursor=time(placements[index].start)
            try Task.checkCancellation()
            let asset = AVURLAsset(url: mediaRoot.appendingPathComponent(clip.filename))
            guard let source = try await asset.loadTracks(withMediaType: .video).first,
                  let video = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else { throw EditError.missingVideo }
            let assetDuration = try await asset.load(.duration)
            guard clip.end <= assetDuration.seconds + 0.05 else { throw EditError.invalidRange }
            let scaled = time(placements[index].start+clip.duration)-cursor
            try insert(clip,source:source,into:video,at:cursor)
            let natural = try await source.load(.naturalSize)
            let effects=clip.effects ?? ClipEffects()
            let preferred = try await source.load(.preferredTransform).concatenating(CGAffineTransform(rotationAngle:Double(effects.quarterTurns)*Double.pi/2))
            let bounds = CGRect(origin: .zero, size: natural).applying(preferred)
            let scale = effects.fit == .fill ? max(renderSize.width / abs(bounds.width), renderSize.height / abs(bounds.height)) : min(renderSize.width / abs(bounds.width), renderSize.height / abs(bounds.height))
            var transform = preferred.concatenating(CGAffineTransform(translationX: -bounds.minX, y: -bounds.minY))
            if effects.mirrored { transform=transform.concatenating(CGAffineTransform(a:-1,b:0,c:0,d:1,tx:abs(bounds.width),ty:0)) }
            transform=transform.concatenating(CGAffineTransform(scaleX: scale,y: scale))
                .concatenating(CGAffineTransform(translationX: (renderSize.width-abs(bounds.width)*scale)/2,y: (renderSize.height-abs(bounds.height)*scale)/2))
            instructions.append(FrameInstruction(trackID:video.trackID,timeRange:CMTimeRange(start:cursor,duration:scaled),transform:transform,overlay:overlay,effects:effects,captions:titleOverlay ? (project.captions ?? []) : [],motion:clip.motion,lut:try loadLUT(effects,root:mediaRoot),clipID:clip.id))
            if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first,
               let audio = composition.addMutableTrack(withMediaType: .audio,preferredTrackID: kCMPersistentTrackID_Invalid) {
                try insert(clip,source:sourceAudio,into:audio,at:cursor)
                let parameter = AVMutableAudioMixInputParameters(track:audio)
                parameter.setVolume(Float(clip.volume),at:cursor)
                let incoming=placements[index].incomingDuration
                if incoming>0{parameter.setVolumeRamp(fromStartVolume:0,toEndVolume:Float(clip.volume),timeRange:CMTimeRange(start:cursor,duration:time(incoming)))}
                let outgoing=index+1<placements.count ? placements[index+1].incomingDuration : 0
                if outgoing>0{parameter.setVolumeRamp(fromStartVolume:Float(clip.volume),toEndVolume:0,timeRange:CMTimeRange(start:cursor+scaled-time(outgoing),duration:time(outgoing)))}
                audioParameters.append(parameter)
            }
            cursor = cursor + scaled
        }
        cursor=time(project.duration)
        if let file = project.musicFilename {
            let asset = AVURLAsset(url: mediaRoot.appendingPathComponent(file))
            guard let source = try await asset.loadTracks(withMediaType:.audio).first,
                  let track = composition.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid) else { throw EditError.invalidProject }
            let duration = try await asset.load(.duration)
            try track.insertTimeRange(CMTimeRange(start:.zero,duration:CMTimeMinimum(cursor,duration)),of:source,at:.zero)
            let parameter = AVMutableAudioMixInputParameters(track:track)
            parameter.setVolume(Float(project.musicVolume),at:.zero); audioParameters.append(parameter)
        }
        var layers:[LayerInstruction]=[]
        for layer in project.overlays ?? [] where layer.timelineStart < cursor.seconds {
            try Task.checkCancellation()
            let clip=layer.clip
            let asset=AVURLAsset(url:mediaRoot.appendingPathComponent(clip.filename))
            let length=min(clip.duration,cursor.seconds-layer.timelineStart)
            let at=time(layer.timelineStart)
            let natural:CGSize,orientation:CGAffineTransform,trackID:CMPersistentTrackID?,still:CIImage?
            if layer.isStill == true {
                guard let image=CIImage(contentsOf:mediaRoot.appendingPathComponent(clip.filename),options:[.applyOrientationProperty:true]),!image.extent.isEmpty else{throw EditError.missingVideo}
                natural=image.extent.size;orientation = .identity;trackID=nil
                still=image.transformed(by:CGAffineTransform(translationX:-image.extent.minX,y:-image.extent.minY))
            }else{
                guard let source=try await asset.loadTracks(withMediaType:.video).first,
                      let track=composition.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid) else{throw EditError.missingVideo}
                let assetDuration=try await asset.load(.duration)
                guard clip.end<=assetDuration.seconds+0.05 else{throw EditError.invalidRange}
                try insert(clip,source:source,into:track,at:at,limit:length)
                natural=try await source.load(.naturalSize);orientation=try await source.load(.preferredTransform);trackID=track.trackID;still=nil
            }
            let effects=clip.effects ?? ClipEffects()
            let preferred=orientation.concatenating(CGAffineTransform(rotationAngle:Double(effects.quarterTurns)*Double.pi/2))
            let bounds=CGRect(origin:.zero,size:natural).applying(preferred)
            let box=CGRect(x:renderSize.width*(layer.centerX-layer.width/2),y:renderSize.height*(layer.centerY-layer.height/2),width:renderSize.width*layer.width,height:renderSize.height*layer.height)
            let scale=effects.fit == .fill ? max(box.width/abs(bounds.width),box.height/abs(bounds.height)) : min(box.width/abs(bounds.width),box.height/abs(bounds.height))
            var transform=preferred.concatenating(CGAffineTransform(translationX:-bounds.minX,y:-bounds.minY))
            if effects.mirrored{transform=transform.concatenating(CGAffineTransform(a:-1,b:0,c:0,d:1,tx:abs(bounds.width),ty:0))}
            transform=transform.concatenating(CGAffineTransform(scaleX:scale,y:scale)).concatenating(CGAffineTransform(translationX:box.midX-abs(bounds.width)*scale/2,y:box.midY-abs(bounds.height)*scale/2))
            let ciBox=CGRect(x:box.minX,y:renderSize.height-box.maxY,width:box.width,height:box.height)
            layers.append(LayerInstruction(trackID:trackID,timeRange:CMTimeRange(start:at,duration:time(length)),transform:transform,box:box,layer:layer,mask:layer.mask == .none ? nil : FrameCompositor.mask(layer.mask,box:ciBox),still:still,lut:try loadLUT(effects,root:mediaRoot)))
            if layer.isStill != true,let sourceAudio=try await asset.loadTracks(withMediaType:.audio).first,
               let audio=composition.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid){
                try insert(clip,source:sourceAudio,into:audio,at:at,limit:length)
                let parameter=AVMutableAudioMixInputParameters(track:audio);parameter.setVolume(Float(clip.volume),at:at);audioParameters.append(parameter)
            }
        }
        for region in project.audioRegions ?? [] where region.timelineStart < cursor.seconds {
            try Task.checkCancellation()
            let asset=AVURLAsset(url:mediaRoot.appendingPathComponent(region.filename))
            guard let source=try await asset.loadTracks(withMediaType:.audio).first,
                  let track=composition.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid) else{throw EditError.invalidProject}
            let sourceDuration=try await asset.load(.duration)
            guard region.sourceEnd<=sourceDuration.seconds+0.05 else{throw EditError.invalidRange}
            let length=min(region.duration,cursor.seconds-region.timelineStart)
            let start=time(region.timelineStart)
            try track.insertTimeRange(CMTimeRange(start:time(region.sourceStart),duration:time(length)),of:source,at:start)
            let parameter=AVMutableAudioMixInputParameters(track:track)
            let fadeIn=min(region.fadeIn,length),fadeOut=min(region.fadeOut,max(0,length-fadeIn))
            parameter.setVolume(Float(region.volume),at:start)
            if fadeIn>0{parameter.setVolumeRamp(fromStartVolume:0,toEndVolume:Float(region.volume),timeRange:CMTimeRange(start:start,duration:time(fadeIn)))}
            if fadeOut>0{parameter.setVolumeRamp(fromStartVolume:Float(region.volume),toEndVolume:0,timeRange:CMTimeRange(start:time(region.timelineStart+length-fadeOut),duration:time(fadeOut)))}
            audioParameters.append(parameter)
        }
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = renderSize; videoComposition.frameDuration = CMTime(value:1,timescale:Int32((project.style ?? ProjectStyle()).fps))
        videoComposition.sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid
        videoComposition.instructions = try scenes(instructions,project:project,layers:layers)
        videoComposition.customVideoCompositorClass = FrameCompositor.self
        let mix = AVMutableAudioMix(); mix.inputParameters = audioParameters
        return RenderedTimeline(composition:composition,videoComposition:videoComposition,audioMix:mix)
    }
    private static func titleImage(_ title:String,size:CGSize,style:ProjectStyle) -> CGImage? {
        guard !title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return nil }
        let width=Int(size.width),height=Int(size.height)
        guard let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let font=CTFontCreateWithName(style.effectiveFontName as CFString,size.width*0.045*style.titleScale,nil)
        let rgb=style.ink.rgb
        let attributes:[NSAttributedString.Key:Any]=[NSAttributedString.Key(kCTFontAttributeName as String):font,NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(red:rgb.0,green:rgb.1,blue:rgb.2,alpha:1)]
        let line=CTLineCreateWithAttributedString(NSAttributedString(string:title,attributes:attributes))
        let lineWidth=CTLineGetTypographicBounds(line,nil,nil,nil)
        let scale=min(1,(size.width*0.88)/max(1,lineWidth))
        context.setShadow(offset:CGSize(width:0,height:-2),blur:4,color:CGColor(gray:0,alpha:0.9))
        let y=size.height*(style.position == .top ? 0.84 : style.position == .center ? 0.48 : 0.12)
        if style.boxed {
            context.setFillColor(CGColor(gray:0,alpha:0.65))
            context.fill(CGRect(x:(size.width-lineWidth*scale)/2-16,y:y-size.width*0.018,width:lineWidth*scale+32,height:size.width*0.075*style.titleScale))
        }
        context.translateBy(x:(size.width-lineWidth*scale)/2,y:y)
        context.scaleBy(x:scale,y:scale);context.textPosition = .zero
        CTLineDraw(line,context)
        return context.makeImage()
    }
    private static func scenes(_ instructions:[FrameInstruction],project:Project,layers:[LayerInstruction]) throws -> [FrameInstruction] {
        let boundaries=Array(Set(instructions.flatMap{[$0.timeRange.start.seconds,CMTimeRangeGetEnd($0.timeRange).seconds]})).sorted()
        var result:[FrameInstruction]=[]
        for (start,end) in zip(boundaries,boundaries.dropFirst()) where end>start {
            let middle=time((start+end)/2)
            let active=instructions.filter{CMTimeRangeContainsTime($0.timeRange,time:middle)}
            guard let first=active.first,active.count<=2 else{throw EditError.invalidProject}
            let secondary=active.count==2 ? active[1] : nil
            let transition=secondary.flatMap{next in project.transitions?.first{$0.from==first.clipID && $0.to==next.clipID}}
            guard secondary==nil || transition != nil else{throw EditError.invalidProject}
            let transitionRange=secondary.map{CMTimeRangeGetIntersection(first.timeRange,otherRange:$0.timeRange)}
            result.append(first.scene(range:CMTimeRange(start:time(start),duration:time(end)-time(start)),secondary:secondary,transition:transition,transitionRange:transitionRange,layers:layers))
        }
        return result
    }
    private static func loadLUT(_ effects:ClipEffects,root:URL) throws -> CubeLUT? {
        guard let filename=effects.lutFilename else{return nil}
        return try CubeLUT.parse(String(contentsOf:root.appendingPathComponent(filename),encoding:.utf8))
    }
    private static func insert(_ clip:Clip,source:AVAssetTrack,into track:AVMutableCompositionTrack,at start:CMTime,limit:Double?=nil) throws {
        let segments=clip.speedCurve?.renderSegments(sourceDuration:clip.end-clip.start,baseSpeed:clip.speed)
            ?? [SpeedSegment(sourceStart:0,sourceDuration:clip.end-clip.start,outputStart:0,outputDuration:clip.duration)]
        let end=limit ?? clip.duration
        for segment in segments where segment.outputStart<end {
            let length=min(segment.outputDuration,end-segment.outputStart)
            let sourceLength=segment.sourceDuration*length/segment.outputDuration
            let range=CMTimeRange(start:time(clip.start+segment.sourceStart),duration:time(sourceLength))
            let at=start+time(segment.outputStart)
            try track.insertTimeRange(range,of:source,at:at)
            track.scaleTimeRange(CMTimeRange(start:at,duration:range.duration),toDuration:time(length))
        }
    }
    private static func time(_ seconds: Double) -> CMTime { CMTime(seconds:seconds,preferredTimescale:6_000_000) }
    public static func export(_ project: Project, mediaRoot: URL, to url: URL, size: CGSize? = nil) async throws {
        let timeline = try await build(project, mediaRoot: mediaRoot, size: size, titleOverlay: true)
        try await MediaExporter.write(timeline,style:project.style ?? ProjectStyle(),to:url)
    }
}

// Immutable instructions keep rendering independent of the editor's mutable state.
private final class FrameInstruction: NSObject, AVVideoCompositionInstructionProtocol, @unchecked Sendable {
    let clipID:UUID
    let trackID:CMPersistentTrackID
    let timeRange:CMTimeRange
    let transform:CGAffineTransform
    let overlay:CGImage?
    let effects:ClipEffects
    let captions:[TextCue]
    let motion:MotionTrack?
    let lut:CubeLUT?
    let layers:[LayerInstruction]
    let clipRange:CMTimeRange
    let secondary:FrameInstruction?
    let transition:ClipTransition?
    let transitionRange:CMTimeRange?
    let enablePostProcessing=false
    let containsTweening=true
    var requiredSourceTrackIDs:[NSValue]? { [NSNumber(value:trackID)]+(secondary.map{[NSNumber(value:$0.trackID)]} ?? [])+layers.filter{CMTimeRangeGetIntersection(timeRange,otherRange:$0.timeRange).duration.seconds>0}.compactMap{$0.trackID.map{NSNumber(value:$0)}} }
    let passthroughTrackID:CMPersistentTrackID=kCMPersistentTrackID_Invalid
    init(trackID:CMPersistentTrackID,timeRange:CMTimeRange,transform:CGAffineTransform,overlay:CGImage?,effects:ClipEffects,captions:[TextCue],motion:MotionTrack?,lut:CubeLUT?,clipID:UUID,layers:[LayerInstruction]=[],clipRange:CMTimeRange?=nil,secondary:FrameInstruction?=nil,transition:ClipTransition?=nil,transitionRange:CMTimeRange?=nil) {
        self.trackID=trackID;self.timeRange=timeRange;self.transform=transform;self.overlay=overlay;self.effects=effects;self.captions=captions;self.motion=motion;self.layers=layers;self.lut=lut;self.clipID=clipID;self.clipRange=clipRange ?? timeRange;self.secondary=secondary;self.transition=transition;self.transitionRange=transitionRange
    }
    func scene(range:CMTimeRange,secondary:FrameInstruction?,transition:ClipTransition?,transitionRange:CMTimeRange?,layers:[LayerInstruction])->FrameInstruction {
        FrameInstruction(trackID:trackID,timeRange:range,transform:transform,overlay:overlay,effects:effects,captions:captions,motion:motion,lut:lut,clipID:clipID,layers:layers,clipRange:clipRange,secondary:secondary,transition:transition,transitionRange:transitionRange)
    }
}
private struct LayerInstruction {
    let trackID:CMPersistentTrackID?
    let timeRange:CMTimeRange
    let transform:CGAffineTransform
    let box:CGRect
    let layer:OverlayLayer
    let mask:CIImage?
    let still:CIImage?
    let lut:CubeLUT?
}
final class FrameCompositor: NSObject, AVVideoCompositing, @unchecked Sendable {
    private let context=CIContext(options:[.cacheIntermediates:false])
    private let captions=CaptionRasterizer()
    var sourcePixelBufferAttributes:[String:any Sendable]? { [kCVPixelBufferPixelFormatTypeKey as String:[kCVPixelFormatType_32BGRA,kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]] }
    var requiredPixelBufferAttributesForRenderContext:[String:any Sendable] { [kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA] }
    func renderContextChanged(_ newRenderContext:AVVideoCompositionRenderContext) {}
    func startRequest(_ request:AVAsynchronousVideoCompositionRequest) {
        autoreleasepool {
            guard let instruction=request.videoCompositionInstruction as? FrameInstruction,
                  let source=request.sourceFrame(byTrackID:instruction.trackID),
                  let destination=request.renderContext.newPixelBuffer() else {
                request.finish(with:EditError.missingVideo);return
            }
            let size=request.renderContext.size
            let bounds=CGRect(origin:.zero,size:size)
            var image=Self.base(source,instruction:instruction,size:size,time:request.compositionTime)
            if let secondary=instruction.secondary,let transition=instruction.transition,let range=instruction.transitionRange {
                guard let source=request.sourceFrame(byTrackID:secondary.trackID) else{request.finish(with:EditError.missingVideo);return}
                let next=Self.base(source,instruction:secondary,size:size,time:request.compositionTime)
                let progress=max(0,min(1,(request.compositionTime-range.start).seconds/range.duration.seconds))
                image=Self.transition(image,to:next,style:transition.style,progress:progress,bounds:bounds)
            }
            for item in instruction.layers where CMTimeRangeContainsTime(item.timeRange,time:request.compositionTime) {
                let source:CIImage
                if let still=item.still{source=still}
                else if let id=item.trackID,let buffer=request.sourceFrame(byTrackID:id){source=CIImage(cvPixelBuffer:buffer)}
                else{request.finish(with:EditError.missingVideo);return}
                let h=source.extent.height
                let transform=CGAffineTransform(a:1,b:0,c:0,d:-1,tx:0,ty:h).concatenating(item.transform).concatenating(CGAffineTransform(a:1,b:0,c:0,d:-1,tx:0,ty:size.height))
                let box=CGRect(x:item.box.minX,y:size.height-item.box.maxY,width:item.box.width,height:item.box.height)
                var foreground=ColorPipeline.apply(source,effects:item.layer.clip.effects ?? ClipEffects(),lut:item.lut).transformed(by:transform).cropped(to:box)
                let effects=item.layer.clip.effects ?? ClipEffects()
                foreground=PixelEffects.privacy(foreground,regions:effects.privacyRegions ?? [],bounds:box)
                if let mask=effects.mask{foreground=PixelEffects.masked(foreground,spec:mask,bounds:box)}
                if let mask=item.mask {
                    foreground=foreground.applyingFilter("CIBlendWithAlphaMask",parameters:["inputBackgroundImage":CIImage(color:.clear).cropped(to:box),"inputMaskImage":mask])
                }
                if let motion=item.layer.clip.motion {
                    let t=(request.compositionTime-item.timeRange.start).seconds/item.layer.clip.duration
                    foreground=Self.animate(foreground,key:motion.sample(at:t),center:CGPoint(x:box.midX,y:box.midY),size:size)
                }
                foreground=Self.opacity(foreground,item.layer.opacity)
                image=foreground.composited(over:image)
            }
            if let overlay=instruction.overlay { image=CIImage(cgImage:overlay).composited(over:image) }
            let seconds=request.compositionTime.seconds
            for cue in instruction.captions where seconds >= cue.start && seconds < cue.end {
                if let layer=captions.image(cue,size:size) { image=layer.composited(over:image) }
            }
            context.render(image,to:destination,bounds:bounds,colorSpace:CGColorSpaceCreateDeviceRGB())
            request.finish(withComposedVideoFrame:destination)
        }
    }
    private static func base(_ source:CVPixelBuffer,instruction:FrameInstruction,size:CGSize,time:CMTime)->CIImage {
        let bounds=CGRect(origin:.zero,size:size)
        let sourceHeight=CGFloat(CVPixelBufferGetHeight(source))
        let transform=CGAffineTransform(a:1,b:0,c:0,d:-1,tx:0,ty:sourceHeight)
            .concatenating(instruction.transform)
            .concatenating(CGAffineTransform(a:1,b:0,c:0,d:-1,tx:0,ty:size.height))
        var image=ColorPipeline.apply(CIImage(cvPixelBuffer:source),effects:instruction.effects,lut:instruction.lut).transformed(by:transform)
        image=PixelEffects.privacy(image,regions:instruction.effects.privacyRegions ?? [],bounds:bounds)
        if let mask=instruction.effects.mask{image=PixelEffects.masked(image,spec:mask,bounds:bounds)}
        if let motion=instruction.motion {
            let t=(time-instruction.clipRange.start).seconds/instruction.clipRange.duration.seconds
            image=Self.animate(image,key:motion.sample(at:t),center:CGPoint(x:size.width/2,y:size.height/2),size:size)
        }
        image=image.composited(over:CIImage(color:CIColor(red:0,green:0,blue:0)).cropped(to:bounds))
        if instruction.effects.cutStyle != .cut {
            let duration=instruction.clipRange.duration.seconds
            let relative=(time-instruction.clipRange.start).seconds
            let fade=min(0.35,duration*0.25)
            let alpha=max(0,min(1,min(relative/fade,(duration-relative)/fade)))
            let value:CGFloat=instruction.effects.cutStyle == .fadeWhite ? 1 : 0
            let background=CIImage(color:CIColor(red:value,green:value,blue:value)).cropped(to:bounds)
            image=image.applyingFilter("CIDissolveTransition",parameters:["inputTargetImage":background,"inputTime":1-alpha])
        }
        return image
    }
    private static func transition(_ image:CIImage,to next:CIImage,style:TransitionStyle,progress:Double,bounds:CGRect)->CIImage {
        switch style {
        case .dissolve:return image.applyingFilter("CIDissolveTransition",parameters:["inputTargetImage":next,"inputTime":progress])
        case .wipeLeft:
            return next.cropped(to:CGRect(x:bounds.maxX-bounds.width*progress,y:bounds.minY,width:bounds.width*progress,height:bounds.height)).composited(over:image)
        case .wipeRight:
            return next.cropped(to:CGRect(x:bounds.minX,y:bounds.minY,width:bounds.width*progress,height:bounds.height)).composited(over:image)
        case .slideLeft,.slideRight:
            let direction:Double=style == .slideLeft ? -1 : 1
            let outgoing=image.transformed(by:CGAffineTransform(translationX:direction*bounds.width*progress,y:0))
            let incoming=next.transformed(by:CGAffineTransform(translationX:-direction*bounds.width*(1-progress),y:0))
            return incoming.composited(over:outgoing).cropped(to:bounds)
        }
    }
    private static func opacity(_ image:CIImage,_ opacity:Double)->CIImage {
        image.applyingFilter("CIColorMatrix",parameters:["inputAVector":CIVector(x:0,y:0,z:0,w:opacity)])
    }
    private static func animate(_ image:CIImage,key:MotionKeyframe,center:CGPoint,size:CGSize)->CIImage {
        let transform=CGAffineTransform(translationX:-center.x,y:-center.y)
            .concatenating(CGAffineTransform(scaleX:key.scale,y:key.scale))
            .concatenating(CGAffineTransform(rotationAngle:-key.rotation*Double.pi/180))
            .concatenating(CGAffineTransform(translationX:center.x+key.x*size.width,y:center.y-key.y*size.height))
        return opacity(image.transformed(by:transform),key.opacity)
    }
    fileprivate static func mask(_ kind:LayerMask,box:CGRect)->CIImage? {
        let width=Int(ceil(box.width)),height=Int(ceil(box.height))
        guard width>0,height>0,let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return nil}
        let rect=CGRect(x:0,y:0,width:width,height:height)
        context.setFillColor(CGColor(gray:1,alpha:1))
        if kind == .circle{context.fillEllipse(in:rect)}else{context.addPath(CGPath(roundedRect:rect,cornerWidth:CGFloat(min(width,height))*0.15,cornerHeight:CGFloat(min(width,height))*0.15,transform:nil));context.fillPath()}
        guard let cg=context.makeImage() else{return nil}
        return CIImage(cgImage:cg).transformed(by:CGAffineTransform(translationX:box.minX,y:box.minY))
    }
}

// Rasterize only active cues. Bounded caching avoids one full-canvas bitmap per subtitle.
private final class CaptionRasterizer {
    private let cache=NSCache<NSString,CGImage>()
    init() { cache.countLimit=16;cache.totalCostLimit=32*1024*1024 }
    func image(_ cue:TextCue,size:CGSize)->CIImage? {
        let encoder=JSONEncoder();encoder.outputFormatting = .sortedKeys
        let key="\((try? encoder.encode(cue.style).base64EncodedString()) ?? "")|\(cue.text)|\(size.width)-\(size.height)" as NSString
        let cg:CGImage
        if let value=cache.object(forKey:key) { cg=value }
        else {
            let padding=max(8,size.width*0.015)
            let width=floor(size.width*0.9)
            let font=CTFontCreateWithName(cue.style.effectiveFontName as CFString,size.width*0.045*cue.style.titleScale,nil)
            let rgb=cue.style.ink.rgb
            var alignment=CTTextAlignment.center
            let paragraph=withUnsafePointer(to:&alignment) { pointer in
                var setting=CTParagraphStyleSetting(spec:.alignment,valueSize:MemoryLayout<CTTextAlignment>.size,value:pointer)
                return CTParagraphStyleCreate(&setting,1)
            }
            let attributes:[NSAttributedString.Key:Any]=[
                NSAttributedString.Key(kCTFontAttributeName as String):font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String):CGColor(red:rgb.0,green:rgb.1,blue:rgb.2,alpha:1),
                NSAttributedString.Key(kCTParagraphStyleAttributeName as String):paragraph]
            let text=NSAttributedString(string:cue.text,attributes:attributes)
            let setter=CTFramesetterCreateWithAttributedString(text)
            let constraint=CGSize(width:width-padding*2,height:size.height*0.8)
            let suggested=CTFramesetterSuggestFrameSizeWithConstraints(setter,CFRange(location:0,length:0),nil,constraint,nil)
            let height=min(size.height*0.8,ceil(suggested.height)+padding*2+4)
            guard let canvas=CGContext(data:nil,width:Int(width),height:Int(height),bitsPerComponent:8,bytesPerRow:Int(width)*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return nil}
            if cue.style.boxed {canvas.setFillColor(CGColor(gray:0,alpha:0.7));canvas.fill(CGRect(x:0,y:0,width:width,height:height))}
            canvas.setShadow(offset:CGSize(width:0,height:-1),blur:2,color:CGColor(gray:0,alpha:0.9))
            let path=CGPath(rect:CGRect(x:padding,y:padding,width:width-padding*2,height:height-padding*2),transform:nil)
            CTFrameDraw(CTFramesetterCreateFrame(setter,CFRange(location:0,length:0),path,nil),canvas)
            guard let rendered=canvas.makeImage() else{return nil};cg=rendered
            cache.setObject(cg,forKey:key,cost:cg.bytesPerRow*cg.height)
        }
        let y:CGFloat
        switch cue.style.position {case .top:y=size.height-CGFloat(cg.height)-size.height*0.06;case .center:y=(size.height-CGFloat(cg.height))/2;case .lower:y=size.height*0.06}
        return CIImage(cgImage:cg).transformed(by:CGAffineTransform(translationX:(size.width-CGFloat(cg.width))/2,y:y))
    }
}
