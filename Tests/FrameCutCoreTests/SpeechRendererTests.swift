import XCTest
import AVFoundation
@testable import FrameCutCore
final class SpeechRendererTests:XCTestCase {
    @MainActor func testLocalSpeechWritesAudibleAudioWithoutRecording() async throws {
        let url=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString+".caf")
        defer{try? FileManager.default.removeItem(at:url)}
        let voice=try XCTUnwrap(AVSpeechSynthesisVoice(language:"en-US"))
        try await SpeechRenderer.render("We are making a short film with music and captions.",voiceIdentifier:voice.identifier,rate:0.5,to:url)
        let file=try AVAudioFile(forReading:url)
        XCTAssertGreaterThan(file.length,10000);XCTAssertLessThan(Double(file.length)/file.processingFormat.sampleRate,15)
        let buffer=AVAudioPCMBuffer(pcmFormat:file.processingFormat,frameCapacity:AVAudioFrameCount(file.length))!;try file.read(into:buffer)
        let samples=try XCTUnwrap(buffer.floatChannelData?[0]);let energy=(0..<Int(buffer.frameLength)).reduce(0.0){$0+Double(samples[$1]*samples[$1])}
        XCTAssertGreaterThan(sqrt(energy/Double(buffer.frameLength)),0.005)
    }
}
