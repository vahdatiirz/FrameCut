import XCTest
@testable import FrameCutCore
final class CaptionTests:XCTestCase {
    func testSRTRoundTripPreservesMultilinePersianOverlapsAndMilliseconds() throws {
        let input="\u{feff}1\r\n00:00:00,125 --> 00:00:01,750\r\nسلام دنیا\r\nخط دوم\r\n\r\n2\r\n00:00:01,500 --> 00:00:03,002\r\nSecond caption\r\n"
        let cues=try SubtitleFile.parse(input)
        XCTAssertEqual(cues.count,2);XCTAssertEqual(cues[0].text,"سلام دنیا\nخط دوم")
        XCTAssertEqual(cues[0].start,0.125,accuracy:0.0001);XCTAssertEqual(cues[1].end,3.002,accuracy:0.0001)
        let decoded=try SubtitleFile.parse(SubtitleFile.encode(cues))
        XCTAssertEqual(decoded.map(\.text),cues.map(\.text));XCTAssertEqual(decoded.map(\.start),cues.map(\.start));XCTAssertEqual(decoded.map(\.end),cues.map(\.end))
    }
    func testMalformedOrBackwardsCueIsRejectedInsteadOfPartiallyImporting() {
        for s in ["1\n00:00:02,000 --> 00:00:01,000\nOops","1\n00:99:00,000 --> 00:00:03,000\nOops","not a subtitle"] {XCTAssertThrowsError(try SubtitleFile.parse(s))}
    }
    func testLegacyProjectAndCueValidationAndPersistence() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:root)}
        var p=Project();p.clips=[Clip(filename:"clip.mov",name:"Clip",duration:5)]
        var cue=TextCue(text:"A line",start:1,end:3);cue.style.boxed=true;p.captions=[cue]
        let store=try ProjectStore(root:root);try store.save(p);XCTAssertEqual(try store.load(p.id),p)
        p.captions![0].start = .nan;XCTAssertThrowsError(try p.validate())
        p.captions=[cue,cue];XCTAssertThrowsError(try p.validate())
    }
}
