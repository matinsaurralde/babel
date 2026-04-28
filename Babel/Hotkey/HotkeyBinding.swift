import Foundation

/// Keys Babel watches for the push-to-hold dictation gesture. Only includes
/// keys that are realistically *unused* in normal typing — modifiers held
/// alone (typing modifiers in chords doesn't release them, so a modifier-only
/// gesture is unambiguous) and the F13–F19 row that almost no app binds.
enum HotkeyBinding: String, Codable, CaseIterable, Identifiable, Sendable {
    // Modifier-only (held alone): we listen on `flagsChanged` and check the
    // device-level mask bit so we can distinguish left from right.
    case rightOption = "right_option"
    case leftOption = "left_option"
    case rightCommand = "right_command"
    case rightControl = "right_control"
    case rightShift = "right_shift"

    // Function row 13–19: discrete keyDown/keyUp, no modifier dance needed.
    case f13, f14, f15, f16, f17, f18, f19

    static let userDefaultsKey = "babel.hotkeyBinding"
    static let `default`: HotkeyBinding = .rightOption

    var id: String { rawValue }

    /// Reads the user's current choice from UserDefaults, defaulting to Right Option.
    static var current: HotkeyBinding {
        guard let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
              let binding = HotkeyBinding(rawValue: raw)
        else { return .default }
        return binding
    }

    var displayName: String {
        switch self {
        case .rightOption: "Right Option (⌥)"
        case .leftOption: "Left Option (⌥)"
        case .rightCommand: "Right Command (⌘)"
        case .rightControl: "Right Control (⌃)"
        case .rightShift: "Right Shift (⇧)"
        case .f13: "F13"
        case .f14: "F14"
        case .f15: "F15"
        case .f16: "F16"
        case .f17: "F17"
        case .f18: "F18"
        case .f19: "F19"
        }
    }

    /// Virtual keycode (HID usage) of the key.
    var keycode: Int64 {
        switch self {
        case .rightOption: 61
        case .leftOption: 58
        case .rightCommand: 54
        case .rightControl: 62
        case .rightShift: 60
        case .f13: 105
        case .f14: 107
        case .f15: 113
        case .f16: 106
        case .f17: 64
        case .f18: 79
        case .f19: 80
        }
    }

    /// For modifier-only bindings, the device-level bit set in
    /// `CGEvent.flags.rawValue` while the key is physically held. `nil` means
    /// this is a discrete key — listen on `keyDown`/`keyUp` instead.
    var deviceMask: UInt64? {
        switch self {
        case .rightOption: 0x40       // NX_DEVICERALTKEYMASK
        case .leftOption: 0x20        // NX_DEVICELALTKEYMASK
        case .rightCommand: 0x10      // NX_DEVICERCMDKEYMASK
        case .rightControl: 0x2000    // NX_DEVICERCTLKEYMASK
        case .rightShift: 0x04        // NX_DEVICERSHIFTKEYMASK
        case .f13, .f14, .f15, .f16, .f17, .f18, .f19: nil
        }
    }

    var isModifier: Bool { deviceMask != nil }

    /// Conventional groupings for Settings UI.
    static let modifierBindings: [HotkeyBinding] = [
        .rightOption, .leftOption, .rightCommand, .rightControl, .rightShift,
    ]
    static let functionKeyBindings: [HotkeyBinding] = [
        .f13, .f14, .f15, .f16, .f17, .f18, .f19,
    ]
}
