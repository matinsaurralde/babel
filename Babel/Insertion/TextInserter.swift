import Foundation

/// Orchestrator for the hybrid insertion strategy:
/// 1. Try the Accessibility API (fast, clean — no pasteboard side-effects).
/// 2. On failure, fall back to pasteboard + synthesized ⌘V.
@MainActor
enum TextInserter {
    static func insert(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if AccessibilityInserter.tryInsert(trimmed) { return }
        PasteboardInserter.insert(trimmed)
    }
}
