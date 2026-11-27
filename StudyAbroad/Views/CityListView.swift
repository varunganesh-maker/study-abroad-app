import CoreLocation
import SwiftUI

/// Second tab: every city as a list, most memories first.
struct CityListView: View {
    @Environment(MemoryStore.self) private var store
    @Environment(VisitMonitor.self) private var visits

    var body: some View {
        NavigationStack {
            List(store.cities) { city in
                NavigationLink(value: city) {
                    HStack(spacing: 12) {
                        if let cover = city.cover {
                            AssetThumbnail(memory: cover, side: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(city.name).font(.headline)
                            Text([city.country, city.dateRangeText].compactMap { $0 }.joined(separator: " · "))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(city.statsText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Cities")
            .navigationDestination(for: CityCluster.self) { city in
                CityStoryView(city: city)
            }
            .refreshable { store.scan() }
            #if DEBUG
            .toolbar {
                // Only in builds run from Xcode: pretend you just spent an hour where you are now,
                // so you can try "You've been here" without walking anywhere.
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Test visit", systemImage: "mappin.and.ellipse") {
                        let surryHills = CLLocationCoordinate2D(latitude: -33.8862, longitude: 151.2108)
                        let here = CLLocationManager().location?.coordinate ?? surryHills
                        visits.record(coordinate: here, arrival: .now.addingTimeInterval(-55 * 60), departure: .now)
                    }
                }
            }
            #endif
            .overlay {
                if store.cities.isEmpty {
                    if store.isScanning {
                        ProgressView("Scanning your camera roll…")
                    } else {
                        ContentUnavailableView("No cities yet", systemImage: "building.2")
                    }
                }
            }
        }
    }
}
