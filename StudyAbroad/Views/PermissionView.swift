import SwiftUI

struct PermissionView: View {
    @Environment(MemoryStore.self) private var store
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "map.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Your memories map")
                .font(.largeTitle.bold())
            Text("Study Abroad puts every photo and video you take on a map, sorted by city. It reads where each one was taken. Nothing is uploaded.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Spacer()
            if store.access == .denied {
                Text("Photo access is off. Turn on **Full Access** in Settings.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Allow Photo Access") {
                    Task { await store.requestAccess() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Text("Pick **Allow Full Access** so the whole camera roll gets mapped.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
