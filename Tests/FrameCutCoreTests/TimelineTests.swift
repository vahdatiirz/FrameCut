import XCTest
@testable import FrameCutCore
final class TimelineTests: XCTestCase {
    func testTrimPreservesSourceAndUpdatesDuration() throws {
        var c = Clip(filename: "a.mov", name: "A", duration: 10)
        try c.trim(start: 2, end: 8)
        XCTAssertEqual(c.duration, 6); XCTAssertEqual(c.sourceDuration, 10)
    }
    func testSplitConvertsOutputTimeToSourceTimeAtDoubleSpeed() throws {
        var c = Clip(filename: "a.mov", name: "A", duration: 10); c.start = 2; c.end = 8; c.speed = 2
        let (a,b) = try c.split(at: 1)
        XCTAssertEqual(a.end, 4); XCTAssertEqual(b.start, 4); XCTAssertEqual(a.duration + b.duration, 3); XCTAssertNotEqual(a.id,b.id)
    }
    func testInvalidRangesAndSpeedAreRejected() {
        var c = Clip(filename: "a.mov", name: "A", duration: 10)
        XCTAssertThrowsError(try c.trim(start: -1, end: 5)); XCTAssertThrowsError(try c.split(at: 0))
        c.speed = 0; XCTAssertThrowsError(try c.validate())
        c.speed = .nan; XCTAssertThrowsError(try c.validate())
    }
    func testPersistenceRoundTripAndPathTraversalRejection() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try ProjectStore(root: root)
        var p = Project(); p.clips = [Clip(filename: "a.mov", name: "A", duration: 10)]; p.title = "سلام"
        try store.save(p); XCTAssertEqual(try store.load(p.id),p); XCTAssertEqual(try store.all().count,1)
        p.clips[0].filename = "../outside.mov"; XCTAssertThrowsError(try store.save(p))
    }
    func testUndoRedoAndBranchingDiscardFuture() {
        var h = History(); let first = Project(); var second = first; second.title = "New"
        h.record(first); XCTAssertEqual(h.undo(second), first); XCTAssertEqual(h.redo(first), second)
        _ = h.undo(second); h.record(first); XCTAssertFalse(h.canRedo)
    }
}
