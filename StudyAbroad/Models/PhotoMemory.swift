import CoreLocation
import Foundation

/// One memory on the map: a photo or video from the camera roll, or a text / voice note made in the app.
/// For photos and videos the app only keeps a pointer (the Photos `localIdentifier`); the file stays in Photos.
struct PhotoMemory: Identifiable, Hashable {
    enum Kind: String, Codable {
        case photo, video
        /// Words only, written in the app.
        case text
        /// A voice recording saved inside the app (never in the camera roll).
        case voice
    }

    /// Photos `localIdentifier` for photos/videos, or "note-…" for notes.
    let id: String
    let coordinate: CLLocationCoordinate2D
    let takenAt: Date?
    let kind: Kind
    /// Length in seconds (0 for photos and text notes).
    var duration: Double = 0
    var pixelWidth: Int = 0
    var pixelHeight: Int = 0

    init(id: String, coordinate: CLLocationCoordinate2D, takenAt: Date?, kind: Kind,
         duration: Double = 0, pixelWidth: Int = 0, pixelHeight: Int = 0) {
        self.id = id
        self.coordinate = coordinate
        self.takenAt = takenAt
        self.kind = kind
        self.duration = duration
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }

    /// Camera roll item (photo or video).
    init(id: String, coordinate: CLLocationCoordinate2D, takenAt: Date?, isVideo: Bool,
         duration: Double = 0, pixelWidth: Int = 0, pixelHeight: Int = 0) {
        self.init(id: id, coordinate: coordinate, takenAt: takenAt, kind: isVideo ? .video : .photo,
                  duration: duration, pixelWidth: pixelWidth, pixelHeight: pixelHeight)
    }

    var isVideo: Bool { kind == .video }
    var isPhoto: Bool { kind == .photo }
    /// Made in the app (text or voice), not from the camera roll.
    var isNote: Bool { kind == .text || kind == .voice }
    /// Something you can press play on.
    var isPlayable: Bool { kind == .video || kind == .voice }

    /// Taller than it is wide, so it can fill a phone screen without losing much.
    var isPortrait: Bool { pixelHeight > pixelWidth }

    /// "0:24" style label for videos and voice notes.
    var durationText: String { Self.timeText(duration) }

    /// "Photo", "Video", "Note", "Voice note"
    var kindName: String {
        switch kind {
        case .photo: "Photo"
        case .video: "Video"
        case .text: "Note"
        case .voice: "Voice note"
        }
    }

    static func timeText(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func == (lhs: PhotoMemory, rhs: PhotoMemory) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
