import CoreLocation
import Foundation
import Photos
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// A backup of everything the app adds on top of your camera roll: captions, notes (with voice
/// recordings), removed memories, ratings and recaps, and the auto-add setting.
/// Photos and videos themselves are NOT in it (they're already in Photos / iCloud Photos).
///
/// Without the paid developer account there's no iCloud sync, so this file is the safety net:
/// save it to Files or iCloud Drive, and restore it after reinstalling or on a new phone.
struct BackupFile: Codable, Equatable {
    static let currentVersion = 1

    struct Memory: Codable, Equatable {
        var key: String
        var kind: String
        var source: String
        var caption: String
        var isHidden: Bool
        var latitude: Double?
        var longitude: Double?
        var takenAt: Date?
        var addedAt: Date
        var duration: Double
        /// Photos' cross-device id for camera roll items, so a restore on a new phone can find them.
        var cloudID: String?
        /// Voice notes: the recording itself.
        var audio: Data?
    }

    struct Place: Codable, Equatable {
        var latitude: Double
        var longitude: Double
        var arrival: Date
        var departure: Date
        var placeName: String
        var area: String?
        var city: String?
        var rating: Double?
        var recap: String
        var status: String
    }

    var version: Int = currentVersion
    var exportedAt: Date = .now
    var memories: [Memory] = []
    var visits: [Place] = []
    var autoAddMode: String?
    var autoAddStart: Date?
    var autoAddEnd: Date?

    static func decode(_ data: Data) throws -> BackupFile {
        try JSONDecoder().decode(BackupFile.self, from: data)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    var summary: String {
        let notes = memories.filter { $0.kind == PhotoMemory.Kind.text.rawValue || $0.kind == PhotoMemory.Kind.voice.rawValue }.count
        let captions = memories.filter { !$0.caption.isEmpty }.count
        let rated = visits.filter { $0.status == Visit.Status.saved.rawValue }.count
        return "\(captions) caption\(captions == 1 ? "" : "s"), \(notes) note\(notes == 1 ? "" : "s"), \(rated) rated place\(rated == 1 ? "" : "s")"
    }
}

/// Makes and restores backups.
@MainActor
enum Backup {
    struct RestoreResult: Equatable {
        var memoriesAdded = 0
        var captionsFilled = 0
        var visitsAdded = 0
        /// Camera roll items in the backup that aren't on this phone's camera roll.
        var notFound = 0

        var message: String {
            var parts = ["Restored \(memoriesAdded) memor\(memoriesAdded == 1 ? "y" : "ies")",
                         "\(captionsFilled) caption\(captionsFilled == 1 ? "" : "s")",
                         "\(visitsAdded) place\(visitsAdded == 1 ? "" : "s")"]
            if notFound > 0 { parts.append("\(notFound) photo\(notFound == 1 ? "" : "s") weren't found on this phone") }
            return parts.joined(separator: ", ") + "."
        }
    }

    /// Everything in the database right now. `cloudIDs` maps Photos ids to cross-device ids.
    static func make(context: ModelContext, cloudIDs: [String: String] = [:], rule: AutoAddRule? = nil) -> BackupFile {
        let entries = (try? context.fetch(FetchDescriptor<MemoryEntry>())) ?? []
        let visits = (try? context.fetch(FetchDescriptor<Visit>())) ?? []
        var file = BackupFile()
        file.memories = entries.map { entry in
            BackupFile.Memory(
                key: entry.key, kind: entry.kindRaw, source: entry.sourceRaw, caption: entry.caption,
                isHidden: entry.isHidden, latitude: entry.latitude, longitude: entry.longitude,
                takenAt: entry.takenAt, addedAt: entry.addedAt, duration: entry.duration,
                cloudID: entry.isNote ? nil : cloudIDs[entry.key],
                audio: entry.kind == .voice ? try? Data(contentsOf: VoiceNoteFiles.url(key: entry.key)) : nil
            )
        }
        file.visits = visits.map { visit in
            BackupFile.Place(
                latitude: visit.latitude, longitude: visit.longitude, arrival: visit.arrival,
                departure: visit.departure, placeName: visit.placeName, area: visit.area, city: visit.city,
                rating: visit.rating, recap: visit.recap, status: visit.statusRaw
            )
        }
        if let rule {
            file.autoAddMode = rule.mode.rawValue
            file.autoAddStart = rule.start
            file.autoAddEnd = rule.end
        }
        return file
    }

    /// Adds what's in the backup to the database without overwriting anything you've changed
    /// since: existing memories only get a caption if theirs is empty; existing visits are skipped.
    /// `localIDs` maps a backup's camera roll keys to ids on this phone (for a new phone);
    /// `assetExists` says whether a camera roll id is on this phone.
    static func restore(
        _ file: BackupFile,
        into context: ModelContext,
        localIDs: [String: String] = [:],
        assetExists: (String) -> Bool = { _ in true }
    ) -> RestoreResult {
        var result = RestoreResult()
        let entries = (try? context.fetch(FetchDescriptor<MemoryEntry>())) ?? []
        var byKey = Dictionary(entries.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })

