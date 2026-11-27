import CoreLocation
import Foundation

/// One geotagged photo or video in the camera roll.
/// The app only keeps a pointer (the Photos `localIdentifier`); the file stays in Photos.
struct PhotoMemory: Identifiable, Hashable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let takenAt: Date?
    let isVideo: Bool

    static func == (lhs: PhotoMemory, rhs: PhotoMemory) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
