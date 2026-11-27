import SwiftUI
import UniformTypeIdentifiers

/// App settings, opened from the slider button on the map.
/// For now: "Add new photos automatically" and memories you removed from the app.
struct SettingsView: View {
    @Environment(MemoryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var rule = AutoAddRule()
    @State private var confirmingUnhide = false
    @State private var exporting = false
    @State private var importing = false
    @State private var backupDocument: BackupDocument?
    @State private var backupMessage: String?
    @AppStorage("backup.lastSaved") private var lastBackup: Double = 0

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
                    Button("Save a backup…") { saveBackup() }
                        .accessibilityIdentifier("saveBackup")
                    Button("Restore from a backup…") { importing = true }
                    if let backupMessage {
                        Text(backupMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text(lastBackupText
                         + " The backup holds your captions, notes, voice notes and ratings (your photos are already in Photos)."
                         + " Save it to iCloud Drive so it's safe if your phone is lost. Restoring never overwrites anything you've changed since.")
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
            .fileExporter(isPresented: $exporting, document: backupDocument, contentType: .json,
                          defaultFilename: Backup.suggestedFilename) { result in
                switch result {
                case .success:
                    lastBackup = Date.now.timeIntervalSince1970
                    backupMessage = "Backup saved."
                case .failure:
                    backupMessage = "The backup wasn't saved."
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                restore(result)
            }
            .confirmationDialog("Bring back \(store.hiddenCount) removed memories?", isPresented: $confirmingUnhide,
                                titleVisibility: .visible) {
                Button("Bring them back") { store.unhideAll() }
            }
        }
    }

    private var lastBackupText: String {
        guard lastBackup > 0 else { return "No backup yet." }
        let date = Date(timeIntervalSince1970: lastBackup)
        let days = Calendar.current.dateComponents([.day], from: date, to: .now).day ?? 0
        let when = "Last backup: \(date.formatted(date: .abbreviated, time: .omitted))."
        return days >= 7 ? when + " Time for a new one." : when
    }

    private func saveBackup() {
        do {
            backupDocument = BackupDocument(data: try store.makeBackup())
            exporting = true
        } catch {
            backupMessage = "Couldn't make a backup: \(error.localizedDescription)"
        }
    }

    private func restore(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        do {
            backupMessage = try store.restoreBackup(Data(contentsOf: url))
            rule = store.autoAddRule
        } catch {
            backupMessage = "That file isn't a Study Abroad backup."
        }
    }
}
