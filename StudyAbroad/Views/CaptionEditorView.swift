import SwiftUI

/// Write or edit the caption for one photo, video or note. Any length: the box grows as you type.
struct CaptionEditorView: View {
    let memory: PhotoMemory
    @Environment(MemoryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    private var isTextNote: Bool { memory.kind == .text }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !isTextNote {
                        AssetThumbnail(memory: memory, width: 120, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .frame(maxWidth: .infinity)
                    }
                    if let date = memory.takenAt {
                        Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    TextField(isTextNote ? "What happened?" : "Write a caption… as long as you like",
                              text: $text, axis: .vertical)
                        .focused($focused)
                        .padding(16)
                        .frame(minHeight: 140, alignment: .topLeading)
                        .background(Color(.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .accessibilityIdentifier("captionField")
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(isTextNote ? "Edit note" : "Caption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.setCaption(text, for: memory.id)
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear {
                text = store.caption(for: memory.id)
                focused = true
            }
        }
        .lightSheet()
    }
}
