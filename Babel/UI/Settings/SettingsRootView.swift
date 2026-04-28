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
    @AppStorage(PillPosition.userDefaultsKey) private var pillPosition: String = PillPosition.default.rawValue

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

            Section("Pill position") {
                Picker("Show the pill at", selection: $pillPosition) {
                    ForEach(PillPosition.allCases) { position in
                        Text(position.displayName).tag(position.rawValue)
                    }
                }
                Text("Where the Liquid Glass pill floats while you're dictating. Takes effect on the next session.")
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
    @AppStorage(WhisperModelChoice.userDefaultsKey) private var whisperModel: String = WhisperModelChoice.default.rawValue

    var body: some View {
        Form {
            Section("Transcription engine") {
                LabeledContent("Fast", value: "Apple SpeechAnalyzer")
                LabeledContent("Balanced", value: "Apple SpeechAnalyzer")
                LabeledContent("Accurate", value: "Whisper via WhisperKit")
            }

            Section("Accurate mode — Whisper variant") {
                Picker("Model", selection: $whisperModel) {
                    ForEach(WhisperModelChoice.allCases) { choice in
                        Text("\(choice.displayName) (\(choice.sizeApprox))")
                            .tag(choice.rawValue)
                    }
                }

                if let current = WhisperModelChoice(rawValue: whisperModel) {
                    Text(current.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text("Downloaded from Hugging Face on first use, cached under ~/Documents/huggingface. Switching models triggers a fresh download for the new one.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
    @AppStorage(HotkeyBinding.userDefaultsKey) private var hotkeyRaw: String = HotkeyBinding.default.rawValue

    var body: some View {
        Form {
            Section("Push-to-hold key") {
                Picker("Hold to record", selection: $hotkeyRaw) {
                    Section("Modifier keys") {
                        ForEach(HotkeyBinding.modifierBindings) { binding in
                            Text(binding.displayName).tag(binding.rawValue)
                        }
                    }
                    Section("Function keys") {
                        ForEach(HotkeyBinding.functionKeyBindings) { binding in
                            Text(binding.displayName).tag(binding.rawValue)
                        }
                    }
                }
                .pickerStyle(.menu)

                Text("Hold the chosen key, speak, release. Babel watches keys that are rarely used elsewhere — modifiers held alone (no chord) and the F13–F19 row — so the gesture is unambiguous.")
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
