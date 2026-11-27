import SwiftUI

/// A thumbnail for one memory, cropped to fill the given size.
/// Photos and videos load lazily from the camera roll; notes draw a little card instead.
struct AssetThumbnail: View {
    let memory: PhotoMemory
    var width: CGFloat
    var height: CGFloat
    @State private var image: UIImage?
    @Environment(\.displayScale) private var displayScale

    init(memory: PhotoMemory, side: CGFloat = 120) {
        self.init(memory: memory, width: side, height: side)
    }

    init(memory: PhotoMemory, width: CGFloat, height: CGFloat) {
        self.memory = memory
        self.width = width
        self.height = height
    }

    var body: some View {
        if memory.isNote {
            NoteThumbnail(memory: memory, width: width, height: height)
        } else {
            mediaThumbnail
        }
    }

    private var mediaThumbnail: some View {
        Color.secondary.opacity(0.15)
            .frame(width: width, height: height)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottomLeading) {
                // "▶ 0:24" on videos, as in the mockups. Skipped on tiny thumbnails.
                if memory.isVideo && width >= 80 {
                    Text("▶ \(memory.durationText)")
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                        .padding(8)
                }
            }
            .task(id: memory.id) {
                let px = max(width, height, 100) * displayScale
                image = await PhotoLoader.shared.image(for: memory.id, targetSize: CGSize(width: px, height: px))
            }
    }
}

/// A text or voice note as a small lavender card: the first words of the note, or a waveform.
private struct NoteThumbnail: View {
    let memory: PhotoMemory
    let width: CGFloat
    let height: CGFloat
    @Environment(MemoryStore.self) private var store

    var body: some View {
        let text = store.caption(for: memory.id)
        let small = width < 80
        LinearGradient(colors: [Theme.pin, Color.indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
            .frame(width: width, height: height)
            .overlay(alignment: memory.kind == .text && !small ? .topLeading : .center) {
                if memory.kind == .voice {
                    VStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(small ? .body : .title.weight(.semibold))
                        if !small {
                            Text("Voice · \(memory.durationText)")
                                .font(.footnote)
                        }
                    }
                } else if small || text.isEmpty {
                    Image(systemName: "text.quote")
                        .font(small ? .body : .title.weight(.semibold))
                } else {
                    Text(text)
                        .font(width > 150 ? .subheadline : .caption)
                        .multilineTextAlignment(.leading)
                        .padding(10)
                }
            }
            .foregroundStyle(.white)
            .clipped()
    }
}
