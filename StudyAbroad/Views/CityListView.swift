import CoreLocation
import SwiftUI

/// Second tab: every city as a list, newest memories first. Search by city, country or caption words.
struct CityListView: View {
    @Environment(MemoryStore.self) private var store
    @Environment(VisitMonitor.self) private var visits
    @State private var query = ""

    private var results: [CitySearch.Result] {
        CitySearch.search(query, in: store.cities, captions: store.captions)
    }

    var body: some View {
        NavigationStack {
            List(results) { result in
                NavigationLink(value: result.city) {
                    CityRow(city: result.city, snippet: result.snippet)
                }
            }
            .navigationTitle("Cities")
            .searchable(text: $query, prompt: "City, country or caption")
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
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
    }
}

/// One city in a list: cover picture, name, country and dates, and how many memories.
/// `snippet` is the caption that matched a search, shown in quotes.
struct CityRow: View {
    let city: CityCluster
    var snippet: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            if let cover = city.cover {
                AssetThumbnail(memory: cover, side: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(city.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text([city.country, city.dateRangeText].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let snippet {
                    Text("“\(snippet)”")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text(city.statsText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// "Find a city", opened with the magnifying glass on the map. Picking a city closes this and
/// opens its page.
struct CitySearchView: View {
    let onPick: (CityCluster) -> Void
    @Environment(MemoryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [CitySearch.Result] {
        CitySearch.search(query, in: store.cities, captions: store.captions)
    }

    var body: some View {
        NavigationStack {
            List(results) { result in
                Button {
                    dismiss()
                    onPick(result.city)
                } label: {
                    HStack {
                        CityRow(city: result.city, snippet: result.snippet)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Find a city")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "City, country or caption")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .overlay {
                if store.cities.isEmpty {
                    ContentUnavailableView("No cities yet", systemImage: "building.2",
                                           description: Text("Cities show up once you have memories with a place."))
                } else if results.isEmpty {
                    ContentUnavailableView("No memories in “\(query)” yet", systemImage: "magnifyingglass",
                                           description: Text("Only places you have memories in can be found."))
                }
            }
        }
        .lightSheet()
    }
}
