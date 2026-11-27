import SwiftUI

/// Every photo and video from one city ("All memories" in the Figma file),
/// sorted by day or by type. Tap one to view it full screen.
struct AllMemoriesView: View {
    let city: CityCluster
    @State private var grouping: Grouping = .day
    @State private var playing: ViewerRequest?

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
            return city.days.map { day in
                MemorySection(title: day.longTitle, subtitle: day.momentsText, memories: day.memories)
            }
        case .type:
            let byOldest = city.memories.reversed()
            let photos = byOldest.filter { !$0.isVideo }
            let videos = byOldest.filter { $0.isVideo }
            return [
                MemorySection(title: "Photos", subtitle: "\(photos.count) photo\(photos.count == 1 ? "" : "s")", memories: photos),
                MemorySection(title: "Videos", subtitle: "\(videos.count) video\(videos.count == 1 ? "" : "s")", memories: videos),
            ].filter { !$0.memories.isEmpty }
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 3)

    var body: some View {
        let shown = sections
        let everything = shown.flatMap(\.memories)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("\(city.memories.count) moments worth keeping")
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
                            }
                            .buttonStyle(.plain)
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
            MemoryViewer(title: city.name, memories: request.memories, start: request.start)
        }
    }
}
