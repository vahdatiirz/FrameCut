import Foundation

public enum MotionCurve:String,Codable,CaseIterable {case linear,easeIn,easeOut,easeInOut,hold
    func map(_ t:Double)->Double {
        switch self {case .linear:return t;case .easeIn:return t*t;case .easeOut:return 1-(1-t)*(1-t);case .easeInOut:return t*t*(3-2*t);case .hold:return 0}
    }
}
public struct MotionKeyframe:Codable,Equatable,Identifiable {
    public var id=UUID()
    /// Normalized time in the clip's output interval.
    public var time:Double
    public var x:Double=0
    public var y:Double=0
    public var scale:Double=1
    public var rotation:Double=0
    public var opacity:Double=1
    public var curve:MotionCurve = .linear
    public init(time:Double){self.time=time}
}
public struct MotionTrack:Codable,Equatable {
    public var keyframes:[MotionKeyframe]
    public var domainStart:Double?
    public var domainEnd:Double?
    public init(keyframes:[MotionKeyframe]){self.keyframes=keyframes}
    public func validate() throws {
        guard !keyframes.isEmpty,keyframes.count<=512 else{throw EditError.invalidProject}
        let start=domainStart ?? 0,end=domainEnd ?? 1
        guard start.isFinite,end.isFinite,start>=0,end<=1,end>start else{throw EditError.invalidProject}
        var previous = -Double.infinity
        for k in keyframes {
            guard [k.time,k.x,k.y,k.scale,k.rotation,k.opacity].allSatisfy(\.isFinite),
                  (0...1).contains(k.time),k.time>previous,(-2...2).contains(k.x),(-2...2).contains(k.y),
                  (0.05...10).contains(k.scale),(-1080...1080).contains(k.rotation),(0...1).contains(k.opacity) else{throw EditError.invalidProject}
            previous=k.time
        }
    }
    public func sample(at time:Double)->MotionKeyframe {
        let mapped=(domainStart ?? 0)+max(0,min(1,time))*((domainEnd ?? 1)-(domainStart ?? 0))
        guard let first=keyframes.first else{return MotionKeyframe(time:mapped)}
        if mapped<=first.time{return first}
        for (a,b) in zip(keyframes,keyframes.dropFirst()) where mapped < b.time {
            let t=a.curve.map((mapped-a.time)/(b.time-a.time))
            var value=MotionKeyframe(time:time)
            value.x=a.x+(b.x-a.x)*t;value.y=a.y+(b.y-a.y)*t;value.scale=a.scale+(b.scale-a.scale)*t
            value.rotation=a.rotation+(b.rotation-a.rotation)*t;value.opacity=a.opacity+(b.opacity-a.opacity)*t
            return value
        }
        return keyframes.last ?? first
    }
    public func segment(from start:Double,to end:Double)->MotionTrack {
        var result=self
        let lower=domainStart ?? 0,length=(domainEnd ?? 1)-lower
        result.domainStart=lower+length*start;result.domainEnd=lower+length*end
        return result
    }
}
public enum LayerMask:String,Codable,CaseIterable {case none,circle,roundedRectangle}
public struct OverlayLayer:Codable,Equatable,Identifiable {
    public var id=UUID()
    public var clip:Clip
    public var timelineStart:Double=0
    public var centerX:Double=0.75
    public var centerY:Double=0.75
    public var width:Double=0.4
    public var height:Double=0.4
    public var opacity:Double=1
    public var mask:LayerMask = .none
    public var isStill:Bool?
    public init(clip:Clip){self.clip=clip}
    public func validate() throws {
        try clip.validate()
        guard [timelineStart,centerX,centerY,width,height,opacity].allSatisfy(\.isFinite),timelineStart>=0,
              (0...1).contains(centerX),(0...1).contains(centerY),(0.05...2).contains(width),(0.05...2).contains(height),(0...1).contains(opacity) else{throw EditError.invalidProject}
    }
}
