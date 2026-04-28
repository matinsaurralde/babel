import Foundation

/// Thread-safe buffer for progressive transcription state.
///
/// `SpeechTranscriber` (and similar streaming engines) emit one
/// `.isFinal` result per phrase/segment, each with its own segment text —
/// not a single cumulative final at end-of-audio. To preserve everything
/// the user said, we have to *append* every final and surface a
/// concatenation, not overwrite on each `.isFinal`.
///
/// `appendFinal(_:)` commits a segment. `setPartial(_:)` replaces the
/// current volatile partial. `snapshot()` returns the user-visible
/// transcript — joined finals, with the partial appended if non-empty.
final class TranscriptAccumulator: @unchecked Sendable {
    private let lock = NSLock()
    private var finals: [String] = []
    private var partial: String = ""

    init() {}

    func appendFinal(_ text: String) {
        lock.lock(); defer { lock.unlock() }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            finals.append(trimmed)
        }
        partial = ""
    }

    func setPartial(_ text: String) {
        lock.lock(); defer { lock.unlock() }
        partial = text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func snapshot() -> String {
        lock.lock(); defer { lock.unlock() }
        var parts = finals
        if !partial.isEmpty { parts.append(partial) }
        return parts.joined(separator: " ")
    }
}
