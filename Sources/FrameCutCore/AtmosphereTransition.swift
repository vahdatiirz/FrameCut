import Foundation
import CoreImage
import CoreGraphics

/// Independent, deterministic visual effects. These do not generate new scene geometry.
enum AtmosphereTransition {
    static func render(_ from:CIImage,to:CIImage,style:TransitionStyle,progress t:Double,bounds:CGRect)->CIImage {
        let reveal=t*t*(3-2*t)
        let base:CIImage
        if style == .smokeDrift {
            base=from.applyingFilter("CIDissolveTransition",parameters:["inputTargetImage":to,"inputTime":reveal]).cropped(to:bounds)
        }else{
            // Reveal intact source regions so lettering/faces do not globally
            // double-expose underneath the sparse particle layer.
            base=TransitionRenderer.render(from,to:to,style:.wave,progress:reveal,bounds:bounds)
        }
        let overlay=style == .smokeDrift ? smoke(t,bounds:bounds) : particles(t,gold:style == .goldConfetti,bounds:bounds)
        return overlay?.composited(over:base).cropped(to:bounds) ?? base
    }
    private static func hash(_ x:Int,_ y:Int)->Double {
        var n=UInt32(truncatingIfNeeded:x) &* 374761393 &+ UInt32(truncatingIfNeeded:y) &* 668265263
        n=(n ^ (n >> 13)) &* 1274126177;n=n ^ (n >> 16)
        return Double(n)/Double(UInt32.max)
    }
    private static func noise(_ x:Double,_ y:Double)->Double {
        let ix=Int(floor(x)),iy=Int(floor(y)),fx=x-floor(x),fy=y-floor(y)
        let u=fx*fx*(3-2*fx),v=fy*fy*(3-2*fy)
        let a=hash(ix,iy)*(1-u)+hash(ix+1,iy)*u
        let b=hash(ix,iy+1)*(1-u)+hash(ix+1,iy+1)*u
        return a*(1-v)+b*v
    }
    private static func dimensions(_ bounds:CGRect,limit:Double)->(Int,Int) {
        let factor=min(1,limit/max(bounds.width,bounds.height))
        return(max(1,Int(ceil(bounds.width*factor))),max(1,Int(ceil(bounds.height*factor))))
    }
    private static func fitted(_ image:CGImage,bounds:CGRect)->CIImage {
        CIImage(cgImage:image).transformed(by:CGAffineTransform(scaleX:bounds.width/Double(image.width),y:bounds.height/Double(image.height)))
            .transformed(by:CGAffineTransform(translationX:bounds.minX,y:bounds.minY))
    }
    private static func smoke(_ t:Double,bounds:CGRect)->CIImage? {
        let (w,h)=dimensions(bounds,limit:384)
        var data=[UInt8](repeating:0,count:w*h*4)
        let envelope=pow(max(0,sin(.pi*t)),1.2)*1.8
        for y in 0..<h {for x in 0..<w {
            let u=Double(x)/Double(w),v=Double(y)/Double(h)
            let curl=0.35*sin(v*7+t*3)
            let n=noise(u*4.5+t*1.8+curl,v*4-t*0.7)*0.58
                + noise(u*10+t*2.7,v*9+t*0.8)*0.28
                + noise(u*22-t*1.3,v*20)*0.14
            let alpha=min(1,envelope*(0.7+n*0.6)),shade=0.57+n*0.42
            let i=(y*w+x)*4,c=UInt8(max(0,min(255,shade*alpha*255)))
            data[i]=c;data[i+1]=c;data[i+2]=c;data[i+3]=UInt8(alpha*255)
        }}
        guard let provider=CGDataProvider(data:Data(data) as CFData),let image=CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:provider,decode:nil,shouldInterpolate:true,intent:.defaultIntent) else{return nil}
        return fitted(image,bounds:bounds)
    }
    private static func particles(_ t:Double,gold:Bool,bounds:CGRect)->CIImage? {
        let (w,h)=dimensions(bounds,limit:640),space=CGColorSpaceCreateDeviceRGB()
        guard let c=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else{return nil}
        let palette:[[CGFloat]]=[[1,0.18,0.3],[0.15,0.5,1],[0.35,0.95,0.55],[0.8,0.3,1],[1,0.8,0.12]]
        let fade=min(1,t/0.12)*min(1,(1-t)/0.18)
        for i in 0..<180 {
            let r=hash(i,11),r2=hash(i,29),r3=hash(i,47),age=t*1.4
            let x=0.5+(r-0.5)*0.12+(r2-0.5)*2.6*age
            let y=0.55+(0.7+r3*0.8)*age-1.6*age*age
            guard x > -0.1 && x < 1.1 && y > -0.1 && y < 1.1 else{continue}
            let size=Double(w)*(0.009+hash(i,71)*0.014)
            let angle=hash(i,97)*6.28+age*(r-0.5)*18
            let flutter=max(0.15,abs(cos(age*(4+r3*8)+r*6.28)))
            c.saveGState();c.translateBy(x:x*Double(w),y:y*Double(h));c.rotate(by:angle);c.scaleBy(x:flutter,y:1)
            c.setAlpha(fade)
            let rect=CGRect(x:-size/2,y:-size*0.32,width:size,height:size*(gold ? 1.05 : 0.64))
            if gold {
                let colors=[CGColor(red:0.5,green:0.28,blue:0.02,alpha:1),CGColor(red:1,green:0.88,blue:0.35,alpha:1),CGColor(red:0.8,green:0.5,blue:0.04,alpha:1)]
                if let gradient=CGGradient(colorsSpace:space,colors:colors as CFArray,locations:[0,0.5,1]){
                    c.addRect(rect);c.clip();c.drawLinearGradient(gradient,start:CGPoint(x:rect.minX,y:0),end:CGPoint(x:rect.maxX,y:0),options:[])
                }
            }else{
                let rgb=palette[i%palette.count];c.setFillColor(red:rgb[0],green:rgb[1],blue:rgb[2],alpha:1);c.fill(rect)
            }
            c.restoreGState()
        }
        guard let image=c.makeImage() else{return nil}
        return fitted(image,bounds:bounds)
    }
}
