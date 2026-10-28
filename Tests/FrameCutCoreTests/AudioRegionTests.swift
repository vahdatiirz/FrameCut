import XCTest
@testable import FrameCutCore
final class AudioRegionTests:XCTestCase {
    func testIndependentAudioRegionsValidateAndRoundTrip() throws {
        var p=Project();p.clips=[Clip(filename:"a.mov",name:"A",duration:10)]
        var a=AudioRegion(filename:"voice.caf",name:"Voice",sourceDuration:3);a.timelineStart=2;a.sourceStart=0.5;a.sourceEnd=2.5;a.fadeIn=0.5;a.fadeOut=0.5
        var b=a;b.id=UUID();b.timelineStart=4;p.audioRegions=[a,b]
        try p.validate();let decoded=try JSONDecoder().decode(Project.self,from:JSONEncoder().encode(p));XCTAssertEqual(decoded,p)
        for bad in [Double.nan,-1,4] {var candidate=a;candidate.fadeIn=bad;XCTAssertThrowsError(try candidate.validate())}
        p.audioRegions![1].id=a.id;XCTAssertThrowsError(try p.validate())
    }
}
