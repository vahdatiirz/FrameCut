import XCTest
import CoreImage
@testable import FrameCutCore
final class TransitionRenderTests:XCTestCase {
    private let bounds=CGRect(x:0,y:0,width:96,height:64)
    private func pixels(_ image:CIImage)->[UInt8] {
        var bytes=[UInt8](repeating:0,count:96*64*4)
        CIContext(options:[.useSoftwareRenderer:false]).render(image,toBitmap:&bytes,rowBytes:96*4,bounds:bounds,format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB())
        return bytes
    }
    func testEveryStyleHasExactEndpointsAndProducesAnOpaqueFiniteFrame() {
        let a=CIImage(color:CIColor(red:1,green:0,blue:0)).cropped(to:bounds)
        let b=CIImage(color:CIColor(red:0,green:0,blue:1)).cropped(to:bounds)
        for style in TransitionStyle.allCases {
            XCTAssertEqual(pixels(TransitionRenderer.render(a,to:b,style:style,progress:0,bounds:bounds)),pixels(a),style.rawValue)
            XCTAssertEqual(pixels(TransitionRenderer.render(a,to:b,style:style,progress:1,bounds:bounds)),pixels(b),style.rawValue)
            for t in [0.1,0.35,0.5,0.75,0.95] {
                let frame=TransitionRenderer.render(a,to:b,style:style,progress:t,bounds:bounds)
                XCTAssertEqual(frame.extent,bounds,style.rawValue)
                let data=pixels(frame)
                XCTAssertTrue(stride(from:3,to:data.count,by:4).allSatisfy{data[$0]==255},"Opaque frame: \(style) at \(t)")
            }
        }
    }
    func testMatteOpeningRevealsCenterBeforeCornersAndBlackDipReachesBlack() {
        let red=CIImage(color:CIColor(red:1,green:0,blue:0)).cropped(to:bounds)
        let blue=CIImage(color:CIColor(red:0,green:0,blue:1)).cropped(to:bounds)
        for style in [TransitionStyle.circle,.diamond,.box] {
            let p=pixels(TransitionRenderer.render(red,to:blue,style:style,progress:0.4,bounds:bounds))
            let center=(32*96+48)*4
            XCTAssertGreaterThan(p[center+2],240);XCTAssertGreaterThan(p[0],240)
        }
        let dip=pixels(TransitionRenderer.render(red,to:blue,style:.fadeBlack,progress:0.5,bounds:bounds))
        XCTAssertEqual(dip[0],0);XCTAssertEqual(dip[2],0)
    }
}
