import AppKit
import SwiftData
import SwiftUI

@main
struct BabelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
                .environment(appDelegate.coordinator.state)
        } label: {
            MenuBarLabel()
                .environment(appDelegate.coordinator.state)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsRootView()
                .environment(appDelegate.coordinator.state)
        }

        Window("History", id: BabelWindows.historyID) {
            HistoryView()
        }
        .modelContainer(HistoryStore.sharedContainer)
        .windowResizability(.contentSize)
        .defaultSize(width: 720, height: 520)
    }
}

enum BabelWindows {
    static let historyID = "babel.history"

    /// Opens Settings programmatically (SwiftUI's `Settings` scene). macOS 14+.
    @MainActor
    static func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

private struct MenuBarLabel: View {
    @Environment(AppState.self) private var state

    var body: some View {
        Image(systemName: state.isActive ? "waveform.circle.fill" : "waveform.circle")
            .symbolRenderingMode(.hierarchical)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator.start()

        if !Permissions.allGranted() {
            // Give SwiftUI a moment to register the Settings scene before we open it.
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(400))
                BabelWindows.openSettings()
            }
        }
    }
}
