import XCTest
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import FrameCutCore
final class GenerationJobTests:XCTestCase {
    private func endpoint()->Data {
        let context=CGContext(data:nil,width:64,height:64,bitsPerComponent:8,bytesPerRow:256,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray:0.5,alpha:1));context.fill(CGRect(x:0,y:0,width:64,height:64))
        let data=NSMutableData();let dest=CGImageDestinationCreateWithData(data,UTType.png.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(dest,context.makeImage()!,nil);CGImageDestinationFinalize(dest);return data as Data
    }
    func testInterchangeCarriesOnlyEndpointImagesAndStablePairIdentities() throws {
        let from=UUID(),to=UUID(),image=endpoint()
        let job=GenerationJob(from:from,to:to,preset:.smokeDrift,prompt:"Smoke joins two scenes",width:64,height:64,numFrames:17,seed:42,transitionDuration:0.5,firstFrame:image,lastFrame:image)
        try job.validate()
        let data=try JSONEncoder().encode(job),json=try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
        XCTAssertEqual(json["fromClipID"] as? String,from.uuidString);XCTAssertEqual(json["toClipID"] as? String,to.uuidString)
        XCTAssertEqual(json["firstFramePNG"] as? String,image.base64EncodedString());XCTAssertNil(json["mediaRoot"])
        XCTAssertEqual(try JSONDecoder().decode(GenerationJob.self,from:data),job)
    }
    func testMalformedGenerationCannotLeaveTheEditorAsAValidJob() {
        let image=endpoint()
        var job=GenerationJob(from:UUID(),to:UUID(),preset:.custom,prompt:"Hello",width:64,height:64,numFrames:17,seed:42,transitionDuration:0.5,firstFrame:image,lastFrame:image)
        job.width=65;XCTAssertThrowsError(try job.validate())
        job.width=64;job.numFrames=18;XCTAssertThrowsError(try job.validate())
        job.numFrames=17;job.transitionDuration = .nan;XCTAssertThrowsError(try job.validate())
        job.transitionDuration=0.5;job.firstFramePNG=Data("bad".utf8);XCTAssertThrowsError(try job.validate())
    }
}
