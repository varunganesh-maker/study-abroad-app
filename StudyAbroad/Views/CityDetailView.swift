import SwiftUI

/// One city: its photos and videos in a grid, grouped by day. Tap one to view it full screen.
struct CityDetailView: View {
    let city: CityCluster
    @State private var viewerStart: PhotoMemory?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 2)]

    private var days: [(day: Date?, memories: [PhotoMemory])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: city.memories) { memory in
            memory.takenAt.map { calendar.startOfDay(for: $0) }
        }
        return grouped
            .map { (day: $0.key, memories: $0.value) }
            .sorted { ($0.day ?? .distantPast) > ($1.day ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2, pinnedViews: [.sectionHeaders]) {
                ForEach(days, id: \.day) { group in
                    Section {
                        ForEach(group.memories) { memory in
                            Button { viewerStart = memory } label: {
                                GeometryReader { geo in
                                    AssetThumbnail(memory: memory, side: geo.size.width)
                                }
                                .aspectRatio(1, contentMode: .fit)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text(group.day.map { $0.formatted(date: .complete, time: .omitted) } ?? "Unknown date")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.bar)
                    }
                }
            }
        }
        .navigationTitle(city.name)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .top) {
            Text([city.country, city.subtitle].compactMap { $0 }.joined(separator: " · "))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
        }
        .fullScreenCover(item: $viewerStart) { start in
            MemoryViewer(memories: city.memories, start: start)
        }
    }
}
