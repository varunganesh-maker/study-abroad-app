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

    static func == (lhs: CityCluster, rhs: CityCluster) -> Bool {
        lhs.id == rhs.id && lhs.memories.count == rhs.memories.count
    }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
