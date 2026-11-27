import Foundation

/// The "Add new photos automatically" setting.
/// Apple doesn't let apps hook into the Camera app, so instead the app files new camera roll
/// photos and videos on its own each time it opens, following this rule.
struct AutoAddRule: Equatable {
    enum Mode: String, CaseIterable, Identifiable {
        /// Every photo and video that has a location (what the app always did).
        case all
        /// From a chosen day on ("from now on").
        case from
        /// Only between two days (e.g. a trip).
        case between
        /// Nothing automatic: only what you add yourself.
        case off

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: "All photos"
            case .from: "From a date on"
            case .between: "Between dates"
            case .off: "Off"
            }
        }

        var explanation: String {
            switch self {
            case .all: "Every photo and video with a location goes on your map."
            case .from: "New photos and videos from this day on are added each time you open the app."
            case .between: "Only photos and videos taken between these days are added. Handy for a trip."
            case .off: "Nothing is added automatically. Use ＋ to add photos yourself."
            }
        }
    }

    var mode: Mode = .all
    var start: Date = .now
    var end: Date = .now

    /// Whether a camera roll item taken at `date` should be added automatically.
    /// Days are whole days in the phone's time zone, so "Between 1 and 3 March" includes all of 3 March.
    func includes(_ date: Date?, calendar: Calendar = .current) -> Bool {
        switch mode {
        case .all:
            return true
        case .off:
            return false
        case .from:
            guard let date else { return false }
            return date >= calendar.startOfDay(for: start)
        case .between:
            guard let date else { return false }
            let first = calendar.startOfDay(for: min(start, end))
            guard let afterLast = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: max(start, end)))
            else { return false }
            return date >= first && date < afterLast
        }
    }

    // MARK: Saving the setting

    static let modeKey = "autoAdd.mode"
    static let startKey = "autoAdd.start"
    static let endKey = "autoAdd.end"

    static func load(from defaults: UserDefaults = .standard) -> AutoAddRule {
        var rule = AutoAddRule()
        if let raw = defaults.string(forKey: modeKey), let mode = Mode(rawValue: raw) { rule.mode = mode }
        if let start = defaults.object(forKey: startKey) as? Date { rule.start = start }
        if let end = defaults.object(forKey: endKey) as? Date { rule.end = end }
        return rule
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: Self.modeKey)
        defaults.set(start, forKey: Self.startKey)
        defaults.set(end, forKey: Self.endKey)
    }
}
