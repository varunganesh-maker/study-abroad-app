import CoreLocation
import Foundation
import Testing
@testable import StudyAbroad

struct CityClusterTests {
    private let sydney = CLLocationCoordinate2D(latitude: -33.8568, longitude: 151.2153)
    private let noon = Date(timeIntervalSince1970: 1_800_000_000)

    private func memory(_ id: String, _ kind: PhotoMemory.Kind, minutes: Double = 0) -> PhotoMemory {
        PhotoMemory(id: id, coordinate: sydney, takenAt: noon.addingTimeInterval(minutes * 60), kind: kind)
    }

    private func city(_ memories: [PhotoMemory]) -> CityCluster {
        CityCluster(id: "Sydney|Australia", name: "Sydney", country: "Australia", center: sydney,
                    memories: memories.sorted { ($0.takenAt ?? .distantPast) > ($1.takenAt ?? .distantPast) })
    }

    @Test func countsPhotosVideosAndNotesSeparately() {
        let sydney = city([memory("p", .photo), memory("v", .video), memory("t", .text), memory("a", .voice)])

        #expect(sydney.photoCount == 1)
        #expect(sydney.videoCount == 1)
        #expect(sydney.noteCount == 2)
        #expect(sydney.subtitle == "1 photo · 1 video · 2 notes")
    }

    @Test func coverIsAPictureEvenWhenANoteIsNewer() {
        let sydney = city([memory("p", .photo, minutes: 0), memory("t", .text, minutes: 30)])

        #expect(sydney.cover?.id == "p")
    }

    @Test func dayCoverPrefersPhotoThenVideoThenNote() {
        let sydney = city([memory("t", .text, minutes: 0), memory("v", .video, minutes: 5)])

        #expect(sydney.days.first?.cover?.id == "v")
    }

    @Test func aCityOfOnlyNotesStillHasACover() {
        let sydney = city([memory("t", .text)])

        #expect(sydney.cover?.id == "t")
    }

    @Test(arguments: [
        (PhotoMemory.Kind.photo, "Photo", false),
        (.video, "Video", true),
        (.text, "Note", false),
        (.voice, "Voice note", true),
    ])
    func kindNamesAndPlayability(kind: PhotoMemory.Kind, name: String, playable: Bool) {
        let item = memory("x", kind)

        #expect(item.kindName == name)
        #expect(item.isPlayable == playable)
    }
}
