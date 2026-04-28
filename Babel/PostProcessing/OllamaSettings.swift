import Foundation

/// User-configurable Ollama settings. Stored in `UserDefaults` so the
/// AppCoordinator and the Settings UI agree on what the active config is.
enum OllamaSettings {
    static let enabledKey = "babel.ollama.enabled"
    static let endpointKey = "babel.ollama.endpoint"
    static let modelKey = "babel.ollama.model"
    static let systemPromptKey = "babel.ollama.systemPrompt"
    static let vocabularyKey = "babel.ollama.vocabulary"

    static let defaultEndpoint = "http://localhost:11434"
    static let defaultModel = "llama3.2:3b"
    static let defaultSystemPrompt = """
    You are a transcription cleanup assistant. The user will give you a raw \
    speech-to-text transcript. Your job:

    1. Fix obvious grammar, capitalization, and punctuation.
    2. Remove filler words (um, uh, like, you know) the speaker clearly didn't intend.
    3. Preserve the speaker's voice, tone, and word choice.
    4. Do NOT add new ideas, expand abbreviations, or change meaning.
    5. Output only the cleaned text — no preamble, no explanations, no quotes.
    """

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    static var endpoint: URL {
        let raw = UserDefaults.standard.string(forKey: endpointKey) ?? defaultEndpoint
        return URL(string: raw) ?? URL(string: defaultEndpoint)!
    }

    static var model: String {
        let raw = UserDefaults.standard.string(forKey: modelKey) ?? ""
        return raw.isEmpty ? defaultModel : raw
    }

    static var systemPrompt: String {
        let raw = UserDefaults.standard.string(forKey: systemPromptKey) ?? ""
        return raw.isEmpty ? defaultSystemPrompt : raw
    }

    /// Free-form vocabulary block the user maintains (e.g. brand names,
    /// product names, jargon the model otherwise mistranscribes). Joined into
    /// the system prompt as a hint paragraph; empty by default.
    static var vocabulary: String {
        UserDefaults.standard.string(forKey: vocabularyKey) ?? ""
    }

    /// The full system prompt actually sent to Ollama: user prompt +
    /// optional "Pay attention to these terms" appendix.
    static func composedSystemPrompt() -> String {
        let vocab = vocabulary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !vocab.isEmpty else { return systemPrompt }
        return systemPrompt + "\n\nPreserve these terms exactly as written when you hear them:\n" + vocab
    }
}
