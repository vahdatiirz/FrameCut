import Foundation
import CoreImage

public struct CubeLUT {
    public let dimension:Int
    public let data:Data
    public let domainMin:[Double]
    public let domainMax:[Double]
    public static func parse(_ text:String) throws -> CubeLUT {
        guard text.utf8.count<=32*1024*1024 else{throw EditError.invalidProject}
        var dimension:Int?
        var minimum:[Double]=[0,0,0],maximum:[Double]=[1,1,1],values:[Float]=[]
        for line in text.components(separatedBy:.newlines) {
            let line=line.components(separatedBy:"#")[0].trimmingCharacters(in:.whitespaces)
            if line.isEmpty{continue}
            let tokens=line.split(whereSeparator:{$0.isWhitespace}).map(String.init)
            switch tokens[0] {
            case "TITLE":continue
            case "LUT_3D_SIZE":
                guard dimension==nil,tokens.count==2,let d=Int(tokens[1]),(2...65).contains(d) else{throw EditError.invalidProject};dimension=d
            case "DOMAIN_MIN","DOMAIN_MAX":
                let parts=tokens.dropFirst().compactMap(Double.init)
                guard tokens.count==4,parts.count==3,parts.allSatisfy({$0.isFinite && abs($0)<=16}) else{throw EditError.invalidProject}
                if tokens[0]=="DOMAIN_MIN"{minimum=parts}else{maximum=parts}
            default:
                guard let d=dimension,tokens.count==3,values.count<d*d*d*4 else{throw EditError.invalidProject}
                let parts=tokens.compactMap(Float.init)
                guard parts.count==3,parts.allSatisfy({$0.isFinite && abs($0)<=16}) else{throw EditError.invalidProject}
                values.append(contentsOf:parts);values.append(1)
            }
        }
        guard let dimension,values.count==dimension*dimension*dimension*4,zip(minimum,maximum).allSatisfy({$0.1-$0.0>=0.000001}) else{throw EditError.invalidProject}
        let data=values.withUnsafeBytes{Data($0)}
        return CubeLUT(dimension:dimension,data:data,domainMin:minimum,domainMax:maximum)
    }
    public func apply(_ image:CIImage)->CIImage {
        let scale=zip(domainMin,domainMax).map{1/($0.1-$0.0)}
        let mapped=image.applyingFilter("CIColorMatrix",parameters:[
            "inputRVector":CIVector(x:scale[0],y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:scale[1],z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:scale[2],w:0),
            "inputBiasVector":CIVector(x:-domainMin[0]*scale[0],y:-domainMin[1]*scale[1],z:-domainMin[2]*scale[2],w:0)])
        return mapped.applyingFilter("CIColorCubeWithColorSpace",parameters:["inputCubeDimension":dimension,"inputCubeData":data,"inputColorSpace":CGColorSpace(name:CGColorSpace.sRGB)!])
    }
}
