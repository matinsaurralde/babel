import AppKit
import Foundation

/// Optional audio cues for session lifecycle. Off by default; toggled in
/// Settings. Uses macOS' built-in named sounds so Babel doesn't ship audio
/// assets — also means every Mac has them available regardless of Setup.
enum SessionSounds {
    static let userDefaultsKey = "babel.soundsEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: userDefaultsKey)
    }

    @MainActor
    static func playStart() {
        play("Tink")
    }

    @MainActor
    static func playStop() {
        play("Pop")
    }

    @MainActor
    private static func play(_ name: String) {
        guard isEnabled else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}
