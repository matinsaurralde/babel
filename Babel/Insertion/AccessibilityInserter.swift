import ApplicationServices
import Foundation

enum AccessibilityInserter {
    /// Attempt to insert `text` into the focused UI element of the frontmost app.
    /// Returns true on success.
    @MainActor
    static func tryInsert(_ text: String) -> Bool {
        guard AXIsProcessTrusted() else { return false }

        let systemWide = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focused
        )
        guard status == .success, let raw = focused else { return false }
        let element = raw as! AXUIElement

        // Prefer AXSelectedText — replaces the current selection / inserts at caret.
        let selStatus = AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextAttribute as CFString,
            text as CFString
        )
        if selStatus == .success { return true }

        // Fall back to AXValue — appends to the full value of the field. Risky if
        // the field already has content; prefer the paste path in that case.
        var current: CFTypeRef?
        let readStatus = AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &current
        )
        guard readStatus == .success, let existing = current as? String, existing.isEmpty else {
            return false
        }
        let valueStatus = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            text as CFString
        )
        return valueStatus == .success
    }
}
