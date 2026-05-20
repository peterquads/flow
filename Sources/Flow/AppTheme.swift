import SwiftUI

// Tracks the system dark-mode preference and publishes a SwiftUI ColorScheme.
// We read UserDefaults directly because NSApp.effectiveAppearance is unreliable
// for `.accessory` (menu-bar) apps.
@MainActor
final class AppTheme: ObservableObject {
    @Published private(set) var colorScheme: ColorScheme

    init() {
        colorScheme = Self.detect()
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.colorScheme = Self.detect()
        }
    }

    static func detect() -> ColorScheme {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" ? .dark : .light
    }

    /// Matching NSAppearance for stamping onto an NSWindow / NSPopover.
    var nsAppearance: NSAppearance {
        NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua) ?? .current
    }
}