        for memory in file.memories {
            let isNote = memory.kind == PhotoMemory.Kind.text.rawValue || memory.kind == PhotoMemory.Kind.voice.rawValue
            // The file could have been edited: only accept well-formed note names (they become file names)
            // and real coordinates.
            if isNote && !isValidNoteKey(memory.key) { continue }
            if let lat = memory.latitude, let lon = memory.longitude,
               !CapturePlacement.isUsable(CLLocationCoordinate2D(latitude: lat, longitude: lon)) { continue }
            var key = memory.key
            if !isNote {
                if !assetExists(key), let mapped = localIDs[key] { key = mapped }
                guard assetExists(key) else {
                    result.notFound += 1
                    continue
                }
            }
            if let existing = byKey[key] {
                if existing.caption.isEmpty && !memory.caption.isEmpty {
                    existing.caption = memory.caption
                    result.captionsFilled += 1
                }
                continue
            }
            let entry = MemoryEntry(key: key, kind: PhotoMemory.Kind(rawValue: memory.kind) ?? .photo,
                                    source: MemoryEntry.Source(rawValue: memory.source) ?? .picker)
            entry.caption = memory.caption
            entry.isHidden = memory.isHidden
            entry.latitude = memory.latitude
            entry.longitude = memory.longitude
            entry.takenAt = memory.takenAt
            entry.addedAt = memory.addedAt
            entry.duration = memory.duration
            if entry.kind == .voice, let audio = memory.audio { try? audio.write(to: VoiceNoteFiles.url(key: key)) }
            context.insert(entry)
            byKey[key] = entry
            result.memoriesAdded += 1
            if !isNote && !memory.caption.isEmpty { result.captionsFilled += 1 }
        }

        let visits = (try? context.fetch(FetchDescriptor<Visit>())) ?? []
        for place in file.visits {
            guard CapturePlacement.isUsable(CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude))
            else { continue }
            let duplicate = visits.contains {
                abs($0.arrival.timeIntervalSince(place.arrival)) < 60
                    && abs($0.latitude - place.latitude) < 0.0005 && abs($0.longitude - place.longitude) < 0.0005
            }
            guard !duplicate else { continue }
            let visit = Visit(coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                              arrival: place.arrival, departure: place.departure)
            visit.placeName = place.placeName
            visit.area = place.area
            visit.city = place.city
            visit.rating = place.rating.map { min(10, max(0, $0)) }
            visit.recap = place.recap
            visit.statusRaw = place.status
            context.insert(visit)
            result.visitsAdded += 1
        }
        try? context.save()
        return result
    }

    /// "note-" followed by a UUID, nothing else (so it can't point outside the voice notes folder).
    nonisolated static func isValidNoteKey(_ key: String) -> Bool {
        guard key.hasPrefix("note-") else { return false }
        return UUID(uuidString: String(key.dropFirst(5))) != nil
    }

    // MARK: Photos ids that work across phones

    /// Slow for big libraries, so call it off the main thread; asks Photos 500 ids at a time.
    nonisolated static func cloudIDs(for localIDs: [String]) -> [String: String] {
        var result: [String: String] = [:]
        var start = 0
        while start < localIDs.count {
            let chunk = Array(localIDs[start..<min(start + 500, localIDs.count)])
            let mappings = PHPhotoLibrary.shared().cloudIdentifierMappings(forLocalIdentifiers: chunk)
            for (local, mapping) in mappings {
                if case .success(let cloud) = mapping { result[local] = cloud.stringValue }
            }
            start += 500
        }
        return result
    }

    /// For a backup's camera roll items that aren't on this phone under their old id,
    /// asks Photos for this phone's id (works when both phones use iCloud Photos).
    static func localIDs(for file: BackupFile) -> [String: String] {
        let missing = file.memories.filter { $0.cloudID != nil && !assetExists($0.key) }
        guard !missing.isEmpty else { return [:] }
        let clouds = missing.compactMap { $0.cloudID.map(PHCloudIdentifier.init(stringValue:)) }
        let mappings = PHPhotoLibrary.shared().localIdentifierMappings(for: clouds)
        var byCloud: [String: String] = [:]
        for (cloud, mapping) in mappings {
            if case .success(let local) = mapping { byCloud[cloud.stringValue] = local }
        }
        var result: [String: String] = [:]
        for memory in missing {
            if let cloud = memory.cloudID, let local = byCloud[cloud] { result[memory.key] = local }
        }
        return result
    }

    static func assetExists(_ id: String) -> Bool {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).count > 0
    }

    static var suggestedFilename: String {
        "Study Abroad backup \(Date.now.formatted(.iso8601.year().month().day()))"
    }
}

/// Lets the system "Save to Files" sheet write the backup.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
