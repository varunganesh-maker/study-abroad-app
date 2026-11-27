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
    /// With "Always", the backup check (significant location changes) runs too; it stops, and its one
    /// saved point is wiped, as soon as permission drops below Always.
    func startIfAllowed() {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            manager.startMonitoringVisits()
            if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                manager.startMonitoringSignificantLocationChanges()
            }
        case .authorizedWhenInUse:
            manager.startMonitoringVisits()
            stopBackupCheck()
        default:
            stopBackupCheck()
        }
    }

    private func stopBackupCheck() {
        manager.stopMonitoringSignificantLocationChanges()
        BackupVisitDetector.clear()
    }

    /// A significant location change: maybe you just left somewhere worth rating.
    fileprivate func handleLocation(latitude: Double, longitude: Double, accuracy: Double, time: Date) {
        guard manager.authorizationStatus == .authorizedAlways else { return }
        var detector = BackupVisitDetector.load()
        let candidate = detector.process(latitude: latitude, longitude: longitude, accuracy: accuracy, time: time)
        detector.save()
        if let candidate {
            record(coordinate: candidate.coordinate, arrival: candidate.arrival, departure: candidate.departure,
                   source: .backup)
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
    /// `manual`: you tapped "I was here", so skip the "you said Not a visit here before" filter and the
    /// notification, and show the rating sheet straight away (named "This spot" until the lookup finishes).
    /// `source`: how the visit was noticed; see `VisitDedupe` for how duplicates are avoided.
    func record(coordinate: CLLocationCoordinate2D, arrival: Date, departure: Date, manual: Bool = false,
                source: Visit.Source = .visit) {
        let source: Visit.Source = manual ? .manual : source
        let all = (try? context.fetch(FetchDescriptor<Visit>())) ?? []
        let existing = all.map {
            VisitDedupe.Existing(coordinate: $0.coordinate, arrival: $0.arrival, departure: $0.departure,
                                 status: $0.status, source: $0.source)
        }
        let visit: Visit
        switch VisitDedupe.decide(coordinate: coordinate, arrival: arrival, departure: departure,
                                  source: source, existing: existing) {
        case .skip:
            return
        case .replace(let index):
            // iOS's own visit is more precise than the backup guess: move that visit to the real spot.
            // It was already announced, so no second notification.
            let old = all[index]
            old.latitude = coordinate.latitude
            old.longitude = coordinate.longitude
            old.arrival = arrival
            old.departure = departure
            old.source = .visit
            try? context.save()
            Task {
                let place = await PlaceNamer.lookUp(coordinate)
                if let name = place.name { old.placeName = name }
                old.area = place.area
                old.city = place.city
                try? context.save()
            }
            return
        case .insert:
            visit = Visit(coordinate: coordinate, arrival: arrival, departure: departure)
        }
        visit.source = source
        if manual { visit.placeName = Self.manualPlaceholder }
        context.insert(visit)
        try? context.save()

        Task {
            let place = await PlaceNamer.lookUp(coordinate)
            if !manual || visit.placeName == Self.manualPlaceholder {
                visit.placeName = place.name ?? (manual ? Self.manualPlaceholder : "")
            }
            visit.area = place.area
            visit.city = place.city
            try? context.save()
            if !manual { Self.notify(about: visit) }
        }
    }

    /// Name shown for an "I was here" visit until (or if) the place can't be looked up.
    static let manualPlaceholder = "This spot"

    /// Fills in names for visits saved while offline. Called when the app opens.
    func nameUnnamedVisits() {
        let placeholder = Self.manualPlaceholder
        let unnamed = (try? context.fetch(FetchDescriptor<Visit>(predicate: #Predicate<Visit> {
            $0.placeName == "" || $0.placeName == placeholder
        }))) ?? []
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

        /// Significant location changes (the backup visit check). Only the newest fix is used.
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            guard let latest = locations.last else { return }
            let owner = self.owner
            let latitude = latest.coordinate.latitude
            let longitude = latest.coordinate.longitude
            let accuracy = latest.horizontalAccuracy
            let time = latest.timestamp
            Task { @MainActor in
                owner?.handleLocation(latitude: latitude, longitude: longitude, accuracy: accuracy, time: time)
            }
        }

        func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
    }
}
