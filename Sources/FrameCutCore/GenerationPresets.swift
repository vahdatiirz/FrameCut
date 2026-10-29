import Foundation
extension GenerationPreset {
    public var title:String {
        switch self {case .orbit:return "3D orbit";case .custom:return "Custom";default:return rawValue.replacingOccurrences(of:"([a-z])([A-Z])",with:"$1 $2",options:.regularExpression).capitalized}
    }
    public var suggestedPrompt:String {
        let action:String
        switch self {
        case .custom:action="Create a smooth visual connection between the supplied beginning and ending scenes."
        case .zoomIn:action="The camera moves closer into the scene, revealing the ending scene through a forward zoom."
        case .zoomOut:action="The camera pulls away from the beginning scene and reveals the ending scene in a smooth wide view."
        case .push:action="A steady forward dolly carries the viewer from the beginning into the ending scene, with coherent perspective."
        case .pull:action="A steady backward dolly reveals the ending scene behind the beginning scene, with coherent perspective."
        case .flyThrough:action="The camera flies smoothly through a natural opening and emerges into the ending scene."
        case .orbit:action="The camera travels in a gentle forty-five degree arc around the main subject and reveals the ending scene with plausible parallax."
        case .smartMove:action="Keep the main subject centered as the camera moves smoothly into the ending composition."
        case .styleMorph:action="The beginning scene transforms gradually into the ending scene, with fluid shapes and coherent visual style."
        case .moneyVeil:action="Falling paper slips briefly cover the view and then clear, revealing the ending scene."
        case .slideLeft:action="The camera travels left in one continuous lateral move and arrives at the ending scene."
        case .slideRight:action="The camera travels right in one continuous lateral move and arrives at the ending scene."
        case .confetti:action="Colorful small confetti particles drift across the view and clear to reveal the ending scene."
        case .goldConfetti:action="Warm metallic gold confetti briefly fills the view and clears to reveal the ending scene."
        case .rise:action="The camera rises gently from the beginning scene and reveals the ending composition."
        case .dive:action="The camera descends smoothly from the beginning scene into the ending composition."
        case .smokeDrift:action="Soft volumetric smoke drifts across the view, briefly obscures the scene, then clears to reveal the ending scene."
        }
        return action+" One continuous shot. Preserve the supplied endpoint compositions. Smooth coherent motion, stable lighting, no abrupt cut, no added text or watermark."
    }
}
