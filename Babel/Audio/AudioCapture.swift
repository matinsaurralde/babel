@preconcurrency import AVFoundation
import Foundation
import OSLog

/// One-shot mutable flag passed to AVAudioConverter's input block. Wrapped in a
/// reference so the `@Sendable` closure can read/write without triggering Swift 6
/// concurrency diagnostics on captured vars.
private final class ConvertOnce: @unchecked Sendable {
    var done = false
}

/// Captures microphone input, downsamples to 16 kHz mono Float32, and publishes
/// chunks plus RMS levels over an `AsyncStream`.
///
/// Uses a fresh `AVAudioEngine` per session. The input node is connected to the
/// mainMixerNode (muted) to force a complete node graph — without this, on
/// macOS the engine sometimes runs without pulling samples from the input, and
/// the tap never fires. We also listen for `AVAudioEngineConfigurationChange`
/// notifications, which the engine posts when the IO unit reconfigures (e.g.,
/// right after Microphone permission is granted); the engine pauses on that
/// event and must be restarted explicitly.
final class AudioCapture: @unchecked Sendable {
    struct Chunk: Sendable {
        let samples: [Float]
        let rms: Float
    }

    enum AudioCaptureError: Error, LocalizedError {
        case microphoneNotAuthorized
        case invalidInputFormat
        case formatSetup

        var errorDescription: String? {
            switch self {
            case .microphoneNotAuthorized: "Microphone permission is not granted."
            case .invalidInputFormat: "The input device returned an invalid format."
            case .formatSetup: "Could not set up 16 kHz mono conversion."
            }
        }
    }

    private static let log = Logger(subsystem: "com.babel.app", category: "audio")

    private let lock = NSLock()
    private var engine: AVAudioEngine?
    private var configObserver: NSObjectProtocol?
    private var continuation: AsyncStream<Chunk>.Continuation?

    func start() throws -> AsyncStream<Chunk> {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else {
            Self.log.error("start: microphone not authorized")
            throw AudioCaptureError.microphoneNotAuthorized
        }

        let engine = AVAudioEngine()
        lock.withLock { self.engine = engine }

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        Self.log.info("start: input format = \(String(describing: inputFormat), privacy: .public)")

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw AudioCaptureError.invalidInputFormat
        }

        guard
            let targetFormat = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: 16_000,
                channels: 1,
                interleaved: false
            ),
            let converter = AVAudioConverter(from: inputFormat, to: targetFormat)
        else {
            throw AudioCaptureError.formatSetup
        }

        // Force a complete node graph. Without a downstream connection the input
        // node sometimes doesn't pull samples on macOS — the engine "runs" but
        // the tap stays quiet. Mixer output volume is 0 so nothing hits speakers.
        let mixer = engine.mainMixerNode
        mixer.outputVolume = 0
        engine.connect(input, to: mixer, format: inputFormat)

        let (stream, cont) = AsyncStream.makeStream(of: Chunk.self, bufferingPolicy: .unbounded)
        lock.withLock { self.continuation = cont }

        let ratio = targetFormat.sampleRate / inputFormat.sampleRate
        let firstTap = ConvertOnce()

        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [converter, targetFormat, cont, firstTap] buffer, _ in
            if !firstTap.done {
                firstTap.done = true
                Self.log.info("tap: first callback, frames=\(buffer.frameLength)")
            }

            let outCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 256
            guard let output = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: outCapacity) else { return }

            var error: NSError?
            let once = ConvertOnce()
            _ = converter.convert(to: output, error: &error) { _, status in
                if once.done {
                    status.pointee = .noDataNow
                    return nil
                }
                once.done = true
                status.pointee = .haveData
                return buffer
            }
            guard error == nil, output.frameLength > 0, let data = output.floatChannelData?[0] else {
                return
            }

            let n = Int(output.frameLength)
            let samples = Array(UnsafeBufferPointer(start: data, count: n))

            var sumSq: Float = 0
            for s in samples { sumSq += s * s }
            let rms = n > 0 ? (sumSq / Float(n)).squareRoot() : 0

            cont.yield(Chunk(samples: samples, rms: rms))
        }

        // Handle IOUnit reconfiguration (notably: right after Microphone is
        // granted). The engine pauses automatically and must be restarted.
        let observer = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak engine] _ in
            guard let engine else { return }
            Self.log.info("config change — restarting engine (isRunning=\(engine.isRunning))")
            do {
                try engine.start()
            } catch {
                Self.log.error("config-change restart failed: \(String(describing: error), privacy: .public)")
            }
        }
        lock.withLock { self.configObserver = observer }

        engine.prepare()
        try engine.start()
        Self.log.info("start: engine running (isRunning=\(engine.isRunning))")
        return stream
    }

    func stop() {
        var engineToStop: AVAudioEngine?
        var obsToRemove: NSObjectProtocol?
        lock.withLock {
            engineToStop = engine
            obsToRemove = configObserver
            continuation?.finish()
            continuation = nil
            engine = nil
            configObserver = nil
        }
        if let obs = obsToRemove {
            NotificationCenter.default.removeObserver(obs)
        }
        if let e = engineToStop {
            e.inputNode.removeTap(onBus: 0)
            e.stop()
            Self.log.info("stop: engine stopped")
        }
    }
}
