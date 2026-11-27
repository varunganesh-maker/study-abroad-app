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

    /// Photos and videos you added by hand that have no GPS of their own: looked up by id and put
    /// at the location the app saved for them. Items deleted from the camera roll are skipped.
    static func fetchMemories(placedAt placements: [String: CLLocationCoordinate2D]) async -> [PhotoMemory] {
        guard !placements.isEmpty else { return [] }
        return await Task.detached(priority: .userInitiated) {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: Array(placements.keys), options: nil)
            var result: [PhotoMemory] = []
            assets.enumerateObjects { asset, _, _ in
                guard let coordinate = placements[asset.localIdentifier] else { return }
                result.append(memory(for: asset, at: coordinate))
            }
            return result
        }.value
    }

    /// What the app needs to know about one camera roll item before adding it.
    struct AssetInfo {
        let id: String
        let kind: PhotoMemory.Kind
        let takenAt: Date?
        /// Nil when the item has no GPS.
        let coordinate: CLLocationCoordinate2D?
        var duration: Double = 0

        /// Enough of a memory to draw a thumbnail before it's on the map.
        var preview: PhotoMemory {
            PhotoMemory(id: id, coordinate: coordinate ?? CLLocationCoordinate2D(), takenAt: takenAt,
                        kind: kind, duration: duration)
        }
    }

    static func info(for ids: [String]) -> [AssetInfo] {
        guard !ids.isEmpty else { return [] }
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var byID: [String: AssetInfo] = [:]
        assets.enumerateObjects { asset, _, _ in
            byID[asset.localIdentifier] = AssetInfo(
                id: asset.localIdentifier,
                kind: asset.mediaType == .video ? .video : .photo,
                takenAt: asset.creationDate,
                coordinate: validCoordinate(asset.location),
                duration: asset.duration
            )
        }
        return ids.compactMap { byID[$0] } // keep the order you picked them in
    }

    private static func memory(for asset: PHAsset, at coordinate: CLLocationCoordinate2D) -> PhotoMemory {
        PhotoMemory(
            id: asset.localIdentifier,
            coordinate: coordinate,
            takenAt: asset.creationDate,
            isVideo: asset.mediaType == .video,
            duration: asset.duration,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight
        )
    }

    private static func validCoordinate(_ location: CLLocation?) -> CLLocationCoordinate2D? {
        guard let coordinate = location?.coordinate,
              CLLocationCoordinate2DIsValid(coordinate),
              !(coordinate.latitude == 0 && coordinate.longitude == 0)
        else { return nil }
        return coordinate
    }
}
