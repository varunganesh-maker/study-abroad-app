import CoreLocation
import Photos

/// Reads the camera roll and returns every photo/video that has a GPS location.
enum PhotoLibraryScanner {
    /// Runs on a background thread; enumerating a big library can take a second or two.
    static func fetchGeotaggedMemories() async -> [PhotoMemory] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            options.predicate = NSPredicate(
                format: "mediaType == %d || mediaType == %d",
                PHAssetMediaType.image.rawValue,
                PHAssetMediaType.video.rawValue
            )
            let assets = PHAsset.fetchAssets(with: options)
            var memories: [PhotoMemory] = []
            assets.enumerateObjects { asset, _, _ in
                guard let coordinate = asset.location?.coordinate,
                      CLLocationCoordinate2DIsValid(coordinate),
                      !(coordinate.latitude == 0 && coordinate.longitude == 0)
                else { return }
                memories.append(PhotoMemory(
                    id: asset.localIdentifier,
                    coordinate: coordinate,
                    takenAt: asset.creationDate,
                    isVideo: asset.mediaType == .video
                ))
            }
            return memories
        }.value
    }
}
