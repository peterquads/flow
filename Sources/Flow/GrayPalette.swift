import SwiftUI

// Chrome colors (kept under `GrayPalette` so existing call sites still work)
// plus a deterministic name → task-color palette.
enum GrayPalette {
    static let cream = Color(red: 0xFA/255.0, green: 0xF8/255.0, blue: 0xF5/255.0)
    static let creamDeep = Color(red: 0xF5/255.0, green: 0xF1/255.0, blue: 0xEB/255.0)
    static let charcoal = Color(red: 0x1A/255.0, green: 0x1A/255.0, blue: 0x1A/255.0)
    static let textSecondary = Color(red: 0x43/255.0, green: 0x43/255.0, blue: 0x43/255.0)
    static let muted = Color(red: 0x9A/255.0, green: 0x9A/255.0, blue: 0x9A/255.0)
    static let hairline = Color(red: 0xBF/255.0, green: 0xBF/255.0, blue: 0xBF/255.0).opacity(0.4)

    // Muted, on-brand palette. Order matters — first entries get assigned to early hashes
    // but every name hashes deterministically so the same name always maps to the same color.
    private static let taskColors: [Color] = [
        Color(red: 0x4A/255.0, green: 0x6B/255.0, blue: 0x7C/255.0),  // slate
        Color(red: 0x6B/255.0, green: 0x8E/255.0, blue: 0x72/255.0),  // sage
        Color(red: 0xA8/255.0, green: 0x7B/255.0, blue: 0x6C/255.0),  // terra
        Color(red: 0xA8/255.0, green: 0x91/255.0, blue: 0x68/255.0),  // gold
        Color(red: 0x8B/255.0, green: 0x7B/255.0, blue: 0x9E/255.0),  // mauve
        Color(red: 0x9A/255.0, green: 0x5B/255.0, blue: 0x4D/255.0),  // brick
        Color(red: 0x5B/255.0, green: 0x6B/255.0, blue: 0x9E/255.0),  // indigo
        Color(red: 0x3D/255.0, green: 0x6B/255.0, blue: 0x6B/255.0),  // teal
        Color(red: 0x7C/255.0, green: 0x4A/255.0, blue: 0x6B/255.0),  // plum
        Color(red: 0x5C/255.0, green: 0x5C/255.0, blue: 0x4A/255.0),  // olive
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
