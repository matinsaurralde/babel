import AppKit
import CoreGraphics
import OSLog

/// Device-level bit mask for the right Option key (NX_DEVICERALTKEYMASK).
/// Stays set in `CGEvent.flags.rawValue` while right-Option is physically held.
private let kRightOptionDeviceMask: UInt64 = 0x40
/// Virtual keycode for the right Option key.
private let kRightOptionKeyCode: Int64 = 61

enum GlobalHotkeyError: Error {
    case tapCreationFailed
}

/// Global push-to-hold hotkey driven by CGEventTap on the main runloop.
///
/// V1 hardcodes Right Option. Settings-driven rebinding comes with the Shortcuts tab.
/// Callback bodies are dispatched on the main actor since the tap is scheduled
/// on `CFRunLoopGetMain()`.
final class GlobalHotkey: @unchecked Sendable {
    private static let log = Logger(subsystem: "com.babel.app", category: "hotkey")

    private let onPress: @MainActor () -> Void
    private let onRelease: @MainActor () -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressed = false

    init(
        onPress: @escaping @MainActor () -> Void,
        onRelease: @escaping @MainActor () -> Void
    ) {
        self.onPress = onPress
        self.onRelease = onRelease
    }

    @MainActor
    func start() throws {
        let mask: CGEventMask = 1 << CGEventType.flagsChanged.rawValue
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: Self.tapCallback,
            userInfo: refcon
        ) else {
            Self.log.error("CGEvent.tapCreate returned nil (Input Monitoring not granted?)")
            throw GlobalHotkeyError.tapCreationFailed
        }
        Self.log.info("CGEvent.tapCreate succeeded")

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    @MainActor
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        pressed = false
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userInfo).takeUnretainedValue()
        // Extract Sendable scalars here — the CGEvent itself isn't Sendable across actors.
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flagsRaw = event.flags.rawValue
        let rawType = type.rawValue
        MainActor.assumeIsolated {
            hotkey.handle(rawType: rawType, keycode: keycode, flagsRaw: flagsRaw)
        }
        return Unmanaged.passUnretained(event)
    }

    @MainActor
    private func handle(rawType: UInt32, keycode: Int64, flagsRaw: UInt64) {
        let type = CGEventType(rawValue: rawType)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }
        guard type == .flagsChanged else { return }
        guard keycode == kRightOptionKeyCode else { return }

        let nowDown = (flagsRaw & kRightOptionDeviceMask) != 0
        if nowDown && !pressed {
            pressed = true
            onPress()
        } else if !nowDown && pressed {
            pressed = false
            onRelease()
        }
    }
}
