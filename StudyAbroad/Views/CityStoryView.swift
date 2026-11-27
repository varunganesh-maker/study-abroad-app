import SwiftData
import SwiftUI

/// A city's page ("Sydney stories" in the Figma file): a big card for your latest day,
/// then a row of all your days. Tap a day to play it like a story.
struct CityStoryView: View {
    let city: CityCluster
    /// The city as it is now (it changes when you add, caption or remove memories),
    /// falling back to the one you tapped if it has just disappeared.
    private var current: CityCluster { store.cities.first { $0.id == city.id } ?? city }

    /// Which memories the full-screen viewer is showing, and where it starts.
    @State private var playing: ViewerRequest?
    @Environment(MemoryStore.self) private var store
    @Query(filter: #Predicate<Visit> { $0.statusRaw == "saved" }) private var savedVisits: [Visit]

    /// Your best-rated places in this city (7 and up), best first.
    private var lovedPlaces: [Visit] {
        savedVisits
            .filter { $0.city == current.name && ($0.rating ?? 0) >= 7 }
            .sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
    }

    var body: some View {
        let days = current.days
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(current.statsText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 14)

                if let latest = days.last(where: { $0.date != nil }) ?? days.last {
                    HeroDayCard(day: latest, title: shortCaption(for: latest) ?? heroTitle(for: latest, in: days)) {
                        play(latest)
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("Your days")
                        .font(.title2.bold())
                    Spacer()
                    NavigationLink("View all") { AllMemoriesView(city: current) }
                }
                .padding(.top, 26)
                .padding(.bottom, 12)

                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 10) {
                        ForEach(days.reversed()) { day in
                            Button { play(day) } label: { DayCard(day: day, caption: firstCaption(for: day)) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .scrollIndicators(.hidden)
                .padding(.horizontal, -20) // let the row run to the screen edges

                if !lovedPlaces.isEmpty {
                    Text("Places you loved")
                        .font(.title2.bold())
                        .padding(.top, 26)
                        .padding(.bottom, 10)
                    ForEach(lovedPlaces.prefix(5)) { visit in
                        NavigationLink {
                            PlaceView(visit: visit)
                        } label: {
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(visit.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(visit.rating ?? 0, format: .number.precision(.fractionLength(1)))
                                        .bold()
                                        .foregroundStyle(.tint)
                                        .monospacedDigit()
                                }
                                .font(.subheadline)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 2)
                                if !visit.recap.isEmpty {
                                    Text(visit.recap)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .padding(.horizontal, 2)
                                        .padding(.bottom, 4)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .navigationTitle(current.name)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(item: $playing) { request in
            MemoryViewer(title: current.name, memories: request.memories, start: request.start)
        }
    }

    private func play(_ day: MemoryDay) {
        guard let first = day.memories.first else { return }
        playing = ViewerRequest(memories: day.memories, start: first)
    }

    /// The first caption written that day (first line only), e.g. "Saltwater".
    private func firstCaption(for day: MemoryDay) -> String? {
        for memory in day.memories {
            let caption = store.caption(for: memory.id)
            if let line = caption.split(separator: "\n").first.map(String.init), !line.isEmpty { return line }
        }
        return nil
    }

    /// A caption short enough to be the day's title ("First light, new city" in the mockup).
    private func shortCaption(for day: MemoryDay) -> String? {
        guard let caption = firstCaption(for: day), caption.count <= 40 else { return nil }
        return caption
    }

    /// "First day in Sydney", "Day 4 in Sydney"…
    private func heroTitle(for day: MemoryDay, in days: [MemoryDay]) -> String {
        guard day.date != nil, let index = days.firstIndex(of: day) else { return current.name }
        return index == 0 ? "First day in \(current.name)" : "Day \(index + 1) in \(current.name)"
    }
}

/// What to open in the full-screen viewer.
struct ViewerRequest: Identifiable {
    let memories: [PhotoMemory]
    let start: PhotoMemory
    /// Shown at the top of the viewer (a city's name, "Recently added"). Screens that know their own
    /// title (the city page) can leave it empty.
    var title: String = ""
    var id: String { start.id + "|\(memories.count)" }
}

/// The big photo card with the day's date, a title and "▶ Play day".
private struct HeroDayCard: View {
    let day: MemoryDay
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { geo in
                Group {
                    if let cover = day.cover {
                        AssetThumbnail(memory: cover, width: geo.size.width, height: geo.size.height)
                    } else {
                        Color.secondary.opacity(0.15)
                    }
                }
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.black.opacity(0), .black.opacity(0.65)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                }
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(day.longTitle.uppercased())
                            .font(.footnote)
                        Text(title)
                            .font(.title2.bold())
                        HStack(spacing: 20) {
                            Text(day.momentsText)
                            Label("Play day", systemImage: "play.fill")
                        }
                        .font(.subheadline)
                        .padding(.top, 2)
                    }
                    .foregroundStyle(.white)
                    .padding(18)
                }
            }
            .frame(height: 316)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title), \(day.momentsText). Play day.")
    }
}

/// One small card in the "Your days" row.
private struct DayCard: View {
    let day: MemoryDay
    /// The day's first caption, shown instead of the moment count ("Tue 25 · Saltwater").
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let cover = day.cover {
                    AssetThumbnail(memory: cover, width: 176, height: 132)
                } else {
                    Color.secondary.opacity(0.15).frame(width: 176, height: 132)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            Text("\(day.shortTitle) · \(caption ?? day.momentsText)")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 2)
        }
        .frame(width: 176, alignment: .leading)
    }
}
