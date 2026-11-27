import CoreLocation
import Foundation
import Testing
@testable import StudyAbroad

struct UntaggedMediaPlacerTests {
    private let sydney = CLLocationCoordinate2D(latitude: -33.8568, longitude: 151.2153)
    private let melbourne = CLLocationCoordinate2D(latitude: -37.8136, longitude: 144.9631)
    private let noon = Date(timeIntervalSince1970: 1_772_000_000)

    private func photo(_ id: String, at date: Date?, _ coordinate: CLLocationCoordinate2D) -> PhotoMemory {
        PhotoMemory(id: id, coordinate: coordinate, takenAt: date, isVideo: false)
    }

    private func video(_ id: String, at date: Date) -> UntaggedMedia {
        UntaggedMedia(id: id, takenAt: date, isVideo: true, duration: 12, pixelWidth: 1080, pixelHeight: 1920)
    }

    @Test func videoBorrowsLocationOfClosestPhotoInTime() {
        // Arrange
        let tagged = [
            photo("syd", at: noon.addingTimeInterval(-30 * 60), sydney),
            photo("mel", at: noon.addingTimeInterval(90 * 60), melbourne),
        ]

        // Act
        let placed = UntaggedMediaPlacer.place([video("v", at: noon)], near: tagged)

        // Assert
        #expect(placed.count == 1)
        #expect(placed[0].coordinate.latitude == sydney.latitude)
        #expect(placed[0].coordinate.longitude == sydney.longitude)
    }

    @Test func placedVideoKeepsItsOwnDetails() {
        let placed = UntaggedMediaPlacer.place([video("v", at: noon)], near: [photo("p", at: noon, sydney)])

        #expect(placed.first?.id == "v")
        #expect(placed.first?.isVideo == true)
        #expect(placed.first?.takenAt == noon)
        #expect(placed.first?.duration == 12)
        #expect(placed.first?.isPortrait == true)
    }

    @Test func videoWithNoPhotoWithinTwoHoursIsLeftOut() {
        let tagged = [photo("p", at: noon.addingTimeInterval(-3 * 60 * 60), sydney)]

        #expect(UntaggedMediaPlacer.place([video("v", at: noon)], near: tagged).isEmpty)
    }

    @Test func photoExactlyTwoHoursAwayStillCounts() {
        let tagged = [photo("p", at: noon.addingTimeInterval(UntaggedMediaPlacer.defaultWindow), sydney)]

        #expect(UntaggedMediaPlacer.place([video("v", at: noon)], near: tagged).count == 1)
    }

    @Test func nothingIsPlacedWhenNoPhotoHasADate() {
        let tagged = [photo("p", at: nil, sydney)]

        #expect(UntaggedMediaPlacer.place([video("v", at: noon)], near: tagged).isEmpty)
    }

    @Test func worksWhenVideoIsBeforeOrAfterEveryPhoto() {
        let tagged = (1...5).map { photo("p\($0)", at: noon.addingTimeInterval(Double($0) * 600), sydney) }
        let before = video("before", at: noon)
        let after = video("after", at: noon.addingTimeInterval(4000))

        let placed = UntaggedMediaPlacer.place([before, after], near: tagged.reversed())

        #expect(placed.map(\.id) == ["before", "after"])
    }

    @Test func doesNotChangeTheMemoriesItWasGiven() {
        let tagged = [photo("p", at: noon, sydney)]
        let copy = tagged

        _ = UntaggedMediaPlacer.place([video("v", at: noon)], near: tagged)

        #expect(tagged == copy)
    }
}

struct PhotoMemoryTests {
    @Test(arguments: [(0.0, "0:00"), (24.4, "0:24"), (84, "1:24"), (-5, "0:00")])
    func timeTextFormatsMinutesAndSeconds(seconds: Double, expected: String) {
        #expect(PhotoMemory.timeText(seconds) == expected)
    }
}
