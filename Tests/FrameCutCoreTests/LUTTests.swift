import XCTest
import CoreImage
@testable import FrameCutCore
final class LUTTests:XCTestCase {
    func testCubeParsingOrderAndRealPixelInversion() throws {
        var lines=["TITLE \"Invert red\"","LUT_3D_SIZE 2","DOMAIN_MIN 0 0 0","DOMAIN_MAX 1 1 1"]
        for b in 0...1{for g in 0...1{for r in 0...1{lines.append("\(1-r) \(g) \(b)")}}}
        let cube=try CubeLUT.parse(lines.joined(separator:"\n"))
        let image=CIImage(color:CIColor(red:1,green:0,blue:0)).cropped(to:CGRect(x:0,y:0,width:1,height:1))
        let rendered=ColorPipeline.apply(image,effects:ClipEffects(),lut:cube)
        var bytes=[UInt8](repeating:0,count:4)
        CIContext().render(rendered,toBitmap:&bytes,rowBytes:4,bounds:image.extent,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB))
        XCTAssertLessThan(bytes[0],10);XCTAssertLessThan(bytes[1],10);XCTAssertLessThan(bytes[2],10);XCTAssertEqual(bytes[3],255)
    }
    func testMalformedAndUnboundedCubesAreRejected() {
        for text in ["LUT_3D_SIZE 999999999","LUT_3D_SIZE 2\n0 0 0","LUT_1D_SIZE 2\n0 0 0\n1 1 1"]{XCTAssertThrowsError(try CubeLUT.parse(text))}
        var e=ClipEffects();e.lutFilename="../outside.cube";XCTAssertThrowsError(try e.validate())
    }
}
