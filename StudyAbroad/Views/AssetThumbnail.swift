import SwiftUI

/// A square thumbnail for one camera roll item, loaded lazily.
struct AssetThumbnail: View {
    let memory: PhotoMemory
    var side: CGFloat = 120
    @State private var image: UIImage?
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Color.secondary.opacity(0.15)
            .frame(width: side, height: side)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                if memory.isVideo {
                    Image(systemName: "play.fill")
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(4)
                        .shadow(radius: 2)
                }
            }
            .task(id: memory.id) {
                let px = max(side, 100) * displayScale
                image = await PhotoLoader.shared.image(for: memory.id, targetSize: CGSize(width: px, height: px))
            }
    }
}
