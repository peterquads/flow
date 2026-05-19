import Foundation
import AppKit
import UniformTypeIdentifiers

enum CSVExport {
    /// One row per closed interval, sorted by start time. Live (still-running)
    /// intervals are skipped — their end time is in flux and would confuse downstream tools.
    static func csv(from tasks: [Task]) -> String {
        let local = SharedFormatters.csvLocal

        struct Row { let task: String; let start: Date; let end: Date }
        var rows: [Row] = []
        for t in tasks {
            for iv in t.intervals {
                guard let end = iv.end else { continue }
                rows.append(Row(task: t.name, start: iv.start, end: end))
            }
        }
        rows.sort { $0.start < $1.start }

        var lines: [String] = ["task,start,end,duration_seconds,duration_hms"]
        for r in rows {
            let secs = max(0, Int(r.end.timeIntervalSince(r.start)))
            let h = secs / 3600
            let m = (secs % 3600) / 60
            let s = secs % 60
            let hms = String(format: "%d:%02d:%02d", h, m, s)
            lines.append([
                escape(r.task),
                local.string(from: r.start),
                local.string(from: r.end),
                String(secs),
                hms,
            ].joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func escape(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") || s.contains("\r") else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Prompts the user for a destination, writes the CSV, and reveals it in Finder.
    /// Activates the app first so the panel takes focus (the agent app has LSUIElement=true).
    @MainActor
    static func presentSavePanel(tasks: [Task]) {
        let suggested = "flow-export-\(SharedFormatters.dayKey.string(from: Date())).csv"

        NSApp.activate(ignoringOtherApps: true)

        let panel = NSSavePanel()
        panel.title = "Export Flow data"
        panel.nameFieldStringValue = suggested
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let content = csv(from: tasks)
        do {
            try content.data(using: .utf8)?.write(to: url, options: .atomic)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            NSLog("Flow: CSV export failed: \(error)")
        }
    }
}
