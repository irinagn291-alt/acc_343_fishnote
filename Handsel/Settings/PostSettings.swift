import Foundation

/// Settings copy and contact destination for the future native sheet; reset uses the presentation seam.
enum PostSettings {
    static let contactURL = URL(string: "https://handsel-stall.site/contact-us")
    static let storageExplanation = "Pets and care rounds stay on this device. No account or network is required."
    static let resetTitle = "Reset all pets and care rounds?"
    static let resetMessage = "This removes every pet, care round and care log from this device."
}
