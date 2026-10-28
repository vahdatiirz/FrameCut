import Foundation

public struct AudioRegion:Codable,Equatable,Identifiable {
    public var id=UUID()
    public var filename:String
    public var name:String
    public var sourceDuration:Double
    public var sourceStart:Double=0
    public var sourceEnd:Double
    public var timelineStart:Double=0
    public var volume:Double=1
    public var fadeIn:Double=0
    public var fadeOut:Double=0
    public var duration:Double {sourceEnd-sourceStart}
    public init(filename:String,name:String,sourceDuration:Double) {
        self.filename=filename;self.name=name;self.sourceDuration=sourceDuration;self.sourceEnd=sourceDuration
    }
    public func validate() throws {
        guard [sourceDuration,sourceStart,sourceEnd,timelineStart,volume,fadeIn,fadeOut].allSatisfy(\.isFinite),
              filename==URL(fileURLWithPath:filename).lastPathComponent,!filename.isEmpty,
              sourceStart>=0,sourceEnd<=sourceDuration+0.001,duration>=0.05,timelineStart>=0,
              (0...1).contains(volume),fadeIn>=0,fadeOut>=0,fadeIn+fadeOut<=duration else{throw EditError.invalidProject}
    }
}
