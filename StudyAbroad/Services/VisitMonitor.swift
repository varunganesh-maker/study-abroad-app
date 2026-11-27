import CoreLocation
import SwiftData
import UserNotifications

/// Listens for iOS "visits": places where the phone stayed put for a while (a café, a beach, a museum).
/// iOS does the hard work in the background with very little battery, and can even wake the app
/// up after it was closed. Each finished visit is saved as a pending `Visit` for "How was it?".
@MainActor
@Observable
final class VisitMonitor {
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let delegate = Delegate()
    @ObservationIgnored private let context: ModelContext

    init(container: ModelContainer) {
        context = container.mainContext
        delegate.owner = self
        manager.delegate = delegate
        startIfAllowed()
    }

    /// Visits need location permission. The map screen asks for it; this starts listening once given.
    func startIfAllowed() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.startMonitoringVisits()
        default:
            break
        }
    }

    /// Asks once for permission to send "You've been here" notifications.
    static func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: Handling a visit

    fileprivate func handle(coordinate: CLLocationCoordinate2D, arrival: Date, departure: Date) {
        // iOS reports twice: once on arrival (no departure yet) and once on leaving. Only keep finished visits.
        guard departure != .distantFuture else { return }
        let start = arrival == .distantPast ? departure.addingTimeInterval(-15 * 60) : arrival
        record(coordinate: coordinate, arrival: start, departure: departure)
    }

    /// Saves a visit, looks up the place name, and sends a notification. Also used by the test button.
    func record(coordinate: CLLocationCoordinate2D, arrival: Date, departure: Date) {
        let all = (try? context.fetch(FetchDescriptor<Visit>())) ?? []
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        func distance(_ visit: Visit) -> CLLocationDistance {
            CLLocation(latitude: visit.latitude, longitude: visit.longitude).distance(from: here)
        }

        // Same visit reported twice.
        if all.contains(where: { abs($0.arrival.timeIntervalSince(arrival)) < 120 && distance($0) < 150 }) { return }
        // You've said "Not a visit" here twice already (home, the bus stop…): stop asking.
        if all.filter({ $0.status == .dismissed && distance($0) < 100 }).count >= 2 { return }

        let visit = Visit(coordinate: coordinate, arrival: arrival, departure: departure)
        context.insert(visit)
        try? context.save()

        Task {
            let place = await PlaceNamer.lookUp(coordinate)
            visit.placeName = place.name ?? ""
            visit.area = place.area
            visit.city = place.city
            try? context.save()
            Self.notify(about: visit)
        }
    }

    /// Fills in names for visits saved while offline. Called when the app opens.
    func nameUnnamedVisits() {
        let unnamed = (try? context.fetch(FetchDescriptor<Visit>(predicate: #Predicate<Visit> { $0.placeName == "" }))) ?? []
        for visit in unnamed {
            Task {
                let place = await PlaceNamer.lookUp(visit.coordinate)
                guard let name = place.name else { return }
                visit.placeName = name
                visit.area = place.area
                visit.city = place.city
                try? context.save()
            }
        }
    }

    private static func notify(about visit: Visit) {
        let content = UNMutableNotificationContent()
        content.title = "You’ve been here"
        content.body = "\(visit.displayName). How was it?"
        content.sound = .default
        let request = UNNotificationRequest(identifier: "visit-\(visit.arrival.timeIntervalSince1970)",
                                            content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: Core Location delegate

    private final class Delegate: NSObject, CLLocationManagerDelegate {
        weak var owner: VisitMonitor?

        func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
            let owner = self.owner
            Task { @MainActor in owner?.startIfAllowed() }
        }

        func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
            let owner = self.owner
            let coordinate = visit.coordinate
            let arrival = visit.arrivalDate
            let departure = visit.departureDate
            Task { @MainActor in owner?.handle(coordinate: coordinate, arrival: arrival, departure: departure) }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
    }
}
