import CoreLocation
import Foundation

/// A backup way to notice visits, for when iOS's own visit detection (`CLVisit`) misses one
/// (there are reports of it going quiet on iOS 26).
///
/// iOS tells the app about "significant location changes": roughly every time the phone moves
/// about 500 m, using very little battery. If the phone stayed near one spot for 20 minutes to 8 hours
/// and then moved more than 400 m away, you probably visited that spot.
///
/// Privacy: only ONE point is ever kept (where you were last still), on the phone, overwritten each
/// time and cleared once a visit is made. It isn't in the backup file and is never sent anywhere.
struct BackupVisitDetector {
    /// Where the phone was last seen sitting still.
    struct Anchor: Codable, Equatable {
        var latitude: Double
        var longitude: Double
        /// When the phone first got here.
        var since: Date
    }

    /// A visit worth asking about.
    struct Candidate: Equatable {
        let coordinate: CLLocationCoordinate2D
        let arrival: Date
        let departure: Date

        static func == (a: Candidate, b: Candidate) -> Bool {
            a.coordinate.latitude == b.coordinate.latitude && a.coordinate.longitude == b.coordinate.longitude
                && a.arrival == b.arrival && a.departure == b.departure
        }
    }

    static let minimumStay: TimeInterval = 20 * 60
    /// Longer than this is probably home overnight, not a visit.
    static let maximumStay: TimeInterval = 8 * 3600
    static let minimumMove: CLLocationDistance = 400
    /// Fixes vaguer than this (in metres) are ignored.
    static let worstAccuracy: CLLocationAccuracy = 1000
    /// Fixes older than this when they arrive are old cached ones; ignored.
    static let oldestFix: TimeInterval = 10 * 60

    private(set) var anchor: Anchor?

    init(anchor: Anchor? = nil) {
        self.anchor = anchor
    }

    /// Feeds in one location update. Returns a visit when you've just left somewhere you stayed.
    /// `now` is passed in so tests can control the clock.
    mutating func process(latitude: Double, longitude: Double, accuracy: CLLocationAccuracy,
                          time: Date, now: Date = .now) -> Candidate? {
        // Treat fixes as untrusted: no accuracy, too vague, from the future or stale.
        guard accuracy >= 0, accuracy <= Self.worstAccuracy,
              time <= now.addingTimeInterval(60), now.timeIntervalSince(time) <= Self.oldestFix,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else { return nil }

        guard let anchor else {
            self.anchor = Anchor(latitude: latitude, longitude: longitude, since: time)
            return nil
        }
        let moved = CLLocation(latitude: anchor.latitude, longitude: anchor.longitude)
            .distance(from: CLLocation(latitude: latitude, longitude: longitude))
        // Still around the same spot: keep the first time you got here.
        guard moved >= Self.minimumMove else { return nil }

        // You've left. Start watching the new spot, and decide whether the old one was a visit.
        self.anchor = Anchor(latitude: latitude, longitude: longitude, since: time)
        let stay = time.timeIntervalSince(anchor.since)
        guard stay >= Self.minimumStay, stay <= Self.maximumStay else { return nil }
        return Candidate(coordinate: CLLocationCoordinate2D(latitude: anchor.latitude, longitude: anchor.longitude),
                         arrival: anchor.since, departure: time)
    }

    // MARK: Saving the one point between app launches (iOS can relaunch the app in the background)

    private static let key = "backupVisit.anchor"

    static func load(from defaults: UserDefaults = .standard) -> BackupVisitDetector {
        let anchor = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(Anchor.self, from: $0) }
        return BackupVisitDetector(anchor: anchor)
    }

    func save(to defaults: UserDefaults = .standard) {
        if let anchor, let data = try? JSONEncoder().encode(anchor) {
            defaults.set(data, forKey: Self.key)
        } else {
            defaults.removeObject(forKey: Self.key)
        }
    }

    static func clear(from defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

/// Decides what to do with a newly noticed visit, given the visits already saved,
/// so the same stop never shows up twice.
enum VisitDedupe {
    enum Decision: Equatable {
        /// Save it as a new visit.
        case insert
        /// Already have it (or you said "Not a visit" here twice): ignore.
        case skip
        /// A real iOS visit for a stop the backup check already noticed (and you haven't rated yet):
        /// update that one with the more precise spot and times. Index into `existing`.
        case replace(Int)
    }

    /// `existing` = every saved visit as plain values (so this is easy to test).
    struct Existing {
        let coordinate: CLLocationCoordinate2D
        let arrival: Date
        let departure: Date
        let status: Visit.Status
        let source: Visit.Source
    }

    static func decide(coordinate: CLLocationCoordinate2D, arrival: Date, departure: Date,
                       source: Visit.Source, existing: [Existing]) -> Decision {
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        func distance(_ e: Existing) -> CLLocationDistance {
            CLLocation(latitude: e.coordinate.latitude, longitude: e.coordinate.longitude).distance(from: here)
        }
        func overlaps(_ e: Existing) -> Bool { e.arrival < departure && arrival < e.departure }

        // Same visit reported twice.
        if existing.contains(where: { abs($0.arrival.timeIntervalSince(arrival)) < 120 && distance($0) < 150 }) {
            return .skip
        }
        // You've said "Not a visit" here twice already (home, the bus stop…): stop asking.
        // Backup spots are less precise, so they count as "here" from a bit further away.
        if source != .manual {
            let radius: CLLocationDistance = source == .backup ? 300 : 100
            if existing.filter({ $0.status == .dismissed && distance($0) < radius }).count >= 2 { return .skip }
        }
        switch source {
        case .backup:
            // Any visit already covering this time (from iOS, the backup or "I was here") wins.
            if existing.contains(where: overlaps) { return .skip }
        case .visit:
            // Upgrade a pending backup visit for the same stop; never touch one you rated or dismissed.
            if let index = existing.firstIndex(where: {
                $0.source == .backup && $0.status == .pending && overlaps($0) && distance($0) < 2_000
            }) {
                return .replace(index)
            }
        case .manual:
            break
        }
        return .insert
    }
}
