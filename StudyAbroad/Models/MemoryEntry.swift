import CoreLocation
import Foundation
import SwiftData

/// One memory saved in the app's own database (SwiftData, on the phone).
///
/// - For a camera roll photo or video it is only a pointer (`key` = the Photos `localIdentifier`)
///   plus what the app adds on top: the caption, and whether you removed it from the app.
///   The picture itself always stays in Photos.
/// - For a text or voice note it is the whole memory: the words, where and when.
///
/// Every property has a default and nothing is marked unique, so iCloud sync (CloudKit) can be
/// switched on later without a database migration.
@Model
final class MemoryEntry {
    enum Source: String, Codable {
        /// Added by the "Add new photos automatically" setting.
        case autoAdd
        /// Picked from the camera roll.
        case picker
        /// Taken with the in-app camera.
        case camera
        /// A text or voice note written in the app.
        case note
    }

    /// Photos `localIdentifier`, or "note-<uuid>" for notes. Same as `PhotoMemory.id`.
    var key: String = ""
    var kindRaw: String = PhotoMemory.Kind.photo.rawValue
    var sourceRaw: String = Source.autoAdd.rawValue
    /// Any length. For a text note this is the note itself.
    var caption: String = ""
    /// "Remove from app": hidden here, still in your camera roll.
    var isHidden: Bool = false
    /// Where it goes on the map, when Photos doesn't know (notes, or a picked photo with no GPS).
    var latitude: Double?
    var longitude: Double?
    /// When it happened, for notes (camera roll items use the date from Photos).
    var takenAt: Date?
    var addedAt: Date = Date.now
    /// Voice notes: length in seconds.
    var duration: Double = 0

    init(key: String, kind: PhotoMemory.Kind, source: Source) {
        self.key = key
        self.kindRaw = kind.rawValue
        self.sourceRaw = source.rawValue
        self.addedAt = .now
    }

    var kind: PhotoMemory.Kind {
        get { PhotoMemory.Kind(rawValue: kindRaw) ?? .photo }
        set { kindRaw = newValue.rawValue }
    }

    var source: Source {
        get { Source(rawValue: sourceRaw) ?? .autoAdd }
        set { sourceRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D? {
        get {
            guard let latitude, let longitude else { return nil }
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
        set {
            latitude = newValue?.latitude
            longitude = newValue?.longitude
        }
    }

    var isNote: Bool { kind == .text || kind == .voice }

    /// The note as a memory for the map, or nil if it has no place yet.
    var noteMemory: PhotoMemory? {
        guard isNote, !isHidden, let coordinate else { return nil }
        return PhotoMemory(id: key, coordinate: coordinate, takenAt: takenAt ?? addedAt, kind: kind, duration: duration)
    }

    static func newNoteKey() -> String { "note-\(UUID().uuidString)" }
}
