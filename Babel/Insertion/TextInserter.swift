import AppKit
import Carbon.HIToolbox
import Foundation

/// Orchestrator for Babel's insertion strategy.
///
/// Routing:
/// 1. **Secure Keyboard Entry** active anywhere on the system (Terminal with
///    Secure Input, password fields, secure text entry apps): we can't insert
///    anywhere — copy to clipboard and tell the user to ⌘V manually.
/// 2. **Known terminal emulators** (iTerm2, Terminal.app, Ghostty, Kitty,
///    Alacritty, Warp, Hyper): paste is silently dropped by these apps, so
///    use raw Unicode keystroke synthesis character-by-character.
/// 3. **Everything else**: Accessibility API first (clean, no pasteboard
///    side-effects); on failure fall back to pasteboard + synthesized ⌘V.
@MainActor
enum TextInserter {
    enum Outcome: Equatable {
        case inserted
        case clipboardOnly
        case empty
    }

    /// Bundle identifiers of terminal emulators that need raw keystroke
    /// synthesis. Paste via synthesized ⌘V is unreliable in these apps.
    private static let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "org.alacritty",
        "io.alacritty",
        "dev.warp.Warp-Stable",
        "dev.warp.Warp",
        "co.zeit.hyper",
    ]

    static func insert(_ text: String) -> Outcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        if IsSecureEventInputEnabled() {
            PasteboardInserter.copyOnly(trimmed)
            return .clipboardOnly
        }

        if let bundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           terminalBundleIDs.contains(bundleID) {
            KeystrokeInserter.type(trimmed)
            return .inserted
        }

        if AccessibilityInserter.tryInsert(trimmed) { return .inserted }
        PasteboardInserter.insert(trimmed)
        return .inserted
    }
}
