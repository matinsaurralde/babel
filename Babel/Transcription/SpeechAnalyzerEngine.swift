@preconcurrency import AVFoundation
import Foundation
import OSLog
import Speech

/// Transcription engine backed by the macOS 26 `SpeechAnalyzer` + `SpeechTranscriber`
/// APIs. Fully on-device. Uses `.progressiveTranscription` so partial results stream
/// while the user is still speaking — we surface those on the pill but only commit
/// the final text on key release.
final class SpeechAnalyzerEngine: TranscriptionEngine {
    let displayName = "Apple SpeechAnalyzer"

    private static let log = Logger(subsystem: "com.babel.app", category: "engine.speech")

    func transcribe(
        audio: AsyncStream<AudioCapture.Chunk>
    ) -> AsyncThrowingStream<TranscriptionUpdate, Error> {
        AsyncThrowingStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                do {
                    try await Self.run(audio: audio, continuation: continuation)
                    continuation.finish()
                } catch {
                    Self.log.error("transcribe failed: \(String(describing: error), privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    enum EngineError: Error, LocalizedError {
        case notAuthorized
        case noInstalledLocale
        case noCompatibleAudioFormat
        case finalizeTimeout

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "Speech Recognition is not authorized."
            case .noInstalledLocale:
                return "No dictation models are installed. Install one in System Settings → General → Language & Region."
            case .noCompatibleAudioFormat:
                return "SpeechAnalyzer rejected the audio format."
            case .finalizeTimeout:
                return "SpeechAnalyzer did not return a result in time."
            }
        }
    }

    // MARK: - Implementation

    private static func run(
        audio: AsyncStream<AudioCapture.Chunk>,
        continuation: AsyncThrowingStream<TranscriptionUpdate, Error>.Continuation
    ) async throws {
        log.info("run: begin")
        try await ensureAuthorized()
        log.info("run: authorized")

        let locale = try await pickLocale()
        log.info("run: picked locale \(locale.identifier(.bcp47), privacy: .public)")

        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        let compatibleFormats = await transcriber.availableCompatibleAudioFormats
        guard let targetFormat = compatibleFormats.first else {
            throw EngineError.noCompatibleAudioFormat
        }
        log.info("run: target format = \(String(describing: targetFormat), privacy: .public)")

        guard
            let sourceFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            )
        else { throw EngineError.noCompatibleAudioFormat }

        let needsConversion = !formatsMatch(sourceFormat, targetFormat)
        let converter: AVAudioConverter? = needsConversion
            ? AVAudioConverter(from: sourceFormat, to: targetFormat)
            : nil

        let (inputStream, inputCont) = AsyncStream.makeStream(
            of: AnalyzerInput.self,
            bufferingPolicy: .unbounded
        )

        try await analyzer.start(inputSequence: inputStream)
        log.info("run: analyzer started")

        let lastPartial = LockedString()

