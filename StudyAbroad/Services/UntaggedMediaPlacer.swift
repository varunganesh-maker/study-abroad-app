import CoreLocation
import Foundation

/// A camera roll item that has no GPS location of its own.
struct UntaggedMedia: Equatable {
    let id: String
    let takenAt: Date
    let isVideo: Bool
    var duration: Double = 0
    var pixelWidth: Int = 0
    var pixelHeight: Int = 0
}

/// Gives location-less items (often videos: saved from Instagram/WhatsApp, AirDropped,
/// or shot with location off) the location of the closest-in-time geotagged memory.
/// If you took a geotagged photo within a couple of hours, you were almost certainly in the same place.
enum UntaggedMediaPlacer {
    /// How far apart in time a borrowed location may be.
    static let defaultWindow: TimeInterval = 2 * 60 * 60

    /// Returns a new memory for every untagged item that has a geotagged neighbour within `window`.
    /// Items with no close neighbour are left out, so nothing lands in the wrong city.
    static func place(
        _ untagged: [UntaggedMedia],
        near tagged: [PhotoMemory],
        window: TimeInterval = defaultWindow
    ) -> [PhotoMemory] {
        let anchors = tagged
            .compactMap { memory in memory.takenAt.map { (date: $0, coordinate: memory.coordinate) } }
            .sorted { $0.date < $1.date }
        guard !anchors.isEmpty else { return [] }

        return untagged.compactMap { item in
            guard let nearest = closest(to: item.takenAt, in: anchors),
                  abs(nearest.date.timeIntervalSince(item.takenAt)) <= window
            else { return nil }
            return PhotoMemory(
                id: item.id,
                coordinate: nearest.coordinate,
                takenAt: item.takenAt,
                isVideo: item.isVideo,
                duration: item.duration,
                pixelWidth: item.pixelWidth,
                pixelHeight: item.pixelHeight
            )
        }
    }

    /// Binary search for the anchor closest in time. `anchors` must be sorted by date.
    private static func closest(
        to date: Date,
        in anchors: [(date: Date, coordinate: CLLocationCoordinate2D)]
    ) -> (date: Date, coordinate: CLLocationCoordinate2D)? {
        var low = 0
        var high = anchors.count
        while low < high {
            let mid = (low + high) / 2
            if anchors[mid].date < date { low = mid + 1 } else { high = mid }
        }
        let candidates = [low - 1, low].filter(anchors.indices.contains).map { anchors[$0] }
        return candidates.min { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) }
    }
}
