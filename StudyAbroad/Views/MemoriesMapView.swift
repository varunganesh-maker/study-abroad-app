import MapKit
import SwiftUI

/// Home screen ("Memories" in the Figma file): a night-style map with a glowing dot per city,
/// a sparkle where you are now, and a card for the city you're in.
///
/// It opens on the city you're in (or the city of your newest memory when location is off).
/// After you save a moment it flies to where that moment went and says "Saved to …".
struct MemoriesMapView: View {
    @Environment(MemoryStore.self) private var store
    @State private var location = LocationProvider()
    @State private var position: MapCameraPosition = .region(MapScope.worldRegion(centeredOn: nil))
    @State private var scope: MapScope = .city
    /// The middle of the map after the last pinch or pan (picks the country name on the switch).
    @State private var visibleCenter: CLLocationCoordinate2D?
    /// True once you've moved the map, used the switch or search: the map stops moving on its own.
    @State private var userTookOver = false
    /// True once the map has centred on the city you're actually in (no more automatic moves).
    @State private var centeredOnHere = false
    @State private var path: [CityCluster] = []
    @State private var capturing = false
    @State private var showingSettings = false
    @State private var searching = false
    @State private var playing: ViewerRequest?
    /// Trip names arrive with the "Start a new trip" feature; for now this is a fixed default.
    @AppStorage("tripName") private var tripName = "Study Abroad Spring 2027"

    var body: some View {
        let focus = MapScope.focusCity(location: location.location, cities: store.cities)
        NavigationStack(path: $path) {
            map
                .safeAreaInset(edge: .top, spacing: 0) { header(focus: focus) }
                .safeAreaInset(edge: .bottom, spacing: 0) { footer(focus: focus) }
                .overlay { emptyState }
                .background(Theme.night)
                // The map screen is always dark, so its text is always light (see the contrast rule in Theme).
                .environment(\.colorScheme, .dark)
                .toolbar(.hidden, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .tabBar)
                .navigationTitle("Memories") // used as the back button label on the city page
                .navigationDestination(for: CityCluster.self) { city in
                    CityStoryView(city: city)
                }
                .task {
                    location.refresh()
                    VisitMonitor.requestNotificationPermission()
                }
                .onChange(of: focusKey(focus), initial: true) { _, _ in autoCenter(on: focus) }
                .onChange(of: savedCity?.id) { _, _ in
                    if let city = savedCity { fly(to: city) }
                }
                // Each sheet makes itself light (light background, dark text) with `.lightSheet()`.
                .sheet(isPresented: $capturing) { CaptureView() }
                .sheet(isPresented: $showingSettings) { SettingsView() }
                .sheet(isPresented: $searching) {
                    CitySearchView { city in
                        fly(to: city)
                        path.append(city)
                    }
                }
                .fullScreenCover(item: $playing) { request in
                    MemoryViewer(title: request.title, memories: request.memories, start: request.start)
                }
                .overlay(alignment: .bottom) { banner }
        }
    }

    // MARK: Banners

    /// The city the memory you just saved went into, once it's on the map.
    private var savedCity: CityCluster? {
        guard let id = store.justSaved, !store.isScanning else { return nil }
        return store.city(containing: id)
    }

