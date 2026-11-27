import CoreLocation
import Observation

/// Where the phone is right now, used for the sparkle on the map and the
/// "You're in Sydney" card. Only looks up the location when the map is opened.
/// It asks for "Always" permission so visit check-ins (VisitMonitor) work in the background.
/// iOS first shows the normal "While Using the App" prompt, then later offers to upgrade to Always.
@MainActor
@Observable
final class LocationProvider {
    var location: CLLocation?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let delegate = Delegate()

    init() {
        delegate.owner = self
        manager.delegate = delegate
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    /// Call when the map appears. First time, iOS shows the permission prompt.
    func refresh() {
        switch manager.authorizationStatus {
        case .notDetermined: manager.requestAlwaysAuthorization()
        case .authorizedWhenInUse, .authorizedAlways: manager.requestLocation()
        default: break
        }
    }

    fileprivate func authorizationChanged() {
        let status = manager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        }
    }

    /// Core Location reports back through a delegate object.
    private final class Delegate: NSObject, CLLocationManagerDelegate {
        weak var owner: LocationProvider?

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            let owner = self.owner
            Task { @MainActor in owner?.authorizationChanged() }
        }

        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let latest = locations.last else { return }
            let owner = self.owner
            Task { @MainActor in owner?.location = latest }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
            // No fix (e.g. indoors or permission off). The map just shows your latest city instead.
        }
    }
}
