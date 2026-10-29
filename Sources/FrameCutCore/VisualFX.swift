import Foundation
import CoreImage

public enum VisualFXKind:String,Codable,CaseIterable,Identifiable {
    case bloom,softBlur,motionBlur,zoomBlur,pixelate,hexMosaic,comic,edges,crystal,posterize,invert,kaleidoscope
    public var id:String{rawValue}
    public var label:String{switch self {
    case .bloom:return "Bloom";case .softBlur:return "Soft blur";case .motionBlur:return "Motion blur";case .zoomBlur:return "Zoom blur"
    case .pixelate:return "Pixel mosaic";case .hexMosaic:return "Hex mosaic";case .comic:return "Comic";case .edges:return "Edge ink"
    case .crystal:return "Crystal";case .posterize:return "Posterize";case .invert:return "Invert";case .kaleidoscope:return "Kaleidoscope"
    }}
    public var category:String{switch self {case .bloom:return "Light";case .softBlur,.motionBlur,.zoomBlur:return "Blur";case .pixelate,.hexMosaic,.crystal:return "Mosaic";case .kaleidoscope:return "Geometry";default:return "Stylize"}}
}
public struct VisualFX:Codable,Equatable,Identifiable {
    public var id=UUID()
    public var kind:VisualFXKind
    public var amount:Double=1
    public var start:Double=0
    public var end:Double=1
    public var domainStart:Double=0
    public var domainEnd:Double=1
    public init(kind:VisualFXKind){self.kind=kind}
    public func isActive(at progress:Double)->Bool{let t=domainStart+progress*(domainEnd-domainStart);return t>=start && t<end}
    public func segment(from a:Double,to b:Double)->VisualFX{var r=self;let length=domainEnd-domainStart;r.domainStart=domainStart+a*length;r.domainEnd=domainStart+b*length;return r}
    public func validate() throws {
        guard [amount,start,end,domainStart,domainEnd].allSatisfy(\.isFinite),(0...1).contains(amount),start>=0,end<=1,end>start,domainEnd>domainStart,domainStart>=(-1_000_000_000),domainEnd<=1_000_000_000 else{throw EditError.invalidProject}
    }
}
public enum VisualFXPipeline {
    public static func apply(_ input:CIImage,effects:[VisualFX],progress:Double)->CIImage {
        let bounds=input.extent
        guard !bounds.isEmpty,!bounds.isInfinite else{return input}
        let unit=max(1,min(bounds.width,bounds.height)/100)
        var image=input
        for fx in effects where fx.amount>0 && fx.isActive(at:progress) {
            let filtered:CIImage
            switch fx.kind {
            case .bloom:filtered=image.clampedToExtent().applyingFilter("CIBloom",parameters:["inputRadius":unit*4,"inputIntensity":1.3])
            case .softBlur:filtered=image.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:["inputRadius":unit*2.5])
            case .motionBlur:filtered=image.clampedToExtent().applyingFilter("CIMotionBlur",parameters:["inputRadius":unit*5,"inputAngle":0])
            case .zoomBlur:filtered=image.clampedToExtent().applyingFilter("CIZoomBlur",parameters:["inputCenter":CIVector(x:bounds.midX,y:bounds.midY),"inputAmount":25])
            case .pixelate:filtered=image.applyingFilter("CIPixellate",parameters:["inputScale":unit*5])
            case .hexMosaic:filtered=image.applyingFilter("CIHexagonalPixellate",parameters:["inputScale":unit*4,"inputCenter":CIVector(x:bounds.midX,y:bounds.midY)])
            case .comic:filtered=image.applyingFilter("CIComicEffect")
            case .edges:filtered=image.applyingFilter("CIEdges",parameters:["inputIntensity":3])
            case .crystal:filtered=image.applyingFilter("CICrystallize",parameters:["inputRadius":unit*5])
            case .posterize:filtered=image.applyingFilter("CIColorPosterize",parameters:["inputLevels":4])
            case .invert:filtered=image.applyingFilter("CIColorInvert")
            case .kaleidoscope:filtered=image.applyingFilter("CIKaleidoscope",parameters:["inputCount":6,"inputCenter":CIVector(x:bounds.midX,y:bounds.midY),"inputAngle":0])
            }
            image=filtered.cropped(to:bounds).applyingFilter("CIDissolveTransition",parameters:["inputTargetImage":image,"inputTime":1-fx.amount]).cropped(to:bounds)
        }
        return image
    }
}