        let resultsTask = Task {
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    lastPartial.set(text)
                    if result.isFinal {
                        log.info("result: FINAL \(text.count) chars")
                        continuation.yield(.final(text))
                    } else {
                        log.debug("result: partial \(text.count) chars")
                        continuation.yield(.partial(text))
                    }
                }
                log.info("results: stream ended")
            } catch {
                log.error("results: stream error \(String(describing: error), privacy: .public)")
                throw error
            }
        }

        var chunkCount = 0
        var frameCount = 0
        for await chunk in audio {
            chunkCount += 1
            frameCount += chunk.samples.count
            if let buffer = makeBuffer(
                samples: chunk.samples,
                sourceFormat: sourceFormat,
                targetFormat: targetFormat,
                converter: converter
            ) {
                inputCont.yield(AnalyzerInput(buffer: buffer))
            }
        }
        inputCont.finish()
        log.info("run: input closed — chunks=\(chunkCount), frames=\(frameCount)")

        // If we never saw any audio (user tapped the hotkey instantly), skip
        // finalize entirely and yield an empty final. Calling finalize with an
        // analyzer that was never fed can hang indefinitely in the results
        // stream and leave the UI trapped in `.processing`.
        if chunkCount == 0 {
            log.info("run: no audio received, skipping finalize")
            resultsTask.cancel()
            continuation.yield(.final(""))
            return
        }

        // Finalize with a hard timeout so the UI never hangs in .processing forever.
        do {
            try await withTimeout(seconds: 6) {
                try await analyzer.finalizeAndFinishThroughEndOfInput()
            }
            log.info("run: analyzer finalized")
        } catch {
            log.error("run: finalize timed out — cancelling: \(String(describing: error), privacy: .public)")
            resultsTask.cancel()
            let fallback = lastPartial.get()
            continuation.yield(.final(fallback))
            return
        }

        // Results stream should close shortly after finalize. Give it up to 2s.
        do {
            try await withTimeout(seconds: 2) {
                _ = await resultsTask.result
            }
            log.info("run: resultsTask completed")
        } catch {
            resultsTask.cancel()
            log.error("run: resultsTask did not settle in 2s — cancelled")
        }

        // If no .final was ever yielded, fall back to the last partial we saw.
        let fallback = lastPartial.get()
        if !fallback.isEmpty {
            log.info("run: yielding fallback from last partial (\(fallback.count) chars)")
            continuation.yield(.final(fallback))
        }
    }

    private static func ensureAuthorized() async throws {
        let current = SFSpeechRecognizer.authorizationStatus()
        if current == .authorized { return }
        if current == .denied || current == .restricted {
            throw EngineError.notAuthorized
        }
        let status = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0) }
        }
        guard status == .authorized else { throw EngineError.notAuthorized }
    }

    private static func pickLocale() async throws -> Locale {
        let installed = await SpeechTranscriber.installedLocales
        guard !installed.isEmpty else { throw EngineError.noInstalledLocale }

        let preferred = Locale.current
        if let match = installed.first(where: { $0.identifier(.bcp47) == preferred.identifier(.bcp47) }) {
            return match
        }
        if let lang = preferred.language.languageCode?.identifier,
           let match = installed.first(where: { $0.language.languageCode?.identifier == lang }) {
            return match
        }
        if let english = installed.first(where: { $0.language.languageCode?.identifier == "en" }) {
            return english
        }
        return installed[0]
    }

    private static func formatsMatch(_ a: AVAudioFormat, _ b: AVAudioFormat) -> Bool {
        a.sampleRate == b.sampleRate
            && a.channelCount == b.channelCount
            && a.commonFormat == b.commonFormat
            && a.isInterleaved == b.isInterleaved
    }

    private static func makeBuffer(
        samples: [Float],
        sourceFormat: AVAudioFormat,
        targetFormat: AVAudioFormat,
        converter: AVAudioConverter?
    ) -> AVAudioPCMBuffer? {
        guard
            let src = AVAudioPCMBuffer(
                pcmFormat: sourceFormat,
                frameCapacity: AVAudioFrameCount(samples.count)
            )
        else { return nil }
        src.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { ptr in
            if let base = ptr.baseAddress, let dst = src.floatChannelData?[0] {
                dst.update(from: base, count: samples.count)
            }
        }

        guard let converter else { return src }

        let ratio = targetFormat.sampleRate / sourceFormat.sampleRate
        let capacity = AVAudioFrameCount(Double(samples.count) * ratio) + 256
        guard let dst = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else {
            return nil
        }

        var error: NSError?
        let once = ConvertOnce()
        _ = converter.convert(to: dst, error: &error) { _, status in
            if once.done {
                status.pointee = .noDataNow
                return nil
            }
            once.done = true
            status.pointee = .haveData
            return src
        }
        return error == nil ? dst : nil
    }

    private static func withTimeout<T: Sendable>(
        seconds: Double,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw EngineError.finalizeTimeout
            }
            let first = try await group.next()!
            group.cancelAll()
            return first
        }
    }
}

private final class ConvertOnce: @unchecked Sendable {
    var done = false
}

private final class LockedString: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String = ""

    func set(_ new: String) {
        lock.lock(); defer { lock.unlock() }
        value = new
    }

    func get() -> String {
        lock.lock(); defer { lock.unlock() }
        return value
    }
}
