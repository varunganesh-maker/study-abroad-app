import CoreLocation
import Photos

/// Reads the camera roll and returns every photo/video that has (or can borrow) a location.
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
            var tagged: [PhotoMemory] = []
            var untaggedVideos: [UntaggedMedia] = []
            assets.enumerateObjects { asset, _, _ in
                let isVideo = asset.mediaType == .video
                if let coordinate = validCoordinate(asset.location) {
                    tagged.append(PhotoMemory(
                        id: asset.localIdentifier,
                        coordinate: coordinate,
                        takenAt: asset.creationDate,
                        isVideo: isVideo,
                        duration: asset.duration,
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight
                    ))
                } else if isVideo, let takenAt = asset.creationDate {
                    // Many videos carry no GPS. Place them next to photos taken around the same time.
                    untaggedVideos.append(UntaggedMedia(
                        id: asset.localIdentifier,
                        takenAt: takenAt,
                        isVideo: true,
                        duration: asset.duration,
                        pixelWidth: asset.pixelWidth,
                        pixelHeight: asset.pixelHeight
                    ))
                }
            }
            return tagged + UntaggedMediaPlacer.place(untaggedVideos, near: tagged)
        }.value
    }

    private static func validCoordinate(_ location: CLLocation?) -> CLLocationCoordinate2D? {
        guard let coordinate = location?.coordinate,
              CLLocationCoordinate2DIsValid(coordinate),
              !(coordinate.latitude == 0 && coordinate.longitude == 0)
        else { return nil }
        return coordinate
    }
}
