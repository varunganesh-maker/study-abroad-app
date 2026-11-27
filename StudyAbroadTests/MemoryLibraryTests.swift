import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import StudyAbroad

/// Saving memories, captions, notes and "Remove from app" in a throwaway in-memory database.
@MainActor
struct MemoryLibraryTests {
    private let sydney = CLLocationCoordinate2D(latitude: -33.8568, longitude: 151.2153)
    private let noon = Date(timeIntervalSince1970: 1_800_000_000)
    private let container: ModelContainer

    init() throws {
        container = try ModelContainer(
            for: MemoryEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeLibrary() -> MemoryLibrary { MemoryLibrary(context: container.mainContext) }

    private func photo(_ id: String, daysLater: Double = 0) -> PhotoMemory {
        PhotoMemory(id: id, coordinate: sydney, takenAt: noon.addingTimeInterval(daysLater * 86_400), isVideo: false)
    }

    private func video(_ id: String) -> PhotoMemory {
        PhotoMemory(id: id, coordinate: sydney, takenAt: noon, isVideo: true, duration: 30)
    }

    @Test func autoAddSavesEachItemOnce() async {
        let library = makeLibrary()
        let scanned = [photo("a"), video("b")]

        let first = await library.autoAdd(scanned, rule: AutoAddRule(mode: .all))
        let second = await library.autoAdd(scanned, rule: AutoAddRule(mode: .all))

        #expect(first == 2)
        #expect(second == 0)
        #expect(library.count == 2)
        #expect(library.entry(for: "b")?.kind == .video)
    }

    @Test func autoAddFollowsTheRule() async {
        let library = makeLibrary()
        let rule = AutoAddRule(mode: .from, start: noon.addingTimeInterval(2 * 86_400))

        await library.autoAdd([photo("old"), photo("new", daysLater: 5)], rule: rule)

        #expect(!library.contains("old"))
        #expect(library.contains("new"))
    }

    @Test func offAddsNothingButKeepsWhatIsAlreadyThere() async {
        let library = makeLibrary()
        await library.autoAdd([photo("a")], rule: AutoAddRule(mode: .all))

        await library.autoAdd([photo("a"), photo("b")], rule: AutoAddRule(mode: .off))
        let shown = library.visible(scanned: [photo("a"), photo("b")])

        #expect(shown.memories.map(\.id) == ["a"])
    }

    @Test func captionsAreSavedTrimmedAndSurviveARestart() async {
        let first = makeLibrary()
        await first.autoAdd([video("v")], rule: AutoAddRule(mode: .all))
        let long = String(repeating: "Best swim of my life. ", count: 200) // captions can be any length

        first.setCaption("\n  " + long + "  \n", for: "v")
        let reopened = makeLibrary()

        #expect(reopened.captions["v"] == long.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    @Test func emptyCaptionsAreNotListed() async {
        let library = makeLibrary()
        await library.autoAdd([photo("a")], rule: AutoAddRule(mode: .all))

        library.setCaption("Hi", for: "a")
        library.setCaption("   ", for: "a")

        #expect(library.captions["a"] == nil)
    }

    @Test func removedPhotosStayRemovedAndAreNotAutoAddedAgain() async {
        let library = makeLibrary()
        await library.autoAdd([photo("a"), photo("b")], rule: AutoAddRule(mode: .all))

        library.remove("a")
        await library.autoAdd([photo("a"), photo("b")], rule: AutoAddRule(mode: .all))

        #expect(library.visible(scanned: [photo("a"), photo("b")]).memories.map(\.id) == ["b"])
        #expect(library.hiddenCount == 1)
    }

    @Test func removedPhotoKeepsItsCaptionAndCanComeBack() async {
        let library = makeLibrary()
        await library.autoAdd([photo("a")], rule: AutoAddRule(mode: .all))
        library.setCaption("Bondi at dusk", for: "a")

        library.remove("a")
        library.unhideAll()

        #expect(library.visible(scanned: [photo("a")]).memories.count == 1)
        #expect(library.captions["a"] == "Bondi at dusk")
    }

    @Test func pickingARemovedPhotoBringsItBack() async {
        let library = makeLibrary()
        await library.autoAdd([photo("a")], rule: AutoAddRule(mode: .all))
        library.remove("a")

        library.addAsset("a", kind: .photo, source: .picker, coordinate: nil)

        #expect(library.visible(scanned: [photo("a")]).memories.count == 1)
    }

    @Test func pickedPhotoWithNoGPSIsReportedAsMissingWithItsSavedPlace() {
        let library = makeLibrary()

        library.addAsset("nogps", kind: .photo, source: .picker, coordinate: sydney)
        let shown = library.visible(scanned: [])

        #expect(shown.memories.isEmpty)
        #expect(shown.missing["nogps"]?.latitude == sydney.latitude)
    }

    @Test func notesShowUpWhereTheyWereWritten() {
        let library = makeLibrary()

        let id = library.addNote(kind: .text, text: "The barista remembered my order", coordinate: sydney, takenAt: noon)
        let shown = library.visible(scanned: [])

        #expect(shown.memories.count == 1)
        #expect(shown.memories.first?.id == id)
        #expect(shown.memories.first?.kind == .text)
        #expect(shown.memories.first?.takenAt == noon)
        #expect(library.captions[id] == "The barista remembered my order")
    }

    @Test func deletingANoteRemovesItForGood() {
        let library = makeLibrary()
        let id = library.addNote(kind: .text, text: "Gone", coordinate: sydney, takenAt: noon)

        library.remove(id)

        #expect(!library.contains(id))
        #expect(library.hiddenCount == 0)
        #expect(library.visible(scanned: []).memories.isEmpty)
    }

    @Test func voiceNoteKeepsItsLength() {
        let library = makeLibrary()

        let id = library.addNote(kind: .voice, text: "", coordinate: sydney, takenAt: noon, duration: 18)

        #expect(library.visible(scanned: []).memories.first { $0.id == id }?.duration == 18)
    }

    @Test func manyPhotosAtOnce() async {
        let library = makeLibrary()
        let scanned = (0..<1_200).map { photo("p\($0)") }

        let added = await library.autoAdd(scanned, rule: AutoAddRule(mode: .all))

        #expect(added == 1_200)
        #expect(library.visible(scanned: scanned).memories.count == 1_200)
    }
}
