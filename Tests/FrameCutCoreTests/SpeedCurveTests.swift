import XCTest
@testable import FrameCutCore
final class SpeedCurveTests:XCTestCase {
    func testIntegralAndSplitPreserveRampDurationAndSourceMapping() throws {
        var c=Clip(filename:"a.mov",name:"A",duration:4)
        c.speedCurve=SpeedCurve(points:[SpeedPoint(position:0,speed:1),SpeedPoint(position:1,speed:2)])
        XCTAssertEqual(c.duration,4*log(2),accuracy:0.000001)
        let (a,b)=try c.split(at:c.duration/2)
        XCTAssertEqual(a.duration+b.duration,c.duration,accuracy:0.000001)
        XCTAssertEqual(a.end,4*(sqrt(2)-1),accuracy:0.00001)
        XCTAssertEqual(a.duration,b.duration,accuracy:0.00001)
        XCTAssertEqual(b.start,a.end,accuracy:0.00001)
    }
    func testExtremeConstantSpeedsAndInvalidCurvePoints() throws {
        var c=Clip(filename:"a.mov",name:"A",duration:10)
        c.speed=100;try c.validate();XCTAssertEqual(c.duration,0.1,accuracy:0.00001)
        c.speed=0.1;try c.validate();XCTAssertEqual(c.duration,100,accuracy:0.00001)
        XCTAssertThrowsError(try SpeedCurve(points:[SpeedPoint(position:0,speed:0),SpeedPoint(position:1,speed:1)]).validate())
        XCTAssertThrowsError(try SpeedCurve(points:[SpeedPoint(position:0.1,speed:1),SpeedPoint(position:1,speed:1)]).validate())
    }
}
