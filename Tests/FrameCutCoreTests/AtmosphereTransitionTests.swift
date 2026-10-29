import XCTest
import CoreImage
@testable import FrameCutCore

final class AtmosphereTransitionTests:XCTestCase {
    let bounds=CGRect(x:0,y:0,width:192,height:108)
    func pixels(_ image:CIImage)->[UInt8]{
        var data=[UInt8](repeating:0,count:192*108*4)
        CIContext().render(image,toBitmap:&data,rowBytes:192*4,bounds:bounds,format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB())
        return data
    }
    func testSmokeActuallyObscuresTheSceneWithMovingCloudTexture() throws {
        let style=try XCTUnwrap(TransitionStyle(rawValue:"smokeDrift"))
        let black=CIImage(color:.black).cropped(to:bounds)
        let mid=pixels(TransitionRenderer.render(black,to:black,style:style,progress:0.5,bounds:bounds))
        let brightness=stride(from:0,to:mid.count,by:4).map{Int(mid[$0])}
        XCTAssertGreaterThan(brightness.filter{$0>150}.count,brightness.count*8/10,"Smoke must visibly cover the image, not silently dissolve")
        XCTAssertGreaterThan((brightness.max() ?? 0)-(brightness.min() ?? 0),25,"Clouds must not be a flat white fade")
        let early=pixels(TransitionRenderer.render(black,to:black,style:style,progress:0.35,bounds:bounds))
        let late=pixels(TransitionRenderer.render(black,to:black,style:style,progress:0.65,bounds:bounds))
        XCTAssertNotEqual(early,late,"Smoke must drift")
    }
    func testConfettiAddsVisibleColoredMovingParticlesWithoutReplacingWholeImage() throws {
        let style=try XCTUnwrap(TransitionStyle(rawValue:"confetti"))
        let black=CIImage(color:.black).cropped(to:bounds)
        let p=pixels(TransitionRenderer.render(black,to:black,style:style,progress:0.45,bounds:bounds))
        var colored=0,red=0,blue=0
        for i in stride(from:0,to:p.count,by:4){
            if max(p[i],p[i+1],p[i+2])>60{colored+=1}
            if Int(p[i])>Int(p[i+2])+60{red+=1}
            if Int(p[i+2])>Int(p[i])+60{blue+=1}
        }
        XCTAssertGreaterThan(colored,100);XCTAssertLessThan(colored,192*108/2)
        XCTAssertGreaterThan(red,20);XCTAssertGreaterThan(blue,20)
        XCTAssertNotEqual(p,pixels(TransitionRenderer.render(black,to:black,style:style,progress:0.65,bounds:bounds)))
        XCTAssertEqual(p,pixels(TransitionRenderer.render(black,to:black,style:style,progress:0.45,bounds:bounds)),"Repeated preview/export frames must use the same particle layout")
    }
    func testGoldConfettiHasGoldHighlightsAndExactOriginalEndpoints() throws {
        let gold=try XCTUnwrap(TransitionStyle(rawValue:"goldConfetti"))
        let black=CIImage(color:.black).cropped(to:bounds),white=CIImage(color:.white).cropped(to:bounds)
        let p=pixels(TransitionRenderer.render(black,to:black,style:gold,progress:0.45,bounds:bounds))
        var lit=0,golden=0
        for i in stride(from:0,to:p.count,by:4) where p[i]>60 {
            lit+=1;if p[i]>=p[i+1] && Int(p[i+1])>Int(p[i+2])+20{golden+=1}
        }
        XCTAssertGreaterThan(lit,100);XCTAssertGreaterThan(golden,lit*3/4)
        for raw in ["smokeDrift","confetti","goldConfetti"] {
            let style=try XCTUnwrap(TransitionStyle(rawValue:raw))
            XCTAssertEqual(pixels(TransitionRenderer.render(black,to:white,style:style,progress:0,bounds:bounds)),pixels(black))
            XCTAssertEqual(pixels(TransitionRenderer.render(black,to:white,style:style,progress:1,bounds:bounds)),pixels(white))
        }
    }
    func testParticlesRevealSourcesWithoutGlobalDoubleExposure() throws {
        let a=CIImage(color:CIColor(red:1,green:0,blue:0)).cropped(to:bounds)
        let b=CIImage(color:CIColor(red:0,green:0,blue:1)).cropped(to:bounds)
        for raw in ["confetti","goldConfetti"] {
            let style=try XCTUnwrap(TransitionStyle(rawValue:raw))
            let p=pixels(TransitionRenderer.render(a,to:b,style:style,progress:0.5,bounds:bounds))
            var unchanged=0
            for i in stride(from:0,to:p.count,by:4){if (p[i]>240 && p[i+2]<10) || (p[i+2]>240 && p[i]<10){unchanged+=1}}
            XCTAssertGreaterThan(unchanged,192*108*8/10,"Outside the particles and reveal edge, keep one intact source rather than ghost both scenes")
        }
    }

}
