import Foundation
import CoreImage

public enum Look: String, Codable, CaseIterable, Identifiable {
    case original, mono, noir, chrome, fade, instant, process, tonal, transfer, sepia
    case golden,arctic,cinema,tealAmber,rose,desert,matte,bleach,vivid,portrait,food,midnight,coastal,autumn,coffee,dream,lilac,emerald,steel,copper
    public var id: String { rawValue }
    public var label: String {self == .tealAmber ? "Teal & amber" : rawValue.capitalized}
    var filter: String? {
        switch self {
        case .original: return nil
        case .sepia: return "CISepiaTone"
        default: return "CIPhotoEffect" + rawValue.capitalized
        }
    }
}
public enum FrameFit: String, Codable, CaseIterable { case fit, fill }
public enum CutStyle: String, Codable, CaseIterable { case cut, fadeBlack, fadeWhite
    public var label: String { self == .cut ? "None" : self == .fadeBlack ? "Fade in/out · black" : "Fade in/out · white" }
}
public struct ClipEffects: Codable, Equatable {
    public var look: Look = .original
    public var intensity: Double = 1
    public var brightness: Double = 0
    public var contrast: Double = 1
    public var saturation: Double = 1
    public var exposure: Double = 0
    public var warmth: Double = 0
    public var quarterTurns: Int = 0
    public var mirrored = false
    public var fit: FrameFit = .fit
    public var cutStyle: CutStyle = .cut
    public var lutFilename:String?
    public var mask:MaskSpec?
    public var privacyRegions:[PrivacyRegion]?
    public var visualFX:[VisualFX]?
    public init() {}
    public mutating func resetColor(){
        look = .original;intensity=1;brightness=0;contrast=1;saturation=1;exposure=0;warmth=0;lutFilename=nil
    }
    public func validate() throws {
        if let lutFilename{guard !lutFilename.isEmpty,lutFilename==URL(fileURLWithPath:lutFilename).lastPathComponent else{throw EditError.invalidProject}}
        if let visualFX{guard visualFX.count<=4,Set(visualFX.map(\.id)).count==visualFX.count else{throw EditError.invalidProject};try visualFX.forEach{try $0.validate()}}
        try mask?.validate()
        if let privacyRegions{guard privacyRegions.count<=64,Set(privacyRegions.map(\.id)).count==privacyRegions.count else{throw EditError.invalidProject};try privacyRegions.forEach{try $0.validate()}}
        let values=[intensity,brightness,contrast,saturation,exposure,warmth]
        guard values.allSatisfy({$0.isFinite}), (0...1).contains(intensity), (-0.5...0.5).contains(brightness), (0.5...2).contains(contrast), (0...2).contains(saturation), (-2...2).contains(exposure), (-1...1).contains(warmth), (0...3).contains(quarterTurns) else { throw EditError.invalidProject }
    }
}
public enum TitleFont: String,Codable,CaseIterable { case modern, editorial, mono
    public var postScriptName: String { self == .modern ? "HelveticaNeue-Bold" : self == .editorial ? "Georgia-Bold" : "Menlo-Bold" }
}
public enum TitlePosition: String,Codable,CaseIterable { case top, center, lower }
public enum Ink: String,Codable,CaseIterable { case white, black, mint, amber
    public var rgb: (Double,Double,Double) {
        switch self { case .white:return (1,1,1); case .black:return (0.04,0.04,0.04); case .mint:return (0.68,0.96,0.35); case .amber:return (1,0.79,0.3) }
    }
}
public enum ExportSize: String,Codable,CaseIterable { case hd720, fullHD, ultraHD
    public var label:String { self == .hd720 ? "720p" : self == .fullHD ? "1080p" : "4K" }
    public var shortEdge:Int { self == .hd720 ? 720 : self == .fullHD ? 1080 : 2160 }
}
public struct ProjectStyle: Codable,Equatable {
    public var templateID: String?
    public var font:TitleFont = .modern
    public var position:TitlePosition = .lower
    public var ink:Ink = .white
    public var titleScale:Double = 1
    public var boxed=false
    public var resolution:ExportSize = .fullHD
    public var fps:Int = 30
    public var bitRateMbps:Double?
    public var fontFilename:String?
    public var fontPostScriptName:String?
    public var effectiveFontName:String {fontPostScriptName ?? font.postScriptName}
    public init() {}
    public func validate() throws {
        guard titleScale.isFinite,(0.5...2).contains(titleScale),[24,25,30,50,60].contains(fps) else {throw EditError.invalidProject}
        if let bitRateMbps{guard bitRateMbps.isFinite,(1...120).contains(bitRateMbps) else{throw EditError.invalidProject}}
        if fontFilename != nil || fontPostScriptName != nil {
            guard let file=fontFilename,let name=fontPostScriptName,!file.isEmpty,file==URL(fileURLWithPath:file).lastPathComponent,!name.isEmpty,name.count<=256 else{throw EditError.invalidProject}
        }
    }
}
public struct EditTemplate: Identifiable {
    public let id:String
    public let name:String
    public let category:String
    public let caption:String
    public let canvas:Canvas
    public let look:Look
    public let speed:Double
    public let clipSeconds:Double
    public let font:TitleFont
    public let position:TitlePosition
    public let ink:Ink
    public let cutStyle:CutStyle
    public let boxed:Bool
    public func apply(to project:inout Project) throws {
        try project.validate()
        var next=project
        next.canvas=canvas
        var style=next.style ?? ProjectStyle()
        style.templateID=id;style.font=font;style.fontFilename=nil;style.fontPostScriptName=nil;style.position=position;style.ink=ink;style.boxed=boxed
        next.style=style
        if next.title.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty { next.title=caption }
        for i in next.clips.indices {
            next.clips[i].speed=speed
            next.clips[i].end=min(next.clips[i].end,next.clips[i].start+clipSeconds*speed)
            var effects=next.clips[i].effects ?? ClipEffects()
            effects.look=look;effects.intensity=1;effects.cutStyle=cutStyle;effects.fit = canvas == .portrait ? .fill : .fit
            next.clips[i].effects=effects
        }
        try next.validate();project=next
    }
    public static let all:[EditTemplate] = [
        .init(id:"cinema",name:"Cinema Journal",category:"Film",caption:"A story worth keeping",canvas:.landscape,look:.fade,speed:1,clipSeconds:4,font:.editorial,position:.lower,ink:.white,cutStyle:.fadeBlack,boxed:false),
        .init(id:"travel",name:"Travel Postcard",category:"Travel",caption:"Somewhere new",canvas:.landscape,look:.chrome,speed:1,clipSeconds:3,font:.modern,position:.lower,ink:.white,cutStyle:.fadeWhite,boxed:false),
        .init(id:"reel",name:"Quick Reel",category:"Social",caption:"In the moment",canvas:.portrait,look:.process,speed:1.5,clipSeconds:1.5,font:.modern,position:.center,ink:.white,cutStyle:.cut,boxed:true),
        .init(id:"mono",name:"Mono Story",category:"Film",caption:"Less, but better",canvas:.square,look:.mono,speed:1,clipSeconds:3,font:.editorial,position:.center,ink:.white,cutStyle:.fadeBlack,boxed:false),
        .init(id:"noir",name:"After Hours",category:"Film",caption:"AFTER HOURS",canvas:.landscape,look:.noir,speed:0.5,clipSeconds:4,font:.mono,position:.lower,ink:.amber,cutStyle:.fadeBlack,boxed:false),
        .init(id:"retro",name:"Analog Days",category:"Lifestyle",caption:"The good days",canvas:.square,look:.instant,speed:1,clipSeconds:2.5,font:.editorial,position:.lower,ink:.amber,cutStyle:.fadeWhite,boxed:false),
        .init(id:"food",name:"On the Menu",category:"Lifestyle",caption:"Made with love",canvas:.portrait,look:.transfer,speed:1,clipSeconds:2,font:.editorial,position:.top,ink:.white,cutStyle:.cut,boxed:true),
        .init(id:"sport",name:"Keep Moving",category:"Social",caption:"KEEP MOVING",canvas:.portrait,look:.chrome,speed:2,clipSeconds:1,font:.modern,position:.center,ink:.mint,cutStyle:.cut,boxed:true),
        .init(id:"wedding",name:"Our Day",category:"Lifestyle",caption:"Together, always",canvas:.landscape,look:.fade,speed:0.5,clipSeconds:5,font:.editorial,position:.lower,ink:.white,cutStyle:.fadeWhite,boxed:false),
        .init(id:"product",name:"Studio Launch",category:"Business",caption:"Meet the new",canvas:.square,look:.tonal,speed:1,clipSeconds:2,font:.modern,position:.center,ink:.white,cutStyle:.cut,boxed:true),
        .init(id:"documentary",name:"Field Notes",category:"Film",caption:"FIELD NOTES",canvas:.landscape,look:.original,speed:1,clipSeconds:6,font:.mono,position:.top,ink:.white,cutStyle:.fadeBlack,boxed:true),
        .init(id:"sepia",name:"Golden Memory",category:"Lifestyle",caption:"Remember this",canvas:.portrait,look:.sepia,speed:1,clipSeconds:3,font:.editorial,position:.lower,ink:.white,cutStyle:.fadeBlack,boxed:false)
    ]
}
public enum ColorPipeline {
    public static func apply(_ input:CIImage,effects:ClipEffects,lut:CubeLUT?=nil) -> CIImage {
        var image=input
        if let lut{image=lut.apply(image)}
        if effects.look != .original, effects.intensity>0 {
            let filtered=effects.look.render(image)
            image=filtered.applyingFilter("CIDissolveTransition",parameters:["inputTargetImage":image,"inputTime":1-effects.intensity])
        }
        image=image.applyingFilter("CIColorControls",parameters:["inputBrightness":effects.brightness,"inputContrast":effects.contrast,"inputSaturation":effects.saturation])
        image=image.applyingFilter("CIExposureAdjust",parameters:["inputEV":effects.exposure])
        if effects.warmth != 0 { image=image.applyingFilter("CITemperatureAndTint",parameters:["inputNeutral":CIVector(x:6500,y:0),"inputTargetNeutral":CIVector(x:6500+effects.warmth*2500,y:0)]) }
        return image.cropped(to:input.extent)
    }
}
