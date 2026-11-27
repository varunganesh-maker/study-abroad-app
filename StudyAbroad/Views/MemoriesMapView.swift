import MapKit
import SwiftUI

/// Home screen: a map with one photo pin per city.
struct MemoriesMapView: View {
    @Environment(MemoryStore.self) private var store
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedCity: CityCluster?

    var body: some View {
        Map(position: $position) {
            ForEach(store.cities) { city in
                Annotation(city.name, coordinate: city.center, anchor: .bottom) {
                    Button { selectedCity = city } label: { CityPin(city: city) }
                        .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .overlay(alignment: .top) { ScanStatusPill() }
        .overlay {
            if !store.isScanning && store.cities.isEmpty {
                ContentUnavailableView(
                    "No geotagged photos yet",
                    systemImage: "location.slash",
                    description: Text("Photos taken with Location Services on for the Camera will show up here.")
                )
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding(40)
            }
        }
        .sheet(item: $selectedCity) { city in
            NavigationStack { CityDetailView(city: city) }
        }
    }
}

/// The round photo bubble with a count badge that sits on the map.
struct CityPin: View {
    let city: CityCluster

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let cover = city.cover {
                        AssetThumbnail(memory: cover, side: 56)
                    } else {
                        Color.gray.frame(width: 56, height: 56)
                    }
                }
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(radius: 3)

                Text("\(city.memories.count)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentColor))
                    .offset(x: 8, y: -4)
            }
            Image(systemName: "triangle.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(180))
                .offset(y: -3)
        }
    }
}

/// "Scanning…" / "Naming 12 places…" indicator.
struct ScanStatusPill: View {
    @Environment(MemoryStore.self) private var store

    var body: some View {
        if store.isScanning || store.isLimited {
            HStack(spacing: 8) {
                if store.isScanning { ProgressView().controlSize(.small) }
                Text(text).font(.footnote)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .padding(.top, 8)
        }
    }

    private var text: String {
        if store.isScanning {
            if store.remainingLookups > 0 { return "Naming \(store.remainingLookups) more places…" }
            return "Scanning your camera roll…"
        }
        return "Limited photo access: only selected photos are mapped"
    }
}
