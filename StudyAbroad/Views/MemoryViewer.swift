import AVKit
import SwiftUI

/// Full-screen, story-style viewer ("Memory viewer" in the Figma file).
/// Swipe sideways for the next memory, tap ✕ to close. Videos play with your own controls.
struct MemoryViewer: View {
    let title: String
    let memories: [PhotoMemory]
    let start: PhotoMemory
    @State private var currentID: String?
    @State private var video = VideoPlayback()
    @Environment(\.dismiss) private var dismiss

    private var currentIndex: Int {
        memories.firstIndex { $0.id == currentID } ?? 0
    }

    private var current: PhotoMemory? {
        memories.indices.contains(currentIndex) ? memories[currentIndex] : nil
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(memories) { memory in
                    MemoryPage(memory: memory, player: memory.id == currentID ? video.player : nil)
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
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) { caption }
        .environment(\.colorScheme, .dark)
        .onAppear { currentID = start.id }
        .onChange(of: currentID) { _, _ in video.load(current) }
        .onDisappear { video.stop() }
    }

    // MARK: Top: close button + story progress

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Close")

            if memories.count <= 30 {
                // One bar per memory, like stories.
                HStack(spacing: 7) {
                    ForEach(memories.indices, id: \.self) { index in
                        Capsule()
                            .fill(.white.opacity(index <= currentIndex ? 1 : 0.35))
                            .frame(height: 3)
                    }
                }
            } else {
                // Too many for separate bars: one bar that fills up as you go.
                ProgressView(value: Double(currentIndex + 1), total: Double(memories.count))
                    .tint(.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    // MARK: Bottom: caption, video controls, hint

    private var caption: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title2.bold())
            if let date = current?.takenAt {
                Text("\(date.formatted(.dateTime.day().month(.wide))) · \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
            }
            if let current {
                Text("\(current.isVideo ? "Video" : "Photo") · \(currentIndex + 1) of \(memories.count)")
                    .font(.footnote)
                    .opacity(0.85)
            }

            if current?.isVideo == true {
                HStack(spacing: 14) {
                    Button { video.togglePlay() } label: {
                        Image(systemName: video.isPlaying ? "pause.fill" : "play.fill")
                            .font(.body.weight(.semibold))
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .accessibilityLabel(video.isPlaying ? "Pause" : "Play")

                    Text(PhotoMemory.timeText(video.currentTime))
                        .font(.subheadline.monospacedDigit())
                    ProgressView(value: min(video.currentTime, video.duration), total: max(video.duration, 0.1))
                        .tint(.white)
                    Text(PhotoMemory.timeText(video.duration))
                        .font(.subheadline.monospacedDigit())
                }
                .padding(.top, 20)
            }

            Text("Swipe for the next memory")
                .font(.footnote)
                .opacity(0.85)
                .frame(maxWidth: .infinity)
                .padding(.top, current?.isVideo == true ? 8 : 24)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .padding(.top, 80)
        .padding(.bottom, 8)
        .background(alignment: .bottom) {
            LinearGradient(colors: [.black.opacity(0), .black.opacity(0.8)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }
}

/// One page of the viewer: a photo, or a video when it's the current page.
private struct MemoryPage: View {
    let memory: PhotoMemory
    /// Only the page on screen gets a player; the others show a still frame.
    let player: AVPlayer?
    @State private var image: UIImage?

    /// Tall pictures fill the screen like a story; wide ones fit so nothing important is cut off.
    private var fills: Bool { memory.isPortrait }

    var body: some View {
        // Black background sets the page size; the picture sits on top and is cropped to it.
        Color.black
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: fills ? .fill : .fit)
                }
            }
            .overlay {
                if let player {
                    PlayerLayerView(player: player, gravity: fills ? .resizeAspectFill : .resizeAspect)
                }
            }
            .overlay {
                if image == nil && player == nil {
                    ProgressView().tint(.white)
                }
            }
            .clipped()
            .task(id: memory.id) {
                let screen = UIScreen.main.bounds.size
                let scale = UIScreen.main.scale
                image = await PhotoLoader.shared.image(
                    for: memory.id,
                    targetSize: CGSize(width: screen.width * scale, height: screen.height * scale),
                    contentMode: fills ? .aspectFill : .aspectFit
                )
            }
    }
}

/// Shows video frames without Apple's default player buttons, so we can draw our own.
private struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let gravity: AVLayerVideoGravity

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        view.playerLayer.player = player
        view.playerLayer.videoGravity = gravity
    }

    final class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

/// Plays the current video and keeps track of time for the progress bar.
@MainActor
@Observable
final class VideoPlayback {
    private(set) var player: AVPlayer?
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPlaying = false

    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: NSObjectProtocol?
    @ObservationIgnored private var loadTask: Task<Void, Never>?

    func load(_ memory: PhotoMemory?) {
        stop()
        guard let memory, memory.isVideo else { return }
        duration = memory.duration
        loadTask = Task {
            guard let item = await PhotoLoader.shared.playerItem(for: memory.id), !Task.isCancelled else { return }
            let player = AVPlayer(playerItem: item)
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.25, preferredTimescale: 600), queue: .main
            ) { [weak self] time in
                MainActor.assumeIsolated { self?.currentTime = time.seconds }
            }
            endObserver = NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.isPlaying = false }
            }
            self.player = player
            player.play()
            isPlaying = true
        }
    }

    func togglePlay() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            if currentTime >= duration - 0.25 { player.seek(to: .zero) }
            player.play()
        }
        isPlaying.toggle()
    }

    func stop() {
        loadTask?.cancel()
        loadTask = nil
        if let timeObserver, let player { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player?.pause()
        player = nil
        currentTime = 0
        isPlaying = false
    }
}
