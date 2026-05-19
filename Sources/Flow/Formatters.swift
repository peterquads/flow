import Foundation

/// DateFormatter is heavyweight to instantiate. Reuse a small set of cached
/// instances so we don't allocate one per body render or per tooltip frame.
enum SharedFormatters {
    static let dayMonth: DateFormatter = make("EEE, MMM d")
    static let longDate: DateFormatter = make("EEEE, MMMM d")
    static let monthYear: DateFormatter = make("MMMM yyyy")
    static let dayKey: DateFormatter = make("yyyy-MM-dd")
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

extension Locale {
    /// Mirrors System Settings → General → Date & Time → "24-Hour Time".
    /// Used everywhere we render a wall-clock time so the whole tool follows
    /// the user's system preference.
    var uses24HourTime: Bool {
        switch hourCycle {
        case .zeroToTwentyThree, .oneToTwentyFour: return true
        case .zeroToEleven, .oneToTwelve: return false
        @unknown default: return false
        }
    }
}
