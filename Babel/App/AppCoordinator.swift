import AppKit
import OSLog
import SwiftUI

/// Wires global state, hotkey, audio capture, transcription engine and text
/// insertion together. The engine is picked per mode — see `engine(for:)`.
@MainActor
@Observable
final class AppCoordinator {
    let state = AppState()

    private static let log = Logger(subsystem: "com.babel.app", category: "coordinator")

    private var hotkey: GlobalHotkey?
    private var pill: PillWindowController?

    private let audio = AudioCapture()
    private var sessionTask: Task<Void, Never>?
    private var installRetryTask: Task<Void, Never>?

    func start() {
        Self.log.info("permissions: mic=\(String(describing: Permissions.status(for: .microphone)), privacy: .public) speech=\(String(describing: Permissions.status(for: .speechRecognition)), privacy: .public) accessibility=\(String(describing: Permissions.status(for: .accessibility)), privacy: .public) inputMonitoring=\(String(describing: Permissions.status(for: .inputMonitoring)), privacy: .public)")

        let pill = PillWindowController(state: state)
        self.pill = pill

        installHotkey()

        // CGEvent.tapCreate fails while Input Monitoring is not granted.
        // The user typically grants it *after* launch via the onboarding flow,
        // so we retry periodically until the tap takes.
        if hotkey == nil {
            installRetryTask = Task { @MainActor in
                while self.hotkey == nil && !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    self.installHotkey()
                }
            }
        }
    }

    private func installHotkey() {
        guard hotkey == nil else { return }
        let hk = GlobalHotkey(
            onPress: { [weak self] in self?.handlePress() },
            onRelease: { [weak self] in self?.handleRelease() }
        )
        do {
            try hk.start()
            hotkey = hk
            if case .error = state.phase { state.phase = .idle }
            Self.log.info("hotkey installed")
        } catch {
            Self.log.error("hotkey install failed: \(String(describing: error), privacy: .public)")
            state.phase = .error("Input Monitoring required")
        }
    }

    private func handlePress() {
        guard sessionTask == nil else { return }
        Self.log.info("press")
        state.phase = .listening
        state.audioLevel = 0
        state.partialTranscript = ""
        state.lastFinalTranscript = ""
        pill?.show()

        let audioStream: AsyncStream<AudioCapture.Chunk>
        do {
            audioStream = try audio.start()
        } catch {
            Self.log.error("audio start failed: \(String(describing: error), privacy: .public)")
            state.phase = .error("Microphone unavailable")
            pill?.hide()
            return
        }

        let selectedMode = state.mode
        let selectedEngine = engine(for: selectedMode)
        let startedAt = Date()
        let frontBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

        sessionTask = Task { @MainActor in
            await runSession(
                audio: audioStream,
                engine: selectedEngine,
                mode: selectedMode,
                startedAt: startedAt,
                frontmostBundleID: frontBundleID
            )
            self.sessionTask = nil
        }
    }

    private func handleRelease() {
        Self.log.info("release")
        audio.stop()
        state.phase = .processing
    }

    @MainActor
    private func runSession(
        audio audioStream: AsyncStream<AudioCapture.Chunk>,
        engine: TranscriptionEngine,
        mode: BabelMode,
        startedAt: Date,
        frontmostBundleID: String?
    ) async {
        let (engineStream, engineCont) = AsyncStream.makeStream(
            of: AudioCapture.Chunk.self,
            bufferingPolicy: .unbounded
        )

        let forwarder = Task { @MainActor in
            for await chunk in audioStream {
                state.audioLevel = min(1, chunk.rms * 8)
                engineCont.yield(chunk)
            }
            state.audioLevel = 0
            engineCont.finish()
        }

        var rawPartials: [String] = []
        do {
            for try await update in engine.transcribe(audio: engineStream) {
                switch update {
                case .partial(let text):
                    state.partialTranscript = text
                    rawPartials.append(text)
                case .final(let text):
                    state.lastFinalTranscript = text
                }
            }
            Self.log.info("runSession: transcribe loop exited")
        } catch {
            Self.log.error("transcription error: \(String(describing: error), privacy: .public)")
            state.phase = .error("Transcription failed")
        }

        forwarder.cancel()
        await forwarder.value
        Self.log.info("runSession: forwarder done")

        if case .error = state.phase {
            try? await Task.sleep(for: .milliseconds(900))
            state.phase = .idle
            pill?.hide()
            return
        }

        state.phase = .inserting
        let finalText = state.lastFinalTranscript
        let outcome = TextInserter.insert(finalText)
        Self.log.info("insertion outcome: \(String(describing: outcome), privacy: .public) front=\(frontmostBundleID ?? "(unknown)", privacy: .public)")

        let duration = Date().timeIntervalSince(startedAt)
        if !finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            HistoryStore.save(Dictation(
                mode: mode,
                engineName: engine.displayName,
                rawTranscript: rawPartials.last ?? finalText,
                finalText: finalText,
                durationSeconds: duration,
                insertedIntoBundleID: frontmostBundleID
            ))
        }

        switch outcome {
        case .clipboardOnly:
            state.phase = .clipboardFallback
            try? await Task.sleep(for: .milliseconds(2000))
        case .inserted, .empty:
            try? await Task.sleep(for: .milliseconds(280))
        }
        state.phase = .idle
        pill?.hide()
    }

    private func engine(for mode: BabelMode) -> TranscriptionEngine {
        // All three modes currently route through SpeechAnalyzer. Accurate will
        // switch to WhisperKit large-v3-turbo once that engine lands.
        SpeechAnalyzerEngine()
    }
}
