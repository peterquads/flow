import SwiftUI
import AppKit

@MainActor
enum MenuBarIcon {
    static func render(running: Task?, elapsed: String) -> NSImage {
        if running != nil {
            // SwiftUI renderer for the running elapsed-time label.
            let view = MenuBarIconView(running: running, elapsed: elapsed)
            let renderer = ImageRenderer(content: view)
            renderer.scale = NSScreen.main?.backingScaleFactor ?? 2.0
            renderer.isOpaque = false
            guard let nsImage = renderer.nsImage else { return placeholder() }
            nsImage.isTemplate = true
            return nsImage
        }
        // Idle: render the cursive "F" via NSAttributedString using the
        // glyph's actual bounding box (not typographic), so the menu bar
        // can vertical-center it correctly without ascender/descender slack.
        return renderCursiveF()
    }

    private static func renderCursiveF() -> NSImage {
        // Load the pre-rendered cursive F from the bundle. Generated offline
        // by `scripts/make-menubar-icon.sh` using Snell Roundhand Black at
        // 400pt, cropped to the true alpha bounds, then downscaled to 18pt
        // (@1x) and 36pt (@2x). Way more reliable than rendering a script
        // font at small sizes at runtime.
        if let url = Bundle.main.url(forResource: "MenuBarF", withExtension: "png"),
           let img = NSImage(contentsOf: url) {
            img.isTemplate = true
            return img
        }
        return placeholder()
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
            // Cursive script "F" — Snell Roundhand Bold. Just a small bit of
            // bottom room for the tail flourish, nothing more.
            Text("F")
                .font(.custom("SnellRoundhand-Bold", size: 18))
                .foregroundColor(.black)
                .padding(.horizontal, 1)
                .padding(.bottom, 2)
                .fixedSize()
        }
    }
}
