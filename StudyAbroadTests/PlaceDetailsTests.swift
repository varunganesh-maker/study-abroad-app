import CoreLocation
import Foundation
import Testing
@testable import StudyAbroad

/// Which visits and memories belong to one place, and the average rating there.
struct PlaceDetailsTests {
    private let cafe = CLLocationCoordinate2D(latitude: -33.8800, longitude: 151.2100)
    private let noon = Date(timeIntervalSince1970: 1_800_000_000)

    /// A point `north` metres north of the cafe (1 degree of latitude is about 111,000 m).
    private func spot(north: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: cafe.latitude + north / 111_000, longitude: cafe.longitude)
    }

    private func visit(north: Double = 0, name: String = "AP Bakery", daysLater: Double = 0, rating: Double? = nil) -> Visit {
        let start = noon.addingTimeInterval(daysLater * 86_400)
        let made = Visit(coordinate: spot(north: north), arrival: start, departure: start.addingTimeInterval(3_600))
        made.placeName = name
        made.rating = rating
        return made
    }

    private func photo(_ id: String, north: Double, daysLater: Double = 0) -> PhotoMemory {
        PhotoMemory(id: id, coordinate: spot(north: north), takenAt: noon.addingTimeInterval(daysLater * 86_400), isVideo: false)
    }

    @Test func sameSpotVisitsAreGroupedNewestFirst() {
        let first = visit(daysLater: 0)
        let second = visit(north: 40, name: "", daysLater: 3)
        let ids = PlaceDetails.otherVisits(at: first, among: [first, second]).map { $0.arrival }
        #expect(ids == [second.arrival, first.arrival])
    }

    @Test func farVisitIsLeftOut() {
        let here = visit()
        let far = visit(north: 5_000, name: "Other Cafe", daysLater: 1)
        let result = PlaceDetails.otherVisits(at: here, among: [here, far])
        #expect(result.count == 1)
        #expect(result.first === here)
    }

    @Test func sameNameWithinAKilometreIsGrouped() {
        let here = visit()
        let nearby = visit(north: 600, name: "ap bakery", daysLater: 2)
        let differentName = visit(north: 600, name: "Another Place", daysLater: 2)
        let result = PlaceDetails.otherVisits(at: here, among: [here, nearby, differentName])
        #expect(result.count == 2)
        #expect(result.contains { $0 === nearby })
        #expect(!result.contains { $0 === differentName })
    }

    @Test func memoriesOutsideTheRadiusAreLeftOut() {
        let all = [photo("old", north: 20), photo("new", north: 100, daysLater: 2), photo("far", north: 500)]
        let result = PlaceDetails.memories(near: cafe, in: all)
        #expect(result.map(\.id) == ["new", "old"])
    }

    @Test func averageIgnoresUnratedVisits() {
        #expect(PlaceDetails.averageRating(of: [8, nil, 6]) == 7)
        #expect(PlaceDetails.averageRating(of: [Double?]([nil])) == nil)
        let visits = [visit(rating: 9), visit(daysLater: 1, rating: nil)]
        #expect(PlaceDetails.averageRating(of: visits) == 9)
    }
}
