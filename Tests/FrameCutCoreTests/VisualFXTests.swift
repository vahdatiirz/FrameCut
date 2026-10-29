import XCTest
import CoreImage
@testable import FrameCutCore
final class VisualFXTests:XCTestCase {
    func testTimedInversionOnlyChangesPixelsInsideWindowAndHonorsStrength() throws {
        let input=CIImage(color:CIColor(red:1,green:0,blue:0)).cropped(to:CGRect(x:0,y:0,width:40,height:40))
        var fx=VisualFX(kind:.invert);fx.start=0.25;fx.end=0.75
        let before=pixel(VisualFXPipeline.apply(input,effects:[fx],progress:0.1))
        let during=pixel(VisualFXPipeline.apply(input,effects:[fx],progress:0.5))
        XCTAssertGreaterThan(before[0],240);XCTAssertLessThan(during[0],10);XCTAssertGreaterThan(during[1],240)
        fx.amount=0
        XCTAssertGreaterThan(pixel(VisualFXPipeline.apply(input,effects:[fx],progress:0.5))[0],240)
    }
    func testFXSplitAndTrimPreserveOriginalActiveWindow() throws {
        var clip=Clip(filename:"a.mov",name:"A",duration:4);var e=ClipEffects();var fx=VisualFX(kind:.invert);fx.start=0.5;fx.end=0.75;e.visualFX=[fx];clip.effects=e
        let (_,right)=try clip.split(at:2)
        XCTAssertTrue(right.effects!.visualFX![0].isActive(at:0.25));XCTAssertFalse(right.effects!.visualFX![0].isActive(at:0.75))
        try clip.trim(start:1,end:3)
        XCTAssertFalse(clip.effects!.visualFX![0].isActive(at:0.25));XCTAssertTrue(clip.effects!.visualFX![0].isActive(at:0.75))
        try clip.trim(start:0,end:4)
        XCTAssertFalse(clip.effects!.visualFX![0].isActive(at:0.25));XCTAssertTrue(clip.effects!.visualFX![0].isActive(at:0.6));XCTAssertFalse(clip.effects!.visualFX![0].isActive(at:0.8))
    }
    func testRampedClipTrimMapsFXByOutputTimeAndRestoresWindow() throws {
        var clip=Clip(filename:"a.mov",name:"A",duration:4)
        clip.speedCurve=SpeedCurve(points:[.init(position:0,speed:1),.init(position:1,speed:2)])
        var e=ClipEffects();var fx=VisualFX(kind:.invert);fx.start=0.5;fx.end=0.75;e.visualFX=[fx];clip.effects=e
        try clip.trim(start:4*(sqrt(2)-1),end:4)
        XCTAssertTrue(clip.effects!.visualFX![0].isActive(at:0.25));XCTAssertFalse(clip.effects!.visualFX![0].isActive(at:0.75))
        try clip.trim(start:0,end:4)
        XCTAssertFalse(clip.effects!.visualFX![0].isActive(at:0.25));XCTAssertTrue(clip.effects!.visualFX![0].isActive(at:0.6))
    }
    func testFXValidationAndProjectRoundTrip() throws {
        var p=Project();var clip=Clip(filename:"a.mov",name:"A",duration:2);var e=ClipEffects();e.visualFX=[VisualFX(kind:.bloom)];clip.effects=e;p.clips=[clip]
        try p.validate();XCTAssertEqual(try JSONDecoder().decode(Project.self,from:JSONEncoder().encode(p)),p)
        e.visualFX![0].amount = .nan;XCTAssertThrowsError(try e.validate())
    }
    func testEveryFXProducesARealFiniteFrame() throws {
        let bounds=CGRect(x:0,y:0,width:160,height:90)
        let input=CIImage(color:CIColor(red:0.8,green:0.2,blue:0.1)).cropped(to:bounds)
        let context=CIContext()
        for kind in VisualFXKind.allCases {
            let fx=VisualFX(kind:kind);try fx.validate()
            let output=VisualFXPipeline.apply(input,effects:[fx],progress:0.5)
            XCTAssertEqual(output.extent,bounds);XCTAssertNotNil(context.createCGImage(output,from:bounds),kind.rawValue)
        }
    }
    private func pixel(_ image:CIImage)->[UInt8]{var b=[UInt8](repeating:0,count:4);CIContext().render(image,toBitmap:&b,rowBytes:4,bounds:CGRect(x:20,y:20,width:1,height:1),format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB());return b}
}
