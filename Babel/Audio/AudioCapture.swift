@preconcurrency import AVFoundation
import Foundation

/// One-shot mutable flag passed to AVAudioConverter's input block. Wrapped in a
/// reference so the `@Sendable` closure can read/write without triggering Swift 6
/// concurrency diagnostics on captured vars.
private final class ConvertOnce: @unchecked Sendable {
    var done = false
}

/// Captures microphone input, downsamples to 16 kHz mono Float32, and publishes
/// chunks plus RMS levels over an `AsyncStream`. Nonisolated so the AVAudioEngine
/// tap (which runs on a dedicated audio thread) can produce without hopping actors.
final class AudioCapture: @unchecked Sendable {
    struct Chunk: Sendable {
        let samples: [Float]
        let rms: Float
    }

    enum AudioCaptureError: Error {
        case formatSetup
    }

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var continuation: AsyncStream<Chunk>.Continuation?

    /// Begin capturing. Returns an `AsyncStream` of 16 kHz mono Float32 chunks.
    /// The stream finishes when `stop()` is called.
    func start() throws -> AsyncStream<Chunk> {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
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

        let (stream, cont) = AsyncStream.makeStream(of: Chunk.self, bufferingPolicy: .unbounded)
        lock.withLock { self.continuation = cont }

        let ratio = targetFormat.sampleRate / inputFormat.sampleRate

        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [converter, targetFormat, cont] buffer, _ in
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

        try engine.start()
        return stream
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.withLock {
            continuation?.finish()
            continuation = nil
        }
    }
}
