import CoreLocation
import Foundation

/// All the memories that belong to one city, e.g. "Sydney, Australia".
struct CityCluster: Identifiable, Hashable {
    /// Stable key, e.g. "Sydney|Australia".
    let id: String
    let name: String
    let country: String?
    let center: CLLocationCoordinate2D
    /// Newest first.
    let memories: [PhotoMemory]

    var cover: PhotoMemory? { memories.first }
    var photoCount: Int { memories.filter { !$0.isVideo }.count }
    var videoCount: Int { memories.filter { $0.isVideo }.count }

    var subtitle: String {
        var parts: [String] = []
        if photoCount > 0 { parts.append("\(photoCount) photo\(photoCount == 1 ? "" : "s")") }
        if videoCount > 0 { parts.append("\(videoCount) video\(videoCount == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    var dateRangeText: String? {
        let dates = memories.compactMap(\.takenAt)
        guard let first = dates.min(), let last = dates.max() else { return nil }
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        let a = f.string(from: first), b = f.string(from: last)
        return a == b ? a : "\(a) – \(b)"
    }

    /// Memories grouped by calendar day, oldest day first (so the city reads like a story).
    var days: [MemoryDay] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: memories) { memory in
            memory.takenAt.map { calendar.startOfDay(for: $0) }
        }
        return grouped
            .map { date, items in
                MemoryDay(date: date, memories: items.sorted { ($0.takenAt ?? .distantPast) < ($1.takenAt ?? .distantPast) })
            }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
    }

    /// Number of different days with at least one memory.
    var dayCount: Int {
        let calendar = Calendar.current
        return Set(memories.compactMap { $0.takenAt.map { calendar.startOfDay(for: $0) } }).count
    }

    /// "128 memories · 12 days"
    var statsText: String {
        let m = memories.count, d = dayCount
        var text = "\(m) memor\(m == 1 ? "y" : "ies")"
        if d > 0 { text += " · \(d) day\(d == 1 ? "" : "s")" }
        return text
    }

    static func == (lhs: CityCluster, rhs: CityCluster) -> Bool {
        lhs.id == rhs.id && lhs.memories.count == rhs.memories.count
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

/// One day's worth of memories in a city.
struct MemoryDay: Identifiable, Hashable {
    /// Start of the day, or nil for items with no date.
    let date: Date?
    /// Oldest first.
    let memories: [PhotoMemory]

    var id: Date { date ?? .distantFuture }

    /// The best picture to put on the day's card: the first photo, else the first video.
    var cover: PhotoMemory? { memories.first { !$0.isVideo } ?? memories.first }

    /// "Monday, 24 February"
    var longTitle: String {
        date?.formatted(.dateTime.weekday(.wide).day().month(.wide)) ?? "Unknown date"
    }

    /// "Tue 25"
    var shortTitle: String {
        date?.formatted(.dateTime.weekday(.abbreviated).day()) ?? "Undated"
    }

    /// "18 moments"
    var momentsText: String {
        "\(memories.count) moment\(memories.count == 1 ? "" : "s")"
    }
}
