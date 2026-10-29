import CoreImage

extension Look {
    /// Independent color recipes; no VN LUT or catalog asset is used.
    private var recipe:(r:Double,g:Double,b:Double,lift:Double,saturation:Double,contrast:Double)? {
        switch self {
        case .golden:return (1.12,1.03,0.83,0.01,1.08,1.05)
        case .arctic:return (0.86,1.02,1.14,0.015,0.9,1.04)
        case .cinema:return (1.03,0.99,0.94,0.025,0.75,1.2)
        case .tealAmber:return (1.08,1.07,0.92,-0.01,1.15,1.14)
        case .rose:return (1.12,0.94,1.02,0.025,0.88,0.98)
        case .desert:return (1.15,1.04,0.8,0.035,0.78,1.1)
        case .matte:return (0.97,0.98,1.01,0.07,0.8,0.85)
        case .bleach:return (1.04,1.04,1.04,-0.025,0.35,1.35)
        case .vivid:return (1.03,1.02,1.02,0,1.45,1.12)
        case .portrait:return (1.04,0.99,0.96,0.02,0.92,0.95)
        case .food:return (1.09,1.04,0.92,0.005,1.3,1.09)
        case .midnight:return (0.8,0.88,1.08,-0.025,0.72,1.18)
        case .coastal:return (0.92,1.08,1.12,0.025,1.12,0.98)
        case .autumn:return (1.15,0.96,0.76,0.005,1.12,1.16)
        case .coffee:return (0.99,0.87,0.73,0.02,0.65,1.15)
        case .dream:return (1.04,1.01,1.08,0.055,0.74,0.87)
        case .lilac:return (1.05,0.93,1.14,0.02,0.85,1.03)
        case .emerald:return (0.91,1.13,0.96,0,1.08,1.08)
        case .steel:return (0.91,0.99,1.07,-0.015,0.5,1.25)
        case .copper:return (1.17,0.91,0.79,0,0.95,1.13)
        default:return nil
        }
    }
    public var category:String {
        switch self {
        case .mono,.noir,.tonal:return "Monochrome"
        case .cinema,.matte,.bleach,.midnight,.steel,.coffee:return "Film"
        case .portrait,.rose,.dream,.lilac:return "Portrait"
        case .golden,.arctic,.desert,.coastal,.autumn,.emerald:return "Travel"
        case .food,.vivid,.copper:return "Food & vivid"
        default:return "Classic"
        }
    }
    public func render(_ input:CIImage)->CIImage {
        if let p=recipe {
            return input.applyingFilter("CIColorControls",parameters:["inputSaturation":p.saturation,"inputContrast":p.contrast])
                .applyingFilter("CIColorMatrix",parameters:["inputRVector":CIVector(x:p.r,y:0,z:0,w:0),"inputGVector":CIVector(x:0,y:p.g,z:0,w:0),"inputBVector":CIVector(x:0,y:0,z:p.b,w:0),"inputBiasVector":CIVector(x:p.lift,y:p.lift,z:p.lift,w:0)]).cropped(to:input.extent)
        }
        if let name=filter{return input.applyingFilter(name).cropped(to:input.extent)}
        return input
    }
}
