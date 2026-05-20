import SwiftUI
import AppKit

// Adaptive palette. Each token has a light and dark variant; AppKit resolves
// the right one based on the host view's effective appearance — driven by
// AppTheme + `window.appearance` at the AppDelegate layer.

enum GrayPalette {
    // MARK: - Surfaces

    /// Page background. Warm off-white in light, warm near-black in dark.
    static let cream = adaptive(
        light: NSColor(red: 0xFA/255.0, green: 0xF8/255.0, blue: 0xF5/255.0, alpha: 1),
        dark:  NSColor(red: 0x18/255.0, green: 0x17/255.0, blue: 0x15/255.0, alpha: 1)
    )

    /// Sunken / inset surface (input field, expanded card highlight).
    static let creamDeep = adaptive(
        light: NSColor(red: 0xF5/255.0, green: 0xF1/255.0, blue: 0xEB/255.0, alpha: 1),
        dark:  NSColor(red: 0x24/255.0, green: 0x22/255.0, blue: 0x1F/255.0, alpha: 1)
    )

    /// Raised card surface. Translucent so the window blur shows through.
    static let cardSurface = adaptive(
        light: NSColor.white.withAlphaComponent(0.62),
        dark:  NSColor(red: 0x22/255.0, green: 0x20/255.0, blue: 0x1D/255.0, alpha: 0.55)
    )

    // MARK: - Text

    /// Primary text and emphasis. Near-black in light, warm off-white in dark.
    static let charcoal = adaptive(
        light: NSColor(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1A/255.0, alpha: 1),
        dark:  NSColor(red: 0xF5/255.0, green: 0xF2/255.0, blue: 0xEC/255.0, alpha: 1)
    )

    static let textSecondary = adaptive(
        light: NSColor(red: 0x43/255.0, green: 0x43/255.0, blue: 0x43/255.0, alpha: 1),
        dark:  NSColor(red: 0xBD/255.0, green: 0xBA/255.0, blue: 0xB5/255.0, alpha: 1)
    )

    static let muted = adaptive(
        light: NSColor(red: 0x9A/255.0, green: 0x9A/255.0, blue: 0x9A/255.0, alpha: 1),
        dark:  NSColor(red: 0x8B/255.0, green: 0x88/255.0, blue: 0x84/255.0, alpha: 1)
    )

    // MARK: - Borders

    static let hairline = adaptive(
        light: NSColor(red: 0xBF/255.0, green: 0xBF/255.0, blue: 0xBF/255.0, alpha: 0.4),
        dark:  NSColor.white.withAlphaComponent(0.12)
    )

    // MARK: - Adaptive helper

    private static func adaptive(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let best = appearance.bestMatch(from: [.aqua, .darkAqua, .vibrantLight, .vibrantDark])
            switch best {
            case .darkAqua, .vibrantDark: return dark
            default: return light
            }
        })
    }

    // MARK: - Task colors (lighter tones in dark mode for contrast on dark BG)

    private static let taskColors: [Color] = [
        adaptive(light: NSColor(red: 0x4A/255, green: 0x6B/255, blue: 0x7C/255, alpha: 1),
                 dark:  NSColor(red: 0x7F/255, green: 0xA8/255, blue: 0xBC/255, alpha: 1)),  // slate
        adaptive(light: NSColor(red: 0x6B/255, green: 0x8E/255, blue: 0x72/255, alpha: 1),
                 dark:  NSColor(red: 0x8F/255, green: 0xBE/255, blue: 0x96/255, alpha: 1)),  // sage
        adaptive(light: NSColor(red: 0xA8/255, green: 0x7B/255, blue: 0x6C/255, alpha: 1),
                 dark:  NSColor(red: 0xD4/255, green: 0xA0/255, blue: 0x8C/255, alpha: 1)),  // terra
        adaptive(light: NSColor(red: 0xA8/255, green: 0x91/255, blue: 0x68/255, alpha: 1),
                 dark:  NSColor(red: 0xD4/255, green: 0xBD/255, blue: 0x8E/255, alpha: 1)),  // gold
        adaptive(light: NSColor(red: 0x8B/255, green: 0x7B/255, blue: 0x9E/255, alpha: 1),
                 dark:  NSColor(red: 0xB1/255, green: 0xA3/255, blue: 0xCA/255, alpha: 1)),  // mauve
        adaptive(light: NSColor(red: 0x9A/255, green: 0x5B/255, blue: 0x4D/255, alpha: 1),
                 dark:  NSColor(red: 0xCC/255, green: 0x82/255, blue: 0x72/255, alpha: 1)),  // brick
        adaptive(light: NSColor(red: 0x5B/255, green: 0x6B/255, blue: 0x9E/255, alpha: 1),
                 dark:  NSColor(red: 0x82/255, green: 0x96/255, blue: 0xCC/255, alpha: 1)),  // indigo
        adaptive(light: NSColor(red: 0x3D/255, green: 0x6B/255, blue: 0x6B/255, alpha: 1),
                 dark:  NSColor(red: 0x6A/255, green: 0xA3/255, blue: 0xA3/255, alpha: 1)),  // teal
        adaptive(light: NSColor(red: 0x7C/255, green: 0x4A/255, blue: 0x6B/255, alpha: 1),
                 dark:  NSColor(red: 0xA8/255, green: 0x71/255, blue: 0x98/255, alpha: 1)),  // plum
        adaptive(light: NSColor(red: 0x5C/255, green: 0x5C/255, blue: 0x4A/255, alpha: 1),
                 dark:  NSColor(red: 0x8C/255, green: 0x8C/255, blue: 0x75/255, alpha: 1)),  // olive
    ]

    static func keyForName(_ name: String) -> Int {
        let normalized = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var h: UInt64 = 14695981039346656037
        for byte in normalized.utf8 {
            h ^= UInt64(byte)
            h = h &* 1099511628211
        }
        return Int(h % UInt64(taskColors.count))
    }

    static func color(forKey key: Int) -> Color {
        let i = ((key % taskColors.count) + taskColors.count) % taskColors.count
        return taskColors[i]
    }

    static func color(forName name: String) -> Color {
        color(forKey: keyForName(name))
    }
}
