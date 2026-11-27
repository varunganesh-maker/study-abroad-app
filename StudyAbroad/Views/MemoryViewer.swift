import AVKit
import SwiftUI

/// Full-screen, story-style viewer ("Memory viewer" in the Figma file).
/// Swipe sideways for the next memory, tap ✕ to close. Videos play with your own controls.
struct MemoryViewer: View {
    let title: String
    let memories: [PhotoMemory]
    let start: PhotoMemory
    @State private var currentID: String
    @State private var video = VideoPlayback()
    @State private var editingCaption: PhotoMemory?
    @State private var addingNoteFor: PhotoMemory?
    @State private var confirmingRemove = false
    @State private var captionExpanded = false
    @Environment(\.dismiss) private var dismiss
    @Environment(MemoryStore.self) private var store

    init(title: String, memories: [PhotoMemory], start: PhotoMemory) {
        self.title = title
        self.memories = memories
        self.start = start
        _currentID = State(initialValue: start.id)
    }

    private var currentIndex: Int {
        memories.firstIndex { $0.id == currentID } ?? 0
    }

    private var current: PhotoMemory? {
        memories.indices.contains(currentIndex) ? memories[currentIndex] : nil
    }

    var body: some View {
        // Apple's built-in pager: reliable swiping, and it opens on the tapped memory.
        // (A hand-made paging ScrollView sometimes got stuck on the first memory.)
        TabView(selection: $currentID) {
            ForEach(memories) { memory in
                MemoryPage(memory: memory, player: memory.id == currentID ? video.player : nil)
                    .tag(memory.id)
                    .ignoresSafeArea()
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .background(.black)
        .ignoresSafeArea()
        .overlay(alignment: .top) { topBar }
        .overlay(alignment: .bottom) { caption }
        .environment(\.colorScheme, .dark)
        .onAppear { video.load(current) }
        .onChange(of: currentID) { _, _ in
            captionExpanded = false
            video.load(current)
        }
        .onDisappear { video.stop() }
        .sheet(item: $editingCaption) { memory in
            CaptionEditorView(memory: memory)
        }
        .sheet(item: $addingNoteFor, onDismiss: { video.load(current) }) { memory in
            CaptureView(attachedTo: memory)
        }
        .confirmationDialog(removeTitle, isPresented: $confirmingRemove, titleVisibility: .visible) {
            Button(current?.isNote == true ? "Delete note" : "Remove from app", role: .destructive) {
                guard let current else { return }
                video.stop()
                store.remove(current.id)
                dismiss()
            }
        } message: {
            Text(current?.isNote == true
                 ? "This note only lives in the app, so it will be gone for good."
                 : "It stays in your camera roll. You can bring it back in Settings.")
        }
    }

    private var removeTitle: String {
        current?.isNote == true ? "Delete this note?" : "Remove from the app?"
    }

    /// The caption for the memory on screen ("" if none). Text notes show their words on the page instead.
    private var currentCaption: String {
        guard let current, current.kind != .text else { return "" }
        return store.caption(for: current.id)
    }

    // MARK: Top: close button + story progress

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Close")
                Spacer()
                moreMenu
            }

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

    /// "•••": caption, add a note next to this memory, remove.
    private var moreMenu: some View {
        Menu {
            if let current {
                Button {
                    video.pause()
                    editingCaption = current
                } label: {
                    if current.kind == .text {
                        Label("Edit note", systemImage: "pencil")
                    } else {
                        Label(currentCaption.isEmpty ? "Add caption" : "Edit caption", systemImage: "text.bubble")
                    }
                }
                Button {
                    video.stop()
                    addingNoteFor = current
                } label: {
                    Label("Add a note here", systemImage: "square.and.pencil")
                }
                Button(role: .destructive) {
                    confirmingRemove = true
                } label: {
                    if current.isNote {
                        Label("Delete note", systemImage: "trash")
                    } else {
                        Label("Remove from app", systemImage: "eye.slash")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("More")
    }

    // MARK: Bottom: caption, video controls, hint

    private var caption: some View {
        let caption = currentCaption
        // A short caption becomes the headline (like "Bondi, on repeat" in the mockup);
        // a long one sits under the city name and opens up when you tap it.
        let captionIsHeadline = !caption.isEmpty && caption.count <= CaptionStyle.headlineLimit && !caption.contains("\n")
        return VStack(alignment: .leading, spacing: 6) {
            Text(captionIsHeadline ? caption : title)
                .font(.title2.bold())
                .accessibilityIdentifier("viewerHeadline")
            if !caption.isEmpty && !captionIsHeadline {
                longCaption(caption)
            }
            if let date = current?.takenAt {
                Text("\(captionIsHeadline ? "\(title) · " : "")\(date.formatted(.dateTime.day().month(.wide))) · \(date.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
            }
            if let current {
                Text("\(current.kindName) · \(currentIndex + 1) of \(memories.count)")
                    .font(.footnote)
                    .opacity(0.85)
            }
            if let current, caption.isEmpty, current.kind != .text {
                Button {
                    video.pause()
                    editingCaption = current
                } label: {
                    Label("Add a caption", systemImage: "text.bubble")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.top, 6)
                .accessibilityIdentifier("addCaptionButton")
            }

            if current?.isPlayable == true {
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
                .padding(.top, current?.isPlayable == true ? 8 : 24)
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

    /// A long caption: four lines, tap to read it all (scrolls if it's really long).
    @ViewBuilder
    private func longCaption(_ caption: String) -> some View {
        if captionExpanded {
            ScrollView {
                Text(caption)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 280)
            .onTapGesture { captionExpanded = false }
        } else {
            Text(caption)
                .font(.body)
                .lineLimit(4)
                .onTapGesture { captionExpanded = true }
                .accessibilityHint("Double-tap to read the whole caption")
        }
    }
}

/// How captions are laid out across screens.
enum CaptionStyle {
    /// Captions up to this many characters (and on one line) are shown as a title.
    static let headlineLimit = 60
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
        if memory.isNote {
            NotePage(memory: memory)
        } else {
            mediaPage
        }
    }

    private var mediaPage: some View {
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
                        .accessibilityElement()
                        .accessibilityLabel("Video")
                        .accessibilityIdentifier("videoPlayer")
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

/// A text note (the words, big) or a voice note (a waveform; play it with the controls below).
private struct NotePage: View {
    let memory: PhotoMemory
    @Environment(MemoryStore.self) private var store

    var body: some View {
        LinearGradient(colors: [Theme.pin.opacity(0.9), Color.indigo, Theme.night],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                if memory.kind == .voice {
                    VStack(spacing: 18) {
                        Image(systemName: "waveform")
                            .font(.system(size: 72, weight: .semibold))
                        if !store.caption(for: memory.id).isEmpty {
                            Text(store.caption(for: memory.id))
                                .font(.title3)
                                .multilineTextAlignment(.center)
                                .lineLimit(6)
                                .padding(.horizontal, 32)
                        }
                    }
                    .foregroundStyle(.white)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Voice note")
                } else {
                    ScrollView {
                        Text(store.caption(for: memory.id).isEmpty ? "Empty note" : store.caption(for: memory.id))
                            .font(.title2.weight(.medium))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 28)
                            .padding(.top, 140)
                            .padding(.bottom, 260) // room for the details at the bottom
                    }
                    .accessibilityIdentifier("textNote")
                }
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
        guard let memory, memory.isPlayable else { return }
        duration = memory.duration
        loadTask = Task {
            let loaded: AVPlayerItem?
            if memory.kind == .voice {
                // Voice notes are files inside the app, not in Photos.
                loaded = VoiceNoteFiles.exists(key: memory.id) ? AVPlayerItem(url: VoiceNoteFiles.url(key: memory.id)) : nil
            } else {
                loaded = await PhotoLoader.shared.playerItem(for: memory.id)
            }
            guard let item = loaded, !Task.isCancelled else { return }
            // Play sound even when the ringer switch is on silent, like Photos does.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
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

    /// Pauses without unloading (e.g. while you write a caption).
    func pause() {
        guard isPlaying, let player else { return }
        player.pause()
        isPlaying = false
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
