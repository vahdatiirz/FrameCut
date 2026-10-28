import XCTest
@testable import FrameCutCore
final class LayerTests:XCTestCase {
    func testKeyframeInterpolationEasingAndSplitContinuity() throws {
        var c=Clip(filename:"a.mov",name:"A",duration:4)
        var a=MotionKeyframe(time:0);a.x = -0.4;a.opacity=0.2
        var b=MotionKeyframe(time:1);b.x=0.4;b.opacity=1;b.scale=2
        c.motion=MotionTrack(keyframes:[a,b])
        XCTAssertEqual(c.motion!.sample(at:0.25).x,-0.2,accuracy:0.0001)
        XCTAssertEqual(c.motion!.sample(at:0.5).opacity,0.6,accuracy:0.0001)
        let (left,right)=try c.split(at:1)
        XCTAssertEqual(left.motion!.sample(at:1).x,right.motion!.sample(at:0).x,accuracy:0.0001)
        XCTAssertEqual(right.motion!.sample(at:1).scale,2,accuracy:0.0001)
    }
    func testOverlayPersistenceAndUnsafeMediaValidation() throws {
        var p=Project();p.clips=[Clip(filename:"a.mov",name:"A",duration:4)]
        var layer=OverlayLayer(clip:Clip(filename:"b.mov",name:"B",duration:2));layer.timelineStart=1;layer.mask = .circle;p.overlays=[layer]
        try p.validate();XCTAssertEqual(try JSONDecoder().decode(Project.self,from:JSONEncoder().encode(p)),p)
        p.overlays![0].clip.filename="../secret.mov";XCTAssertThrowsError(try p.validate())
        var m=MotionKeyframe(time:0);m.scale=0;XCTAssertThrowsError(try MotionTrack(keyframes:[m]).validate())
    }
}
