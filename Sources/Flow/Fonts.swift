import SwiftUI
import CoreText
import AppKit

enum Fonts {
    static func registerBundled() {
        let bundleResources = Bundle.main.resourceURL
        let fontsDir = bundleResources?.appendingPathComponent("Fonts", isDirectory: true)
        guard let dir = fontsDir,
              let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return
        }
        for url in files where url.pathExtension.lowercased() == "otf" || url.pathExtension.lowercased() == "ttf" {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }
}

extension Font {
    static func emilio(_ weight: EmilioWeight = .regular, size: CGFloat) -> Font {
        .custom(weight.familyName, size: size)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

enum EmilioWeight {
    case regular, semibold, bold
    var familyName: String {
        switch self {
        case .regular:  return "EmilioTest"
        case .semibold: return "EmilioTest-Semibold"
        case .bold:     return "EmilioTest-Bold"
        }
    }
}
