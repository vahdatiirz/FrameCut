import Foundation

public enum TransitionStyle:String,Codable,CaseIterable {case dissolve,wipeLeft,wipeRight,slideLeft,slideRight}
public struct ClipTransition:Codable,Equatable,Identifiable {
    public var id=UUID()
    public var from:UUID
    public var to:UUID
    public var duration:Double
    public var style:TransitionStyle = .dissolve
    public init(from:UUID,to:UUID,duration:Double){self.from=from;self.to=to;self.duration=duration}
    public func validate() throws {guard from != to,duration.isFinite,(0.05...5).contains(duration) else{throw EditError.invalidProject}}
}
public struct ClipPlacement {
    public let start:Double
    public let duration:Double
    public let incomingDuration:Double
}
extension Project {
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
