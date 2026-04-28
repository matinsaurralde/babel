import Foundation

/// Whisper variants we expose for the Accurate mode. Sizes are
/// approximate, taken from the WhisperKit / Hugging Face artifact
/// catalog (download size on disk for the CoreML packages).
enum WhisperModelChoice: String, CaseIterable, Identifiable, Sendable {
    case tiny
    case base
    case small
    case largeV3Turbo = "large_v3_turbo"

    static let userDefaultsKey = "babel.whisperModel"
    static let `default`: WhisperModelChoice = .largeV3Turbo

    static var current: WhisperModelChoice {
        guard
            let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
            let value = WhisperModelChoice(rawValue: raw)
        else { return .default }
        return value
    }

    var id: String { rawValue }

    /// The exact model identifier WhisperKit pulls from Hugging Face.
    var modelID: String {
        switch self {
        case .tiny: "openai_whisper-tiny"
        case .base: "openai_whisper-base"
        case .small: "openai_whisper-small"
        case .largeV3Turbo: "openai_whisper-large-v3-v20240930_turbo"
        }
    }

    var displayName: String {
        switch self {
        case .tiny: "Tiny"
        case .base: "Base"
        case .small: "Small"
        case .largeV3Turbo: "Large v3 Turbo"
        }
    }

    var sizeApprox: String {
        switch self {
        case .tiny: "≈75 MB"
        case .base: "≈145 MB"
        case .small: "≈475 MB"
        case .largeV3Turbo: "≈1.5 GB"
        }
    }

    var subtitle: String {
        switch self {
        case .tiny: "Smallest, fastest, lowest accuracy. Good for short utterances or low-storage Macs."
        case .base: "Solid baseline. Faster than Small, less accurate."
        case .small: "Good balance for most users."
        case .largeV3Turbo: "Default. Best accuracy, takes more disk and a few seconds longer to load."
        }
    }
}
