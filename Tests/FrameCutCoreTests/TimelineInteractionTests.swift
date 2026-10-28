import XCTest
@testable import FrameCutCore
final class TimelineInteractionTests:XCTestCase {
    func testTrimmingARampPreservesTheRetainedSourceSpeedProfile() throws {
        var clip=Clip(filename:"a.mov",name:"A",duration:4)
        clip.speedCurve=SpeedCurve(points:[.init(position:0,speed:1),.init(position:1,speed:2)])
        let full=clip.duration,sourceHalf=4*(sqrt(2)-1)
        try clip.trim(start:sourceHalf,end:4)
        XCTAssertEqual(clip.duration,full/2,accuracy:0.00001)
        XCTAssertEqual(clip.speedCurve!.speedMultiplier(at:0),sqrt(2),accuracy:0.00001)
    }
    func testTrimHandlesMapOutputTimeAndCanRestoreCroppedSpeedCurve() throws {
        var clip=Clip(filename:"a.mov",name:"A",duration:4)
        clip.speedCurve=SpeedCurve(points:[.init(position:0,speed:1),.init(position:1,speed:2)])
        let original=clip
        try clip.trim(start:1,end:3)
        clip=try clip.applyingTimelineTrim(leadingOutputDelta:-100,trailingOutputDelta:100)
        XCTAssertEqual(clip.start,0);XCTAssertEqual(clip.end,4);XCTAssertEqual(clip.duration,original.duration,accuracy:0.000001)
        var fixed=Clip(filename:"b.mov",name:"B",duration:10);fixed.start=2;fixed.end=8;fixed.speed=2
        let trimmed=try fixed.applyingTimelineTrim(leadingOutputDelta:1,trailingOutputDelta:-0.5)
        XCTAssertEqual(trimmed.start,4);XCTAssertEqual(trimmed.end,7);XCTAssertEqual(trimmed.duration,1.5)
        let tiny=try fixed.applyingTimelineTrim(leadingOutputDelta:100)
        XCTAssertEqual(tiny.end-tiny.start,0.1,accuracy:0.000001);try tiny.validate()
    }
    func testDragReorderingPreservesClipIdentityAndUndoRestoresTransitions() throws {
        var p=Project();p.clips=(0..<3).map{Clip(filename:"\($0).mov",name:"\($0)",duration:2)}
        let ids=p.clips.map(\.id);p.transitions=[ClipTransition(from:ids[0],to:ids[1],duration:0.5)]
        let before=p;var history=History();history.record(before)
        try p.moveClip(ids[2],before:ids[0]);XCTAssertEqual(p.clips.map(\.id),[ids[2],ids[0],ids[1]])
        XCTAssertEqual(p.transitions?.count,1);XCTAssertEqual(history.undo(p),before)
        XCTAssertThrowsError(try p.moveClip(UUID(),before:ids[0]))
    }
    func testMovingCaptionsKeepsWordAlignmentAndRejectsNegativeTimeAtomically() throws {
        var cue=TextCue(text:"A line",start:1,end:3);cue.words=[CaptionWord(text:"A",start:1,end:1.5),CaptionWord(text:" line",start:1.6,end:3)]
        try cue.shift(by:2);XCTAssertEqual(cue.start,3);XCTAssertEqual(cue.words![1].end,5)
        let before=cue;XCTAssertThrowsError(try cue.shift(by:-4));XCTAssertEqual(cue,before)
    }
    func testOverlappingRegionsUseSeparateLanesAndTouchingEdgesReuseRows(){
        let a=UUID(),b=UUID(),c=UUID(),d=UUID()
        let layout=TimelineLaneLayout(regions:[(a,0,3),(b,1,1),(c,2,2),(d,4,1)])
        XCTAssertEqual(layout.count,2)
        XCTAssertEqual(layout.lanes[a],0);XCTAssertEqual(layout.lanes[b],1)
        XCTAssertEqual(layout.lanes[c],1);XCTAssertEqual(layout.lanes[d],0)
        let music=TimelineLaneLayout(regions:[(a,0,2),(b,2,1)],reservedLanes:1)
        XCTAssertEqual(music.count,2);XCTAssertEqual(music.lanes[a],1);XCTAssertEqual(music.lanes[b],1)
    }
}
