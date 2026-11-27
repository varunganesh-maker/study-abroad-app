import Foundation
import Testing
@testable import StudyAbroad

/// Guards for "readable everywhere": colour contrast, and the sheet colour-scheme mistake that once
/// gave black text on a dark sheet.
struct ContrastRuleTests {
    private let white = (1.0, 1.0, 1.0)
    private let black = (0.0, 0.0, 0.0)

    @Test func whiteTextIsReadableOnTheNightColours() {
        #expect(Theme.contrast(white, Theme.nightRGB) >= 4.5)
        #expect(Theme.contrast(white, Theme.nightCardRGB) >= 4.5)
    }

    @Test func blackOnWhiteIsTheMaximum() {
        #expect(abs(Theme.contrast(black, white) - 21) < 0.01)
        #expect(abs(Theme.contrast(white, black) - 21) < 0.01)
        #expect(abs(Theme.contrast(white, white) - 1) < 0.01)
    }

    /// Only Theme.swift may force a light colour scheme (through its sheet helper). Anywhere else it
    /// leaks the map's dark scheme into sheets, so text becomes unreadable.
    @Test func noSourceFileForcesALightColourSchemeExceptTheme() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("StudyAbroad")
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: sourceRoot.path, isDirectory: &isDirectory)
        try #require(exists && isDirectory.boolValue, "StudyAbroad source folder not found at \(sourceRoot.path)")

        let enumerator = try #require(FileManager.default.enumerator(at: sourceRoot, includingPropertiesForKeys: nil))
        var scanned = 0
        var offenders: [String] = []
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            scanned += 1
            if url.lastPathComponent == "Theme.swift" { continue }
            let text = try String(contentsOf: url, encoding: .utf8)
            if text.contains("colorScheme, .light)") { offenders.append(url.lastPathComponent) }
        }
        #expect(scanned > 10, "Expected to scan the app's source files, found \(scanned)")
        #expect(offenders.isEmpty, "Forced light colour scheme in: \(offenders.joined(separator: ", "))")
    }
}
