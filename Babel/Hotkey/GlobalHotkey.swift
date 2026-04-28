import AppKit
import CoreGraphics
import OSLog

enum GlobalHotkeyError: Error {
    case tapCreationFailed
}

/// Global push-to-hold hotkey driven by `CGEventTap` on the main runloop.
/// The watched key is configurable via `HotkeyBinding`; modifiers use
/// `flagsChanged` events with device-level bit checks, function keys (F13–F19)
/// use `keyDown`/`keyUp`.
///
/// Callback bodies are dispatched on the main actor since the tap is scheduled
/// on `CFRunLoopGetMain()`.
final class GlobalHotkey: @unchecked Sendable {
    private static let log = Logger(subsystem: "com.babel.app", category: "hotkey")

    let binding: HotkeyBinding
    private let onPress: @MainActor () -> Void
    private let onRelease: @MainActor () -> Void

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressed = false

    init(
        binding: HotkeyBinding,
        onPress: @escaping @MainActor () -> Void,
        onRelease: @escaping @MainActor () -> Void
    ) {
        self.binding = binding
        self.onPress = onPress
        self.onRelease = onRelease
    }

    @MainActor
    func start() throws {
        let mask: CGEventMask = binding.isModifier
            ? 1 << CGEventType.flagsChanged.rawValue
            : (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.tapCallback,
            userInfo: refcon
        ) else {
            Self.log.error("CGEvent.tapCreate returned nil — Input Monitoring not granted?")
            throw GlobalHotkeyError.tapCreationFailed
        }
        Self.log.info("CGEvent.tapCreate succeeded for \(self.binding.displayName, privacy: .public)")

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
        if pressed {
            // Synthesize a release so callers don't get stuck in `.listening`
            // if the user happened to be holding the key while we tore down.
            pressed = false
            onRelease()
        }
    }

    /// If the system disabled the tap (e.g., after long sleep), turn it back on.
    @MainActor
    func reenableIfNeeded() {
        guard let tap = eventTap else { return }
        if !CGEvent.tapIsEnabled(tap: tap) {
            Self.log.info("tap was disabled, re-enabling")
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    private static let tapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return Unmanaged.passUnretained(event) }
        let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userInfo).takeUnretainedValue()
        let keycode = event.getIntegerValueField(.keyboardEventKeycode)
        let flagsRaw = event.flags.rawValue
        let rawType = type.rawValue

        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                hotkey.handle(rawType: rawType, keycode: keycode, flagsRaw: flagsRaw)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    @MainActor
    private func handle(rawType: UInt32, keycode: Int64, flagsRaw: UInt64) {
        let type = CGEventType(rawValue: rawType)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Self.log.error("tap disabled (type=\(rawType)) — re-enabling")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }
        guard keycode == binding.keycode else { return }

        if binding.isModifier {
            guard type == .flagsChanged, let mask = binding.deviceMask else { return }
            let nowDown = (flagsRaw & mask) != 0
            if nowDown && !pressed {
                pressed = true
                Self.log.info("press")
                onPress()
            } else if !nowDown && pressed {
                pressed = false
                Self.log.info("release")
                onRelease()
            }
        } else {
            // Function key: discrete keyDown / keyUp. Dedupe autorepeat.
            switch type {
            case .keyDown:
                if !pressed {
                    pressed = true
                    Self.log.info("press")
                    onPress()
                }
            case .keyUp:
                if pressed {
                    pressed = false
                    Self.log.info("release")
                    onRelease()
                }
            default:
                return
            }
        }
    }
}
