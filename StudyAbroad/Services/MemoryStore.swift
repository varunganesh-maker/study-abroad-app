import CoreLocation
import Observation
import Photos
import SwiftData
import SwiftUI

/// App-wide state: photo permission, scan progress, the list of cities, and captions.
///
/// Each scan reads the camera roll, adds new photos to the app's database following the
/// "Add new photos automatically" setting, then groups everything that's in the app
/// (photos, videos and notes) into cities.
@MainActor
@Observable
final class MemoryStore {
    enum Access { case unknown, notDetermined, denied, granted }

    var access: Access = .unknown
    var cities: [CityCluster] = []
    var isScanning = false
    /// How many places are still being named (shown in the status pill).
    var remainingLookups = 0
    var totalGeotagged = 0
    /// True when the user picked "Limited Access" instead of "Full Access".
    var isLimited = false
    /// Captions by memory id. Kept here so every screen updates the moment you edit one.
    private(set) var captions: [String: String] = [:]
    /// The "Add new photos automatically" setting.
    private(set) var autoAddRule: AutoAddRule
    /// How many photos/videos you've removed from the app (shown in Settings).
    private(set) var hiddenCount = 0
    /// A short message after adding things, e.g. "Added 3 memories".
    var notice: String?

    @ObservationIgnored let library: MemoryLibrary
    @ObservationIgnored private let grouper = CityGrouper()
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    /// The last camera roll scan, so adding a note doesn't need a full re-scan.
    @ObservationIgnored private var scanned: [PhotoMemory] = []
    @ObservationIgnored private var hasScanned = false

    init(container: ModelContainer) {
        library = MemoryLibrary(context: container.mainContext)
        autoAddRule = AutoAddRule.load()
        captions = library.captions
        hiddenCount = library.hiddenCount
    }

    func start() async {
        updateAccess(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        if access == .granted { scan() }
    }

    func requestAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        updateAccess(status)
        if access == .granted { scan() }
    }

    func refreshIfAllowed() async {
        updateAccess(PHPhotoLibrary.authorizationStatus(for: .readWrite))
        if access == .granted && !isScanning { scan() }
    }

    /// Reads the camera roll again, auto-adds new items, and rebuilds the cities.
    func scan() {
        rebuild(rescan: true)
    }

