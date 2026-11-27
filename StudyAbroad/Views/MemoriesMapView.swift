import MapKit
import SwiftUI

/// Home screen ("Memories" in the Figma file): a night-style map with a glowing dot per city,
/// a sparkle where you are now, and a card for the city you're in.
struct MemoriesMapView: View {
    @Environment(MemoryStore.self) private var store
    @State private var location = LocationProvider()
    @State private var position: MapCameraPosition = .region(MapScope.australiaRegion)
    @State private var scope: MapScope = .australia
    @State private var path: [CityCluster] = []
    /// Trip names arrive with the "Start a new trip" feature; for now this is a fixed default.
    @AppStorage("tripName") private var tripName = "Study Abroad Spring 2027"

    var body: some View {
        NavigationStack(path: $path) {
            map
                .safeAreaInset(edge: .top, spacing: 0) { header }
                .safeAreaInset(edge: .bottom, spacing: 0) { footer }
                .overlay { emptyState }
                .background(Theme.night)
                .environment(\.colorScheme, .dark)
                .toolbar(.hidden, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .tabBar)
                .navigationTitle("Memories") // used as the back button label on the city page
                .navigationDestination(for: CityCluster.self) { city in
                    CityStoryView(city: city)
                }
                .task { location.refresh() }
        }
    }

    // MARK: Map

    private var map: some View {
        Map(position: $position) {
            ForEach(store.cities) { city in
                Annotation(city.name, coordinate: city.center, anchor: .center) {
                    Button { path.append(city) } label: { CityDot(name: city.name) }
                        .buttonStyle(.plain)
                }
                .annotationTitles(.hidden)
            }
            if let here = location.location {
                Annotation("You", coordinate: here.coordinate, anchor: .center) {
                    YouAreHereSparkle()
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .onMapCameraChange(frequency: .onEnd) { context in
            // "Zoom follows your map": pinching updates the Australia / World / City switch.
            scope = MapScope.matching(context.region)
        }
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(tripName)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text("Memories")
                .font(.largeTitle.bold())
            Picker("Map zoom", selection: Binding(get: { scope }, set: { move(to: $0) })) {
                ForEach(MapScope.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.top, 12)
            ScanStatusPill()
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .background(
            LinearGradient(colors: [Theme.night, Theme.night.opacity(0.85), Theme.night.opacity(0)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .top)
        )
    }

    private func move(to newScope: MapScope) {
        scope = newScope
        withAnimation(.easeInOut(duration: 0.6)) {
            switch newScope {
            case .australia:
                position = .region(MapScope.australiaRegion)
            case .world:
                position = .region(MapScope.worldRegion)
            case .city:
                if let city = focusCity?.city {
                    position = .region(MKCoordinateRegion(center: city.center,
                                                          span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)))
                } else if let here = location.location {
                    position = .region(MKCoordinateRegion(center: here.coordinate,
                                                          span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)))
                }
            }
        }
    }

    // MARK: Footer

    /// The city you're in (within ~60 km), or else the city with your most recent memory.
    private var focusCity: (city: CityCluster, isHere: Bool)? {
        if let here = location.location {
            let nearest = store.cities.min { distance($0, here) < distance($1, here) }
            if let nearest, distance(nearest, here) < 60_000 { return (nearest, true) }
        }
        let latest = store.cities.max { ($0.cover?.takenAt ?? .distantPast) < ($1.cover?.takenAt ?? .distantPast) }
        return latest.map { ($0, false) }
    }

    private func distance(_ city: CityCluster, _ location: CLLocation) -> CLLocationDistance {
        CLLocation(latitude: city.center.latitude, longitude: city.center.longitude).distance(from: location)
    }

    @ViewBuilder private var footer: some View {
        if let focus = focusCity {
            VStack(spacing: 14) {
                Text("Pinch to explore · zoom follows your map")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button { path.append(focus.city) } label: {
                    HStack(spacing: 14) {
                        Group {
                            if let cover = focus.city.cover {
                                AssetThumbnail(memory: cover, side: 70)
                            } else {
                                Theme.pin.frame(width: 70, height: 70)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                        VStack(alignment: .leading, spacing: 6) {
                            Text(focus.isHere ? "You’re in \(focus.city.name)" : "Latest: \(focus.city.name)")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("\(focus.city.statsText)    ›")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder private var emptyState: some View {
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
}

/// The Australia / World / City switch above the map.
enum MapScope: String, CaseIterable, Identifiable {
    case australia, world, city

    var id: String { rawValue }
    var title: String {
        switch self {
        case .australia: "Australia"
        case .world: "World"
        case .city: "City"
        }
    }

    static let australiaRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -27.5, longitude: 134),
        span: MKCoordinateSpan(latitudeDelta: 40, longitudeDelta: 42)
    )
    static let worldRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 10, longitude: 140),
        span: MKCoordinateSpan(latitudeDelta: 150, longitudeDelta: 300)
    )

    /// Which option best describes what the map is showing after you pinch or pan.
    static func matching(_ region: MKCoordinateRegion) -> MapScope {
        let span = region.span.latitudeDelta
        if span < 4 { return .city }
        if span < 70 { return .australia }
        return .world
    }
}

/// A glowing lavender dot with the city's name beside it.
struct CityDot: View {
    let name: String

    var body: some View {
        Circle()
            .fill(Theme.pin)
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(color: Theme.pin.opacity(0.9), radius: 6)
            .frame(width: 44, height: 44) // big enough to tap
            .contentShape(Rectangle())
            .overlay(alignment: .leading) {
                Text(name)
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 2)
                    .fixedSize()
                    .offset(x: 32)
                    .allowsHitTesting(false)
            }
            .accessibilityLabel(name)
    }
}

/// The "✦" sparkle that marks where you are right now.
struct YouAreHereSparkle: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.pin.opacity(0.25))
                .frame(width: 44, height: 44)
            Image(systemName: "sparkle")
                .font(.title2.bold())
                .foregroundStyle(.white)
        }
        .accessibilityLabel("You are here")
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
