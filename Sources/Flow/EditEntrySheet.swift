import SwiftUI

// MARK: - EditEntrySheet
//
// Opened from a right-click on a breakdown row. Lists the intervals that
// contributed to that row within the current range; each can be retimed or
// removed. Visual language matches ManualEntrySheet (cream surface, Emilio
// numerals, mono labels, endpoint cards + inline picker + quick chips).

struct EditEntrySheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let taskName: String
    let range: ChartRange
    var fontScale: CGFloat = 1.0

    @State private var selectedID: UUID? = nil
    @State private var draftStart: Date = Date()
    @State private var draftEnd: Date = Date()
    @State private var openPicker: Endpoint? = nil
    @State private var confirmDeleteID: UUID? = nil

    enum Endpoint { case start, end }

    private let quickDurations: [Int] = [15, 30, 45, 60, 90, 120, 180, 240]

    private var refs: [AppStore.IntervalRef] {
        store.intervalRefs(forBreakdownNamed: taskName, range: range)
    }

    private var selectedRef: AppStore.IntervalRef? {
        refs.first(where: { $0.id == selectedID })
    }

    private var durationMinutes: Int {
        max(0, Int(draftEnd.timeIntervalSince(draftStart) / 60))
    }

    private var hasChanges: Bool {
        guard let ref = selectedRef, let end = ref.end else { return false }
        return draftStart != ref.start || draftEnd != end
    }

    private var canSave: Bool {
        selectedRef != nil && draftEnd > draftStart && hasChanges
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            divider
            if refs.isEmpty {
                emptyState
            } else {
                if refs.count > 1 {
                    intervalList
                    divider
                }
                if selectedRef != nil {
                    endpointsBlock
                    if let endpoint = openPicker {
                        inlinePicker(endpoint)
                    }
                    divider
                    quickChipsBlock
                }
            }
            Spacer(minLength: 24 * fontScale)
            actions
        }
        .padding(.horizontal, 32 * fontScale)
        .padding(.vertical, 28 * fontScale)
        .frame(width: 540 * fontScale)
        .background(GrayPalette.cream)
        .onAppear { selectInitialInterval() }
        .alert("Delete this entry?", isPresented: deleteAlertBinding) {
            Button("Cancel", role: .cancel) { confirmDeleteID = nil }
            Button("Delete", role: .destructive) { performDelete() }
        } message: {
            Text("This will permanently remove the time recorded for this interval.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(GrayPalette.color(forName: taskName))
                        .frame(width: 10 * fontScale, height: 10 * fontScale)
                    Text("Edit entry")
                        .font(.emilio(.semibold, size: 22 * fontScale))
                        .foregroundColor(GrayPalette.charcoal)
                }
                Text(headerSubtitle)
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

    private var headerSubtitle: String {
        let trimmed = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        if refs.count <= 1 { return trimmed }
        return "\(trimmed) · \(refs.count) entries in \(range.title.lowercased())"
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 10 * fontScale) {
            Text("No entries to edit in this range.")
                .font(.mono(12 * fontScale))
                .foregroundColor(GrayPalette.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40 * fontScale)
    }

    // MARK: - Interval list (only when multiple)

    private var intervalList: some View {
        VStack(alignment: .leading, spacing: 6 * fontScale) {
            Text("ENTRIES")
                .font(.mono(9 * fontScale, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(GrayPalette.muted)
                .padding(.top, 18 * fontScale)
            VStack(spacing: 4 * fontScale) {
                ForEach(refs) { ref in
                    intervalRow(ref)
                }
            }
            .padding(.bottom, 14 * fontScale)
        }
    }

    private func intervalRow(_ ref: AppStore.IntervalRef) -> some View {
        let selected = ref.id == selectedID
        let isOpen = ref.end == nil
        return Button(action: { select(ref) }) {
            HStack(spacing: 10 * fontScale) {
                Text(intervalLineFormatter.string(from: ref.start))
                    .font(.mono(12 * fontScale))
                    .foregroundColor(GrayPalette.textSecondary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 9 * fontScale, weight: .medium))
                    .foregroundColor(GrayPalette.muted)
                Text(ref.end.map { intervalLineFormatter.string(from: $0) } ?? "now")
                    .font(.mono(12 * fontScale))
                    .foregroundColor(GrayPalette.textSecondary)
                Spacer()
                Text(formatDurationLabel(intervalMinutes(ref)))
                    .font(.mono(11 * fontScale, weight: .semibold))
                    .foregroundColor(selected ? GrayPalette.charcoal : GrayPalette.muted)
                    .monospacedDigit()
                if isOpen {
                    Text("LIVE")
                        .font(.mono(8 * fontScale, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(GrayPalette.charcoal))
                }
            }
            .padding(.horizontal, 12 * fontScale)
            .padding(.vertical, 10 * fontScale)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? GrayPalette.creamDeep.opacity(0.7) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? GrayPalette.charcoal.opacity(0.25) : GrayPalette.hairline.opacity(0.6),
                            lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isOpen)
        .opacity(isOpen ? 0.55 : 1.0)
    }

    private func intervalMinutes(_ ref: AppStore.IntervalRef) -> Int {
        let end = ref.end ?? Date()
        return max(0, Int(end.timeIntervalSince(ref.start) / 60))
    }

    // MARK: - Endpoints

    private var endpointsBlock: some View {
        HStack(alignment: .bottom, spacing: 16 * fontScale) {
            endpointButton(.start)
            middleDuration
            endpointButton(.end)
        }
        .padding(.vertical, 20 * fontScale)
    }

    private func endpointButton(_ endpoint: Endpoint) -> some View {
        let date = endpoint == .start ? draftStart : draftEnd
        let isOpen = openPicker == endpoint
        let label = endpoint == .start ? "STARTED" : "ENDED"

        return Button(action: { toggle(endpoint) }) {
            VStack(alignment: .leading, spacing: 6 * fontScale) {
                HStack(spacing: 6) {
                    Text(label)
                        .font(.mono(9 * fontScale, weight: .semibold))
                        .tracking(1.5)
                        .foregroundColor(GrayPalette.muted)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7 * fontScale, weight: .semibold))
                        .foregroundColor(GrayPalette.muted)
                }
                Text(dateLineFormatter.string(from: date))
                    .font(.mono(11 * fontScale))
                    .foregroundColor(GrayPalette.textSecondary)
                Text(timeLineFormatter.string(from: date))
                    .font(.emilio(.semibold, size: 26 * fontScale))
                    .foregroundColor(GrayPalette.charcoal)
                    .monospacedDigit()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14 * fontScale)
            .padding(.vertical, 12 * fontScale)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isOpen ? GrayPalette.creamDeep.opacity(0.7) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var middleDuration: some View {
        VStack(spacing: 4 * fontScale) {
            Text(formatDurationLabel(durationMinutes))
                .font(.mono(10 * fontScale, weight: .semibold))
                .tracking(0.5)
                .foregroundColor(GrayPalette.muted)
                .monospacedDigit()
            Image(systemName: "arrow.right")
                .font(.system(size: 13 * fontScale, weight: .medium))
                .foregroundColor(GrayPalette.textSecondary)
        }
        .padding(.bottom, 18 * fontScale)
        .fixedSize()
    }

    private func toggle(_ endpoint: Endpoint) {
        if openPicker == endpoint { openPicker = nil } else { openPicker = endpoint }
    }

    @ViewBuilder
    private func inlinePicker(_ endpoint: Endpoint) -> some View {
        InlineDateTimePicker(
            date: endpoint == .start
                ? Binding(get: { draftStart }, set: { newValue in
                    draftStart = newValue
                    if draftEnd < draftStart { draftEnd = draftStart.addingTimeInterval(30 * 60) }
                })
                : Binding(get: { draftEnd }, set: { newValue in
                    draftEnd = newValue
                    if draftEnd < draftStart { draftStart = draftEnd.addingTimeInterval(-30 * 60) }
                }),
            fontScale: fontScale,
            allowFuture: false
        )
        .padding(.vertical, 18 * fontScale)
        .padding(.horizontal, 4 * fontScale)
    }

    // MARK: - Quick chips

    private var quickChipsBlock: some View {
        VStack(alignment: .leading, spacing: 12 * fontScale) {
            Text("DURATION")
                .font(.mono(9 * fontScale, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(GrayPalette.muted)
            HStack(spacing: 6 * fontScale) {
                ForEach(quickDurations, id: \.self) { m in
                    let selected = m == durationMinutes
                    Button(action: {
                        draftEnd = draftStart.addingTimeInterval(TimeInterval(m * 60))
                        if draftEnd > Date() {
                            draftEnd = Date()
                            draftStart = draftEnd.addingTimeInterval(TimeInterval(-m * 60))
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
        }
        .padding(.vertical, 18 * fontScale)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack {
            if selectedRef != nil, selectedRef?.end != nil {
                Button(action: { confirmDeleteID = selectedID }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 11 * fontScale, weight: .medium))
                        Text("Delete")
                            .font(.mono(12 * fontScale, weight: .medium))
                    }
                    .foregroundColor(GrayPalette.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
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
                Text("Save")
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

    // MARK: - Behavior

    private func selectInitialInterval() {
        // Prefer the most recent closed interval; fall back to the first ref.
        let closed = refs.filter { $0.end != nil }
        if let pick = closed.last ?? refs.first {
            select(pick)
        }
    }

    private func select(_ ref: AppStore.IntervalRef) {
        guard let end = ref.end else { return } // can't edit the live one
        selectedID = ref.id
        draftStart = ref.start
        draftEnd = end
        openPicker = nil
    }

    private func save() {
        guard let ref = selectedRef, canSave else { return }
        store.updateInterval(taskID: ref.taskID, intervalID: ref.id,
                             start: draftStart, end: draftEnd)
        dismiss()
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { confirmDeleteID != nil },
            set: { if !$0 { confirmDeleteID = nil } }
        )
    }

    private func performDelete() {
        guard let id = confirmDeleteID,
              let ref = refs.first(where: { $0.id == id }) else { return }
        store.deleteInterval(taskID: ref.taskID, intervalID: ref.id)
        confirmDeleteID = nil
        dismiss()
    }

    // MARK: - Helpers

    private var divider: some View {
        Rectangle()
            .fill(GrayPalette.hairline.opacity(0.5))
            .frame(height: 1)
    }

    private var dateLineFormatter: DateFormatter { SharedFormatters.dayMonth }
    private var timeLineFormatter: DateFormatter { SharedFormatters.time12 }
    private var intervalLineFormatter: DateFormatter { SharedFormatters.intervalShort }

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
