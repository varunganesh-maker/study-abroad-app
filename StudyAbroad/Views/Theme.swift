import SwiftUI

/// Colours from the Figma mockups, in one place so screens stay consistent.
/// The app's accent colour (indigo, used for buttons and back arrows) lives in
/// Assets.xcassets > AccentColor.
enum Theme {
    /// Deep navy behind the night-style memories map.
    static let night = Color(red: 0x10 / 255, green: 0x1D / 255, blue: 0x2B / 255)
    /// The "You're in Sydney" card on the map.
    static let nightCard = Color(red: 0x24 / 255, green: 0x33 / 255, blue: 0x42 / 255)
    /// Soft lavender for memory pins and the glow around your location.
    static let pin = Color(red: 0x8D / 255, green: 0x8E / 255, blue: 0xFF / 255)
}
