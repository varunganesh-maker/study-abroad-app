import CoreLocation
import Foundation

/// Decides where a photo or video you added by hand goes on the map.
enum CapturePlacement {
    /// A picked item with no GPS can borrow the location of a memory taken this close in time.
    /// Wider than the automatic 2 hours, because you chose this item yourself.
    static let neighbourWindow: TimeInterval = 12 * 60 * 60
    /// Your current location is only used for things taken in the last day
    /// (an old photo with no GPS was almost certainly taken somewhere else).
    static let currentLocationWindow: TimeInterval = 24 * 60 * 60

    /// 1. The item's own GPS. 2. A memory taken within 12 hours. 3. Where you are now, if the item
    /// is from the last day. Otherwise nil: the app can't place it and says so.
    static func resolve(
        own: CLLocationCoordinate2D?,
        takenAt: Date?,
        neighbours: [PhotoMemory],
        current: CLLocationCoordinate2D?,
        now: Date = .now
    ) -> CLLocationCoordinate2D? {
        if let own, isUsable(own) { return own }
        guard let takenAt else { return nil }

        let probe = UntaggedMedia(id: "probe", takenAt: takenAt, isVideo: false)
        if let placed = UntaggedMediaPlacer.place([probe], near: neighbours, window: neighbourWindow).first {
            return placed.coordinate
        }
        if let current, isUsable(current), abs(now.timeIntervalSince(takenAt)) <= currentLocationWindow {
            return current
        }
        return nil
    }

    /// Photos sometimes reports 0,0 (the middle of the ocean) for "no location".
    static func isUsable(_ coordinate: CLLocationCoordinate2D) -> Bool {
        CLLocationCoordinate2DIsValid(coordinate) && !(coordinate.latitude == 0 && coordinate.longitude == 0)
    }
}
