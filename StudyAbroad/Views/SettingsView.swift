import SwiftUI

/// App settings, opened from the slider button on the map.
/// For now: "Add new photos automatically" and memories you removed from the app.
struct SettingsView: View {
    @Environment(MemoryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var rule = AutoAddRule()
    @State private var confirmingUnhide = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Add new photos", selection: $rule.mode) {
                        ForEach(AutoAddRule.Mode.allCases) { Text($0.title).tag($0) }
                    }
                    .accessibilityIdentifier("autoAddPicker")

                    switch rule.mode {
                    case .from:
                        DatePicker("From", selection: $rule.start, displayedComponents: .date)
                        Button("From today") { rule.start = .now }
                    case .between:
                        DatePicker("From", selection: $rule.start, displayedComponents: .date)
                        DatePicker("To", selection: $rule.end, in: rule.start..., displayedComponents: .date)
                    case .all, .off:
                        EmptyView()
                    }
                } header: {
                    Text("Add new photos automatically")
                } footer: {
                    Text(rule.mode.explanation
                         + " Apple doesn't let apps add a button to the Camera app, so this is how your photos get in on their own."
                         + " Changing it never removes anything that's already in the app.")
                }

                Section {
                    LabeledContent("Removed from the app", value: "\(store.hiddenCount)")
                    if store.hiddenCount > 0 {
                        Button("Bring them all back") { confirmingUnhide = true }
                    }
                } header: {
                    Text("Removed memories")
                } footer: {
                    Text("Removing a photo or video from the app (••• in the viewer) never deletes it from your camera roll.")
                }

                Section {
                    LabeledContent("Photos and videos", value: "Stay in your camera roll")
                    LabeledContent("Captions and notes", value: "On this phone")
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Nothing leaves your phone. Deleting the app deletes captions and notes, so don't delete it to reinstall: just run it again from Xcode.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.setAutoAddRule(rule)
                        dismiss()
                    }
                    .bold()
                }
            }
            .onAppear { rule = store.autoAddRule }
            .onDisappear { store.setAutoAddRule(rule) } // swiping the sheet away saves too
            .onChange(of: rule.start) { _, start in
                if rule.end < start { rule.end = start }
            }
            .confirmationDialog("Bring back \(store.hiddenCount) removed memories?", isPresented: $confirmingUnhide,
                                titleVisibility: .visible) {
                Button("Bring them back") { store.unhideAll() }
            }
        }
    }
}
