import AVFoundation
import Observation
import Speech

/// Records one voice note ("Listening…" card on the New moment screen) and can turn it into text.
@MainActor
@Observable
final class VoiceRecorder {
    enum State { case idle, recording, recorded }

    /// The note this recording belongs to; the file is saved under this name.
    let key: String
    private(set) var state: State = .idle
    private(set) var elapsed: Double = 0
    /// Recent loudness values (0…1) for the little waveform.
    private(set) var levels: [Float] = []
    var errorMessage: String?

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var timer: Timer?

    /// How many bars the waveform shows.
    static let barCount = 28
    /// Give up on speech-to-text after this many seconds and keep the audio.
    static let transcriptionTimeout: TimeInterval = 45

    init(key: String = MemoryEntry.newNoteKey()) {
        self.key = key
    }

    var fileURL: URL { VoiceNoteFiles.url(key: key) }

    func toggle() async {
        switch state {
        case .recording: stop()
        case .idle, .recorded: await start()
        }
    }

    func start() async {
        errorMessage = nil
        guard await Self.askForMicrophone() else {
            errorMessage = "Microphone access is off. Turn it on in Settings › Study Abroad."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            ]
            let recorder = try AVAudioRecorder(url: fileURL, settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.record() else {
                errorMessage = "Couldn't start recording."
                return
            }
            self.recorder = recorder
            levels = []
            elapsed = 0
            state = .recording
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
        } catch {
            errorMessage = "Couldn't start recording."
        }
    }

    func stop() {
        guard let recorder else { return }
        elapsed = recorder.currentTime
        recorder.stop()
        self.recorder = nil
        timer?.invalidate()
        timer = nil
        state = .recorded
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Throws the recording away (Cancel, or recording again).
    func discard() {
        if state == .recording { stop() }
        VoiceNoteFiles.delete(key: key)
        state = .idle
        elapsed = 0
        levels = []
    }

    private func tick() {
        guard let recorder else { return }
        recorder.updateMeters()
        elapsed = recorder.currentTime
        // Decibels run from about -60 (silence) to 0 (loud).
        let power = recorder.averagePower(forChannel: 0)
        let level = max(0.08, min(1, (power + 50) / 50))
        levels.append(level)
        if levels.count > Self.barCount { levels.removeFirst(levels.count - Self.barCount) }
    }

    private static func askForMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: Speech to text

    enum TranscriptionResult: Equatable {
        case text(String)
        /// Nothing recognisable was said.
        case empty
        /// Speech recognition is off, or this phone can't do it without sending audio to Apple.
        case unavailable(String)
    }

    /// Turns the recording into text, on the phone only. If the phone can't recognise speech
    /// offline, it says so rather than uploading your voice.
    func transcribe() async -> TranscriptionResult {
        let status: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else {
            return .unavailable("Speech recognition is off. Turn it on in Settings › Study Abroad.")
        }
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable, recognizer.supportsOnDeviceRecognition else {
            return .unavailable("This phone can't turn speech into text offline in your language, so only the audio was kept.")
        }
        let request = SFSpeechURLRecognitionRequest(url: fileURL)
        request.requiresOnDeviceRecognition = true // your voice never leaves the phone
        request.shouldReportPartialResults = false
        request.addsPunctuation = true

        let text: String? = await withCheckedContinuation { continuation in
            let once = ResumeOnce()
            let task = recognizer.recognitionTask(with: request) { result, error in
                if let result, result.isFinal {
                    once.run { continuation.resume(returning: result.bestTranscription.formattedString) }
                } else if error != nil {
                    once.run { continuation.resume(returning: nil) }
                }
            }
            // Never leave the screen stuck on "Turning speech into text…".
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.transcriptionTimeout) {
                once.run {
                    task.cancel()
                    continuation.resume(returning: nil)
                }
            }
        }
        guard let text else { return .empty }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? .empty : .text(trimmed)
    }
}

/// Makes sure a callback that may fire more than once only finishes the wait one time.
private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false

    func run(_ body: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        guard !done else { return }
        done = true
        body()
    }
}
