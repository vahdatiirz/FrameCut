import XCTest
@testable import FrameCutCore
final class TransitionTests:XCTestCase {
    func testTransitionEditsAreAtomicAndApplyToEveryAdjacentPair() throws {
        var p=Project();p.clips=(0..<4).map{Clip(filename:"\($0).mov",name:"Clip",duration:4)}
        try p.setTransition(from:p.clips[0].id,to:p.clips[1].id,style:.circle,duration:0.75,applyToAll:true)
        XCTAssertEqual(p.transitions?.count,3);XCTAssertEqual(p.duration,13.75,accuracy:0.001)
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys];let before=try encoder.encode(p)
        XCTAssertThrowsError(try p.setTransition(from:p.clips[0].id,to:p.clips[3].id,style:.dissolve,duration:1))
        XCTAssertEqual(try encoder.encode(p),before)
        XCTAssertThrowsError(try p.setTransition(from:p.clips[0].id,to:p.clips[1].id,style:.dissolve,duration:.nan))
        XCTAssertEqual(try encoder.encode(p),before)
        try p.setTransition(from:p.clips[1].id,to:p.clips[2].id,style:nil,duration:1)
        XCTAssertEqual(p.transitions?.count,2);try p.validate()
    }

    func testOverlapsShortenTimelineAndNeverRequireThreeMainClips() throws {
        var p=Project();p.clips=(0..<3).map{Clip(filename:"\($0).mov",name:"\($0)",duration:2)}
        p.transitions=[ClipTransition(from:p.clips[0].id,to:p.clips[1].id,duration:2),ClipTransition(from:p.clips[1].id,to:p.clips[2].id,duration:2)]
        try p.validate();XCTAssertEqual(p.duration,4);XCTAssertEqual(p.placements.map(\.start),[0,1,2])
        for t in stride(from:0.0,to:p.duration,by:0.01){XCTAssertLessThanOrEqual(p.placements.filter{t >= $0.start && t < $0.start+$0.duration}.count,2)}
        p.clips.remove(at:1);p.removeInactiveTransitions();XCTAssertTrue(p.transitions!.isEmpty);try p.validate()
    }
    func testBrokenTransitionReferencesAndDurationsAreRejected() {
        var p=Project();p.clips=[Clip(filename:"a.mov",name:"A",duration:2),Clip(filename:"b.mov",name:"B",duration:2)]
        p.transitions=[ClipTransition(from:UUID(),to:p.clips[1].id,duration:0.5)];XCTAssertThrowsError(try p.validate())
        p.transitions=[ClipTransition(from:p.clips[0].id,to:p.clips[1].id,duration:.nan)];XCTAssertThrowsError(try p.validate())
    }
}
