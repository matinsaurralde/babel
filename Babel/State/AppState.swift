import Foundation
import Observation

enum BabelMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case fast
    case balanced
    case accurate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fast: "Fast"
        case .balanced: "Balanced"
        case .accurate: "Accurate"
        }
    }

    var tagline: String {
        switch self {
        case .fast: "Apple SpeechAnalyzer · instant"
        case .balanced: "SpeechAnalyzer + partial results"
        case .accurate: "Whisper large-v3-turbo"
        }
    }

    var sfSymbol: String {
        switch self {
        case .fast: "bolt.fill"
        case .balanced: "scale.3d"
        case .accurate: "sparkles"
        }
    }
}

enum SessionPhase: Equatable, Sendable {
    case idle
    case listening
    case processing
    case inserting
    case error(String)

    var label: String {
        switch self {
        case .idle: "Ready"
        case .listening: "Listening…"
        case .processing: "Processing…"
        case .inserting: "Inserting…"
        case .error(let msg): "Error: \(msg)"
        }
    }
}

@MainActor
@Observable
final class AppState {
    var mode: BabelMode = .fast
    var phase: SessionPhase = .idle
    /// Normalized RMS level 0…1 for blob animation.
    var audioLevel: Float = 0
    var partialTranscript: String = ""
    var lastFinalTranscript: String = ""

    var isActive: Bool {
        if case .idle = phase { return false }
        return true
    }
}
