import Foundation

/// Where voice notes live: inside the app's own storage on the phone (never the camera roll).
enum VoiceNoteFiles {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("VoiceNotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func url(key: String) -> URL {
        directory.appendingPathComponent("\(key).m4a")
    }

    static func exists(key: String) -> Bool {
        FileManager.default.fileExists(atPath: url(key: key).path)
    }

    static func delete(key: String) {
        try? FileManager.default.removeItem(at: url(key: key))
    }
}
