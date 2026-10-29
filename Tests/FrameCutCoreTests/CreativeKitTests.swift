import XCTest
import CoreImage
@testable import FrameCutCore
final class CreativeKitTests:XCTestCase {
    func testResettingColorPreservesPrivacyMaskAndFraming() throws {
        var e=ClipEffects();e.look = .noir;e.brightness=0.3;e.exposure=1;e.lutFilename="grade.cube"
        e.privacyRegions=[PrivacyRegion()];e.mask=MaskSpec();e.quarterTurns=1;e.mirrored=true;e.fit = .fill;e.cutStyle = .fadeBlack
        let regions=e.privacyRegions,mask=e.mask
        e.resetColor()
        XCTAssertEqual(e.look,.original);XCTAssertEqual(e.brightness,0);XCTAssertEqual(e.exposure,0);XCTAssertNil(e.lutFilename)
        XCTAssertEqual(e.privacyRegions,regions);XCTAssertEqual(e.mask,mask)
        XCTAssertEqual(e.quarterTurns,1);XCTAssertTrue(e.mirrored);XCTAssertEqual(e.fit,.fill);XCTAssertEqual(e.cutStyle,.fadeBlack)
        try e.validate()
    }

    func testTemplateChangesTimingCanvasAndStyleWithoutReplacingMediaOrTitle() throws {
        var p=Project();p.clips=[Clip(filename:"owned.mov",name:"Owned",duration:10)];p.title="My words"
        let id=p.clips[0].id
        try XCTUnwrap(EditTemplate.all.first{$0.id=="reel"}).apply(to:&p)
        XCTAssertEqual(p.canvas,.portrait);XCTAssertEqual(p.clips[0].speed,1.5);XCTAssertEqual(p.clips[0].duration,1.5,accuracy:0.001)
        XCTAssertEqual(p.clips[0].filename,"owned.mov");XCTAssertEqual(p.clips[0].id,id);XCTAssertEqual(p.title,"My words")
        XCTAssertEqual(p.style?.templateID,"reel");XCTAssertEqual(p.clips[0].effects?.look,.process)
    }
    func testEveryTemplateProducesValidPersistableProject() throws {
        for recipe in EditTemplate.all {
            var p=Project();p.clips=[Clip(filename:"short.mov",name:"Short",duration:0.5),Clip(filename:"long.mov",name:"Long",duration:12)]
            try recipe.apply(to:&p);try p.validate()
            XCTAssertFalse(p.title.isEmpty)
            XCTAssertEqual(try JSONDecoder().decode(Project.self,from:JSONEncoder().encode(p)),p)
            XCTAssertLessThanOrEqual(p.clips[1].duration,recipe.clipSeconds+0.001)
        }
    }
    func testLegacyProjectLoadsWithNeutralEffects() throws {
        var p=Project();p.clips=[Clip(filename:"a.mov",name:"A",duration:2)]
        var object=try XCTUnwrap(JSONSerialization.jsonObject(with:JSONEncoder().encode(p)) as? [String:Any])
        object.removeValue(forKey:"style")
        var clips=try XCTUnwrap(object["clips"] as? [[String:Any]]);clips[0].removeValue(forKey:"effects");object["clips"]=clips
        let loaded=try JSONDecoder().decode(Project.self,from:JSONSerialization.data(withJSONObject:object))
        try loaded.validate();XCTAssertNil(loaded.style);XCTAssertNil(loaded.clips[0].effects)
    }
    func testMonoFilterChangesActualPixelAndZeroIntensityPreservesColor() {
        let input=CIImage(color:CIColor(red:0.9,green:0.1,blue:0.2)).cropped(to:CGRect(x:0,y:0,width:1,height:1))
        var effects=ClipEffects();effects.look = .mono
        let mono=pixel(ColorPipeline.apply(input,effects:effects))
        XCTAssertEqual(mono[0],mono[1],accuracy:4);XCTAssertEqual(mono[1],mono[2],accuracy:4)
        effects.intensity=0
        let original=pixel(ColorPipeline.apply(input,effects:effects));XCTAssertGreaterThan(original[0],original[1]+100)
    }
    func testExpandedLookRecipesRenderAndZeroStrengthPreservesInput() throws {
        let input=CIImage(color:CIColor(red:0.4,green:0.4,blue:0.4)).cropped(to:CGRect(x:0,y:0,width:1,height:1))
        for look in Look.allCases {var e=ClipEffects();e.look=look;let result=ColorPipeline.apply(input,effects:e);XCTAssertEqual(result.extent,input.extent);_ = pixel(result)}
        var e=ClipEffects();e.look = .golden;let warm=pixel(ColorPipeline.apply(input,effects:e));XCTAssertGreaterThan(warm[0],warm[2]+10)
        e.look = .arctic;let cool=pixel(ColorPipeline.apply(input,effects:e));XCTAssertGreaterThan(cool[2],cool[0]+10)
        e.intensity=0;let neutral=pixel(ColorPipeline.apply(input,effects:e));XCTAssertEqual(neutral[0],neutral[2],accuracy:1)
    }
    func testEffectValidationRejectsInvalidNumericParameters() {
        var e=ClipEffects();e.brightness = .nan;XCTAssertThrowsError(try e.validate())
        e=ClipEffects();e.quarterTurns=4;XCTAssertThrowsError(try e.validate())
        var style=ProjectStyle();style.fps=61;XCTAssertThrowsError(try style.validate())
    }
    private func pixel(_ image:CIImage)->[Double] {
        var b=[UInt8](repeating:0,count:4)
        b.withUnsafeMutableBytes{CIContext().render(image,toBitmap:$0.baseAddress!,rowBytes:4,bounds:CGRect(x:0,y:0,width:1,height:1),format:.RGBA8,colorSpace:CGColorSpaceCreateDeviceRGB())}
        return b.map(Double.init)
    }
}
