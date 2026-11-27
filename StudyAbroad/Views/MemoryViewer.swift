import AVKit
import SwiftUI

/// Full-screen swipe-through of a city's memories. Swipe sideways to move, tap ✕ to close.
struct MemoryViewer: View {
    let memories: [PhotoMemory]
    let start: PhotoMemory
    @State private var currentID: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(memories) { memory in
                    MemoryPage(memory: memory, isCurrent: memory.id == currentID)
                        .containerRelativeFrame([.horizontal, .vertical])
                        .id(memory.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentID)
        .scrollIndicators(.hidden)
        .background(.black)
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .padding()
        }
        .overlay(alignment: .bottom) {
            if let current = memories.first(where: { $0.id == currentID }), let date = current.takenAt {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5), in: Capsule())
                    .padding(.bottom, 30)
            }
        }
        .onAppear { currentID = start.id }
    }
}

private struct MemoryPage: View {
    let memory: PhotoMemory
    let isCurrent: Bool
    @State private var image: UIImage?
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black
            if let player {
                VideoPlayer(player: player)
            } else if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: memory.id) {
            if memory.isVideo, let item = await PhotoLoader.shared.playerItem(for: memory.id) {
                player = AVPlayer(playerItem: item)
                if isCurrent { player?.play() }
            } else {
                let screen = UIScreen.main.bounds.size
                let scale = UIScreen.main.scale
                image = await PhotoLoader.shared.image(
                    for: memory.id,
                    targetSize: CGSize(width: screen.width * scale, height: screen.height * scale),
                    contentMode: .aspectFit
                )
            }
        }
        .onChange(of: isCurrent) { _, nowCurrent in
            if nowCurrent { player?.play() } else { player?.pause() }
        }
        .onDisappear { player?.pause() }
    }
}