    /// "Saved to Sydney · View" after you save a moment, or "Added 3 memories." style notices.
    @ViewBuilder private var banner: some View {
        if let city = savedCity, let id = store.justSaved {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.pin)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved to \(city.name)")
                        .font(.subheadline.weight(.semibold))
                    if let notice = store.notice {
                        Text(notice)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Button("View") { view(id, in: city) }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("viewSavedMemory")
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 20)
            .padding(.bottom, 130)
            .transition(.opacity)
            .task(id: id) {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                guard !Task.isCancelled else { return }
                withAnimation {
                    if store.justSaved == id { store.justSaved = nil }
                    store.notice = nil
                }
            }
        } else if let notice = store.notice, store.justSaved == nil {
            Text(notice)
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.nightCard, in: Capsule())
                .padding(.horizontal, 20)
                .padding(.bottom, 130)
                .transition(.opacity)
                .onTapGesture { store.notice = nil }
                .task(id: notice) {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    withAnimation { store.notice = nil }
                }
        }
    }

    /// Opens the memory you just saved, with the rest of that city's memories to swipe through.
    private func view(_ id: String, in city: CityCluster) {
        let inOrder = city.days.flatMap(\.memories)
        guard let memory = inOrder.first(where: { $0.id == id }) else { return }
        store.justSaved = nil
        store.notice = nil
        playing = ViewerRequest(memories: inOrder, start: memory, title: city.name)
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
            // "Zoom follows your map": pinching updates the City / Country / World switch.
            if position.positionedByUser { userTookOver = true }
            scope = MapScope.matching(span: context.region.span.latitudeDelta)
            visibleCenter = context.region.center
        }
    }

    // MARK: Moving the map

    /// Changes whenever the city to open on changes (or location arrives with no cities yet).
    private func focusKey(_ focus: (city: CityCluster, isHere: Bool)?) -> String {
        if let focus { return "\(focus.city.id)|\(focus.isHere)" }
        return location.location == nil ? "none" : "here"
    }

    /// Opens on the city you're in, or your newest memory's city, until you move the map yourself.
    /// Once it has centred on where you actually are, it stays put.
    private func autoCenter(on focus: (city: CityCluster, isHere: Bool)?) {
        guard !userTookOver, !position.positionedByUser, !centeredOnHere else { return }
        if let focus {
            position = .region(MapScope.cityRegion(focus.city.center))
            centeredOnHere = focus.isHere
        } else if let here = location.location {
            position = .region(MapScope.cityRegion(here.coordinate))
            centeredOnHere = true
        } else {
            return
        }
        scope = .city
    }

    /// Flies to a city (after saving a moment there, or picking it in search).
    private func fly(to city: CityCluster) {
        userTookOver = true
        centeredOnHere = true
        scope = .city
        withAnimation(.easeInOut(duration: 0.8)) {
            position = .region(MapScope.cityRegion(city.center))
        }
    }

    /// The country the middle option is named after: the one the map is pointing at, else yours.
    private func countryName(focus: (city: CityCluster, isHere: Bool)?) -> String? {
        let pointedAt = visibleCenter.flatMap { MapScope.nearestCity(to: $0, in: store.cities) }
        return (pointedAt ?? focus?.city)?.country
    }

    private func move(to newScope: MapScope, focus: (city: CityCluster, isHere: Bool)?) {
        let region: MKCoordinateRegion?
        switch newScope {
        case .city:
            if let city = focus?.city {
                region = MapScope.cityRegion(city.center)
            } else if let here = location.location {
                region = MapScope.cityRegion(here.coordinate)
            } else {
                region = nil
            }
        case .country:
            region = countryName(focus: focus).flatMap { MapScope.countryRegion($0, cities: store.cities) }
        case .world:
            let longitude = location.location?.coordinate.longitude ?? focus?.city.center.longitude
            region = MapScope.worldRegion(centeredOn: longitude)
        }
        // Nowhere to go (no memories and no location yet): leave the switch where it was.
        guard let region else { return }
        userTookOver = true
        scope = newScope
        withAnimation(.easeInOut(duration: 0.6)) {
            position = .region(region)
        }
    }

    // MARK: Header

    private func header(focus: (city: CityCluster, isHere: Bool)?) -> some View {
        let country = countryName(focus: focus)
        return VStack(alignment: .leading, spacing: 6) {
            Text(tripName)
                .font(.footnote)
                .foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 10) {
                Text("Memories")
                    .font(.largeTitle.bold())
                Spacer()
                Button { searching = true } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(Theme.nightCard, in: Circle())
                }
                .accessibilityLabel("Find a city")
                .accessibilityIdentifier("findCityButton")
                Button { showingSettings = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(Theme.nightCard, in: Circle())
                }
                .accessibilityLabel("Settings")
                Button { capturing = true } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .frame(width: 48, height: 48)
                        .background(Theme.nightCard, in: Circle())
                }
                .accessibilityLabel("Add a memory")
                .accessibilityIdentifier("addMemoryButton")
            }
            .foregroundStyle(.white)
            Picker("Map zoom", selection: Binding(get: { scope }, set: { move(to: $0, focus: focus) })) {
                ForEach(MapScope.allCases) { Text($0.title(country: country)).tag($0) }
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

    // MARK: Footer

    private func footer(focus: (city: CityCluster, isHere: Bool)?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if !store.recentlyAdded.isEmpty {
                recentlyAddedRow
            } else if focus != nil {
                Text("Pinch to explore · zoom follows your map")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            if let focus {
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
                                .foregroundStyle(.white)
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
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    /// Small pictures of what you added yourself this week. Tap one to open it.
    private var recentlyAddedRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recently added")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(store.recentlyAdded) { memory in
                        Button {
                            playing = ViewerRequest(memories: store.recentlyAdded, start: memory, title: "Recently added")
                        } label: {
                            AssetThumbnail(memory: memory, side: 52)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(memory.kindName)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("recentlyAdded")
    }

    @ViewBuilder private var emptyState: some View {
        if !store.isScanning && store.cities.isEmpty {
            ContentUnavailableView(
                "No memories yet",
                systemImage: "location.slash",
                description: Text("Photos taken with Location Services on for the Camera show up here. Tap ＋ to add photos, videos or notes yourself.")
            )
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(40)
        }
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
