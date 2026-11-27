import CoreLocation
import Foundation
import SwiftData

/// Reads and writes the app's saved memories (`MemoryEntry`) in SwiftData.
/// Keeps an in-memory index by key, so checking "is this photo already in the app?" is instant
/// even with thousands of photos.
@MainActor
final class MemoryLibrary {
    let context: ModelContext
    private var entries: [String: MemoryEntry] = [:]

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    /// Re-reads every entry from the database (after restoring a backup).
    func reload() {
        entries = [:]
        let all = (try? context.fetch(FetchDescriptor<MemoryEntry>())) ?? []
        for entry in all {
            if entries[entry.key] == nil {
                entries[entry.key] = entry
            } else {
                context.delete(entry) // a duplicate should never happen; tidy it up if it does
            }
        }
    }

    var count: Int { entries.count }

    func allKeys(includingNotes: Bool) -> [String] {
        entries.values.filter { includingNotes || !$0.isNote }.map(\.key)
    }

    func entry(for key: String) -> MemoryEntry? { entries[key] }

    func contains(_ key: String) -> Bool { entries[key] != nil }

    /// Every non-empty caption, by memory id.
    var captions: [String: String] {
        var result: [String: String] = [:]
        for (key, entry) in entries where !entry.caption.isEmpty { result[key] = entry.caption }
        return result
    }

    // MARK: Camera roll items

    /// Saves every scanned item the rule allows that isn't in the app yet.
    /// Items you removed stay removed. Returns how many were added.
    @discardableResult
    func autoAdd(_ scanned: [PhotoMemory], rule: AutoAddRule) async -> Int {
        guard rule.mode != .off else { return 0 }
        var added = 0
        for memory in scanned where entries[memory.id] == nil && rule.includes(memory.takenAt) {
            let entry = MemoryEntry(key: memory.id, kind: memory.kind, source: .autoAdd)
            context.insert(entry)
            entries[memory.id] = entry
            added += 1
            if added % 500 == 0 {
                // First launch can add thousands at once: save in chunks and let the screen breathe.
                save()
                await Task.yield()
            }
        }
        if added > 0 { save() }
        return added
    }

    /// Adds (or brings back) a photo or video you chose yourself.
    /// `coordinate` is only needed when Photos has no location for it.
    @discardableResult
    func addAsset(_ id: String, kind: PhotoMemory.Kind, source: MemoryEntry.Source,
                  coordinate: CLLocationCoordinate2D?) -> MemoryEntry {
        let entry: MemoryEntry
        if let existing = entries[id] {
            entry = existing
            entry.isHidden = false
            // You chose it just now, so it counts as "recently added" even if auto-add saved it before.
            entry.source = source
            entry.addedAt = .now
        } else {
            entry = MemoryEntry(key: id, kind: kind, source: source)
            context.insert(entry)
            entries[id] = entry
        }
        if let coordinate { entry.coordinate = coordinate }
        save()
        return entry
    }

    // MARK: Notes

    /// Saves a text or voice note and returns its key.
    @discardableResult
    func addNote(kind: PhotoMemory.Kind, text: String, coordinate: CLLocationCoordinate2D?,
                 takenAt: Date, duration: Double = 0, key: String = MemoryEntry.newNoteKey()) -> String {
        let entry = MemoryEntry(key: key, kind: kind, source: .note)
        entry.caption = text
        entry.coordinate = coordinate
        entry.takenAt = takenAt
        entry.duration = duration
        context.insert(entry)
        entries[key] = entry
        save()
        return key
    }

    // MARK: Captions, removing

    /// Saves a caption (any length). Leading/trailing blank lines are trimmed.
    func setCaption(_ text: String, for key: String) {
        guard let entry = entries[key] else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard entry.caption != trimmed else { return }
        entry.caption = trimmed
        save()
    }

    /// "Remove from app". Photos and videos stay in your camera roll and their caption is kept,
    /// in case you add them back. Notes only exist in the app, so they are deleted for good.
    func remove(_ key: String) {
        guard let entry = entries[key] else { return }
        if entry.isNote {
            if entry.kind == .voice { VoiceNoteFiles.delete(key: key) }
            context.delete(entry)
            entries[key] = nil
        } else {
            entry.isHidden = true
        }
        save()
    }

    var hiddenCount: Int { entries.values.filter(\.isHidden).count }

    func unhideAll() {
        for entry in entries.values where entry.isHidden { entry.isHidden = false }
        save()
    }

    // MARK: Recently added

    /// Keys of memories you added yourself (camera, picker, notes) since `date`, newest first.
    /// Auto-added photos and removed ones are left out.
    func recentlyAddedKeys(since date: Date) -> [String] {
        entries.values
            .filter { $0.source != .autoAdd && !$0.isHidden && $0.addedAt >= date }
            .sorted { $0.addedAt > $1.addedAt }
            .map(\.key)
    }

    // MARK: What goes on the map

    /// Which memories to show, given what the camera roll scan found.
    /// - `memories`: scanned items that are in the app (not removed), plus notes.
    /// - `missing`: items you added by hand that the scan didn't place (no GPS); the store
    ///   looks these up in Photos and puts them where `coordinate` says.
    func visible(scanned: [PhotoMemory]) -> (memories: [PhotoMemory], missing: [String: CLLocationCoordinate2D]) {
        var memories: [PhotoMemory] = []
        var seen = Set<String>()
        for memory in scanned {
            guard let entry = entries[memory.id], !entry.isHidden else { continue }
            memories.append(memory)
            seen.insert(memory.id)
        }
        var missing: [String: CLLocationCoordinate2D] = [:]
        for (key, entry) in entries where !entry.isHidden && !seen.contains(key) {
            if entry.isNote {
                if let note = entry.noteMemory { memories.append(note) }
            } else if let coordinate = entry.coordinate {
                missing[key] = coordinate
            }
        }
        return (memories, missing)
    }

    private func save() {
        do {
            try context.save()
        } catch {
            print("MemoryLibrary: could not save: \(error)")
        }
    }
}
