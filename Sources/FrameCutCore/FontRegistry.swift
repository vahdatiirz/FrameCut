import Foundation
import CoreText

public enum FontRegistry {
    public static func register(_ url:URL) throws -> [String] {
        guard let descriptors=CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],!descriptors.isEmpty else{throw EditError.invalidProject}
        let names=Array(Set(descriptors.compactMap{CTFontDescriptorCopyAttribute($0,kCTFontNameAttribute) as? String})).sorted()
        guard !names.isEmpty else{throw EditError.invalidProject}
        var error:Unmanaged<CFError>?
        if !CTFontManagerRegisterFontsForURL(url as CFURL,.process,&error){
            guard let value=error?.takeRetainedValue(),CFErrorGetCode(value)==CTFontManagerError.alreadyRegistered.rawValue else{throw EditError.invalidProject}
        }
        return names
    }
}
