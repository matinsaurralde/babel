import Foundation
import OSLog

/// Pipes a transcript through a locally running Ollama instance (default
/// `http://localhost:11434`) for grammar / filler-word cleanup. Stateless —
/// every call reads fresh settings from `OllamaSettings`.
///
/// Babel doesn't install Ollama itself; the user runs `ollama pull <model>`
/// once before enabling post-processing. If the daemon isn't reachable or
/// the requested model isn't pulled, `process(transcript:)` throws, and
/// the coordinator recovers by inserting the original transcript.
final class OllamaProcessor: LLMProcessor {
    let displayName = "Ollama (local)"

    private static let log = Logger(subsystem: "com.babel.app", category: "llm.ollama")

    enum ProcessorError: Error, LocalizedError {
        case unreachable
        case badResponse(Int)
        case modelMissing(String)

        var errorDescription: String? {
            switch self {
            case .unreachable:
                return "Couldn't reach the local Ollama server."
            case .badResponse(let code):
                return "Ollama returned HTTP \(code)."
            case .modelMissing(let m):
                return "Ollama doesn't have the model '\(m)' installed. Run `ollama pull \(m)` first."
            }
        }
    }

    func process(transcript: String) async throws -> String {
        let endpoint = OllamaSettings.endpoint.appending(path: "api/chat")
        let model = OllamaSettings.model
        let prompt = OllamaSettings.composedSystemPrompt()

        struct Message: Codable {
            let role: String
            let content: String
        }
        struct Request: Codable {
            let model: String
            let messages: [Message]
            let stream: Bool
        }
        struct Response: Codable {
            let message: Message
        }

        let body = Request(
            model: model,
            messages: [
                .init(role: "system", content: prompt),
                .init(role: "user", content: transcript),
            ],
            stream: false
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await URLSession.shared.data(for: request)
        } catch {
            Self.log.error("ollama request failed: \(error.localizedDescription, privacy: .public)")
            throw ProcessorError.unreachable
        }

        guard let http = urlResponse as? HTTPURLResponse else {
            throw ProcessorError.badResponse(0)
        }
        if http.statusCode == 404 {
            throw ProcessorError.modelMissing(model)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ProcessorError.badResponse(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(Response.self, from: data)
        let cleaned = decoded.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
        Self.log.info("ollama returned \(cleaned.count) chars")
        return cleaned
    }

    /// One-shot probe — used by the Settings "Test connection" button. Returns
    /// the list of installed model tags on success, throws on the same errors
    /// `process` would throw.
    func reachableModels() async throws -> [String] {
        let endpoint = OllamaSettings.endpoint.appending(path: "api/tags")
        struct Response: Codable {
            struct Model: Codable { let name: String }
            let models: [Model]
        }

        let (data, urlResponse): (Data, URLResponse)
        do {
            (data, urlResponse) = try await URLSession.shared.data(from: endpoint)
        } catch {
            throw ProcessorError.unreachable
        }
        guard let http = urlResponse as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw ProcessorError.badResponse((urlResponse as? HTTPURLResponse)?.statusCode ?? 0)
        }
        let decoded = try JSONDecoder().decode(Response.self, from: data)
        return decoded.models.map(\.name)
    }
}
