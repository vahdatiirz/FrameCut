import XCTest
import CoreImage
@testable import FrameCutCore
final class MaskTests:XCTestCase {
    func testMaskInversionAndRegionalBlurAffectOnlySelectedArea() throws {
        let bounds=CGRect(x:0,y:0,width:100,height:100)
        let red=CIImage(color:CIColor(red:1,green:0,blue:0)).cropped(to:bounds)
        var mask=MaskSpec();mask.shape = .circle;mask.width=0.5;mask.height=0.5
        let clipped=PixelEffects.masked(red,spec:mask,bounds:bounds)
        XCTAssertGreaterThan(pixel(clipped,x:50,y:50)[3],240);XCTAssertEqual(pixel(clipped,x:2,y:2)[3],0)
        mask.inverted=true
        let inverse=PixelEffects.masked(red,spec:mask,bounds:bounds)
        XCTAssertEqual(pixel(inverse,x:50,y:50)[3],0);XCTAssertGreaterThan(pixel(inverse,x:2,y:2)[3],240)
        let blue=CIImage(color:CIColor(red:0,green:0,blue:1)).cropped(to:CGRect(x:50,y:0,width:50,height:100))
        let pattern=blue.composited(over:red)
        var region=PrivacyRegion();region.mask.width=0.6;region.mask.height=1;region.amount=1
        let blurred=PixelEffects.privacy(pattern,regions:[region],bounds:bounds)
        let edge=pixel(blurred,x:49,y:50)
        XCTAssertGreaterThan(edge[2],30);XCTAssertEqual(pixel(blurred,x:5,y:50)[0],255)
    }
    func testEveryShapeAndCustomPolygonIsRenderableAndInvalidGeometryRejected() throws {
        for shape in MaskShape.allCases {
            var spec=MaskSpec();spec.shape=shape;try spec.validate()
            XCTAssertNotNil(PixelEffects.mask(spec,bounds:CGRect(x:0,y:0,width:160,height:90)))
        }
        var spec=MaskSpec();spec.width = .nan;XCTAssertThrowsError(try spec.validate())
        spec=MaskSpec();spec.shape = .custom;spec.points=[];XCTAssertThrowsError(try spec.validate())
    }
    private func pixel(_ image:CIImage,x:Int,y:Int)->[UInt8]{var result=[UInt8](repeating:0,count:4);CIContext().render(image,toBitmap:&result,rowBytes:4,bounds:CGRect(x:x,y:y,width:1,height:1),format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB));return result}
}
