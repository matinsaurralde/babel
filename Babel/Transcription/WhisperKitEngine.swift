import Foundation
import OSLog
@preconcurrency import WhisperKit

/// Transcription engine powered by WhisperKit (`openai_whisper-large-v3-v20240930_turbo`).
/// Batch transcription — we accumulate all captured audio until the user releases
/// the hotkey, then hand the full buffer to WhisperKit in one call. Slower than
/// SpeechAnalyzer for short utterances but measurably more accurate, which is
/// the whole point of the Accurate mode.
///
/// Model management:
/// - First use downloads the ~1.5 GB model from Hugging Face (needs internet)
/// - Subsequent uses load from local cache (`~/Documents/huggingface/...`)
/// - The loaded `WhisperKit` instance is cached across sessions so we don't
///   pay the cold-start cost every dictation.
final class WhisperKitEngine: TranscriptionEngine, @unchecked Sendable {
    let displayName = "Whisper large-v3-turbo"

    /// Default model. Keep in sync with `ModelsTab` copy.
    static let modelName = "openai_whisper-large-v3-v20240930_turbo"

    private static let log = Logger(subsystem: "com.babel.app", category: "engine.whisperkit")
    private let cache = WhisperKitCache()

    enum EngineError: Error, LocalizedError {
        case modelLoadFailed(Error)
        case transcriptionFailed(Error)

        var errorDescription: String? {
            switch self {
            case .modelLoadFailed(let e): "Couldn't load Whisper model: \(e.localizedDescription)"
            case .transcriptionFailed(let e): "Whisper transcription failed: \(e.localizedDescription)"
            }
        }
    }

    func transcribe(
        audio: AsyncStream<AudioCapture.Chunk>
    ) -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) { [cache] in
                do {
                    try await Self.run(audio: audio, cache: cache, continuation: continuation)
                    continuation.finish()
                } catch {
                    Self.log.error("transcribe failed: \(String(describing: error), privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Implementation

    private static func run(
        audio: AsyncStream<AudioCapture.Chunk>,
        cache: WhisperKitCache,
        continuation: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation
    ) async throws {
        log.info("run: begin")
        continuation.yield(.partial("Loading model…"))

        let kit: WhisperKit
        do {
            kit = try await cache.load(modelName: modelName)
        } catch {
            throw EngineError.modelLoadFailed(error)
        }
        log.info("run: model ready, collecting audio")

        var samples: [Float] = []
        samples.reserveCapacity(16_000 * 30) // ~30 s runway
        for await chunk in audio {
            samples.append(contentsOf: chunk.samples)
        }
        log.info("run: audio collected, frames=\(samples.count)")

        guard !samples.isEmpty else {
            continuation.yield(.final(""))
            return
        }

        continuation.yield(.partial("Transcribing…"))

        let results: [TranscriptionResult]
        do {
            results = try await kit.transcribe(audioArray: samples)
        } catch {
            throw EngineError.transcriptionFailed(error)
        }

        let text = results
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        log.info("run: transcribed (\(text.count) chars)")
        continuation.yield(.final(text))
    }
}

/// Lazy cache for a single `WhisperKit` instance. The load is expensive — model
/// decompression + CoreML graph construction — so we keep the loaded instance
/// alive across dictation sessions. Actor-isolated so concurrent first-dictations
/// don't try to load twice.
private actor WhisperKitCache {
    private var instance: WhisperKit?

    func load(modelName: String) async throws -> WhisperKit {
        if let instance { return instance }
        let config = WhisperKitConfig(
            model: modelName,
            verbose: false,
            prewarm: true,
            load: true,
            download: true
        )
        let kit = try await WhisperKit(config)
        instance = kit
        return kit
    }
}
