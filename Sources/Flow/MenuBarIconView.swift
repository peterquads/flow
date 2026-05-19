import SwiftUI
import AppKit

@MainActor
enum MenuBarIcon {
    static func render(running: Task?, elapsed: String) -> NSImage {
        let view = MenuBarIconView(running: running, elapsed: elapsed)
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
        renderer.isOpaque = false
        guard let nsImage = renderer.nsImage else { return placeholder() }
        nsImage.isTemplate = true
        return nsImage
    }

    private static func placeholder() -> NSImage {
        let cfg = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        return NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Flow")?
            .withSymbolConfiguration(cfg) ?? NSImage(size: NSSize(width: 18, height: 18))
    }
}

private struct MenuBarIconView: View {
    let running: Task?
    let elapsed: String

    var body: some View {
        if running != nil {
            Text(elapsed)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .monospacedDigit()
                .foregroundColor(.black)
                .padding(.horizontal, 4)
                .frame(height: 18)
        } else {
            Text("F")
                .font(.custom("EmilioTest-RegularItalic", size: 16))
                .foregroundColor(.black)
                .frame(width: 14, height: 18)
                .offset(y: -1)
        }
    }
}
