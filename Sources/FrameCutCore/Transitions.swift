import Foundation

public enum TransitionStyle:String,Codable,CaseIterable {
    case smokeDrift,confetti,goldConfetti
    case dissolve,wipeLeft,wipeRight,slideLeft,slideRight
    case fadeBlack,fadeWhite,flash,blur,pixelate,zoomIn,zoomOut,rotate
    case wipeUp,wipeDown,slideUp,slideDown,coverLeft,coverRight
    case circle,diamond,box,verticalOpen,horizontalOpen,blinds,checkerboard,diagonal,wave,ink
    public var category:String {
        switch self {
        case .smokeDrift,.confetti,.goldConfetti:return "Effects"
        case .circle,.diamond,.box,.verticalOpen,.horizontalOpen,.blinds,.checkerboard,.diagonal,.wave,.ink:return "Matte"
        case .slideLeft,.slideRight,.slideUp,.slideDown,.coverLeft,.coverRight,.zoomIn,.zoomOut,.rotate:return "Motion"
        default:return "Basic"
        }
    }
    public var title:String {
        switch self {
        case .slideLeft:return "Push left"
        case .slideRight:return "Push right"
        case .slideUp:return "Push up"
        case .slideDown:return "Push down"
        default:return rawValue.replacingOccurrences(of:"([a-z])([A-Z])",with:"$1 $2",options:.regularExpression).capitalized
        }
    }
}
public struct ClipTransition:Codable,Equatable,Identifiable {
    public var id=UUID()
    public var from:UUID
    public var to:UUID
    public var duration:Double
    public var style:TransitionStyle = .dissolve
    public var generatedBridge:GeneratedBridgeAsset?
    public init(from:UUID,to:UUID,duration:Double){self.from=from;self.to=to;self.duration=duration}
    public func validate() throws {guard from != to,duration.isFinite,(0.05...5).contains(duration) else{throw EditError.invalidProject};try generatedBridge?.validate()}
}
public struct ClipPlacement {
    public let start:Double
    public let duration:Double
    public let incomingDuration:Double
}
extension Project {
    /// Validate a candidate before committing so failed edits leave the draft untouched.
    public mutating func setTransition(from:UUID,to:UUID,style:TransitionStyle?,duration:Double,applyToAll:Bool=false) throws {
        let pairs=Array(zip(clips,clips.dropFirst()))
        guard pairs.contains(where:{$0.0.id==from && $0.1.id==to}) else{throw EditError.invalidProject}
        var candidate=self
        let targets=applyToAll ? pairs : pairs.filter{$0.0.id==from && $0.1.id==to}
        for (a,b) in targets {
            let existing=candidate.transitions?.first{$0.from==a.id && $0.to==b.id}
            candidate.transitions=candidate.transitions?.filter{$0.to != b.id} ?? []
            if let style {
                var edge=existing ?? ClipTransition(from:a.id,to:b.id,duration:duration)
                edge.duration=duration;edge.style=style;edge.generatedBridge=nil;try edge.validate()
                candidate.transitions?.append(edge)
            }
        }
        try candidate.validate();self=candidate
    }

    public var placements:[ClipPlacement] {
        var result:[ClipPlacement]=[],cursor:Double=0
        let incoming=(transitions ?? []).reduce(into:[UUID:ClipTransition]()){$0[$1.to]=$1}
        for (i,clip) in clips.enumerated(){
            var overlap:Double=0
            if i>0,let transition=incoming[clip.id],transition.from==clips[i-1].id{
                overlap=min(transition.duration,clips[i-1].duration/2,clip.duration/2)
            }
            let start=cursor-overlap
            result.append(ClipPlacement(start:start,duration:clip.duration,incomingDuration:overlap));cursor=start+clip.duration
        }
        return result
    }
    public func clipStart(at index:Int)->Double {let items=placements;return items.indices.contains(index) ? items[index].start : 0}
    public mutating func moveClip(_ id:UUID,before target:UUID) throws {
        guard let source=clips.firstIndex(where:{$0.id==id}),clips.contains(where:{$0.id==target}) else{throw EditError.invalidProject}
        guard id != target else{return}
        let clip=clips.remove(at:source)
        guard let destination=clips.firstIndex(where:{$0.id==target}) else{throw EditError.invalidProject}
        clips.insert(clip,at:destination);removeInactiveTransitions();try validate()
    }
    public mutating func removeInactiveTransitions(){
        let pairs=Set(zip(clips,clips.dropFirst()).map{$0.id.uuidString+$1.id.uuidString})
        transitions=transitions?.filter{pairs.contains($0.from.uuidString+$0.to.uuidString)}
    }
}
