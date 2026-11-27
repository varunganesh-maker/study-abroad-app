import SwiftUI

/// Colours from the Figma mockups, in one place so screens stay consistent.
/// The app's accent colour (indigo, used for buttons and back arrows) lives in
/// Assets.xcassets > AccentColor.
///
/// THE CONTRAST RULE (Varun, Nov 27): a light background always gets dark text and a dark
/// background always gets light text. The night colours below are dark, so text on them is white.
enum Theme {
    /// Deep navy behind the night-style memories map.
    static let night = Color(red: 0x10 / 255, green: 0x1D / 255, blue: 0x2B / 255)
    /// The "You're in Sydney" card on the map.
    static let nightCard = Color(red: 0x24 / 255, green: 0x33 / 255, blue: 0x42 / 255)
    /// Soft lavender for memory pins and the glow around your location.
    static let pin = Color(red: 0x8D / 255, green: 0x8E / 255, blue: 0xFF / 255)

    /// The same colours as plain numbers (red, green, blue from 0 to 1), so a unit test can check
    /// that text on them is readable.
    static let nightRGB = (0x10 / 255.0, 0x1D / 255.0, 0x2B / 255.0)
    static let nightCardRGB = (0x24 / 255.0, 0x33 / 255.0, 0x42 / 255.0)

    /// How readable one colour is on another, from 1 (invisible) to 21 (black on white).
    /// 4.5 or more is the usual bar for normal-size text (WCAG).
    static func contrast(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        func channel(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        func luminance(_ c: (Double, Double, Double)) -> Double {
            0.2126 * channel(c.0) + 0.7152 * channel(c.1) + 0.0722 * channel(c.2)
        }
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}

extension View {
    /// Shows a sheet in light mode (light background, dark text), whatever the phone's dark mode setting.
    ///
    /// Use this on the sheet's own content instead of `.environment(\.colorScheme, .light)` on its own:
    /// that only flips the SwiftUI text colour, while the sheet's background and navigation bar keep
    /// following the phone, which is what made "New moment" black text on a black sheet.
    /// - `preferredColorScheme` sets the whole presentation (background, navigation bar).
    /// - The environment line stops a dark screen behind the sheet (the map, the viewer) from
    ///   passing its "dark" setting down into the sheet's text.
    /// Together, background, bar and text always agree. A unit test (ContrastRuleTests) checks that
    /// no other file forces light mode by hand.
    func lightSheet() -> some View {
        environment(\.colorScheme, .light)
            .preferredColorScheme(.light)
    }
}
