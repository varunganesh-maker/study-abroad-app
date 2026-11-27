import AVFoundation
import CoreLocation
import PhotosUI
import SwiftUI

/// "New moment" (the "Capture a moment" screen in the Figma file), opened with ＋ on the map.
/// Note: write and/or record your voice. Photo / Video: snap with the in-app camera.
/// Upload: pick photos and videos from your camera roll, with a caption for each.
struct CaptureView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case note = "Note", photo = "Photo", video = "Video", upload = "Upload"
        var id: String { rawValue }
    }

    /// How a voice recording is kept ("Save your voice as" in the mockup).
    enum VoiceSaveAs: String, CaseIterable, Identifiable {
        case both = "Both", audio = "Audio", text = "Text"
        var id: String { rawValue }
    }

    /// Set when you add a note from a memory in the viewer: the note goes in the same place and time.
    var attachedTo: PhotoMemory?

    @Environment(MemoryStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode
    @State private var text = ""
    @FocusState private var textFocused: Bool

    // Voice
    @State private var recorder = VoiceRecorder()
    @State private var saveVoiceAs: VoiceSaveAs = .both
    @State private var isTranscribing = false
    @State private var voiceMessage: String?

    // Place
    @State private var location = LocationProvider()
    @State private var chosenCoordinate: CLLocationCoordinate2D?
    @State private var placeName: String?
    @State private var choosingPlace = false

    // Camera
    @State private var showingCamera = false
    @State private var capture: CameraRollSaver.Capture?
    @State private var capturePreview: UIImage?

    // Upload
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var picked: [PhotoLibraryScanner.AssetInfo] = []
    @State private var uploadCaptions: [String: String] = [:]

    @State private var isSaving = false
    @State private var errorMessage: String?

    init(attachedTo: PhotoMemory? = nil, mode: Mode = .note) {
        self.attachedTo = attachedTo
        _mode = State(initialValue: attachedTo == nil ? mode : .note)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(attachedTo == nil ? "What happened?" : "Add a note")
                        .font(.largeTitle.bold())
                    Text(attachedTo == nil ? "Small moments count, too." : "It sits right next to this memory.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)

                    if attachedTo == nil {
                        Picker("Kind of moment", selection: $mode) {
                            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 18)
                    }

                    switch mode {
                    case .note: noteSection
                    case .photo, .video: cameraSection
                    case .upload: uploadSection
                    }

                    if mode != .upload {
                        placeRow.padding(.top, 22)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .padding(.top, 14)
                    }

                    Text(footnote)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 24)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("New moment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Save") { Task { await save() } }
                            .bold()
                            .disabled(!canSave)
                    }
                }
            }
            .interactiveDismissDisabled(hasUnsavedWork)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker(media: mode == .video ? .video : .photo) { result in
                    showingCamera = false
                    if let result { useCapture(result) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $choosingPlace) {
                LocationPickerView(start: coordinate) { picked in
                    chosenCoordinate = picked
                    errorMessage = nil
                }
                .lightSheet()
            }
            .onChange(of: mode) { _, newMode in
                errorMessage = nil
                if (newMode == .photo || newMode == .video) && capture == nil { openCamera() }
                if newMode != .note && recorder.state == .recording { recorder.stop() }
            }
            .onChange(of: pickerItems) { _, items in
                let ids = items.compactMap(\.itemIdentifier)
                picked = PhotoLibraryScanner.info(for: ids)
                let unavailable = items.count - picked.count
                errorMessage = unavailable > 0
                    ? "\(unavailable) of these aren't shared with the app (Limited photo access). Allow them in Settings › Study Abroad › Photos."
                    : nil
            }
            .task { if attachedTo == nil { location.refresh() } }
            .task(id: coordinateKey) { await lookUpPlaceName() }
        }
        .lightSheet()
    }

    // MARK: Note: words + voice

    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            TextField("What happened? Write as much as you like.", text: $text, axis: .vertical)
                .focused($textFocused)
                .padding(16)
                .frame(minHeight: 150, alignment: .topLeading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .accessibilityIdentifier("noteText")

            voiceCard

            if recorder.state != .idle {
                VStack(alignment: .leading, spacing: 10) {
                    Text("SAVE YOUR VOICE AS")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Picker("Save your voice as", selection: $saveVoiceAs) {
                        ForEach(VoiceSaveAs.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .padding(.top, 22)
    }

    private var voiceCard: some View {
        HStack(spacing: 16) {
            Button {
                Task { await toggleRecording() }
            } label: {
                ZStack {
                    Circle().fill(Color(.tertiarySystemFill)).frame(width: 52, height: 52)
                    if recorder.state == .recording {
                        RoundedRectangle(cornerRadius: 4).fill(.red).frame(width: 18, height: 18)
                    } else {
                        Image(systemName: recorder.state == .recorded ? "arrow.counterclockwise" : "mic.fill")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.tint)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recordButtonLabel)
            .accessibilityIdentifier("recordButton")

            VStack(alignment: .leading, spacing: 8) {
                Text(voiceTitle)
                    .font(.headline)
                    .foregroundStyle(.tint)
                HStack(alignment: .center, spacing: 4) {
                    Waveform(levels: recorder.levels)
                    Spacer(minLength: 8)
                    if recorder.state != .idle {
                        Text(PhotoMemory.timeText(recorder.elapsed))
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.tint)
                    }
                }
                .frame(height: 28)
                if let voiceMessage {
                    Text(voiceMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let error = recorder.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var voiceTitle: String {
        if isTranscribing { return "Turning speech into text…" }
        switch recorder.state {
        case .idle: return "Tap to record a voice note"
        case .recording: return "Listening…"
        case .recorded: return "Voice note recorded"
        }
    }

    private var recordButtonLabel: String {
        switch recorder.state {
        case .idle: "Record voice note"
        case .recording: "Stop recording"
        case .recorded: "Record again"
        }
    }

    private func toggleRecording() async {
        voiceMessage = nil
        switch recorder.state {
        case .recording:
            recorder.stop()
            if saveVoiceAs != .audio { await transcribe() }
        case .recorded:
            recorder.discard()
            await recorder.start()
        case .idle:
            textFocused = false
            await recorder.start()
        }
    }

    private func transcribe() async {
        isTranscribing = true
        defer { isTranscribing = false }
        switch await recorder.transcribe() {
        case .text(let words):
            text = text.isEmpty ? words : text + "\n\n" + words
        case .empty:
            voiceMessage = "Couldn't make out any words, so only the audio will be kept."
        case .unavailable(let reason):
            voiceMessage = reason
        }
    }

    // MARK: Photo / video

    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Button(action: openCamera) {
                Group {
                    if let capturePreview {
                        Image(uiImage: capturePreview)
                            .resizable()
                            .scaledToFill()
                            .overlay(alignment: .bottomLeading) {
                                if case .video? = capture {
                                    Label("Video", systemImage: "video.fill")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .shadow(radius: 2)
                                        .padding(12)
                                }
                            }
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: mode == .video ? "video.fill" : "camera.fill")
                                .font(.largeTitle)
                            Text(mode == .video ? "Record a video" : "Take a photo")
                                .font(.headline)
                        }
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.secondarySystemBackground))
                    }
                }
                .frame(height: 260)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(capture == nil ? (mode == .video ? "Record a video" : "Take a photo") : "Retake")

            if capture != nil {
                Text("Tap the picture to retake. It's saved to your camera roll too.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            TextField("Caption (optional, any length)", text: $text, axis: .vertical)
                .padding(16)
                .frame(minHeight: 90, alignment: .topLeading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(.top, 22)
    }

    private func openCamera() {
        guard CameraPicker.isAvailable else {
            errorMessage = "This device has no camera (the simulator doesn't). Try Upload instead."
            return
        }
        showingCamera = true
    }

    private func useCapture(_ result: CameraRollSaver.Capture) {
        capture = result
        switch result {
        case .photo(let image):
            capturePreview = image
        case .video(let url):
            capturePreview = nil
            Task { capturePreview = await Self.firstFrame(of: url) }
        }
    }

    private static func firstFrame(of url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        guard let frame = try? await generator.image(at: .zero) else { return nil }
        return UIImage(cgImage: frame.image)
    }

    // MARK: Upload from camera roll

    private var uploadSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            PhotosPicker(selection: $pickerItems,
                         selectionBehavior: .ordered,
                         matching: .any(of: [.images, .videos]),
                         photoLibrary: .shared()) {
                Label(picked.isEmpty ? "Choose photos and videos" : "Change selection",
                      systemImage: "photo.on.rectangle.angled")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .accessibilityIdentifier("choosePhotos")

            if !picked.isEmpty {
                Text("Each one goes on the map where it was taken. Add a caption to any of them.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            ForEach(picked, id: \.id) { item in
                HStack(alignment: .top, spacing: 12) {
                    AssetThumbnail(memory: item.preview, side: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    TextField("Caption", text: Binding(
                        get: { uploadCaptions[item.id] ?? "" },
                        set: { uploadCaptions[item.id] = $0 }
                    ), axis: .vertical)
                        .padding(12)
                        .frame(minHeight: 72, alignment: .topLeading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(.top, 22)
    }

    // MARK: Place

    /// Where a note or new photo goes on the map.
    private var coordinate: CLLocationCoordinate2D? {
        attachedTo?.coordinate ?? chosenCoordinate ?? location.location?.coordinate ?? store.latestMemory?.coordinate
    }

    private var coordinateKey: String {
        guard let c = coordinate else { return "none" }
        return String(format: "%.4f,%.4f", c.latitude, c.longitude)
    }

    private var placeSubtitle: String {
        if attachedTo != nil { return "Same place as the \(attachedTo?.kindName.lowercased() ?? "memory")" }
        if chosenCoordinate != nil { return "Chosen on the map · Tap to change" }
        if location.location != nil { return "Current location · Tap to change" }
        if store.latestMemory != nil { return "Near your latest memory · Tap to change" }
        return "Tap to choose a place"
    }

    private var placeRow: some View {
        Button {
            if attachedTo == nil { choosingPlace = true }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(placeName ?? (coordinate == nil ? "No place yet" : "Finding the place…"))
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(placeSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if attachedTo == nil {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 12)
            .overlay(alignment: .top) { Divider() }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("placeRow")
    }

    private func lookUpPlaceName() async {
        guard let coordinate else {
            placeName = nil
            return
        }
        placeName = nil
        let place = await PlaceNamer.lookUp(coordinate)
        if Task.isCancelled { return }
        let name = [place.name, place.area].compactMap { $0 }.uniqued().joined(separator: ", ")
        placeName = name.isEmpty ? "Pinned location" : name
    }

    private var footnote: String {
        switch mode {
        case .note:
            return recorder.state == .idle
                ? "Notes stay on your phone, inside the app."
                : "Your audio stays on your phone. Speech is turned into text on the phone, never uploaded."
        case .photo, .video:
            return "Saved to your camera roll and the app at the same time."
        case .upload:
            return "Nothing is copied or uploaded: the app just points at your camera roll."
        }
    }

    // MARK: Saving

    private var canSave: Bool {
        guard !isTranscribing, recorder.state != .recording else { return false }
        switch mode {
        case .note:
            let hasWords = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            return (hasWords || recorder.state == .recorded) && coordinate != nil
        case .photo, .video:
            return capture != nil
        case .upload:
            return !picked.isEmpty
        }
    }

    private var hasUnsavedWork: Bool {
        !text.isEmpty || recorder.state != .idle || capture != nil || !picked.isEmpty
    }

    private func cancel() {
        recorder.discard()
        if case .video(let url)? = capture { try? FileManager.default.removeItem(at: url) }
        dismiss()
    }

    private func save() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        let takenAt = attachedTo?.takenAt.map { $0.addingTimeInterval(1) } ?? .now

        switch mode {
        case .note:
            guard let coordinate else { return }
            let hasWords = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            // "Text" only drops the audio when there are words to keep; otherwise the recording would be lost.
            let keepAudio = recorder.state == .recorded && (saveVoiceAs != .text || !hasWords)
                && VoiceNoteFiles.exists(key: recorder.key)
            if keepAudio {
                store.addNote(kind: .voice, text: text, coordinate: coordinate, takenAt: takenAt,
                              duration: recorder.elapsed, key: recorder.key)
            } else if !hasWords {
                // The recording file is missing and there are no words: saving now would make an
                // empty note and the voice note would be gone. Say so instead.
                errorMessage = "The recording couldn't be saved. Tap the mic to record again, or type your note."
                return
            } else {
                recorder.discard() // "Text" only: the words are kept, the audio isn't
                store.addNote(kind: .text, text: text, coordinate: coordinate, takenAt: takenAt)
            }
            dismiss()

        case .photo, .video:
            guard let capture else { return }
            guard coordinate != nil else {
                // With no place it would land in your camera roll but never on the map.
                errorMessage = "Where did this happen? Pick the spot on the map, then tap Save."
                choosingPlace = true
                return
            }
            // Only a real place goes into the photo file itself (it's permanent in your camera roll);
            // the "near your latest memory" guess is only used for the app's map.
            let stamped = chosenCoordinate.map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) } ?? location.location
            do {
                let id = try await CameraRollSaver.save(capture, location: stamped)
                store.addCameraCapture(id, kind: mode == .video ? .video : .photo, coordinate: coordinate, caption: text)
                if case .video(let url) = capture { try? FileManager.default.removeItem(at: url) }
                dismiss()
            } catch {
                errorMessage = "Couldn't save to your camera roll. Check that the app has full photo access in Settings."
            }

        case .upload:
            let placed = store.addFromCameraRoll(picked.map(\.id), currentLocation: location.location)
            for id in placed {
                if let caption = uploadCaptions[id], !caption.isEmpty { store.setCaption(caption, for: id) }
            }
            dismiss()
        }
    }
}

/// The little bars that move while you record (and stay once you stop).
private struct Waveform: View {
    let levels: [Float]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<VoiceRecorder.barCount, id: \.self) { index in
                let level = index < levels.count ? CGFloat(levels[index]) : 0.12
                Capsule()
                    .fill(.tint)
                    .frame(width: 3, height: max(4, 28 * level))
            }
        }
        .accessibilityHidden(true)
    }
}

private extension Array where Element: Hashable {
    /// Drops repeats, keeping the first ("Bondi Beach, Bondi Beach" → "Bondi Beach").
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
