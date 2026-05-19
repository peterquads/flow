import Foundation

/// DateFormatter is heavyweight to instantiate. Reuse a small set of cached
/// instances so we don't allocate one per body render or per tooltip frame.
enum SharedFormatters {
    static let dayMonth: DateFormatter = make("EEE, MMM d")
    static let time12: DateFormatter = make("h:mm a")
    static let monthYear: DateFormatter = make("MMMM yyyy")
    static let intervalShort: DateFormatter = make("EEE h:mm a")
    static let dayKey: DateFormatter = make("yyyy-MM-dd")
    static let bucketHour: DateFormatter = make("ha")
    static let bucketDay: DateFormatter = make("EEE d MMM")
    static let bucketWeek: DateFormatter = make("'Wk of' d MMM")
    static let csvLocal: DateFormatter = {
        let f = make("yyyy-MM-dd HH:mm:ss")
        f.timeZone = TimeZone.current
        return f
    }()

    private static func make(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale.autoupdatingCurrent
        f.dateFormat = format
        return f
    }
}
