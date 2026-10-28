import XCTest
@testable import FrameCutCore
final class MotionPresetTests:XCTestCase {
    func testFadeAndSlideRecipesHaveExpectedVisibleEndpoints() throws {
        let fade=MotionPreset.fadeIn.track
        XCTAssertEqual(fade.sample(at:0).opacity,0)
        XCTAssertEqual(fade.sample(at:1).opacity,1)
        XCTAssertEqual(MotionPreset.slideLeft.track.sample(at:1).x,-0.4)
        XCTAssertEqual(MotionPreset.slideUp.track.sample(at:1).y,-0.4)
        XCTAssertEqual(MotionPreset.zoomOut.track.sample(at:0).scale,1.3)
        XCTAssertEqual(MotionPreset.zoomOut.track.sample(at:1).scale,1)
    }
    func testEveryRecipeProducesFiniteDistinctMotionThatSurvivesSplitting() throws {
        var signatures=Set<String>()
        for preset in MotionPreset.allCases {
            let track=preset.track;try track.validate()
            let samples=[0.0,0.2,0.5,0.8,1.0].map{track.sample(at:$0)}
            signatures.insert(samples.map{String(format:"%.3f,%.3f,%.3f,%.3f,%.3f",$0.x,$0.y,$0.scale,$0.rotation,$0.opacity)}.joined(separator:";"))
            let middle=track.segment(from:0.2,to:0.8)
            XCTAssertEqual(middle.sample(at:0).scale,track.sample(at:0.2).scale,accuracy:0.00001)
            XCTAssertEqual(middle.sample(at:1).opacity,track.sample(at:0.8).opacity,accuracy:0.00001)
        }
        XCTAssertEqual(signatures.count,19)
    }
}
