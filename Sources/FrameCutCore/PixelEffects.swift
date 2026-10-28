import Foundation
import CoreImage
import CoreGraphics

public enum MaskShape:String,Codable,CaseIterable {case rectangle,circle,roundedRectangle,triangle,triangleDown,diamond,pentagon,octagon,star,star4,star12,hexagram,octagram,heart,drop,arch,hourglass,bookmark,custom}
public struct MaskPoint:Codable,Hashable,Identifiable {
    public var id=UUID()
    public var x:Double
    public var y:Double
    public init(x:Double,y:Double){self.x=x;self.y=y}
}
public struct MaskSpec:Codable,Hashable {
    public var shape:MaskShape = .rectangle
    public var centerX:Double=0.5
    public var centerY:Double=0.5
    public var width:Double=0.8
    public var height:Double=0.8
    public var rotation:Double=0
    public var feather:Double=0
    public var inverted=false
    public var points:[MaskPoint]=[.init(x:0.1,y:0.9),.init(x:0.5,y:0.1),.init(x:0.9,y:0.9)]
    public init(){}
    public func validate() throws {
        guard [centerX,centerY,width,height,rotation,feather].allSatisfy(\.isFinite),
              (0...1).contains(centerX),(0...1).contains(centerY),(0.01...2).contains(width),(0.01...2).contains(height),
              (-180...180).contains(rotation),(0...0.2).contains(feather),points.count<=64 else{throw EditError.invalidProject}
        if shape == .custom{guard points.count>=3,points.allSatisfy({$0.x.isFinite && $0.y.isFinite && (0...1).contains($0.x) && (0...1).contains($0.y)}) else{throw EditError.invalidProject}}
    }
}
public enum PrivacyStyle:String,Codable,CaseIterable {case blur,pixelate,hexagon}
public struct PrivacyRegion:Codable,Equatable,Identifiable {
    public var id=UUID()
    public var mask=MaskSpec()
    public var style:PrivacyStyle = .blur
    public var amount:Double=0.5
    public init(){}
    public func validate() throws {try mask.validate();guard amount.isFinite,(0.01...1).contains(amount) else{throw EditError.invalidProject}}
}
public enum PixelEffects {
    private static let cache:NSCache<NSString,CGImage> = {let c=NSCache<NSString,CGImage>();c.totalCostLimit=32*1024*1024;c.countLimit=16;return c}()
    public static func masked(_ image:CIImage,spec:MaskSpec,bounds:CGRect)->CIImage {
        guard let mask=mask(spec,bounds:bounds) else{return image}
        return image.applyingFilter("CIBlendWithAlphaMask",parameters:["inputBackgroundImage":CIImage(color:.clear).cropped(to:bounds),"inputMaskImage":mask])
    }
    public static func privacy(_ image:CIImage,regions:[PrivacyRegion],bounds:CGRect)->CIImage {
        var result=image
        for region in regions {
            guard let mask=mask(region.mask,bounds:bounds) else{continue}
            let amount=max(1,min(bounds.width,bounds.height)*region.amount*0.12)
            let filtered:CIImage
            switch region.style {
            case .blur:filtered=result.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:["inputRadius":amount]).cropped(to:bounds)
            case .pixelate:filtered=result.applyingFilter("CIPixellate",parameters:["inputScale":amount,"inputCenter":CIVector(x:bounds.midX,y:bounds.midY)])
            case .hexagon:filtered=result.applyingFilter("CIHexagonalPixellate",parameters:["inputScale":amount,"inputCenter":CIVector(x:bounds.midX,y:bounds.midY)])
            }
            result=filtered.applyingFilter("CIBlendWithAlphaMask",parameters:["inputBackgroundImage":result,"inputMaskImage":mask]).cropped(to:bounds)
        }
        return result
    }
    public static func mask(_ spec:MaskSpec,bounds:CGRect)->CIImage? {
        guard (try? spec.validate()) != nil,bounds.width.isFinite,bounds.height.isFinite,bounds.width>0,bounds.height>0 else{return nil}
        let factor=min(1,1024/max(bounds.width,bounds.height))
        let width=max(1,Int(ceil(bounds.width*factor))),height=max(1,Int(ceil(bounds.height*factor)))
        let encoder=JSONEncoder();encoder.outputFormatting = .sortedKeys
        guard let data=try? encoder.encode(spec) else{return nil}
        let key=(data.base64EncodedString()+"-\(width)-\(height)") as NSString
        let cg:CGImage
        if let cached=cache.object(forKey:key){cg=cached}
        else{
            guard let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return nil}
            var transform=CGAffineTransform(scaleX:spec.width*Double(width),y:spec.height*Double(height))
                .concatenating(CGAffineTransform(rotationAngle:-spec.rotation*Double.pi/180))
                .concatenating(CGAffineTransform(translationX:spec.centerX*Double(width),y:(1-spec.centerY)*Double(height)))
            guard let path=path(spec).copy(using:&transform) else{return nil}
            context.setFillColor(CGColor(gray:1,alpha:1));context.addPath(path);context.fillPath()
            guard let image=context.makeImage() else{return nil};cg=image;cache.setObject(cg,forKey:key,cost:cg.bytesPerRow*cg.height)
        }
        var result=CIImage(cgImage:cg).transformed(by:CGAffineTransform(scaleX:bounds.width/Double(width),y:bounds.height/Double(height))).transformed(by:CGAffineTransform(translationX:bounds.minX,y:bounds.minY))
        if spec.inverted{result=result.applyingFilter("CIColorMatrix",parameters:["inputAVector":CIVector(x:0,y:0,z:0,w:-1),"inputBiasVector":CIVector(x:0,y:0,z:0,w:1)])}
        if spec.feather>0{result=result.clampedToExtent().applyingFilter("CIGaussianBlur",parameters:["inputRadius":min(bounds.width,bounds.height)*spec.feather])}
        return result.cropped(to:bounds)
    }
    private static func path(_ spec:MaskSpec)->CGPath {
        let rect=CGRect(x:-0.5,y:-0.5,width:1,height:1),p=CGMutablePath()
        func polygon(_ count:Int,inner:Double?=nil,phase:Double = .pi/2){
            let n=inner==nil ? count : count*2
            for i in 0..<n{let radius=(inner != nil && i%2==1) ? inner! : 0.5,angle=phase+Double(i)*2*Double.pi/Double(n);let point=CGPoint(x:cos(angle)*radius,y:sin(angle)*radius);if i==0{p.move(to:point)}else{p.addLine(to:point)}};p.closeSubpath()
        }
        switch spec.shape {
        case .rectangle:p.addRect(rect)
        case .circle:p.addEllipse(in:rect)
        case .roundedRectangle:p.addRoundedRect(in:rect,cornerWidth:0.15,cornerHeight:0.15)
        case .triangle:polygon(3)
        case .triangleDown:polygon(3,phase:-Double.pi/2)
        case .diamond:polygon(4)
        case .pentagon:polygon(5)
        case .octagon:polygon(8,phase:Double.pi/8)
        case .star:polygon(5,inner:0.22)
        case .star4:polygon(4,inner:0.18)
        case .star12:polygon(12,inner:0.35)
        case .hexagram:polygon(6,inner:0.28)
        case .octagram:polygon(8,inner:0.3)
        case .heart:
            p.move(to:CGPoint(x:0,y:-0.5));p.addCurve(to:CGPoint(x:0,y:0.28),control1:CGPoint(x:-0.9,y:0.1),control2:CGPoint(x:-0.35,y:0.85));p.addCurve(to:CGPoint(x:0,y:-0.5),control1:CGPoint(x:0.35,y:0.85),control2:CGPoint(x:0.9,y:0.1));p.closeSubpath()
        case .drop:
            p.move(to:CGPoint(x:0,y:0.5));p.addCurve(to:CGPoint(x:0,y:-0.5),control1:CGPoint(x:-0.8,y:-0.15),control2:CGPoint(x:-0.4,y:-0.5));p.addCurve(to:CGPoint(x:0,y:0.5),control1:CGPoint(x:0.4,y:-0.5),control2:CGPoint(x:0.8,y:-0.15));p.closeSubpath()
        case .arch:
            p.move(to:CGPoint(x:-0.5,y:-0.5));p.addLine(to:CGPoint(x:-0.5,y:0));p.addCurve(to:CGPoint(x:0.5,y:0),control1:CGPoint(x:-0.5,y:0.67),control2:CGPoint(x:0.5,y:0.67));p.addLine(to:CGPoint(x:0.5,y:-0.5));p.closeSubpath()
        case .hourglass:
            p.move(to:CGPoint(x:-0.5,y:0.5));p.addLine(to:CGPoint(x:0.5,y:0.5));p.addLine(to:CGPoint(x:-0.5,y:-0.5));p.addLine(to:CGPoint(x:0.5,y:-0.5));p.closeSubpath()
        case .bookmark:
            p.move(to:CGPoint(x:-0.5,y:0.5));p.addLine(to:CGPoint(x:0.5,y:0.5));p.addLine(to:CGPoint(x:0.5,y:-0.5));p.addLine(to:CGPoint(x:0,y:-0.2));p.addLine(to:CGPoint(x:-0.5,y:-0.5));p.closeSubpath()
        case .custom:
            for (i,point) in spec.points.enumerated(){let value=CGPoint(x:point.x-0.5,y:0.5-point.y);if i==0{p.move(to:value)}else{p.addLine(to:value)}};p.closeSubpath()
        }
        return p
    }
}
