import SwiftUI

/// Second tab: every city as a list, most memories first.
struct CityListView: View {
    @Environment(MemoryStore.self) private var store

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
