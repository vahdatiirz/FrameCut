import XCTest
@testable import FrameCutCore
final class GeneratedBridgeTests:XCTestCase {
    private func project()->Project {var p=Project();p.clips=[Clip(filename:"a.mov",name:"A",duration:2),Clip(filename:"b.mov",name:"B",duration:2)];return p}
    func testAttachFitsExistingOverlapAndLeavesTimedTracksUnchanged() throws {
        var p=project();let a=p.clips[0].id,b=p.clips[1].id
        try p.setTransition(from:a,to:b,style:.circle,duration:0.75)
        let oldDuration=p.duration,starts=p.placements.map(\.start),clips=p.clips
        let asset=GeneratedBridgeAsset(filename:"bridge.mp4",sourceDuration:2,jobID:UUID())
        try p.attachGeneratedBridge(from:a,to:b,asset:asset,duration:0.75)
        XCTAssertEqual(p.transitions?.first?.generatedBridge,asset)
        XCTAssertEqual(p.duration,oldDuration);XCTAssertEqual(p.placements.map(\.start),starts);XCTAssertEqual(p.clips,clips)
        XCTAssertEqual(try JSONDecoder().decode(Project.self,from:JSONEncoder().encode(p)),p)
        try p.setTransition(from:a,to:b,style:.wipeLeft,duration:0.75)
        XCTAssertNil(p.transitions?.first?.generatedBridge,"Choosing a native transition must remove the generated video")
    }
    func testInvalidAttachmentDoesNotMutateProject() throws {
        var p=project();let before=p
        for file in ["../bridge.mp4","/tmp/bridge.mp4",""] {
            XCTAssertThrowsError(try p.attachGeneratedBridge(from:p.clips[0].id,to:p.clips[1].id,asset:GeneratedBridgeAsset(filename:file,sourceDuration:1,jobID:UUID()),duration:0.5))
            XCTAssertEqual(p,before)
        }
        XCTAssertThrowsError(try p.attachGeneratedBridge(from:p.clips[1].id,to:p.clips[0].id,asset:GeneratedBridgeAsset(filename:"bridge.mp4",sourceDuration:1,jobID:UUID()),duration:0.5))
        XCTAssertEqual(p,before)
    }
}
