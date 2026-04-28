import Foundation

/// A post-processing pass over a finished transcript. Runs *after* the
/// transcription engine and *before* `TextInserter` so we can clean up
/// grammar, drop filler words, and apply user-defined vocabulary.
///
/// Implementations should treat post-processing as polish, not a hard
/// requirement. Failures are surfaced via `throws` but the coordinator
/// is expected to recover by inserting the original transcript.
protocol LLMProcessor: Sendable {
    var displayName: String { get }

    func process(transcript: String) async throws -> String
}
