import SwiftUI
import Charts

enum ChartRange: String, CaseIterable, Identifiable {
    case day, week, month, quarter
    var id: String { rawValue }
    var label: String {
        switch self {
        case .day: return "Day"
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "Quarter"
        }
    }
    var title: String {
        switch self {
        case .day: return "Today"
        case .week: return "This week"
        case .month: return "This month"
        case .quarter: return "This quarter"
        }
    }
}

struct Bucket: Identifiable {
    var id: String { "\(date.timeIntervalSince1970)-\(taskName)" }
    let date: Date
    let taskName: String
    let seconds: Double
}

struct TooltipEntry: Identifiable {
    let id = UUID()
    let name: String
    let seconds: Double
}

struct HoverInfo {
    let bucketStart: Date
    let entries: [TooltipEntry]
    let totalSeconds: Double
    let x: CGFloat
    let y: CGFloat
}

enum Aggregator {
    static func windowStart(for range: ChartRange, now: Date = Date()) -> Date {
        let cal = Calendar.current
        switch range {
        case .day:
            return cal.startOfDay(for: now)
        case .week:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
            return cal.date(from: comps) ?? now
        case .month:
            let comps = cal.dateComponents([.year, .month], from: now)
            return cal.date(from: comps) ?? now
        case .quarter:
            let month = cal.component(.month, from: now)
            let qStartMonth = ((month - 1) / 3) * 3 + 1
            var comps = cal.dateComponents([.year], from: now)
            comps.month = qStartMonth
            comps.day = 1
            return cal.date(from: comps) ?? now
        }
    }

    static func bucketDate(for date: Date, range: ChartRange) -> Date {
        let cal = Calendar.current
        switch range {
        case .day:
            let comps = cal.dateComponents([.year, .month, .day, .hour], from: date)
            return cal.date(from: comps) ?? date
        case .week, .month:
            return cal.startOfDay(for: date)
        case .quarter:
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return cal.date(from: comps) ?? date
        }
    }

    static func buckets(tasks: [Task], range: ChartRange, now: Date = Date()) -> [Bucket] {
        let windowStart = windowStart(for: range, now: now)
        var map: [String: Bucket] = [:]
        for task in tasks {
            for iv in task.intervals {
                let end = iv.end ?? now
                let segStart = max(iv.start, windowStart)
                let segEnd = max(segStart, end)
                if segEnd <= windowStart { continue }
                splitInterval(start: segStart, end: segEnd, range: range) { bucketStart, seconds in
                    let key = "\(bucketStart.timeIntervalSince1970)-\(task.name)"
                    if let prev = map[key] {
                        map[key] = Bucket(date: prev.date,
                                          taskName: prev.taskName,
                                          seconds: prev.seconds + seconds)
                    } else {
                        map[key] = Bucket(date: bucketStart,
                                          taskName: task.name,
                                          seconds: seconds)
                    }
                }
            }
        }
        return map.values.sorted { $0.date < $1.date }
    }

    private static func splitInterval(start: Date, end: Date, range: ChartRange, emit: (Date, Double) -> Void) {
        let cal = Calendar.current
        var cursor = start
        while cursor < end {
            let bucketStart = bucketDate(for: cursor, range: range)
            let bucketEnd: Date
            switch range {
            case .day:
                bucketEnd = cal.date(byAdding: .hour, value: 1, to: bucketStart) ?? end
            case .week, .month:
                bucketEnd = cal.date(byAdding: .day, value: 1, to: bucketStart) ?? end
            case .quarter:
                bucketEnd = cal.date(byAdding: .weekOfYear, value: 1, to: bucketStart) ?? end
            }
            let segEnd = min(end, bucketEnd)
            emit(bucketStart, segEnd.timeIntervalSince(cursor))
            cursor = segEnd
        }
    }

    static func totalsByTask(tasks: [Task], range: ChartRange, now: Date = Date()) -> [(task: Task, seconds: Double)] {
        let windowStart = windowStart(for: range, now: now)
        // Group by lowercased name so multiple per-day instances of the same task roll up
        // into one breakdown row. Pick the representative Task (most recently used) per group.
        var sums: [String: Double] = [:]
        var representatives: [String: Task] = [:]
        for task in tasks {
            var total: Double = 0
            for iv in task.intervals {
                let end = iv.end ?? now
                let segStart = max(iv.start, windowStart)
                let segEnd = max(segStart, end)
                if segEnd > windowStart {
                    total += segEnd.timeIntervalSince(segStart)
                }
            }
            if total > 0 {
                let key = task.name.lowercased()
                sums[key, default: 0] += total
                if let prev = representatives[key] {
                    if task.lastUsed > prev.lastUsed { representatives[key] = task }
                } else {
                    representatives[key] = task
                }
            }
        }
        var result: [(Task, Double)] = []
        result.reserveCapacity(sums.count)
        for (key, total) in sums {
            if let rep = representatives[key] {
                result.append((rep, total))
            }
        }
        result.sort { $0.1 > $1.1 }
        return result
    }

