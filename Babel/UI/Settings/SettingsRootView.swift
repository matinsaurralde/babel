import Speech
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
    @AppStorage(LocalePreference.userDefaultsKey) private var dictationLocale: String = ""

    @State private var installedLocales: [Locale] = []
    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled
    @AppStorage(SessionSounds.userDefaultsKey) private var soundsEnabled: Bool = false

    var body: some View {
        @Bindable var state = state
        Form {
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, new in
                        LaunchAtLogin.setEnabled(new)
                        launchAtLogin = LaunchAtLogin.isEnabled
                    }
                Text("Babel lives in the menu bar, so it's useful to have it ready whenever your Mac starts.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Feedback") {
                Toggle("Play a sound when I start and stop dictating", isOn: $soundsEnabled)
                Text("Subtle built-in macOS sounds (Tink / Pop). Useful if you'd rather keep your eyes on the app you're typing into than on the pill.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

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

            Section("Dictation language") {
                Picker("Language", selection: $dictationLocale) {
                    Text("Auto (follow system)").tag("")
                    if !installedLocales.isEmpty {
                        Divider()
                        ForEach(installedLocales, id: \.identifier) { locale in
                            Text(LocalePreference.displayName(for: locale))
                                .tag(locale.identifier(.bcp47))
                        }
                    }
                }

                Text(localeHelpText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .task {
            installedLocales = await SpeechTranscriber.installedLocales
                .sorted { LocalePreference.displayName(for: $0) < LocalePreference.displayName(for: $1) }
        }
    }

    private var localeHelpText: String {
        if installedLocales.isEmpty {
            return "No dictation languages are installed yet. Open System Settings → General → Keyboard → Dictation to enable the languages you want."
        }
        return "On-device transcription. Only languages you've enabled for macOS dictation appear above. Add more in System Settings → Keyboard → Dictation."
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
