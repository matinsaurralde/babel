import SwiftUI

struct SettingsRootView: View {
    @State private var selected: Tab = Permissions.allGranted() ? .general : .permissions

    enum Tab: String, Hashable {
        case permissions, general, models, shortcuts, about
    }

    var body: some View {
        TabView(selection: $selected) {
            OnboardingView()
                .tabItem { Label("Permissions", systemImage: "checkmark.shield") }
                .tag(Tab.permissions)

            GeneralTab()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Tab.general)

            ModelsTab()
                .tabItem { Label("Models", systemImage: "cpu") }
                .tag(Tab.models)

            ShortcutsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                .tag(Tab.shortcuts)

            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(Tab.about)
        }
        .frame(width: 560, height: 520)
    }
}

private struct GeneralTab: View {
    @Environment(AppState.self) private var state
    @AppStorage("babel.defaultMode") private var defaultModeRaw: String = BabelMode.fast.rawValue

    var body: some View {
        @Bindable var state = state
        Form {
            Section("Default mode") {
                Picker("Mode", selection: $state.mode) {
                    ForEach(BabelMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.sfSymbol).tag(mode)
                    }
                }
                .pickerStyle(.inline)
                .onChange(of: state.mode) { _, new in
                    defaultModeRaw = new.rawValue
                }

                Text("Fast uses Apple SpeechAnalyzer with minimal overhead. Balanced surfaces partial results. Accurate will route through Whisper large-v3-turbo when that engine lands.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct ModelsTab: View {
    var body: some View {
        Form {
            Section("Transcription engine") {
                LabeledContent("Fast", value: "Apple SpeechAnalyzer")
                LabeledContent("Balanced", value: "Apple SpeechAnalyzer")
                LabeledContent("Accurate", value: "Whisper large-v3-turbo (coming in v1.0)")
            }
            Section("Post-processing LLM") {
                Text("Coming in v1.1 — Ollama integration for grammar cleanup.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct ShortcutsTab: View {
    var body: some View {
        Form {
            Section("Global hotkey") {
                LabeledContent("Push-to-hold", value: "Right Option")
                Text("Rebinding will arrive in v1.0. The hotkey captures Right Option anywhere on macOS — release to insert the transcript into the frontmost app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct AboutTab: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(.tint)
            Text("Babel")
                .font(.title.weight(.semibold))
            Text("Native macOS dictation. Local-first. Open-source.")
                .foregroundStyle(.secondary)
            Text("Version 0.1.0")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            Link("github.com/babel/babel", destination: URL(string: "https://github.com/")!)
                .font(.footnote)
                .padding(.top, 8)
        }
        .padding(40)
    }
}
