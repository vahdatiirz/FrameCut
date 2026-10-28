import Foundation

public struct TextCue: Codable, Equatable, Identifiable {
    public var id = UUID()
    public var text: String
    public var start: Double
    public var end: Double
    public var style = ProjectStyle()
    public var words:[CaptionWord]?
    public init(text: String, start: Double, end: Double) {
        self.text = text; self.start = start; self.end = end
    }
    public mutating func shift(by seconds:Double) throws {
        guard seconds.isFinite else{throw EditError.invalidRange}
        var next=self;next.start+=seconds;next.end+=seconds
        next.words=words?.map{CaptionWord(text:$0.text,start:$0.start+seconds,end:$0.end+seconds)}
        try next.validate();self=next
    }
    public func validate() throws {
        guard start.isFinite, end.isFinite, start >= 0, end > start,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.utf8.count <= 16_384 else { throw EditError.invalidProject }
        try style.validate()
        if let words{
            guard words.count<=4096 else{throw EditError.invalidProject}
            for word in words{guard word.start.isFinite,word.end.isFinite,word.start>=start-0.001,word.end<=end+0.001,word.end>word.start,!word.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else{throw EditError.invalidProject}}
        }
    }
}
public struct CaptionWord:Codable,Equatable {
    public var text:String
    public var start:Double
    public var end:Double
    public init(text:String,start:Double,end:Double){self.text=text;self.start=start;self.end=end}
}

public enum SubtitleFile {
    public static func parse(_ text: String) throws -> [TextCue] {
        let normalized = text.replacingOccurrences(of: "\u{feff}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var cues: [TextCue] = []
        var block: [String] = []
        func consume() throws {
            guard !block.isEmpty else { return }
            let hasIndex = Int(block[0].trimmingCharacters(in: .whitespaces)) != nil
            let index = hasIndex ? 1 : 0
            guard block.count > index + 1 else { throw EditError.invalidProject }
            let times = block[index].components(separatedBy: "-->")
            guard times.count == 2 else { throw EditError.invalidProject }
            let start = try seconds(times[0]), end = try seconds(times[1])
            let cue = TextCue(text: block.dropFirst(index + 1).joined(separator: "\n"), start: start, end: end)
            try cue.validate(); cues.append(cue); block.removeAll()
        }
        for line in normalized.components(separatedBy: "\n") {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { try consume() }
            else { block.append(line) }
        }
        try consume()
        guard !cues.isEmpty else { throw EditError.invalidProject }
        return cues
    }
    private static func seconds(_ value: String) throws -> Double {
        let parts = value.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: ",")
            .components(separatedBy: CharacterSet(charactersIn: ":,"))
        guard parts.count == 4, parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let h = Int(parts[0]), let m = Int(parts[1]), let s = Int(parts[2]), let ms = Int(parts[3]),
              h <= 999, m < 60, s < 60, parts[3].count == 3 else { throw EditError.invalidProject }
        return Double(h * 3600 + m * 60 + s) + Double(ms) / 1000
    }
    public static func encode(_ cues: [TextCue]) throws -> String {
        try cues.forEach { try $0.validate() }
        return cues.enumerated().map { i, cue in
            "\(i + 1)\n\(stamp(cue.start)) --> \(stamp(cue.end))\n\(cue.text)\n"
        }.joined(separator: "\n")
    }
    private static func stamp(_ seconds: Double) -> String {
        let n = Int((seconds * 1000).rounded())
        return String(format: "%02d:%02d:%02d,%03d", n / 3_600_000, n / 60_000 % 60, n / 1000 % 60, n % 1000)
    }
}