    // Cheap single-number total for a range — iterates intervals once, no bucketing.
    static func totalSeconds(tasks: [Task], range: ChartRange, now: Date = Date()) -> Double {
        let windowStart = windowStart(for: range, now: now)
        var total: Double = 0
        for task in tasks {
            for iv in task.intervals {
                let end = iv.end ?? now
                let segStart = max(iv.start, windowStart)
                let segEnd = max(segStart, end)
                if segEnd > windowStart {
                    total += segEnd.timeIntervalSince(segStart)
                }
            }
        }
        return total
    }

    static func aggregate(tasks: [Task], range: ChartRange, now: Date = Date()) -> Aggregate {
        let totals = totalsByTask(tasks: tasks, range: range, now: now)
        let buckets = buckets(tasks: tasks, range: range, now: now)
        let grandTotal = totals.reduce(0) { $0 + $1.seconds }
        let rangeSeconds = max(1, now.timeIntervalSince(windowStart(for: range, now: now)))
        return Aggregate(totals: totals, buckets: buckets, grandTotal: grandTotal, rangeSeconds: rangeSeconds)
    }
}

struct Aggregate {
    let totals: [(task: Task, seconds: Double)]
    let buckets: [Bucket]
    let grandTotal: Double
    let rangeSeconds: Double
}

struct FlowBarChart: View {
    let buckets: [Bucket]
    let range: ChartRange
    let rangeSeconds: Double
    let fontScale: CGFloat

    @State private var hoverInfo: HoverInfo?

    private var taskNamesOrdered: [String] {
        var seen = Set<String>()
        var out: [String] = []
        for b in buckets where !seen.contains(b.taskName) {
            seen.insert(b.taskName)
            out.append(b.taskName)
        }
        return out
    }

