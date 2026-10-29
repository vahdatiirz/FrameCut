import XCTest
@testable import FrameCutCore
final class SampleProjectTests:XCTestCase {
    func testSampleContainsEditableMediaAndOverlayWithoutOverwritingExistingDraft() throws {
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer{try? FileManager.default.removeItem(at:folder)}
        let store=try ProjectStore(root:folder)
        var original=Project();original.name="Existing film";try store.save(original)
        let before=try Data(contentsOf:folder.appendingPathComponent(original.id.uuidString+".json"))
        let sample=try SampleProject.make(first:Clip(filename:"dawn.mov",name:"Dawn",duration:3),second:Clip(filename:"dusk.mov",name:"Dusk",duration:3))
        try store.save(sample)
        XCTAssertNotEqual(sample.id,original.id);XCTAssertEqual(sample.clips.count,2);XCTAssertEqual(sample.overlays?.count,1)
        XCTAssertEqual(sample.duration,6,accuracy:0.001)
        XCTAssertEqual(try store.load(sample.id),sample)
        XCTAssertEqual(try Data(contentsOf:folder.appendingPathComponent(original.id.uuidString+".json")),before)
    }
    func testInvalidSampleMediaCannotCreateAPersistableDraft() {
        let first=Clip(filename:"../bad.mov",name:"Bad",duration:3)
        XCTAssertThrowsError(try SampleProject.make(first:first,second:Clip(filename:"good.mov",name:"Good",duration:3)))
    }
}
