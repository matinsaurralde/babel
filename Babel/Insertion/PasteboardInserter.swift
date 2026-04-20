import AppKit
import CoreGraphics
import Foundation

enum PasteboardInserter {
    /// Write `text` to the pasteboard without restoring previous contents.
    /// Used as the Secure-Keyboard-Entry fallback: the user pastes manually
    /// so we must leave the text on the clipboard indefinitely.
    @MainActor
    static func copyOnly(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Save the current pasteboard, write `text`, synthesize ⌘V, and restore
    /// the previous contents after a short delay so the user doesn't lose what
    /// they had copied.
    @MainActor
    static func insert(_ text: String) {
        let pasteboard = NSPasteboard.general
        let saved = captureCurrentContents(of: pasteboard)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        sendPasteShortcut()

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            pasteboard.clearContents()
            if !saved.isEmpty {
                pasteboard.writeObjects(saved)
            }
        }
    }

    private static func captureCurrentContents(of pasteboard: NSPasteboard) -> [NSPasteboardItem] {
        guard let items = pasteboard.pasteboardItems else { return [] }
        return items.map { item in
            let clone = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    clone.setData(data, forType: type)
                }
            }
            return clone
        }
    }

    private static func sendPasteShortcut() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let vKey: CGKeyCode = 9 // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cgAnnotatedSessionEventTap)
        up?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
