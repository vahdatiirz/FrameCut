import Foundation
import CoreImage
import CoreGraphics

/// One implementation for editor previews and the exported two-source compositor.
public enum TransitionRenderer {
    public static func render(_ from:CIImage,to:CIImage,style:TransitionStyle,progress:Double,bounds:CGRect)->CIImage {
        let t=progress.isFinite ? max(0,min(1,progress)) : 0
        if t==0{return from.cropped(to:bounds)}
        if t==1{return to.cropped(to:bounds)}
        func mix(_ a:CIImage,_ b:CIImage,_ amount:Double)->CIImage {
            a.applyingFilter("CIDissolveTransition",parameters:["inputTargetImage":b,"inputTime":amount]).cropped(to:bounds)
        }
        func transform(_ image:CIImage,scale:Double,angle:Double=0)->CIImage {
            image.clampedToExtent().transformed(by:CGAffineTransform(translationX:-bounds.midX,y:-bounds.midY)
                .concatenating(CGAffineTransform(scaleX:scale,y:scale))
                .concatenating(CGAffineTransform(rotationAngle:angle))
                .concatenating(CGAffineTransform(translationX:bounds.midX,y:bounds.midY))).cropped(to:bounds)
        }
        switch style {
        case .smokeDrift,.confetti,.goldConfetti:return AtmosphereTransition.render(from,to:to,style:style,progress:t,bounds:bounds)
        case .dissolve:return mix(from,to,t)
        case .fadeBlack,.fadeWhite:
            let color:CGFloat=style == .fadeWhite ? 1 : 0
            let solid=CIImage(color:CIColor(red:color,green:color,blue:color)).cropped(to:bounds)
            return t<0.5 ? mix(from,solid,t*2) : mix(solid,to,(t-0.5)*2)
        case .flash:
            let solid=CIImage(color:.white).cropped(to:bounds)
            return mix(mix(from,to,t),solid,pow(sin(.pi*t),8))
        case .blur:
            return mix(from,to,t).clampedToExtent().applyingFilter("CIGaussianBlur",parameters:["inputRadius":min(bounds.width,bounds.height)*0.06*sin(.pi*t)]).cropped(to:bounds)
        case .pixelate:
            return mix(from,to,t).clampedToExtent().applyingFilter("CIPixellate",parameters:["inputScale":max(1,min(bounds.width,bounds.height)*0.12*sin(.pi*t)),"inputCenter":CIVector(x:bounds.midX,y:bounds.midY)]).cropped(to:bounds)
        case .zoomIn:return mix(transform(from,scale:1+t*0.8),transform(to,scale:0.5+t*0.5),t)
        case .zoomOut:return mix(transform(from,scale:1-t*0.5),transform(to,scale:1.8-t*0.8),t)
        case .rotate:return mix(transform(from,scale:1+sin(.pi*t)*0.4,angle:t * .pi/2),transform(to,scale:1+sin(.pi*t)*0.4,angle:(t-1) * .pi/2),t)
        case .wipeLeft,.wipeRight,.wipeUp,.wipeDown:
            var rect=bounds
            if style == .wipeLeft || style == .wipeRight {rect.size.width *= t;if style == .wipeLeft{rect.origin.x=bounds.maxX-rect.width}}
            else{rect.size.height *= t;if style == .wipeDown{rect.origin.y=bounds.maxY-rect.height}}
            return to.cropped(to:rect).composited(over:from).cropped(to:bounds)
        case .slideLeft,.slideRight,.slideUp,.slideDown,.coverLeft,.coverRight:
            let horizontal=style != .slideUp && style != .slideDown
            let direction:Double=(style == .slideLeft || style == .slideDown || style == .coverLeft) ? -1 : 1
            let dx=horizontal ? direction*bounds.width : 0,dy=horizontal ? 0 : direction*bounds.height
            let outgoing=(style == .coverLeft || style == .coverRight) ? from : from.transformed(by:CGAffineTransform(translationX:dx*t,y:dy*t))
            let incoming=to.transformed(by:CGAffineTransform(translationX:-dx*(1-t),y:-dy*(1-t)))
            return incoming.composited(over:outgoing).composited(over:from).cropped(to:bounds)
        default:
            guard let mask=matte(style,t:t,bounds:bounds) else{return mix(from,to,t)}
            return to.applyingFilter("CIBlendWithMask",parameters:["inputBackgroundImage":from,"inputMaskImage":mask]).cropped(to:bounds)
        }
    }
    /// Bounded mask rasterization: at most 384 pixels on its longest side even for 4K.
    private static func matte(_ style:TransitionStyle,t:Double,bounds:CGRect)->CIImage? {
        let factor=min(1,384/max(bounds.width,bounds.height))
        let w=max(1,Int(ceil(bounds.width*factor))),h=max(1,Int(ceil(bounds.height*factor)))
        var bytes=[UInt8](repeating:0,count:w*h)
        for y in 0..<h {for x in 0..<w {
            let u=(Double(x)+0.5)/Double(w),v=(Double(y)+0.5)/Double(h)
            let dx=abs(u-0.5)*2,dy=abs(v-0.5)*2
            let threshold:Double
            switch style {
            case .circle:threshold=hypot((u-0.5)*bounds.width,(v-0.5)*bounds.height)/hypot(bounds.width/2,bounds.height/2)
            case .diamond:threshold=(dx+dy)/2
            case .box:threshold=max(dx,dy)
            case .verticalOpen:threshold=dx
            case .horizontalOpen:threshold=dy
            case .blinds:threshold=(u*8).truncatingRemainder(dividingBy:1)
            case .checkerboard:threshold=((Int(u*8)+Int(v*6))%2==0 ? 0 : 0.5)+dx*0.5
            case .diagonal:threshold=(u+v)/2
            case .wave:threshold=(u+0.08*sin(v*24)+0.08)/1.16
            case .ink:threshold=min(1,max(0,hypot(dx,dy)/sqrt(2)+0.12*sin(u*25)*cos(v*31)))
            default:threshold=u
            }
            let feather=style == .ink ? 0.06 : 0.012
            bytes[y*w+x]=UInt8(max(0,min(255,(t-threshold)/feather*255+127.5)))
        }}
        let data=Data(bytes)
        guard let provider=CGDataProvider(data:data as CFData),let cg=CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:8,bytesPerRow:w,space:CGColorSpaceCreateDeviceGray(),bitmapInfo:CGBitmapInfo(rawValue:0),provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent) else{return nil}
        return CIImage(cgImage:cg).transformed(by:CGAffineTransform(scaleX:bounds.width/Double(w),y:bounds.height/Double(h))).transformed(by:CGAffineTransform(translationX:bounds.minX,y:bounds.minY))
    }
}
