import Foundation

/// Original motion recipes, using the same keyframes as manually authored animations.
public enum MotionPreset:String,CaseIterable,Identifiable {
    case zoomIn,zoomOut,slideLeft,slideRight,slideUp,slideDown,fadeIn,fadeOut,turnLeft,turnRight,pulse,bounce,shake,swing,spin,driftUp,driftDown,popIn,popOut
    public var id:String{rawValue}
    public var label:String {
        switch self {
        case .zoomIn:return "Zoom in";case .zoomOut:return "Zoom out"
        case .slideLeft:return "Slide left";case .slideRight:return "Slide right"
        case .slideUp:return "Slide up";case .slideDown:return "Slide down"
        case .fadeIn:return "Fade in";case .fadeOut:return "Fade out"
        case .turnLeft:return "Turn left";case .turnRight:return "Turn right"
        case .pulse:return "Pulse";case .bounce:return "Bounce";case .shake:return "Shake"
        case .swing:return "Swing";case .spin:return "Spin";case .driftUp:return "Drift up"
        case .driftDown:return "Drift down";case .popIn:return "Pop in";case .popOut:return "Pop out"
        }
    }
    public var track:MotionTrack {
        func key(_ t:Double,x:Double=0,y:Double=0,scale:Double=1,rotation:Double=0,opacity:Double=1)->MotionKeyframe{
            var k=MotionKeyframe(time:t);k.x=x;k.y=y;k.scale=scale;k.rotation=rotation;k.opacity=opacity;k.curve = .easeInOut;return k
        }
        let a=key(0),b=key(1)
        let frames:[MotionKeyframe]
        switch self {
        case .zoomIn:frames=[a,key(1,scale:1.3)]
        case .zoomOut:frames=[key(0,scale:1.3),b]
        case .slideLeft:frames=[a,key(1,x:-0.4)]
        case .slideRight:frames=[a,key(1,x:0.4)]
        case .slideUp:frames=[a,key(1,y:-0.4)]
        case .slideDown:frames=[a,key(1,y:0.4)]
        case .fadeIn:frames=[key(0,opacity:0),key(0.3),b]
        case .fadeOut:frames=[a,key(0.7),key(1,opacity:0)]
        case .turnLeft:frames=[a,key(1,scale:1.2,rotation:-12)]
        case .turnRight:frames=[a,key(1,scale:1.2,rotation:12)]
        case .pulse:frames=[a,key(0.25,scale:1.15),key(0.5),key(0.75,scale:1.15),b]
        case .bounce:frames=[a,key(0.25,y:-0.15),key(0.5),key(0.75,y:-0.07),b]
        case .shake:frames=[a,key(0.2,x:-0.04),key(0.4,x:0.04),key(0.6,x:-0.04),key(0.8,x:0.04),b]
        case .swing:frames=[key(0,rotation:-8),key(0.5,rotation:8),key(1,rotation:-8)]
        case .spin:frames=[a,key(1,rotation:360)]
        case .driftUp:frames=[key(0,y:0.08,scale:1.2),key(1,y:-0.08,scale:1.2)]
        case .driftDown:frames=[key(0,y:-0.08,scale:1.2),key(1,y:0.08,scale:1.2)]
        case .popIn:frames=[key(0,scale:0.1,opacity:0),key(0.2,scale:1.12),key(0.35),b]
        case .popOut:frames=[a,key(0.65),key(0.8,scale:1.12),key(1,scale:0.1,opacity:0)]
        }
        return MotionTrack(keyframes:frames)
    }
}
