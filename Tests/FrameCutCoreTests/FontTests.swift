import XCTest
import CoreText
@testable import FrameCutCore
final class FontTests:XCTestCase {
    func testFontRegistrationIsIdempotentAndImportedStylePersists() throws {
        let native=CTFontCreateWithName("HelveticaNeue" as CFString,20,nil)
        let source=try XCTUnwrap(CTFontCopyAttribute(native,kCTFontURLAttribute) as? URL)
        let faces=try FontRegistry.register(source)
        XCTAssertFalse(faces.isEmpty);XCTAssertEqual(try FontRegistry.register(source),faces)
        var style=ProjectStyle();style.fontFilename="font.ttf";style.fontPostScriptName=faces[0]
        try style.validate();XCTAssertEqual(style.effectiveFontName,faces[0])
        XCTAssertEqual(try JSONDecoder().decode(ProjectStyle.self,from:JSONEncoder().encode(style)),style)
    }
    func testInvalidFontAndUnsafeReferenceFailBeforeRendering() throws {
        let path=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".ttf")
        defer{try? FileManager.default.removeItem(at:path)};try Data("invalid".utf8).write(to:path)
        XCTAssertThrowsError(try FontRegistry.register(path))
        var style=ProjectStyle();style.fontFilename="../font.ttf";style.fontPostScriptName="Custom";XCTAssertThrowsError(try style.validate())
    }
}
