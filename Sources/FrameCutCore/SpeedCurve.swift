import Foundation

public struct SpeedPoint:Codable,Equatable,Identifiable {
    public var id=UUID()
    public var position:Double
    public var speed:Double
    public init(position:Double,speed:Double){self.position=position;self.speed=speed}
}
public struct SpeedCurve:Codable,Equatable {
    public var points:[SpeedPoint]
    public var domainStart:Double?
    public var domainEnd:Double?
    public init(points:[SpeedPoint]){self.points=points}
    public func validate() throws {
        guard (2...128).contains(points.count),points.first?.position==0,points.last?.position==1 else{throw EditError.invalidSpeed}
        var previous = -Double.infinity
        for p in points {
            guard p.position.isFinite,p.speed.isFinite,(0...1).contains(p.position),p.position>previous,(0.1...100).contains(p.speed) else{throw EditError.invalidSpeed}
            previous=p.position
        }
        let lower=domainStart ?? 0,upper=domainEnd ?? 1
        guard lower.isFinite,upper.isFinite,lower>=0,upper<=1,upper>lower else{throw EditError.invalidSpeed}
    }
    private func value(at x:Double)->Double {
        for (a,b) in zip(points,points.dropFirst()) where x<=b.position {
            let t=max(0,min(1,(x-a.position)/(b.position-a.position)))
            return a.speed+(b.speed-a.speed)*t
        }
        return points.last?.speed ?? 1
    }
    private func rawIntegral(from start:Double,to end:Double)->Double {
        if end<start{return -rawIntegral(from:end,to:start)}
        var result:Double=0
        if start<0{result += max(0,min(end,0)-start)/value(at:0)}
        if end>1{result += max(0,end-max(start,1))/value(at:1)}
        for (a,b) in zip(points,points.dropFirst()){
            let low=max(start,a.position),high=min(end,b.position)
            guard high>low else{continue}
            let v0=value(at:low),v1=value(at:high)
            result += abs(v1-v0)<0.00000001 ? (high-low)/v0 : (high-low)*log(v1/v0)/(v1-v0)
        }
        return result
    }
    public func speedMultiplier(at fraction:Double)->Double {
        value(at:max(0,min(1,(domainStart ?? 0)+fraction*((domainEnd ?? 1)-(domainStart ?? 0)))))
    }
    public func sourceFraction(forElapsedOutput seconds:Double,sourceDuration:Double,baseSpeed:Double,bounds:ClosedRange<Double>)->Double {
        let origin=domainStart ?? 0,length=(domainEnd ?? 1)-origin
        let target=seconds*baseSpeed/sourceDuration
        var low=bounds.lowerBound,high=bounds.upperBound
        for _ in 0..<50{let mid=(low+high)/2;let value=rawIntegral(from:origin,to:origin+mid*length)/length;if value<target{low=mid}else{high=mid}}
        return (low+high)/2
    }
    public func resized(from start:Double,to end:Double)->SpeedCurve {
        let origin=domainStart ?? 0,length=(domainEnd ?? 1)-origin
        let low=origin+start*length,high=origin+end*length
        var result=self
        if low>=0 && high<=1{result.domainStart=low;result.domainEnd=high;return result}
        let baseLow=min(0,low),baseHigh=max(1,high),span=baseHigh-baseLow
        let positions=Array(Set(points.map(\.position)+[baseLow,baseHigh])).sorted()
        var expanded=positions.map{SpeedPoint(position:($0-baseLow)/span,speed:value(at:max(0,min(1,$0))))}
        var i=1
        while i<expanded.count-1{
            let a=expanded[i-1],b=expanded[i],c=expanded[i+1]
            let lhs=(b.speed-a.speed)*(c.position-b.position),rhs=(c.speed-b.speed)*(b.position-a.position)
            if abs(lhs-rhs)<1e-10{expanded.remove(at:i)}else{i+=1}
        }
        result.points=expanded;result.domainStart=(low-baseLow)/span;result.domainEnd=(high-baseLow)/span;return result
    }
    /// Output duration per source second, integrated exactly for piecewise-linear source-speed curves.
    public func integral(to fraction:Double=1)->Double {
        let lower=domainStart ?? 0,length=(domainEnd ?? 1)-lower
        return rawIntegral(from:lower,to:lower+length*max(0,min(1,fraction)))/length
    }
    public func sourceFraction(forOutputFraction fraction:Double)->Double {
        let target=integral()*fraction
        var low:Double=0,high:Double=1
        for _ in 0..<50{let middle=(low+high)/2;if integral(to:middle)<target{low=middle}else{high=middle}}
        return (low+high)/2
    }
    public func segment(from start:Double,to end:Double)->SpeedCurve {
        var result=self;let low=domainStart ?? 0,length=(domainEnd ?? 1)-low
        result.domainStart=low+length*start;result.domainEnd=low+length*end;return result
    }
    /// Fine render segments preserve exact total timing. Within each segment the rate is constant.
    public func renderSegments(sourceDuration:Double,baseSpeed:Double)->[SpeedSegment] {
        let count=min(512,max(24,Int(ceil(sourceDuration*30))))
        let lower=domainStart ?? 0,length=(domainEnd ?? 1)-lower
        var positions=(0...count).map{Double($0)/Double(count)}
        positions += points.map{($0.position-lower)/length}.filter{$0>0 && $0<1}
        positions=Array(Set(positions)).sorted()
        return zip(positions,positions.dropFirst()).map{a,b in
            let start=integral(to:a)*sourceDuration/baseSpeed,end=integral(to:b)*sourceDuration/baseSpeed
            return SpeedSegment(sourceStart:a*sourceDuration,sourceDuration:(b-a)*sourceDuration,outputStart:start,outputDuration:end-start)
        }
    }
    public static let presets:[(String,SpeedCurve)]=[
        ("Montage",.init(points:[.init(position:0,speed:1),.init(position:0.3,speed:3),.init(position:0.6,speed:0.5),.init(position:1,speed:1)])),
        ("Hero Time",.init(points:[.init(position:0,speed:2),.init(position:0.35,speed:0.25),.init(position:0.65,speed:0.25),.init(position:1,speed:2)])),
        ("Bullet Time",.init(points:[.init(position:0,speed:1),.init(position:0.45,speed:1),.init(position:0.5,speed:0.1),.init(position:0.55,speed:1),.init(position:1,speed:1)])),
        ("Jump Cut",.init(points:[.init(position:0,speed:1),.init(position:0.3,speed:1),.init(position:0.4,speed:8),.init(position:0.6,speed:8),.init(position:0.7,speed:1),.init(position:1,speed:1)])),
        ("Fast In",.init(points:[.init(position:0,speed:4),.init(position:1,speed:0.5)])),
        ("Fast Out",.init(points:[.init(position:0,speed:0.5),.init(position:1,speed:4)]))]
}
public struct SpeedSegment {
    public var sourceStart:Double
    public var sourceDuration:Double
    public var outputStart:Double
    public var outputDuration:Double
}
