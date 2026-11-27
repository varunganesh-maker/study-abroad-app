import SwiftUI

/// A thumbnail for one camera roll item, loaded lazily, cropped to fill the given size.
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