    // Stacked per-task blocks. Each task gets a deterministic color (same name → same color).
    var body: some View {
        let domain = taskNamesOrdered.isEmpty ? ["—"] : taskNamesOrdered
        let colors = taskNamesOrdered.isEmpty
            ? [GrayPalette.muted]
            : taskNamesOrdered.map { GrayPalette.color(forName: $0) }

        return Chart {
            ForEach(buckets) { b in
                BarMark(
                    x: .value("Time", b.date, unit: xUnit),
                    y: .value("Minutes", b.seconds / 60.0),
                    width: .ratio(0.62)
                )
                .foregroundStyle(by: .value("Task", b.taskName))
                .cornerRadius(2)
            }
        }
        .chartForegroundStyleScale(domain: domain, range: colors)
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: xMarkValues) { value in
                AxisGridLine().foregroundStyle(GrayPalette.hairline.opacity(0.5))
                AxisValueLabel(format: xLabelFormat(), centered: xLabelCentered)
                    .font(.system(size: 12 * fontScale, weight: .medium, design: .monospaced))
                    .foregroundStyle(GrayPalette.muted)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(GrayPalette.hairline.opacity(0.5))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(yLabel(minutes: v))
                            .font(.system(size: 11 * fontScale, weight: .medium, design: .monospaced))
                            .foregroundColor(GrayPalette.muted)
                    }
                }
            }
        }
        .chartPlotStyle { plot in
            plot.background(GrayPalette.cardSurface)
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                hoverTracker(proxy: proxy, geo: geo)
            }
        }
    }

    @ViewBuilder
    private func hoverTracker(proxy: ChartProxy, geo: GeometryProxy) -> some View {
        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let pos):
                        updateHover(at: pos, proxy: proxy, geo: geo)
                    case .ended:
                        hoverInfo = nil
                    }
                }
            if let info = hoverInfo {
                tooltip(info)
                    .offset(x: clampedTooltipX(info.x, viewWidth: geo.size.width),
                            y: max(0, info.y - 86 * fontScale))
                    .allowsHitTesting(false)
            }
        }
    }

    private func updateHover(at pos: CGPoint, proxy: ChartProxy, geo: GeometryProxy) {
        guard let plot = proxy.plotFrame else { hoverInfo = nil; return }
        let frame = geo[plot]
        let xInPlot = pos.x - frame.origin.x
        guard xInPlot >= 0, xInPlot <= frame.width else { hoverInfo = nil; return }

        guard let hoverDate: Date = proxy.value(atX: xInPlot) else { hoverInfo = nil; return }
        let bucketDate = Aggregator.bucketDate(for: hoverDate, range: range)
        let stack = buckets.filter { Calendar.current.isDate($0.date, equalTo: bucketDate, toGranularity: bucketGranularity) }
        guard !stack.isEmpty else { hoverInfo = nil; return }
        let totalSecs = stack.reduce(0) { $0 + $1.seconds }
        let entries = stack.sorted { $0.seconds > $1.seconds }
            .map { TooltipEntry(name: $0.taskName, seconds: $0.seconds) }
        hoverInfo = HoverInfo(
            bucketStart: bucketDate,
            entries: entries,
            totalSeconds: totalSecs,
            x: pos.x,
            y: pos.y
        )
    }

    private var bucketGranularity: Calendar.Component {
        switch range {
        case .day: return .hour
        case .week, .month: return .day
        case .quarter: return .weekOfYear
        }
    }

    private func tooltip(_ info: HoverInfo) -> some View {
        VStack(alignment: .leading, spacing: 6 * fontScale) {
            Text(bucketLabel(info.bucketStart))
                .font(.mono(10 * fontScale, weight: .semibold))
                .tracking(1)
                .textCase(.uppercase)
                .foregroundColor(GrayPalette.muted)
            ForEach(Array(info.entries.prefix(5).enumerated()), id: \.offset) { _, e in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(GrayPalette.color(forName: e.name))
                        .frame(width: 8 * fontScale, height: 8 * fontScale)
                    Text(e.name)
                        .font(.mono(11 * fontScale))
                        .foregroundColor(GrayPalette.charcoal)
                        .lineLimit(1)
                    Spacer(minLength: 12)
                    Text(shortDuration(e.seconds))
                        .font(.mono(11 * fontScale, weight: .medium))
                        .foregroundColor(GrayPalette.charcoal)
                        .monospacedDigit()
                    Text(percent(e.seconds / max(1, rangeSeconds)))
                        .font(.mono(10 * fontScale))
                        .foregroundColor(GrayPalette.muted)
                        .monospacedDigit()
                        .frame(width: 44 * fontScale, alignment: .trailing)
                }
            }
            if info.entries.count > 5 {
                Text("+ \(info.entries.count - 5) more")
                    .font(.mono(10 * fontScale))
                    .foregroundColor(GrayPalette.muted)
            }
            Divider().padding(.vertical, 2)
            HStack {
                Text("Bucket total")
                    .font(.mono(10 * fontScale, weight: .semibold))
                    .foregroundColor(GrayPalette.muted)
                Spacer()
                Text(shortDuration(info.totalSeconds))
                    .font(.mono(11 * fontScale, weight: .semibold))
                    .foregroundColor(GrayPalette.charcoal)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 14 * fontScale)
        .padding(.vertical, 12 * fontScale)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(GrayPalette.cardSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(GrayPalette.hairline.opacity(0.7), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 6)
        .frame(maxWidth: 320 * fontScale)
    }

    private func clampedTooltipX(_ x: CGFloat, viewWidth: CGFloat) -> CGFloat {
        let target = x + 12 * fontScale
        let maxX = viewWidth - 280 * fontScale
        return min(max(0, target), max(0, maxX))
    }

    private func bucketLabel(_ date: Date) -> String {
        switch range {
        case .day: return date.formatted(.dateTime.hour())  // respects 12h/24h system pref
        case .week, .month: return SharedFormatters.bucketDay.string(from: date)
        case .quarter: return SharedFormatters.bucketWeek.string(from: date)
        }
    }

    private func shortDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%dh %dm", h, m) }
        if m > 0 { return String(format: "%dm %ds", m, s) }
        return String(format: "%ds", s)
    }

    private func percent(_ p: Double) -> String {
        let pp = p * 100
        if pp < 0.1 { return "<0.1%" }
        if pp < 10 { return String(format: "%.1f%%", pp) }
        return String(format: "%.0f%%", pp)
    }

    private var xLabelCentered: Bool {
        switch range {
        case .day: return false                  // hour boundaries — align to tick
        case .week, .month, .quarter: return true // bucket spans — center under bar
        }
    }

    private var xUnit: Calendar.Component {
        switch range {
        case .day: return .hour
        case .week, .month: return .day
        case .quarter: return .weekOfYear
        }
    }

    private var xMarkValues: AxisMarkValues {
        switch range {
        case .day: return .stride(by: .hour, count: 3)
        case .week: return .stride(by: .day, count: 1)
        case .month: return .stride(by: .day, count: 5)
        case .quarter: return .stride(by: .weekOfYear, count: 2)
        }
    }

    private func xLabelFormat() -> Date.FormatStyle {
        switch range {
        case .day: return .dateTime.hour()
        case .week: return .dateTime.weekday(.abbreviated)
        case .month: return .dateTime.day().month(.abbreviated)
        case .quarter: return .dateTime.day().month(.abbreviated)
        }
    }

    private func yLabel(minutes: Double) -> String {
        if minutes >= 60 {
            return String(format: "%.0fh", minutes / 60)
        }
        return String(format: "%.0fm", minutes)
    }
}
