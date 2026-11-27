import CoreLocation
import Foundation

/// One geotagged photo or video in the camera roll.
/// The app only keeps a pointer (the Photos `localIdentifier`); the file stays in Photos.
struct PhotoMemory: Identifiable, Hashable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let takenAt: Date?
    let isVideo: Bool
    /// Length in seconds (0 for photos).
    var duration: Double = 0
    var pixelWidth: Int = 0
    var pixelHeight: Int = 0

    /// Taller than it is wide, so it can fill a phone screen without losing much.
    var isPortrait: Bool { pixelHeight > pixelWidth }

    /// "0:24" style label for videos.
    var durationText: String { Self.timeText(duration) }

    static func timeText(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func == (lhs: PhotoMemory, rhs: PhotoMemory) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
