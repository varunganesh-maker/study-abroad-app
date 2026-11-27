import Observation
import Photos
import SwiftUI

/// App-wide state: photo permission, scan progress and the list of cities.
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

    private let grouper = CityGrouper()
    private var scanTask: Task<Void, Never>?

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

    func scan() {
        scanTask?.cancel()
        isScanning = true
        scanTask = Task {
            let memories = await PhotoLibraryScanner.fetchGeotaggedMemories()
            totalGeotagged = memories.count
            let final = await grouper.group(memories) { [weak self] partial, remaining in
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

    private func updateAccess(_ status: PHAuthorizationStatus) {
        switch status {
        case .authorized: access = .granted; isLimited = false
        case .limited: access = .granted; isLimited = true
        case .notDetermined: access = .notDetermined
        default: access = .denied
        }
    }
}
