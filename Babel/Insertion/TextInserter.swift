import Carbon.HIToolbox
import Foundation

/// Orchestrator for the hybrid insertion strategy:
/// 1. If the focused context has **Secure Keyboard Entry** enabled (Terminal,
///    password fields, secure text entry apps), both AX and pasteboard+⌘V are
///    silently dropped by the system. Short-circuit to the clipboard and let
///    the user paste manually.
/// 2. Otherwise try the Accessibility API (clean, no pasteboard side-effects).
/// 3. On AX failure, fall back to pasteboard + synthesized ⌘V.
@MainActor
enum TextInserter {
    enum Outcome: Equatable {
        case inserted
        case clipboardOnly
        case empty
    }

    static func insert(_ text: String) -> Outcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        if IsSecureEventInputEnabled() {
            PasteboardInserter.copyOnly(trimmed)
            return .clipboardOnly
        }

        if AccessibilityInserter.tryInsert(trimmed) { return .inserted }
        PasteboardInserter.insert(trimmed)
        return .inserted
    }
}
