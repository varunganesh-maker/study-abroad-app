import CoreLocation
import Foundation
import Testing
@testable import StudyAbroad

/// The backup visit check (significant location changes) and the "never show the same stop twice" rules.
struct BackupVisitDetectorTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    // About 0.0045 degrees of latitude is 500 m; 0.0009 is 100 m.
    private let lat = -33.8688
    private let lon = 151.2093

    private func mins(_ m: Double) -> Date { now.addingTimeInterval(m * 60) }

    /// Feeds a fix as if it just arrived at `time` (so `now` == `time`).
    private func feed(_ d: inout BackupVisitDetector, lat: Double, lon: Double, accuracy: Double = 50,
                      at time: Date) -> BackupVisitDetector.Candidate? {
        d.process(latitude: lat, longitude: lon, accuracy: accuracy, time: time, now: time)
    }

    // MARK: Detector

    @Test func firstFixSetsAnchorOnly() {
        var d = BackupVisitDetector()
        let result = feed(&d, lat: lat, lon: lon, at: now)
        #expect(result == nil)
        #expect(d.anchor?.latitude == lat)
        #expect(d.anchor?.since == now)
    }

    @Test func smallMoveKeepsOriginalArrival() {
        var d = BackupVisitDetector()
        _ = feed(&d, lat: lat, lon: lon, at: now)
        let result = feed(&d, lat: lat + 0.0009, lon: lon, at: mins(10))
        #expect(result == nil)
        #expect(d.anchor?.since == now)
        #expect(d.anchor?.latitude == lat)
    }

    @Test func leavingAfterThirtyMinutesGivesCandidate() throws {
        var d = BackupVisitDetector()
        _ = feed(&d, lat: lat, lon: lon, at: now)
        let result = try #require(feed(&d, lat: lat + 0.0045, lon: lon, at: mins(30)))
        #expect(result.coordinate.latitude == lat)
        #expect(result.coordinate.longitude == lon)
        #expect(result.arrival == now)
        #expect(result.departure == mins(30))
        // The new spot is now being watched.
        #expect(d.anchor?.latitude == lat + 0.0045)
        #expect(d.anchor?.since == mins(30))
    }

    @Test func tooShortAStayIsNotAVisitButAnchorMoves() {
        var d = BackupVisitDetector()
        _ = feed(&d, lat: lat, lon: lon, at: now)
        let result = feed(&d, lat: lat + 0.0045, lon: lon, at: mins(19))
        #expect(result == nil)
        #expect(d.anchor?.since == mins(19))
    }

    @Test func tooLongAStayIsNotAVisitButAnchorMoves() {
        var d = BackupVisitDetector()
        _ = feed(&d, lat: lat, lon: lon, at: now)
        let result = feed(&d, lat: lat + 0.0045, lon: lon, at: mins(8 * 60 + 1))
        #expect(result == nil)
        #expect(d.anchor?.since == mins(8 * 60 + 1))
    }

    @Test func exactlyTwentyMinutesAndEightHoursCount() {
        var a = BackupVisitDetector()
        _ = feed(&a, lat: lat, lon: lon, at: now)
        #expect(feed(&a, lat: lat + 0.0045, lon: lon, at: mins(20)) != nil)
        var b = BackupVisitDetector()
        _ = feed(&b, lat: lat, lon: lon, at: now)
        #expect(feed(&b, lat: lat + 0.0045, lon: lon, at: mins(480)) != nil)
    }

    @Test func badAccuracyIsIgnored() {
        var d = BackupVisitDetector()
        #expect(feed(&d, lat: lat, lon: lon, accuracy: -1, at: now) == nil)
        #expect(d.anchor == nil)
        #expect(feed(&d, lat: lat, lon: lon, accuracy: 1001, at: now) == nil)
        #expect(d.anchor == nil)
        #expect(feed(&d, lat: lat, lon: lon, accuracy: 1000, at: now) == nil)
        #expect(d.anchor != nil)
    }

    @Test func badAccuracyDoesNotMoveAnExistingAnchor() {
        var d = BackupVisitDetector()
        _ = feed(&d, lat: lat, lon: lon, at: now)
        _ = feed(&d, lat: lat + 0.05, lon: lon, accuracy: 5_000, at: mins(30))
        #expect(d.anchor?.latitude == lat)
    }

    @Test func futureAndStaleFixesAreIgnored() {
        var d = BackupVisitDetector()
        // 5 minutes in the future.
        #expect(d.process(latitude: lat, longitude: lon, accuracy: 50, time: now.addingTimeInterval(300), now: now) == nil)
        #expect(d.anchor == nil)
        // 11 minutes old.
        #expect(d.process(latitude: lat, longitude: lon, accuracy: 50, time: now.addingTimeInterval(-660), now: now) == nil)
        #expect(d.anchor == nil)
        // 5 minutes old is fine.
        _ = d.process(latitude: lat, longitude: lon, accuracy: 50, time: now.addingTimeInterval(-300), now: now)
        #expect(d.anchor != nil)
    }

    @Test func impossibleCoordinatesAreIgnored() {
        var d = BackupVisitDetector()
        _ = feed(&d, lat: 91, lon: 0, at: now)
        _ = feed(&d, lat: 0, lon: 181, at: now)
        #expect(d.anchor == nil)
    }

    @Test func anchorSurvivesSaveAndLoadAndClear() throws {
        let name = "BackupVisitDetectorTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(BackupVisitDetector.load(from: defaults).anchor == nil)

        var d = BackupVisitDetector()
        _ = feed(&d, lat: lat, lon: lon, at: now)
        d.save(to: defaults)
        let loaded = BackupVisitDetector.load(from: defaults)
        #expect(loaded.anchor == d.anchor)

        BackupVisitDetector.clear(from: defaults)
        #expect(BackupVisitDetector.load(from: defaults).anchor == nil)
    }

    @Test func savingNoAnchorRemovesTheStoredOne() throws {
        let name = "BackupVisitDetectorTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        var d = BackupVisitDetector()
        _ = feed(&d, lat: lat, lon: lon, at: now)
        d.save(to: defaults)
        BackupVisitDetector().save(to: defaults)
        #expect(BackupVisitDetector.load(from: defaults).anchor == nil)
    }

    // MARK: Dedupe

    private func here(_ metresNorth: Double = 0) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat + metresNorth / 111_000, longitude: lon)
    }

    private func existing(at metresNorth: Double = 0, start: Double = 0, length: Double = 30,
                          status: Visit.Status = .saved, source: Visit.Source = .visit) -> VisitDedupe.Existing {
        VisitDedupe.Existing(coordinate: here(metresNorth), arrival: mins(start), departure: mins(start + length),
                             status: status, source: source)
    }

    private func decide(source: Visit.Source, start: Double = 0, length: Double = 30, at metresNorth: Double = 0,
                        _ list: [VisitDedupe.Existing]) -> VisitDedupe.Decision {
        VisitDedupe.decide(coordinate: here(metresNorth), arrival: mins(start), departure: mins(start + length),
                           source: source, existing: list)
    }

    @Test func emptyListInserts() {
        #expect(decide(source: .visit, []) == .insert)
        #expect(decide(source: .backup, []) == .insert)
        #expect(decide(source: .manual, []) == .insert)
    }

    @Test func sameVisitTwiceIsSkipped() {
        #expect(decide(source: .visit, [existing()]) == .skip)
        // A minute later and 100 m away is still the same visit.
        #expect(decide(source: .visit, start: 1, at: 100, [existing()]) == .skip)
    }

    @Test func sameTimeButFarAwayIsNotADuplicate() {
        #expect(decide(source: .visit, at: 500, [existing()]) == .insert)
    }

    @Test func dismissedTwiceNearbySkipsVisit() {
        let list = [existing(start: -600, status: .dismissed), existing(start: -300, status: .dismissed)]
        #expect(decide(source: .visit, at: 50, list) == .skip)
        // 150 m is outside the 100 m radius for real visits.
        #expect(decide(source: .visit, at: 150, list) == .insert)
    }

    @Test func dismissedOnceDoesNotSkip() {
        #expect(decide(source: .visit, at: 50, [existing(start: -600, status: .dismissed)]) == .insert)
    }

    @Test func backupUsesWiderDismissRadius() {
        let list = [existing(start: -600, status: .dismissed), existing(start: -300, status: .dismissed)]
        #expect(decide(source: .backup, at: 250, list) == .skip)
        #expect(decide(source: .backup, at: 350, list) == .insert)
    }

    @Test func manualIgnoresDismissedFilter() {
        let list = [existing(start: -600, status: .dismissed), existing(start: -300, status: .dismissed)]
        #expect(decide(source: .manual, at: 20, list) == .insert)
    }

    @Test func backupOverlappingAnyExistingIsSkipped() {
        // 10 minutes overlap, different place and different start.
        #expect(decide(source: .backup, start: 20, at: 800, [existing(at: 0, start: 0, length: 30)]) == .skip)
        #expect(decide(source: .backup, start: 20, at: 800, [existing(start: 0, length: 30, source: .manual)]) == .skip)
    }

    @Test func backupAfterAnExistingVisitInserts() {
        #expect(decide(source: .backup, start: 40, at: 800, [existing(start: 0, length: 30)]) == .insert)
    }

    @Test func realVisitReplacesAnOverlappingPendingBackup() {
        let list = [existing(at: 1_000, start: 5, length: 30, status: .saved, source: .manual),
                    existing(at: 400, start: 5, length: 30, status: .pending, source: .backup)]
        #expect(decide(source: .visit, start: 0, length: 40, list) == .replace(1))
    }

    @Test func realVisitDoesNotReplaceBackupOver2kmAway() {
        let list = [existing(at: 2_500, start: 5, length: 30, status: .pending, source: .backup)]
        #expect(decide(source: .visit, start: 0, length: 40, list) == .insert)
    }

    @Test func realVisitNeverReplacesSavedOrDismissedBackup() {
        let saved = [existing(at: 400, start: 5, length: 30, status: .saved, source: .backup)]
        let dismissed = [existing(at: 400, start: 5, length: 30, status: .dismissed, source: .backup)]
        #expect(decide(source: .visit, start: 0, length: 40, saved) == .insert)
        #expect(decide(source: .visit, start: 0, length: 40, dismissed) == .insert)
    }

    @Test func realVisitDoesNotReplaceNonOverlappingBackup() {
        let list = [existing(at: 400, start: 100, length: 30, status: .pending, source: .backup)]
        #expect(decide(source: .visit, start: 0, length: 40, list) == .insert)
    }
}
