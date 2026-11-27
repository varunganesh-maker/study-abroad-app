import SwiftData
import SwiftUI

/// A city's page ("Sydney stories" in the Figma file): a big card for your latest day,
/// then a row of all your days. Tap a day to play it like a story.
struct CityStoryView: View {
    let city: CityCluster

    /// Which memories the full-screen viewer is showing, and where it starts.
    @State private var playing: ViewerRequest?
    @Query(filter: #Predicate<Visit> { $0.statusRaw == "saved" }) private var savedVisits: [Visit]

    /// Your best-rated places in this city (7 and up), best first.
    private var lovedPlaces: [Visit] {
        savedVisits
            .filter { $0.city == city.name && ($0.rating ?? 0) >= 7 }
            .sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
    }

    var body: some View {
        let days = city.days
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(city.statsText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 14)

                if let latest = days.last(where: { $0.date != nil }) ?? days.last {
                    HeroDayCard(day: latest, title: heroTitle(for: latest, in: days)) {
                        play(latest)
                    }
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("Your days")
                        .font(.title2.bold())
                    Spacer()
                    NavigationLink("View all") { AllMemoriesView(city: city) }
                }
                .padding(.top, 26)
                .padding(.bottom, 12)

                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: 10) {
                        ForEach(days.reversed()) { day in
                            Button { play(day) } label: { DayCard(day: day) }
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
                        HStack(alignment: .firstTextBaseline) {
                            Text(visit.displayName)
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
                                .padding(.horizontal, 2)
                                .padding(.bottom, 4)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .navigationTitle(city.name)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(item: $playing) { request in
            MemoryViewer(title: city.name, memories: request.memories, start: request.start)
        }
    }

    private func play(_ day: MemoryDay) {
        guard let first = day.memories.first else { return }
        playing = ViewerRequest(memories: day.memories, start: first)
    }

    /// "First day in Sydney", "Day 4 in Sydney"…
    private func heroTitle(for day: MemoryDay, in days: [MemoryDay]) -> String {
        guard day.date != nil, let index = days.firstIndex(of: day) else { return city.name }
        return index == 0 ? "First day in \(city.name)" : "Day \(index + 1) in \(city.name)"
    }
}

/// What to open in the full-screen viewer.
struct ViewerRequest: Identifiable {
    let memories: [PhotoMemory]
    let start: PhotoMemory
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

            Text("\(day.shortTitle) · \(day.momentsText)")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 2)
        }
        .frame(width: 176, alignment: .leading)
    }
}
