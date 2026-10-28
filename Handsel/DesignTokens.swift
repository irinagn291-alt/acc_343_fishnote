import SwiftUI

/// SPEC section 7. The only place these hex values live — reach colours
/// and the font family through here. Keep this file and its values.
enum DesignTokens {
    /// #FCFCFC
    static let bg = Color(red: 0.988235, green: 0.988235, blue: 0.988235)
    static let bgHex = "#FCFCFC"
    /// #F5F5F5
    static let surface = Color(red: 0.960784, green: 0.960784, blue: 0.960784)
    static let surfaceHex = "#F5F5F5"
    /// #121212
    static let ink = Color(red: 0.070588, green: 0.070588, blue: 0.070588)
    static let inkHex = "#121212"
    /// #27A586
    static let accent = Color(red: 0.152941, green: 0.647059, blue: 0.525490)
    static let accentHex = "#27A586"
    /// #575757
    static let muted = Color(red: 0.341176, green: 0.341176, blue: 0.341176)
    static let mutedHex = "#575757"
    static let fontFamily = "DIN Alternate"

    // Opaque care surfaces keep identity and status visible in native captures.
    static let careGreen = Color(red: 0.07, green: 0.26, blue: 0.22)
    static let mint = Color(red: 0.68, green: 0.88, blue: 0.78)
    static let sky = Color(red: 0.70, green: 0.82, blue: 0.94)
    static let ochre = Color(red: 0.96, green: 0.76, blue: 0.40)
    static let warm = Color(red: 0.98, green: 0.95, blue: 0.88)
}
