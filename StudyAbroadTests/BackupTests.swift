import CoreLocation
import Foundation
import SwiftData
import Testing
@testable import StudyAbroad

/// Backing up and restoring captions, notes and ratings, using throwaway in-memory databases.
@MainActor
struct BackupTests {
    private let sydney = CLLocationCoordinate2D(latitude: -33.8568, longitude: 151.2153)
    private let noon = Date(timeIntervalSince1970: 1_800_000_000)
    /// Keeps the in-memory databases alive for the whole test.
    private let containers = Containers()

    private final class Containers {
        var all: [ModelContainer] = []
    }

    private func freshContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: MemoryEntry.self, Visit.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        containers.all.append(container)
        return ModelContext(container)
    }

    /// A phone with one captioned photo, one text note and one rated place.
    private func filledContext() throws -> ModelContext {
        let context = try freshContext()
        let library = MemoryLibrary(context: context)
        library.addAsset("photo-1", kind: .photo, source: .picker, coordinate: nil)
        library.setCaption("Bondi at dusk", for: "photo-1")
        library.addNote(kind: .text, text: "Barista remembered me", coordinate: sydney, takenAt: noon, key: "note-1")
        let visit = Visit(coordinate: sydney, arrival: noon, departure: noon.addingTimeInterval(3600))
        visit.placeName = "AP Bakery"
        visit.rating = 9.2
        visit.recap = "Flaky pastry"
        visit.status = .saved
        context.insert(visit)
        try context.save()
        return context
    }

    @Test func roundTripsThroughJSON() throws {
        let file = Backup.make(context: try filledContext(), rule: AutoAddRule(mode: .from, start: noon))

        let decoded = try BackupFile.decode(try file.encoded())

        #expect(decoded == file)
        #expect(decoded.memories.count == 2)
        #expect(decoded.visits.count == 1)
        #expect(decoded.autoAddMode == "from")
    }

    @Test func restoresEverythingOntoAnEmptyPhone() throws {
        let file = Backup.make(context: try filledContext())
        let empty = try freshContext()

        let result = Backup.restore(file, into: empty)
        let library = MemoryLibrary(context: empty)

        #expect(result.memoriesAdded == 2)
        #expect(result.visitsAdded == 1)
        #expect(library.captions["photo-1"] == "Bondi at dusk")
        #expect(library.captions["note-1"] == "Barista remembered me")
        let visits = try empty.fetch(FetchDescriptor<Visit>())
        #expect(visits.first?.rating == 9.2)
        #expect(visits.first?.status == .saved)
    }

    @Test func restoringTwiceAddsNothingTheSecondTime() throws {
        let file = Backup.make(context: try filledContext())
        let phone = try freshContext()

        _ = Backup.restore(file, into: phone)
        let second = Backup.restore(file, into: phone)

        #expect(second == Backup.RestoreResult())
        #expect(try phone.fetch(FetchDescriptor<MemoryEntry>()).count == 2)
        #expect(try phone.fetch(FetchDescriptor<Visit>()).count == 1)
    }

    @Test func neverOverwritesACaptionYouChangedSince() throws {
        let file = Backup.make(context: try filledContext())
        let phone = try freshContext()
        let library = MemoryLibrary(context: phone)
        library.addAsset("photo-1", kind: .photo, source: .picker, coordinate: nil)
        library.setCaption("Newer caption", for: "photo-1")

        _ = Backup.restore(file, into: phone)
        library.reload()

        #expect(library.captions["photo-1"] == "Newer caption")
    }

    @Test func fillsInAnEmptyCaption() throws {
        let file = Backup.make(context: try filledContext())
        let phone = try freshContext()
        let library = MemoryLibrary(context: phone)
        library.addAsset("photo-1", kind: .photo, source: .autoAdd, coordinate: nil)

        let result = Backup.restore(file, into: phone)
        library.reload()

        #expect(result.captionsFilled == 1)
        #expect(library.captions["photo-1"] == "Bondi at dusk")
    }

    @Test func photosNotOnThisPhoneAreCountedButNotesStillComeBack() throws {
        let file = Backup.make(context: try filledContext())
        let phone = try freshContext()

        let result = Backup.restore(file, into: phone, assetExists: { _ in false })

        #expect(result.notFound == 1)
        #expect(result.memoriesAdded == 1) // the note
        #expect(MemoryLibrary(context: phone).contains("note-1"))
    }

    @Test func newPhoneIdsAreUsedWhenPhotosKnowsThem() throws {
        let file = Backup.make(context: try filledContext())
        let phone = try freshContext()

        let result = Backup.restore(file, into: phone, localIDs: ["photo-1": "new-phone-id"],
                                    assetExists: { $0 == "new-phone-id" })

        #expect(result.notFound == 0)
        #expect(MemoryLibrary(context: phone).captions["new-phone-id"] == "Bondi at dusk")
    }

    @Test func rejectsAFileThatIsNotABackup() {
        #expect(throws: (any Error).self) {
            try BackupFile.decode(Data("{\"hello\": 1}".utf8))
        }
    }
}
