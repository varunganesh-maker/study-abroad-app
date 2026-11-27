import SwiftData
import SwiftUI

@main
struct StudyAbroadApp: App {
    /// Photos, captions, notes and the city list.
    @State private var store: MemoryStore
    /// The on-phone database (memories, captions, notes, visits, ratings, recaps).
    private let container: ModelContainer
    /// Created at launch so iOS can wake the app in the background to report a visit.
    @State private var visits: VisitMonitor

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: Visit.self, MemoryEntry.self)
        } catch {
            fatalError("Could not open the app database: \(error)")
        }
        self.container = container
        _store = State(initialValue: MemoryStore(container: container))
        _visits = State(initialValue: VisitMonitor(container: container))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(visits)
        }
        .modelContainer(container)
    }
}
