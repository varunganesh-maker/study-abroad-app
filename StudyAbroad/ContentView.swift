import SwiftUI

/// Root screen: asks for photo access first, then shows the app's tabs.
struct ContentView: View {
    @Environment(MemoryStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

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
                        .tabItem { Label("Map", systemImage: "map") }
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
            }
        }
    }
}
