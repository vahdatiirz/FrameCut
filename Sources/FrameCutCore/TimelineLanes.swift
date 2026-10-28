import Foundation

/// Places overlapping regions on separate visual rows. Touching edges share a row.
public struct TimelineLaneLayout {
    public let lanes:[UUID:Int]
    public let count:Int
    public init(regions:[(id:UUID,start:Double,duration:Double)],reservedLanes:Int=0){
        var ends=[Double](repeating:.infinity,count:max(0,reservedLanes))
        var assignments:[UUID:Int]=[:]
        let ordered=regions.enumerated().sorted{a,b in a.element.start == b.element.start ? a.offset<b.offset : a.element.start<b.element.start}
        for (_,region) in ordered {
            let lane=ends.firstIndex(where:{$0<=region.start+0.000001}) ?? ends.count
            if lane==ends.count{ends.append(region.start+region.duration)}else{ends[lane]=region.start+region.duration}
            assignments[region.id]=lane
        }
        lanes=assignments;count=max(1,ends.count)
    }
}
