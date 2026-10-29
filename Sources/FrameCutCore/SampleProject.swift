import Foundation

public enum SampleProject {
    /// Creates a separate editable example; saving it never reuses another project's identity.
    public static func make(first:Clip,second:Clip) throws -> Project {
        try first.validate();try second.validate()
        var p=Project();p.name="Sample film · فیلم نمونه";p.clips=[first,second];p.title="Make it yours"
        var style=ProjectStyle();style.resolution = .hd720;style.fps=30;p.style=style
        var overlayClip=second;overlayClip.id=UUID()
        var layer=OverlayLayer(clip:overlayClip);layer.timelineStart=0.5;layer.width=0.3;layer.height=0.3;layer.mask = .circle
        p.overlays=[layer];try p.validate();return p
    }
}
