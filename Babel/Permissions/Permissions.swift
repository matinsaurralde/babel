import AppKit
import ApplicationServices
import AVFoundation
import Foundation
import Speech

enum PermissionStatus: Equatable, Sendable {
    case granted
    case denied
    case notDetermined
}

enum Permission: String, CaseIterable, Identifiable, Sendable {
    case microphone
    case speechRecognition
    case accessibility
    case inputMonitoring

    var id: String { rawValue }

    var title: String {
        switch self {
        case .microphone: "Microphone"
        case .speechRecognition: "Speech Recognition"
        case .accessibility: "Accessibility"
        case .inputMonitoring: "Input Monitoring"
        }
    }

    var explanation: String {
        switch self {
        case .microphone:
            "Babel needs to hear you. Audio is processed on-device and never leaves your Mac."
        case .speechRecognition:
            "Feeds captured audio to Apple SpeechAnalyzer for on-device transcription."
        case .accessibility:
            "Lets Babel paste the transcribed text into the focused app and detect the global hotkey."
        case .inputMonitoring:
            "Required to observe the push-to-hold hotkey (Right Option) system-wide."
        }
    }

    /// Deep link into the relevant System Settings pane.
    var settingsURL: URL? {
        switch self {
        case .microphone:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
        case .speechRecognition:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
        case .accessibility:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .inputMonitoring:
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
        }
    }
}

/// Nonisolated intentionally. The macOS privacy callbacks (AVCaptureDevice,
/// SFSpeechRecognizer, TCC) fire on arbitrary queues; pinning this API to
/// MainActor caused a runtime isolation assertion when the Speech framework
/// invoked its completion on `com.apple.root.default-qos`.
enum Permissions {
    static func status(for permission: Permission) -> PermissionStatus {
        switch permission {
        case .microphone:
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized: .granted
            case .denied, .restricted: .denied
            case .notDetermined: .notDetermined
            @unknown default: .notDetermined
            }
        case .speechRecognition:
            switch SFSpeechRecognizer.authorizationStatus() {
            case .authorized: .granted
            case .denied, .restricted: .denied
            case .notDetermined: .notDetermined
            @unknown default: .notDetermined
            }
        case .accessibility:
            AXIsProcessTrusted() ? .granted : .notDetermined
        case .inputMonitoring:
            switch IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) {
            case kIOHIDAccessTypeGranted: .granted
            case kIOHIDAccessTypeDenied: .denied
            default: .notDetermined
            }
        }
    }

    static func allGranted() -> Bool {
        Permission.allCases.allSatisfy { status(for: $0) == .granted }
    }

    static func request(_ permission: Permission) async {
        switch permission {
        case .microphone:
            _ = await AVCaptureDevice.requestAccess(for: .audio)
        case .speechRecognition:
            await requestSpeechAuthorization()
        case .accessibility:
            await MainActor.run { requestAccessibilityPrompt() }
        case .inputMonitoring:
            _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            await MainActor.run { openSettings(for: .inputMonitoring) }
        }
    }

    static func openSettings(for permission: Permission) {
        if let url = permission.settingsURL {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Private

    private static func requestSpeechAuthorization() async {
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            SFSpeechRecognizer.requestAuthorization { @Sendable _ in
                cont.resume()
            }
        }
    }

    @MainActor
    private static func requestAccessibilityPrompt() {
        let options: NSDictionary = ["AXTrustedCheckOptionPrompt": true]
        _ = AXIsProcessTrustedWithOptions(options)
        openSettings(for: .accessibility)
    }
}