    /// Rebuilds the cities. `rescan: false` reuses the last camera roll scan (e.g. after adding a note).
    private func rebuild(rescan: Bool) {
        scanTask?.cancel()
        isScanning = true
        let needsScan = rescan || !hasScanned
        scanTask = Task {
            if needsScan {
                let fresh = await PhotoLibraryScanner.fetchGeotaggedMemories()
                if Task.isCancelled { return }
                scanned = fresh
                hasScanned = true
                await library.autoAdd(fresh, rule: autoAddRule)
            }
            let shown = library.visible(scanned: scanned)
            let extra = await PhotoLibraryScanner.fetchMemories(placedAt: shown.missing)
            if Task.isCancelled { return }
            let memories = shown.memories + extra
            totalGeotagged = memories.count
            let final = await grouper.group(memories) { [weak self] partial, remaining in
                // A newer rebuild may have started; don't let this one's half-finished list land on top.
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    self?.cities = partial
                    self?.remainingLookups = remaining
                }
            }
            if !Task.isCancelled {
                cities = final
                remainingLookups = 0
                isScanning = false
            }
        }
    }

    // MARK: Captions

    func caption(for id: String) -> String { captions[id] ?? "" }

    func setCaption(_ text: String, for id: String) {
        library.setCaption(text, for: id)
        captions[id] = library.entry(for: id)?.caption
    }

    // MARK: Adding memories

    /// Adds photos/videos you picked from the camera roll.
    /// Returns the ids that made it onto the map, in the order you picked them.
    @discardableResult
    func addFromCameraRoll(_ ids: [String], currentLocation: CLLocation?) -> [String] {
        let infos = PhotoLibraryScanner.info(for: ids)
        var placed: [String] = []
        for info in infos {
            let coordinate = CapturePlacement.resolve(
                own: info.coordinate,
                takenAt: info.takenAt,
                neighbours: scanned,
                current: currentLocation?.coordinate
            )
            guard let coordinate else { continue }
            // Only store a location when Photos doesn't have one, so the photo's own GPS always wins.
            library.addAsset(info.id, kind: info.kind, source: .picker,
                             coordinate: info.coordinate == nil ? coordinate : nil)
            placed.append(info.id)
        }
        let unplaced = ids.count - placed.count
        var message = placed.isEmpty ? "" : "Added \(placed.count) memor\(placed.count == 1 ? "y" : "ies")."
        if unplaced > 0 {
            message += (message.isEmpty ? "" : " ")
                + "\(unplaced) had no location, so \(unplaced == 1 ? "it" : "they") couldn't go on the map."
        }
        notice = message.isEmpty ? nil : message
        afterChange(rescan: true)
        return placed
    }

    /// Adds a photo or video you just took with the in-app camera.
    func addCameraCapture(_ id: String, kind: PhotoMemory.Kind, coordinate: CLLocationCoordinate2D?, caption: String) {
        library.addAsset(id, kind: kind, source: .camera, coordinate: coordinate)
        if !caption.isEmpty { setCaption(caption, for: id) }
        if coordinate == nil {
            notice = "Saved to your camera roll, but with no location it can't go on the map. Turn on Location Services to place new photos."
        }
        afterChange(rescan: true)
    }

    /// Saves a text or voice note. Returns its id.
    @discardableResult
    func addNote(kind: PhotoMemory.Kind, text: String, coordinate: CLLocationCoordinate2D,
                 takenAt: Date, duration: Double = 0, key: String? = nil) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let id = library.addNote(kind: kind, text: trimmed, coordinate: coordinate, takenAt: takenAt,
                                 duration: duration, key: key ?? MemoryEntry.newNoteKey())
        captions[id] = trimmed.isEmpty ? nil : trimmed
        afterChange(rescan: false)
        return id
    }

    /// "Remove from app" (photos/videos stay in your camera roll) or delete a note.
    func remove(_ id: String) {
        library.remove(id)
        if library.entry(for: id) == nil { captions[id] = nil }
        afterChange(rescan: false)
    }

    func unhideAll() {
        library.unhideAll()
        afterChange(rescan: false)
    }

    // MARK: Auto-add setting

    func setAutoAddRule(_ rule: AutoAddRule) {
        guard rule != autoAddRule else { return }
        autoAddRule = rule
        rule.save()
        // New rule: add whatever it now allows (nothing already in the app is removed).
        afterChange(rescan: true)
    }

    // MARK: Backup file

    /// Everything the app adds on top of your camera roll, ready to save to Files.
    func makeBackup() async throws -> Data {
        let assetKeys = library.allKeys(includingNotes: false)
        let cloudIDs = await Task.detached(priority: .userInitiated) { Backup.cloudIDs(for: assetKeys) }.value
        return try Backup.make(context: library.context, cloudIDs: cloudIDs, rule: autoAddRule).encoded()
    }

    /// Restores a backup file on top of what's here (nothing you've changed since is overwritten).
    func restoreBackup(_ data: Data) throws -> String {
        let file = try BackupFile.decode(data)
        let result = Backup.restore(file, into: library.context, localIDs: Backup.localIDs(for: file),
                                    assetExists: Backup.assetExists)
        library.reload()
        captions = library.captions
        // Only take the backup's auto-add setting if you haven't changed yours from the default.
        if autoAddRule.mode == .all, let raw = file.autoAddMode, let mode = AutoAddRule.Mode(rawValue: raw) {
            var rule = AutoAddRule(mode: mode)
            rule.start = file.autoAddStart ?? .now
            rule.end = file.autoAddEnd ?? .now
            autoAddRule = rule
            rule.save()
        }
        afterChange(rescan: true)
        return result.message
    }

    /// A memory you'd want to place a new note next to (most recent first).
    var latestMemory: PhotoMemory? {
        cities.compactMap(\.cover).max { ($0.takenAt ?? .distantPast) < ($1.takenAt ?? .distantPast) }
    }

    private func afterChange(rescan: Bool) {
        hiddenCount = library.hiddenCount
        guard access == .granted else { return }
        rebuild(rescan: rescan)
    }

    private func updateAccess(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized: access = .granted; isLimited = false
        case .limited: access = .granted; isLimited = true
        case .notDetermined: access = .notDetermined
        default: access = .denied
        }
    }
}
