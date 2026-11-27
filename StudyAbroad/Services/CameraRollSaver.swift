import CoreLocation
import Photos
import UIKit

/// Saves a photo or video taken with the in-app camera into your camera roll (with the location
/// stamped on it, like Apple's Camera app does), so it's in Photos and in the app at the same time.
enum CameraRollSaver {
    enum Capture {
        case photo(UIImage)
        case video(URL)
    }

    enum SaveError: LocalizedError {
        case couldNotSave

        var errorDescription: String? { "Couldn't save to your camera roll." }
    }

    /// Returns the new item's Photos id.
    static func save(_ capture: Capture, location: CLLocation?) async throws -> String {
        let newID = IDBox()
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetCreationRequest.forAsset()
            switch capture {
            case .photo(let image):
                if let data = image.jpegData(compressionQuality: 0.92) {
                    request.addResource(with: .photo, data: data, options: nil)
                }
            case .video(let url):
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = false
                request.addResource(with: .video, fileURL: url, options: options)
            }
            request.creationDate = .now
            request.location = location
            newID.value = request.placeholderForCreatedAsset?.localIdentifier
        }
        guard let id = newID.value else { throw SaveError.couldNotSave }
        return id
    }

    /// Carries the new item's id out of Photos' change block.
    private final class IDBox: @unchecked Sendable {
        var value: String?
    }
}
