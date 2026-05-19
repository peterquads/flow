import SwiftUI

// MARK: - ManualEntrySheet

struct ManualEntrySheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var openPicker: Endpoint? = nil
    @FocusState private var nameFocused: Bool

    var fontScale: CGFloat = 1.0

    init(fontScale: CGFloat = 1.0) {
        self.fontScale = fontScale
        let now = Date()
        _endDate = State(initialValue: now)
        _startDate = State(initialValue: now.addingTimeInterval(-30 * 60))
    }

    private let quickDurations: [Int] = [15, 30, 45, 60, 90, 120, 180, 240]

    private var durationMinutes: Int {
        max(0, Int(endDate.timeIntervalSince(startDate) / 60))
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && endDate > startDate
    }

    private var suggestions: [String] {
        Autocomplete.suggestions(for: name, from: store.historyMRU, limit: 5)
    }

    enum Endpoint { case start, end }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            divider
            taskBlock
            divider
            endpointsBlock
            if let endpoint = openPicker {
                inlinePicker(endpoint)
            }
            divider
            quickChipsBlock
            Spacer(minLength: 24 * fontScale)
            actions
        }
        .padding(.horizontal, 32 * fontScale)
        .padding(.vertical, 28 * fontScale)
        .frame(width: 540 * fontScale)
        .background(GrayPalette.cream)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { nameFocused = true }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Manual entry")
                    .font(.emilio(.semibold, size: 22 * fontScale))
                    .foregroundColor(GrayPalette.charcoal)
                Text("Log time you tracked elsewhere or forgot to start.")
                    .font(.mono(11 * fontScale))
                    .foregroundColor(GrayPalette.muted)
            }
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 11 * fontScale, weight: .medium))
                    .foregroundColor(GrayPalette.muted)
                    .frame(width: 28 * fontScale, height: 28 * fontScale)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.bottom, 22 * fontScale)
    }

    // MARK: - Task block (borderless input + suggestions)

    private var taskBlock: some View {
        VStack(alignment: .leading, spacing: 10 * fontScale) {
            TextField("", text: $name, prompt: Text("What were you working on?")
                .foregroundColor(GrayPalette.muted))
                .font(.mono(15 * fontScale))
                .foregroundColor(GrayPalette.charcoal)
                .textFieldStyle(.plain)
                .focused($nameFocused)
                .padding(.vertical, 10 * fontScale)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(nameFocused ? GrayPalette.charcoal : GrayPalette.hairline)
                        .frame(height: nameFocused ? 1.5 : 1)
                        .animation(.easeOut(duration: 0.12), value: nameFocused)
                }
            if !suggestions.isEmpty && !name.isEmpty {
                suggestionRows
            }
        }
        .padding(.vertical, 18 * fontScale)
    }

    private var suggestionRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.offset) { idx, s in
                Button(action: { name = s }) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(GrayPalette.color(forName: s))
                            .frame(width: 7, height: 7)
                        Text(s)
                            .font(.mono(12 * fontScale))
                            .foregroundColor(GrayPalette.textSecondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.vertical, 7 * fontScale)
                    .padding(.horizontal, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Endpoints row

    private var endpointsBlock: some View {
        VStack(spacing: 14 * fontScale) {
            dateHeader
            HStack(alignment: .center, spacing: 24 * fontScale) {
                endpointTime(.start)
                Image(systemName: "arrow.right")
                    .font(.system(size: 16 * fontScale, weight: .regular))
                    .foregroundColor(GrayPalette.muted)
                endpointTime(.end)
            }
            .frame(maxWidth: .infinity)
            durationBadge
        }
        .padding(.vertical, 22 * fontScale)
    }

    @ViewBuilder
    private var dateHeader: some View {
        let cal = Calendar.current
        let sameDay = cal.isDate(startDate, inSameDayAs: endDate)
        if sameDay {
            Text(SharedFormatters.longDate.string(from: startDate))
                .font(.emilio(.regular, size: 14 * fontScale))
                .foregroundColor(GrayPalette.textSecondary)
                .frame(maxWidth: .infinity)
        } else {
            HStack(spacing: 8) {
                Text(SharedFormatters.dayMonth.string(from: startDate))
                Image(systemName: "arrow.right")
                    .font(.system(size: 10 * fontScale, weight: .medium))
                Text(SharedFormatters.dayMonth.string(from: endDate))
            }
            .font(.emilio(.regular, size: 13 * fontScale))
            .foregroundColor(GrayPalette.textSecondary)
            .frame(maxWidth: .infinity)
        }
    }

    private func endpointTime(_ endpoint: Endpoint) -> some View {
        let date = endpoint == .start ? startDate : endDate
        let isOpen = openPicker == endpoint
        let cal = Calendar.current
        let h24 = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        let uses24h = Locale.current.uses24HourTime

        return Button(action: { toggle(endpoint) }) {
            HStack(alignment: .lastTextBaseline, spacing: 6 * fontScale) {
                Text(uses24h
                     ? String(format: "%02d:%02d", h24, m)
                     : String(format: "%d:%02d", h24 == 0 ? 12 : (h24 > 12 ? h24 - 12 : h24), m))
                    .font(.emilio(.semibold, size: 34 * fontScale))
                    .foregroundColor(GrayPalette.charcoal)
                    .monospacedDigit()
                if !uses24h {
                    Text(h24 >= 12 ? "PM" : "AM")
                        .font(.mono(11 * fontScale, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(GrayPalette.muted)
                }
            }
            .padding(.horizontal, 16 * fontScale)
            .padding(.vertical, 10 * fontScale)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isOpen ? GrayPalette.creamDeep.opacity(0.7) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var durationBadge: some View {
        Text(formatDurationLabel(durationMinutes))
            .font(.mono(10 * fontScale, weight: .semibold))
            .tracking(1)
            .foregroundColor(GrayPalette.muted)
            .monospacedDigit()
            .padding(.horizontal, 14 * fontScale)
            .padding(.vertical, 5 * fontScale)
            .background(Capsule().fill(GrayPalette.creamDeep.opacity(0.55)))
    }

    private func toggle(_ endpoint: Endpoint) {
        if openPicker == endpoint { openPicker = nil } else { openPicker = endpoint }
    }

    // MARK: - Inline picker

    @ViewBuilder
    private func inlinePicker(_ endpoint: Endpoint) -> some View {
        InlineDateTimePicker(
            date: endpoint == .start
                ? Binding(get: { startDate }, set: { newValue in
                    startDate = newValue
                    if endDate < startDate { endDate = startDate.addingTimeInterval(30 * 60) }
                })
                : Binding(get: { endDate }, set: { newValue in
                    endDate = newValue
                    if endDate < startDate { startDate = endDate.addingTimeInterval(-30 * 60) }
                }),
            fontScale: fontScale,
            allowFuture: false
        )
        .padding(.vertical, 18 * fontScale)
        .padding(.horizontal, 4 * fontScale)
    }

    // MARK: - Quick chips

    private var quickChipsBlock: some View {
        HStack(spacing: 6 * fontScale) {
            ForEach(quickDurations, id: \.self) { m in
                let selected = m == durationMinutes
                Button(action: {
                    endDate = startDate.addingTimeInterval(TimeInterval(m * 60))
                    if endDate > Date() {
                        endDate = Date()
                        startDate = endDate.addingTimeInterval(TimeInterval(-m * 60))
                    }
                }) {
                    Text(formatChipLabel(m))
                        .font(.mono(11 * fontScale, weight: .medium))
                        .foregroundColor(selected ? GrayPalette.cream : GrayPalette.textSecondary)
                        .padding(.horizontal, 12 * fontScale)
                        .padding(.vertical, 6 * fontScale)
                        .background(Capsule().fill(selected ? GrayPalette.charcoal : Color.clear))
                        .overlay(Capsule().stroke(GrayPalette.hairline, lineWidth: selected ? 0 : 1))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.vertical, 14 * fontScale)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack {
            Spacer()
            Button(action: { dismiss() }) {
                Text("Cancel")
                    .font(.mono(13 * fontScale, weight: .medium))
                    .foregroundColor(GrayPalette.textSecondary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)

            Button(action: save) {
                Text("Add entry")
                    .font(.mono(13 * fontScale, weight: .semibold))
                    .foregroundColor(canSave ? GrayPalette.cream : GrayPalette.muted)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(canSave ? GrayPalette.charcoal : GrayPalette.creamDeep)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
    }

    private func save() {
        store.addManualEntry(name: name, start: startDate, end: endDate)
        dismiss()
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(GrayPalette.hairline.opacity(0.5))
            .frame(height: 1)
    }


    private func formatDurationLabel(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }

    private func formatChipLabel(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 && m == 0 { return "\(h)h" }
        if h > 0 { return "\(h)h\(m)" }
        return "\(m)m"
    }
}

// MARK: - InlineDateTimePicker (calendar grid + minimal time input)

struct InlineDateTimePicker: View {
    @Binding var date: Date
    let fontScale: CGFloat
    let allowFuture: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14 * fontScale) {
            CalendarGrid(date: $date, fontScale: fontScale, allowFuture: allowFuture)
            MinimalTimeField(date: $date, fontScale: fontScale)
        }
    }
}

// MARK: - CalendarGrid

private struct CalendarGrid: View {
    @Binding var date: Date
    let fontScale: CGFloat
    let allowFuture: Bool

    @State private var visibleMonth: Date = Date()
    @State private var hovered: Date? = nil

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        VStack(spacing: 12 * fontScale) {
            headerRow
            HStack { Spacer(minLength: 0); weekdayRow; Spacer(minLength: 0) }
            HStack { Spacer(minLength: 0); grid; Spacer(minLength: 0) }
        }
        .onAppear { visibleMonth = startOfMonth(for: date) }
    }

    private var headerRow: some View {
        HStack {
            navButton("chevron.left") { changeMonth(by: -1) }
            Spacer()
            Text(monthLabelFormatter.string(from: visibleMonth))
                .font(.emilio(.semibold, size: 16 * fontScale))
                .foregroundColor(GrayPalette.charcoal)
            Spacer()
            navButton("chevron.right") { changeMonth(by: 1) }
        }
    }

    private func navButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11 * fontScale, weight: .medium))
                .foregroundColor(GrayPalette.textSecondary)
                .frame(width: 26 * fontScale, height: 26 * fontScale)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var weekdayRow: some View {
        let symbols = calendar.veryShortWeekdaySymbols
        return HStack(spacing: 2 * fontScale) {
            ForEach(0..<7, id: \.self) { i in
                Text(symbols[i])
                    .font(.mono(10 * fontScale, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(GrayPalette.muted)
                    .frame(width: 36 * fontScale)
            }
        }
    }

    private var grid: some View {
        let days = monthDays
        let rows = days.chunked(into: 7)
        return VStack(spacing: 2 * fontScale) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 2 * fontScale) {
                    ForEach(row, id: \.self) { day in
                        cell(for: day)
                    }
                }
            }
        }
    }

    private func cell(for day: Date) -> some View {
        let isOutOfMonth = !calendar.isDate(day, equalTo: visibleMonth, toGranularity: .month)
        let isSelected = calendar.isDate(day, inSameDayAs: date)
        let isToday = calendar.isDateInToday(day)
        let disabled = !allowFuture && calendar.startOfDay(for: day) > calendar.startOfDay(for: Date())
        let isHovered = hovered.map { calendar.isDate(day, inSameDayAs: $0) } ?? false

        return Button(action: {
            guard !disabled else { return }
            selectDay(day)
        }) {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(GrayPalette.charcoal)
                } else if isHovered && !disabled {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(GrayPalette.creamDeep)
                }
                VStack(spacing: 2) {
                    Text("\(calendar.component(.day, from: day))")
                        .font(.mono(14 * fontScale, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(
                            isSelected ? GrayPalette.cream
                            : disabled ? GrayPalette.muted.opacity(0.4)
                            : isOutOfMonth ? GrayPalette.muted.opacity(0.5)
                            : GrayPalette.charcoal
                        )
                        .monospacedDigit()
                    if isToday && !isSelected {
                        Circle()
                            .fill(GrayPalette.charcoal)
                            .frame(width: 3, height: 3)
                    } else if isToday && isSelected {
                        Circle()
                            .fill(GrayPalette.cream)
                            .frame(width: 3, height: 3)
                    }
                }
            }
            .frame(width: 36 * fontScale, height: 36 * fontScale)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { h in hovered = h ? day : nil }
    }

    // Build 6-row × 7-col grid of dates for the visible month, including padding from
    // surrounding months so the grid is always full.
    private var monthDays: [Date] {
        let firstOfMonth = startOfMonth(for: visibleMonth)
        let weekdayOfFirst = calendar.component(.weekday, from: firstOfMonth) // 1 = Sunday
        let gridStart = calendar.date(byAdding: .day, value: -(weekdayOfFirst - calendar.firstWeekday), to: firstOfMonth)!
        return (0..<42).map { calendar.date(byAdding: .day, value: $0, to: gridStart)! }
    }

    private func startOfMonth(for d: Date) -> Date {
        let comps = calendar.dateComponents([.year, .month], from: d)
        return calendar.date(from: comps) ?? d
    }

    private func changeMonth(by delta: Int) {
        if let next = calendar.date(byAdding: .month, value: delta, to: visibleMonth) {
            visibleMonth = next
        }
    }

    private func selectDay(_ day: Date) {
        // Preserve the existing hour/minute, replace the y/m/d.
        let timeComps = calendar.dateComponents([.hour, .minute, .second], from: date)
        var dayComps = calendar.dateComponents([.year, .month, .day], from: day)
        dayComps.hour = timeComps.hour
        dayComps.minute = timeComps.minute
        dayComps.second = timeComps.second
        if let merged = calendar.date(from: dayComps) {
            let clamped = allowFuture ? merged : min(merged, Date())
            date = clamped
            visibleMonth = startOfMonth(for: merged)
        }
    }

    private var monthLabelFormatter: DateFormatter { SharedFormatters.monthYear }
}

// MARK: - MinimalTimeField (HH : MM  AM/PM, borderless)

private struct MinimalTimeField: View {
    @Binding var date: Date
    let fontScale: CGFloat

    @State private var hourText: String = ""
    @State private var minuteText: String = ""
    @FocusState private var focused: Field?

    private enum Field { case hour, minute }

    private var calendar: Calendar { Calendar.current }
    private var uses24h: Bool { Locale.current.uses24HourTime }
    private var hour24: Int { calendar.component(.hour, from: date) }
    private var minute: Int { calendar.component(.minute, from: date) }
    private var hour12: Int { let h = hour24 % 12; return h == 0 ? 12 : h }
    private var isPM: Bool { hour24 >= 12 }
    private var displayedHour: Int { uses24h ? hour24 : hour12 }
    private var hourPlaceholder: String { uses24h ? "00" : "12" }

    var body: some View {
        HStack(spacing: 10 * fontScale) {
            digitField($hourText, placeholder: hourPlaceholder, focus: .hour) { text in
                if let i = Int(text) {
                    if uses24h, i >= 0 && i <= 23 {
                        setHour24(i, minute: minute)
                    } else if !uses24h, i >= 1 && i <= 12 {
                        setTime(hour12: i, minute: minute, isPM: isPM)
                    }
                }
                hourText = String(format: uses24h ? "%02d" : "%d", displayedHour)
            }
            .frame(width: 44 * fontScale)

            Text(":")
                .font(.emilio(.semibold, size: 22 * fontScale))
                .foregroundColor(GrayPalette.muted)

            digitField($minuteText, placeholder: "00", focus: .minute) { text in
                if let i = Int(text), i >= 0 && i <= 59 {
                    if uses24h {
                        setHour24(hour24, minute: i)
                    } else {
                        setTime(hour12: hour12, minute: i, isPM: isPM)
                    }
                }
                minuteText = String(format: "%02d", minute)
            }
            .frame(width: 50 * fontScale)

            if !uses24h {
                ampmToggle
            }
            Spacer()
        }
        .onAppear { syncFields() }
        .onChange(of: date) { _, _ in syncFields() }
    }

    private func digitField(_ binding: Binding<String>, placeholder: String,
                            focus: Field, onCommit: @escaping (String) -> Void) -> some View {
        TextField(placeholder, text: binding)
            .textFieldStyle(.plain)
            .font(.emilio(.semibold, size: 22 * fontScale))
            .foregroundColor(GrayPalette.charcoal)
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .focused($focused, equals: focus)
            .onSubmit { onCommit(binding.wrappedValue) }
            .onChange(of: binding.wrappedValue) { _, new in
                // Strip non-digits and clamp to 2 chars.
                let filtered = String(new.filter { $0.isNumber }.prefix(2))
                if filtered != new { binding.wrappedValue = filtered }
            }
            .onChange(of: focused) { old, _ in
                if old == focus { onCommit(binding.wrappedValue) }
            }
            .padding(.vertical, 6)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(focused == focus ? GrayPalette.charcoal : GrayPalette.hairline)
                    .frame(height: focused == focus ? 1.5 : 1)
                    .animation(.easeOut(duration: 0.12), value: focused)
            }
    }

    private var ampmToggle: some View {
        HStack(spacing: 4) {
            ampmBtn("AM", selected: !isPM) { setTime(hour12: hour12, minute: minute, isPM: false) }
            ampmBtn("PM", selected: isPM) { setTime(hour12: hour12, minute: minute, isPM: true) }
        }
    }

    private func ampmBtn(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.mono(11 * fontScale, weight: .semibold))
                .foregroundColor(selected ? GrayPalette.cream : GrayPalette.textSecondary)
                .padding(.horizontal, 12 * fontScale)
                .padding(.vertical, 7 * fontScale)
                .background(Capsule().fill(selected ? GrayPalette.charcoal : Color.clear))
                .overlay(Capsule().stroke(GrayPalette.hairline, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private func setTime(hour12: Int, minute: Int, isPM: Bool) {
        var hour24 = hour12 % 12
        if isPM { hour24 += 12 }
        setHour24(hour24, minute: minute)
    }

    private func setHour24(_ h24: Int, minute: Int) {
        var comps = calendar.dateComponents([.year, .month, .day], from: date)
        comps.hour = h24
        comps.minute = minute
        comps.second = 0
        if let d = calendar.date(from: comps) {
            date = d
        }
    }

    private func syncFields() {
        hourText = String(format: uses24h ? "%02d" : "%d", displayedHour)
        minuteText = String(format: "%02d", minute)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
