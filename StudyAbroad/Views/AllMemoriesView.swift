import SwiftUI

/// Every photo and video from one city ("All memories" in the Figma file),
/// sorted by day or by type. Tap one to view it full screen.
struct AllMemoriesView: View {
    let city: CityCluster
    /// The city as it is now (it changes when you add, caption or remove memories),
    /// falling back to the one you tapped if it has just disappeared.
    private var current: CityCluster { store.cities.first { $0.id == city.id } ?? city }
    @State private var grouping: Grouping = .day
    @State private var playing: ViewerRequest?
    @Environment(MemoryStore.self) private var store

    enum Grouping: String, CaseIterable, Identifiable {
        case day = "Day"
        case type = "Type"
        var id: String { rawValue }
    }

    private struct MemorySection: Identifiable {
        let title: String
        let subtitle: String
        let memories: [PhotoMemory]
        var id: String { title }
    }

    private var sections: [MemorySection] {
        switch grouping {
        case .day:
            return current.days.map { day in
                MemorySection(title: day.longTitle, subtitle: day.momentsText, memories: day.memories)
            }
        case .type:
            let byOldest = current.memories.reversed()
            let photos = byOldest.filter(\.isPhoto)
            let videos = byOldest.filter(\.isVideo)
            let notes = byOldest.filter(\.isNote)
            return [
                MemorySection(title: "Photos", subtitle: "\(photos.count) photo\(photos.count == 1 ? "" : "s")", memories: photos),
                MemorySection(title: "Videos", subtitle: "\(videos.count) video\(videos.count == 1 ? "" : "s")", memories: videos),
                MemorySection(title: "Notes", subtitle: "\(notes.count) note\(notes.count == 1 ? "" : "s")", memories: notes),
            ].filter { !$0.memories.isEmpty }
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 3)

    var body: some View {
        let shown = sections
        let everything = shown.flatMap(\.memories)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("\(current.memories.count) moments worth keeping")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 2)

                Picker("Sort by", selection: $grouping) {
                    ForEach(Grouping.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.top, 20)
                .padding(.bottom, 8)

                ForEach(shown) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.title2.bold())
                        Text(section.subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 26)
                    .padding(.bottom, 12)

                    LazyVGrid(columns: columns, spacing: 7) {
                        ForEach(section.memories) { memory in
                            Button {
                                playing = ViewerRequest(memories: everything, start: memory)
                            } label: {
                                Color.clear
                                    .aspectRatio(116.0 / 139.0, contentMode: .fit)
                                    .overlay {
                                        GeometryReader { geo in
                                            AssetThumbnail(memory: memory, width: geo.size.width, height: geo.size.height)
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        // A small speech bubble on memories that have a caption.
                                        if !memory.isNote && !store.caption(for: memory.id).isEmpty {
                                            Image(systemName: "text.bubble.fill")
                                                .font(.caption)
                                                .foregroundStyle(.white)
                                                .shadow(color: .black.opacity(0.6), radius: 2)
                                                .padding(8)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(cellLabel(for: memory))
                            .accessibilityIdentifier("memoryCell")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .navigationTitle("All memories")
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(item: $playing) { request in
            MemoryViewer(title: current.name, memories: request.memories, start: request.start)
        }
    }

    /// "Video, 0:24", "Photo, captioned: Bondi at dusk", "Note"…
    private func cellLabel(for memory: PhotoMemory) -> String {
        var label = memory.isPlayable ? "\(memory.kindName), \(memory.durationText)" : memory.kindName
        let caption = store.caption(for: memory.id)
        if !caption.isEmpty { label += ", captioned: \(caption.prefix(80))" }
        return label
    }
}
