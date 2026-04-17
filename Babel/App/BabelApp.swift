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

        Window("Welcome to Babel", id: BabelWindows.onboardingID) {
            OnboardingWindow()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 560, height: 560)

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
    static let onboardingID = "babel.onboarding"
}

/// Hosts `OnboardingView` in its own window (separate from Settings so the
/// window can be opened programmatically via `openWindow` and activated
/// reliably for a menu-bar-only app).
struct OnboardingWindow: View {
    var body: some View {
        OnboardingView()
            .onAppear {
                NSApp.activate(ignoringOtherApps: true)
            }
    }
}

private struct MenuBarLabel: View {
    @Environment(AppState.self) private var state
    @Environment(\.openWindow) private var openWindow
    @State private var didCheckPermissions = false

    var body: some View {
        Image(systemName: state.isActive ? "waveform.circle.fill" : "waveform.circle")
            .symbolRenderingMode(.hierarchical)
            .task {
                // Runs once when the menu-bar label is first rendered — SwiftUI
                // scenes are registered by then, so openWindow works reliably.
                guard !didCheckPermissions else { return }
                didCheckPermissions = true
                try? await Task.sleep(for: .milliseconds(500))
                if !Permissions.allGranted() {
                    openWindow(id: BabelWindows.onboardingID)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        coordinator.start()
    }
}
