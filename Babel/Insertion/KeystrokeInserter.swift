import AppKit
import CoreGraphics
import Foundation

/// Character-by-character Unicode keystroke synthesis. Works in apps that
/// reject synthesized ⌘V — most notably terminals like Terminal.app, iTerm2,
/// Ghostty, Kitty, Alacritty — because those consume raw keyboard events
/// directly instead of going through the standard paste pipeline.
///
/// Slower than paste (~1.5 ms/char) but universal. Matches the approach
/// Superwhisper takes (`simulateKeypressesEnabled`).
enum KeystrokeInserter {
    @MainActor
    static func type(_ text: String) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        for scalar in text.unicodeScalars {
            let utf16 = Array(String(scalar).utf16)
            guard
                let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
            else { continue }

            utf16.withUnsafeBufferPointer { ptr in
                guard let base = ptr.baseAddress else { return }
                down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: base)
                up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: base)
            }
            down.post(tap: .cgAnnotatedSessionEventTap)
            up.post(tap: .cgAnnotatedSessionEventTap)
            // A very small delay keeps the target app from dropping events when
            // it's busy (common in terminal emulators during a redraw).
            usleep(1_500)
        }
    }
}
