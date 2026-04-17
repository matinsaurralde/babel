import Foundation

/// Streaming update emitted by a transcription engine.
enum TranscriptionUpdate: Sendable, Equatable {
    case partial(String)
    case final(String)
}

/// Protocol every transcription backend (SpeechAnalyzer, MLX Whisper, cloud APIs)
/// implements. Consumes an async stream of 16 kHz mono Float32 audio chunks and
/// produces a stream of partial/final updates.
protocol TranscriptionEngine: Sendable {
    var displayName: String { get }

    /// Transcribe the given audio stream. The returned stream finishes when the
    /// audio input finishes (user released the push-to-hold key).
    func transcribe(
        audio: AsyncStream<AudioCapture.Chunk>
    ) -> AsyncThrowingStream<TranscriptionUpdate, Error>
}
