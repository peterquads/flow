import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var theme: AppTheme
    @State private var range: ChartRange = .day
    @State private var showClearAlert = false
    @State private var showSettingsSheet = false
    @State private var showManualEntry = false
    @State private var editingTaskName: String? = nil
    @State private var contentWidth: CGFloat = 900

    var fontScale: CGFloat {
        max(1.0, min(1.6, contentWidth / 900.0))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Frosted-glass window background.
                BlurView(material: .underWindowBackground, blending: .behindWindow)
                    .ignoresSafeArea()
                GrayPalette.cream.opacity(0.18)
                    .ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 28 * fontScale) {
                        header
                        rangePicker
                        summary
                        ChartBreakdownSection(
                            tasks: store.tasks,
                            range: range,
                            fontScale: fontScale,
                            onEdit: { editingTaskName = $0 }
                        )
                        .equatable()
                    }
                    .padding(.horizontal, 44 * fontScale)
                    .padding(.vertical, 44 * fontScale)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .onAppear { contentWidth = geo.size.width }
            .onChange(of: geo.size.width) { _, new in contentWidth = new }
        }
        .frame(minWidth: 760, minHeight: 600)
        .preferredColorScheme(theme.colorScheme)
        .alert("Clear all data?", isPresented: $showClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { store.clearAllData() }
        } message: {
            Text("This will permanently erase every tracked task and interval. This cannot be undone.")
        }
        .sheet(item: editingBinding) { editing in
            EditEntrySheet(taskName: editing.name, range: range, fontScale: fontScale)
                .environmentObject(store)
                .environmentObject(theme)
                .preferredColorScheme(theme.colorScheme)
        }
    }

    private struct EditingTarget: Identifiable {
        let name: String
        var id: String { name.lowercased() }
    }

    private var editingBinding: Binding<EditingTarget?> {
        Binding(
            get: { editingTaskName.map { EditingTarget(name: $0) } },
            set: { editingTaskName = $0?.name }
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                // Cursive wordmark.
                Text("Flow")
                    .font(.custom("SnellRoundhand-Bold", size: 30 * fontScale))
                    .foregroundColor(GrayPalette.textSecondary)
                Text(range.title)
                    .font(.emilio(.semibold, size: 36 * fontScale))
                    .foregroundColor(GrayPalette.charcoal)
            }
            Spacer()
            HStack(spacing: 10 * fontScale) {
                addEntryButton
                settingsButton
            }
        }
    }

    private var circleButtonSize: CGFloat { 40 * fontScale }
    private var circleIconSize: CGFloat { 15 * fontScale }

    private var addEntryButton: some View {
        Button(action: { showManualEntry = true }) {
            ZStack {
                Circle().fill(GrayPalette.charcoal)
                Image(systemName: "plus")
                    .font(.system(size: circleIconSize * 1.25, weight: .heavy))
                    .foregroundColor(GrayPalette.cream)
            }
            .frame(width: circleButtonSize, height: circleButtonSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Add manual entry")
        .sheet(isPresented: $showManualEntry) {
            ManualEntrySheet(fontScale: fontScale)
                .environmentObject(store)
                .environmentObject(theme)
                .preferredColorScheme(theme.colorScheme)
        }
    }

    private var settingsButton: some View {
        Button(action: { showSettingsSheet = true }) {
            ZStack {
                // strokeBorder insets the line — keeps the visible outer edge
                // at exactly the same diameter as the filled add-entry circle.
                Circle()
                    .fill(GrayPalette.cardSurface)
                    .overlay(
                        Circle().strokeBorder(GrayPalette.hairline.opacity(0.6), lineWidth: 1)
                    )
                Image(systemName: "gearshape")
                    .font(.system(size: circleIconSize, weight: .semibold))
                    .foregroundColor(GrayPalette.textSecondary)
            }
            .frame(width: circleButtonSize, height: circleButtonSize)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help("Settings")
        .confirmationDialog("Settings", isPresented: $showSettingsSheet, titleVisibility: .hidden) {
            Button("Download as CSV…") { CSVExport.presentSavePanel(tasks: store.tasks) }
            Button(store.showDailyQuote ? "Hide daily quote" : "Show daily quote") {
                store.showDailyQuote.toggle()
            }
            Button("Clear all data…", role: .destructive) { showClearAlert = true }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Range picker

    private var rangePicker: some View {
        HStack(spacing: 6 * fontScale) {
            ForEach(ChartRange.allCases) { r in
                Button(action: { range = r }) {
                    Text(r.label)
                        .font(.mono(12 * fontScale, weight: .medium))
                        .foregroundColor(r == range ? GrayPalette.cream : GrayPalette.charcoal)
                        .padding(.horizontal, 16 * fontScale)
                        .padding(.vertical, 8 * fontScale)
                        .background(
                            Capsule().fill(r == range ? GrayPalette.charcoal : Color.clear)
                        )
                        .overlay(
                            Capsule().stroke(GrayPalette.hairline, lineWidth: r == range ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Summary (live — updates each second while running)

    private var summary: some View {
        let today = Aggregator.totalSeconds(tasks: store.tasks, range: .day)
        let week = Aggregator.totalSeconds(tasks: store.tasks, range: .week)
        let month = Aggregator.totalSeconds(tasks: store.tasks, range: .month)
        let isLive = store.currentTask?.isRunning == true

        return HStack(spacing: 0) {
            metric(label: "Today", value: formatDuration(today))
            metricDivider
            metric(label: "This week", value: formatDuration(week))
            metricDivider
            metric(label: "This month", value: formatDuration(month))
            if isLive {
                metricDivider
                metric(label: "Now", value: store.elapsedDisplay)
            }
            Spacer()
        }
        .padding(.horizontal, 32 * fontScale)
        .padding(.vertical, 24 * fontScale)
        .modifier(CardSurface())
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(GrayPalette.hairline.opacity(0.5))
            .frame(width: 1, height: 42 * fontScale)
            .padding(.horizontal, 32 * fontScale)
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.mono(10 * fontScale, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(GrayPalette.muted)
            Text(value)
                .font(.emilio(.regular, size: 28 * fontScale))
                .foregroundColor(GrayPalette.charcoal)
                .monospacedDigit()
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%dh %dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }
}

// MARK: - ChartBreakdownSection
//
// Equatable so SwiftUI skips body evaluation (and therefore the Aggregator
// pass + Charts re-layout) when only the live elapsed display changed.
// Inputs that genuinely affect the chart — the tasks array, the selected
// range, and the font scale — drive re-renders.

private struct ChartBreakdownSection: View, Equatable {
    let tasks: [Task]
    let range: ChartRange
    let fontScale: CGFloat
    let onEdit: (String) -> Void

    static func == (lhs: ChartBreakdownSection, rhs: ChartBreakdownSection) -> Bool {
        lhs.range == rhs.range &&
        lhs.fontScale == rhs.fontScale &&
        lhs.tasks == rhs.tasks
    }

    var body: some View {
        let agg = Aggregator.aggregate(tasks: tasks, range: range)
        VStack(alignment: .leading, spacing: 28 * fontScale) {
            chartCard(agg)
            taskList(agg)
        }
    }

    // MARK: Chart

    private func chartCard(_ agg: Aggregate) -> some View {
        VStack(alignment: .leading, spacing: 20 * fontScale) {
            Text(chartHeaderLabel)
                .font(.emilio(.regular, size: 14 * fontScale))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(GrayPalette.muted)
            if agg.buckets.isEmpty {
                emptyChart
            } else {
                FlowBarChart(
                    buckets: agg.buckets,
                    range: range,
                    rangeSeconds: agg.rangeSeconds,
                    fontScale: fontScale
                )
                .frame(minHeight: 320 * fontScale)
            }
        }
        .padding(32 * fontScale)
        .modifier(CardSurface())
    }

    private var chartHeaderLabel: String {
        switch range {
        case .day: return "Time by hour"
        case .week, .month: return "Time by day"
        case .quarter: return "Time by week"
        }
    }

    private var emptyChart: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 26 * fontScale))
                    .foregroundColor(GrayPalette.muted)
                Text("No tracked time yet for this range")
                    .font(.mono(12 * fontScale))
                    .foregroundColor(GrayPalette.muted)
            }
            .padding(.vertical, 48 * fontScale)
            Spacer()
        }
    }

    // MARK: Breakdown

    private func taskList(_ agg: Aggregate) -> some View {
        VStack(alignment: .leading, spacing: 18 * fontScale) {
            Text("Breakdown")
                .font(.emilio(.regular, size: 14 * fontScale))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundColor(GrayPalette.muted)
            if agg.totals.isEmpty {
                Text("Start a task from the menu bar to see it here.")
                    .font(.mono(13 * fontScale))
                    .foregroundColor(GrayPalette.muted)
                    .padding(.vertical, 12 * fontScale)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(agg.totals.enumerated()), id: \.offset) { idx, row in
                        taskRow(task: row.task, seconds: row.seconds, rangeSeconds: agg.rangeSeconds)
                        if idx < agg.totals.count - 1 {
                            Rectangle()
                                .fill(GrayPalette.hairline.opacity(0.6))
                                .frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, 28 * fontScale)
                .padding(.vertical, 10 * fontScale)
                .modifier(CardSurface())
            }
        }
    }

    private func taskRow(task: Task, seconds: Double, rangeSeconds: Double) -> some View {
        let pct = rangeSeconds > 0 ? seconds / rangeSeconds : 0
        return HStack(spacing: 14 * fontScale) {
            RoundedRectangle(cornerRadius: 3)
                .fill(GrayPalette.color(forName: task.name))
                .frame(width: 12 * fontScale, height: 12 * fontScale)
            Text(task.name)
                .font(.mono(15 * fontScale))
                .foregroundColor(GrayPalette.charcoal)
                .lineLimit(1)
                .truncationMode(.tail)
            if task.isRunning {
                Text("LIVE")
                    .font(.mono(9 * fontScale, weight: .semibold))
                    .tracking(2)
                    .foregroundColor(GrayPalette.cream)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(GrayPalette.charcoal))
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 12 * fontScale) {
                Text(formatPercent(pct))
                    .font(.mono(13 * fontScale, weight: .medium))
                    .foregroundColor(GrayPalette.muted)
                    .frame(width: 60 * fontScale, alignment: .trailing)
                Text(formatDuration(seconds))
                    .font(.emilio(.regular, size: 20 * fontScale))
                    .foregroundColor(GrayPalette.charcoal)
                    .monospacedDigit()
                    .frame(minWidth: 90 * fontScale, alignment: .trailing)
            }
        }
        .padding(.vertical, 18 * fontScale)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Edit recorded time…") { onEdit(task.name) }
        }
    }

    private func formatPercent(_ pct: Double) -> String {
        let p = pct * 100
        if p < 0.1 { return "<0.1%" }
        if p < 10 { return String(format: "%.1f%%", p) }
        return String(format: "%.0f%%", p)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%dh %dm", h, m) }
        if m > 0 { return String(format: "%dm %02ds", m, s) }
        return String(format: "%ds", s)
    }
}

private struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(GrayPalette.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(GrayPalette.hairline.opacity(0.6), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 16, x: 0, y: 4)
    }
}
