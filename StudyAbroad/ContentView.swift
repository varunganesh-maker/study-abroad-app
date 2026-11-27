import SwiftData
import SwiftUI

/// Root screen: asks for photo access first, then shows the app's tabs.
/// Also pops up "You've been here" whenever a detected visit is waiting for a rating.
struct ContentView: View {
    @Environment(MemoryStore.self) private var store
    @Environment(VisitMonitor.self) private var visits
    @Environment(\.scenePhase) private var scenePhase

    @Query(filter: #Predicate<Visit> { $0.statusRaw == "pending" && $0.placeName != "" },
           sort: \Visit.arrival)
    private var waitingVisits: [Visit]
    @State private var reviewing: Visit?
    @State private var lastShown: Visit?
    /// Visits you swiped away: asked again next time the app opens, not straight away.
    @State private var askLater: Set<PersistentIdentifier> = []

    var body: some View {
        Group {
            switch store.access {
            case .unknown:
                ProgressView()
            case .notDetermined, .denied:
                PermissionView()
            case .granted:
                TabView {
                    MemoriesMapView()
                        .tabItem { Label("Memories", systemImage: "map") }
                    CityListView()
                        .tabItem { Label("Cities", systemImage: "building.2") }
                }
            }
        }
        .task { await store.start() }
        .onChange(of: scenePhase) { _, phase in
            // Re-scan every time the app comes back to the foreground,
            // so new photos show up without a manual refresh.
            if phase == .active {
                Task { await store.refreshIfAllowed() }
                visits.nameUnnamedVisits()
                showNextVisit()
            } else if phase == .background {
                askLater = []
            }
        }
        .onChange(of: waitingVisits.count) { _, _ in showNextVisit() }
        .onChange(of: store.access) { _, _ in showNextVisit() }
        .sheet(item: $reviewing, onDismiss: {
            if let visit = lastShown, visit.status == .pending {
                askLater.insert(visit.persistentModelID)
            }
            showNextVisit()
        }) { visit in
            VisitReviewView(visit: visit)
                .presentationDragIndicator(.hidden) // the card draws its own grabber
                .onAppear { lastShown = visit }
        }
    }

    private func showNextVisit() {
        guard store.access == .granted, reviewing == nil else { return }
        reviewing = waitingVisits.first { !askLater.contains($0.persistentModelID) }
    }
}
