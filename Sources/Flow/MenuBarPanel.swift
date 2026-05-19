import SwiftUI
import AppKit

struct MenuBarPanel: View {
    @EnvironmentObject var store: AppStore
    @FocusState private var fieldFocused: Bool
    @State private var highlightedIndex: Int = -1

    var onOpenDashboard: () -> Void = {}
    var onClose: () -> Void = {}

    private var suggestions: [String] {
        Autocomplete.suggestions(for: store.draftName, from: store.historyMRU, limit: 5)
    }

    var body: some View {
        ZStack {
            BlurView(material: .popover, blending: .behindWindow)
            GrayPalette.cream.opacity(0.35)
            VStack(alignment: .leading, spacing: 12) {
                if let current = store.currentTask {
                    runningStrip(current)
                } else {
                    idleStrip
                }
                divider
                inputField
                if !suggestions.isEmpty {
                    suggestionList
                }
                divider
                quoteBlock
                footer
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .frame(width: 340)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                fieldFocused = true
            }
        }
    }

    private var idleStrip: some View {
        HStack(spacing: 10) {
            Circle()
                .stroke(GrayPalette.hairline, lineWidth: 1)
                .frame(width: 6, height: 6)
            Text("No task running")
                .font(.mono(12))
                .foregroundColor(GrayPalette.muted)
            Spacer()
            Text("--:--")
                .font(.mono(14, weight: .medium))
                .foregroundColor(GrayPalette.muted.opacity(0.6))
                .monospacedDigit()
        }
        .frame(height: 32)
    }

    private func runningStrip(_ task: Task) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(GrayPalette.charcoal)
                .frame(width: 6, height: 6)
                .opacity(task.isRunning ? 1.0 : 0.25)
            Text(task.name)
                .font(.mono(13))
                .foregroundColor(GrayPalette.charcoal)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text(store.elapsedDisplay)
                .font(.mono(14, weight: .medium))
                .foregroundColor(GrayPalette.charcoal)
                .monospacedDigit()
                .opacity(task.isRunning ? 1.0 : 0.55)
            CircleIconButton(systemName: task.isRunning ? "pause.fill" : "play.fill",
                             help: task.isRunning ? "Pause" : "Resume",
                             action: { store.pauseResume() })
            CircleIconButton(systemName: "stop.fill",
                             help: "End task",
                             action: {
                                 store.endCurrentTask()
                                 onClose()
                             })
        }
        .frame(height: 32)
    }

    private var inputField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(store.currentTask != nil ? "Start a new task" : "What are you working on?")
                .font(.emilio(.regular, size: 13))
                .foregroundColor(GrayPalette.textSecondary)
            HStack(spacing: 8) {
                TextField("", text: $store.draftName, prompt: Text("Type a task name…")
                    .foregroundColor(GrayPalette.muted))
                    .font(.mono(13))
                    .foregroundColor(GrayPalette.charcoal)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .onSubmit(submit)
                    .onChange(of: store.draftName) { _, _ in highlightedIndex = -1 }
                if !store.draftName.isEmpty {
                    Button(action: { store.draftName = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(GrayPalette.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(GrayPalette.creamDeep.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(GrayPalette.hairline, lineWidth: 1)
            )
        }
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, name in
                Button(action: {
                    store.draftName = name
                    submit()
                }) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(GrayPalette.color(forName: name))
                            .frame(width: 6, height: 6)
                        Text(name)
                            .font(.mono(12))
                            .foregroundColor(GrayPalette.charcoal)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Image(systemName: "return")
                            .font(.system(size: 10))
                            .foregroundColor(GrayPalette.muted)
                            .opacity(idx == highlightedIndex ? 1 : 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(idx == highlightedIndex ? GrayPalette.creamDeep.opacity(0.7) : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onHover { hovering in if hovering { highlightedIndex = idx } }
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(GrayPalette.hairline)
            .frame(height: 1)
    }

    private var quoteBlock: some View {
        let q = Quotes.today()
        return VStack(alignment: .leading, spacing: 5) {
            Text("\u{201C}\(q.text)\u{201D}")
                .font(.custom("EmilioTest-RegularItalic", size: 12))
                .foregroundColor(GrayPalette.textSecondary)
                .lineLimit(5)
                .fixedSize(horizontal: false, vertical: true)
            Text(q.author.uppercased())
                .font(.mono(9, weight: .semibold))
                .tracking(1.8)
                .foregroundColor(GrayPalette.muted)
        }
        .padding(.bottom, 2)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button(action: onOpenDashboard) {
                Label("Dashboard", systemImage: "chart.bar.xaxis")
                    .font(.mono(11))
                    .foregroundColor(GrayPalette.textSecondary)
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }

    private func submit() {
        let name: String
        if highlightedIndex >= 0 && highlightedIndex < suggestions.count {
            name = suggestions[highlightedIndex]
        } else if !store.draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            name = store.draftName
        } else {
            return
        }
        store.startTask(name: name)
        onClose()
    }

}

private struct CircleIconButton: View {
    let systemName: String
    let help: String
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(GrayPalette.charcoal)
                .frame(width: 28, height: 28)
                .background(
                    Circle().fill(hovering ? GrayPalette.charcoal.opacity(0.08) : .white.opacity(0.5))
                )
                .overlay(
                    Circle().stroke(GrayPalette.hairline, lineWidth: 1)
                )
                .scaleEffect(hovering ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { h in
            withAnimation(.easeOut(duration: 0.12)) { hovering = h }
        }
    }
}
