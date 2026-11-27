import CoreLocation
import Foundation
import Testing
@testable import StudyAbroad

struct CapturePlacementTests {
    private let sydney = CLLocationCoordinate2D(latitude: -33.8568, longitude: 151.2153)
    private let melbourne = CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)
    private let here = CLLocationCoordinate2D(latitude: -27.4698, longitude: 153.0251) // Brisbane
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func photo(at date: Date, _ coordinate: CLLocationCoordinate2D) -> PhotoMemory {
        PhotoMemory(id: UUID().uuidString, coordinate: coordinate, takenAt: date, isVideo: false)
    }

    @Test func ownLocationAlwaysWins() {
        let result = CapturePlacement.resolve(own: sydney, takenAt: now, neighbours: [photo(at: now, melbourne)],
                                              current: here, now: now)

        #expect(result?.latitude == sydney.latitude)
    }

    @Test func zeroZeroCountsAsNoLocation() {
        let result = CapturePlacement.resolve(own: CLLocationCoordinate2D(latitude: 0, longitude: 0), takenAt: now,
                                              neighbours: [photo(at: now, melbourne)], current: nil, now: now)

        #expect(result?.latitude == melbourne.latitude)
    }

    @Test func borrowsFromAMemoryTakenWithin12Hours() {
        let neighbours = [photo(at: now.addingTimeInterval(-10 * 3600), melbourne)]

        let result = CapturePlacement.resolve(own: nil, takenAt: now, neighbours: neighbours, current: here, now: now)

        #expect(result?.latitude == melbourne.latitude)
    }

    @Test func usesCurrentLocationForSomethingFromToday() {
        let result = CapturePlacement.resolve(own: nil, takenAt: now.addingTimeInterval(-3600), neighbours: [],
                                              current: here, now: now)

        #expect(result?.latitude == here.latitude)
    }

    @Test func doesNotPutAnOldPhotoWhereYouAreNow() {
        let result = CapturePlacement.resolve(own: nil, takenAt: now.addingTimeInterval(-3 * 24 * 3600),
                                              neighbours: [], current: here, now: now)

        #expect(result == nil)
    }

    @Test func noDateAndNoLocationCannotBePlaced() {
        let result = CapturePlacement.resolve(own: nil, takenAt: nil, neighbours: [photo(at: now, sydney)],
                                              current: here, now: now)

        #expect(result == nil)
    }
}
