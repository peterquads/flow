import SwiftUI

/// Big Emilio time numerals rendered as editable text fields. Used as the
/// inline editor for an open endpoint — click "11:11 AM" and the digits
/// themselves become typeable, no second input box. Follows the system
/// 12h/24h preference.
struct TimeNumeralsEditor: View {
    @Binding var date: Date
    let fontScale: CGFloat

    @State private var hourText: String = ""
    @State private var minuteText: String = ""
    @FocusState private var focus: Field?

    enum Field { case hour, minute }

    private var cal: Calendar { Calendar.current }
    private var uses24h: Bool { Locale.current.uses24HourTime }
    private var hour24: Int { cal.component(.hour, from: date) }
    private var minute: Int { cal.component(.minute, from: date) }
    private var hour12: Int { let h = hour24 % 12; return h == 0 ? 12 : h }
    private var displayedHour: Int { uses24h ? hour24 : hour12 }
    private var isPM: Bool { hour24 >= 12 }

    private var hourFieldWidth: CGFloat { (uses24h ? 50 : 44) * fontScale }
    private var minuteFieldWidth: CGFloat { 50 * fontScale }

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6 * fontScale) {
            HStack(spacing: 0) {
                digitField(.hour)
                Text(":")
                    .font(.emilio(.semibold, size: 34 * fontScale))
                    .foregroundColor(GrayPalette.charcoal)
                    .monospacedDigit()
                    .padding(.horizontal, 2)
                digitField(.minute)
            }
            if !uses24h {
                ampmToggle
            }
        }
        .onAppear {
            syncFields()
            // Defer focus so the field is mounted before we grab it.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                focus = .hour
            }
        }
        .onChange(of: date) { _, _ in syncFields() }
    }

    private func digitField(_ field: Field) -> some View {
        let binding = field == .hour ? $hourText : $minuteText
        let width = field == .hour ? hourFieldWidth : minuteFieldWidth
        return TextField("", text: binding)
            .textFieldStyle(.plain)
            .font(.emilio(.semibold, size: 34 * fontScale))
            .foregroundColor(GrayPalette.charcoal)
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .frame(width: width)
            .focused($focus, equals: field)
            .onChange(of: binding.wrappedValue) { _, new in
                let filtered = String(new.filter { $0.isNumber }.prefix(2))
                if filtered != new { binding.wrappedValue = filtered }
                if filtered.count == 2 && field == .hour { focus = .minute }
            }
            .onSubmit {
                commit(field)
                if field == .hour { focus = .minute } else { focus = nil }
            }
            .onChange(of: focus) { old, _ in
                if let o = old { commit(o) }
            }
    }

    private var ampmToggle: some View {
        HStack(spacing: 4 * fontScale) {
            ampmBtn("AM", selected: !isPM) {
                setTime(hour12: hour12, minute: minute, isPM: false)
            }
            ampmBtn("PM", selected: isPM) {
                setTime(hour12: hour12, minute: minute, isPM: true)
            }
        }
        .padding(.leading, 4 * fontScale)
    }

    private func ampmBtn(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.mono(10 * fontScale, weight: .semibold))
                .tracking(1)
                .foregroundColor(selected ? GrayPalette.cream : GrayPalette.textSecondary)
                .padding(.horizontal, 9 * fontScale)
                .padding(.vertical, 5 * fontScale)
                .background(Capsule().fill(selected ? GrayPalette.charcoal : Color.clear))
                .overlay(Capsule().stroke(GrayPalette.hairline, lineWidth: selected ? 0 : 1))
        }
        .buttonStyle(.plain)
    }

    private func commit(_ field: Field) {
        switch field {
        case .hour:
            guard let i = Int(hourText) else { syncFields(); return }
            if uses24h, i >= 0 && i <= 23 {
                setHour24(i, minute: minute)
            } else if !uses24h, i >= 1 && i <= 12 {
                setTime(hour12: i, minute: minute, isPM: isPM)
            }
            syncFields()
        case .minute:
            guard let i = Int(minuteText), i >= 0 && i <= 59 else { syncFields(); return }
            if uses24h {
                setHour24(hour24, minute: i)
            } else {
                setTime(hour12: hour12, minute: i, isPM: isPM)
            }
            syncFields()
        }
    }

    private func setTime(hour12: Int, minute: Int, isPM: Bool) {
        var h = hour12 % 12
        if isPM { h += 12 }
        setHour24(h, minute: minute)
    }

    private func setHour24(_ h: Int, minute: Int) {
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = h
        comps.minute = minute
        comps.second = 0
        if let d = cal.date(from: comps) { date = d }
    }

    private func syncFields() {
        hourText = String(format: uses24h ? "%02d" : "%d", displayedHour)
        minuteText = String(format: "%02d", minute)
    }
}
