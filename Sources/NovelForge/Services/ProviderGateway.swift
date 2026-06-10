import Foundation

/// Einheitliche Anbindung aller KI-Provider.
/// Die Konfiguration (API-Key, Basis-URL, Modell) wird pro Aufruf übergeben –
/// es gibt keinen versteckten globalen Zustand mehr.
actor ProviderGateway {
    static let shared = ProviderGateway()

    private let urlSession: URLSession
    private let maxRetries = 3

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - Public API

    func generateText(request: GenerationRequest, configuration: ProviderConfiguration) async throws -> GenerationResponse {
        var attempt = 0
        while true {
            try Task.checkCancellation()
            do {
                return try await executeRequest(request: request, configuration: configuration)
            } catch let error as AIError {
                attempt += 1
                let retryable = (error == .rateLimitExceeded || error == .networkError || error == .providerUnavailable)
                guard retryable && attempt < maxRetries else { throw error }
                // Exponentielles Backoff: 2s, 4s
                try await Task.sleep(nanoseconds: UInt64(attempt) * 2_000_000_000)
            }
        }
    }

    /// Verbindungstest. Gibt nil bei Erfolg zurück, sonst eine Fehlerbeschreibung.
    func testConnection(configuration: ProviderConfiguration) async -> String? {
        let model = configuration.defaultModel ?? configuration.provider.suggestedModels.first ?? ""
        let request = GenerationRequest(
            prompt: "Antworte nur mit OK.",
            systemPrompt: nil,
            model: model,
            provider: configuration.provider,
            maxTokens: 10,
            temperature: 0.0
        )
        do {
            _ = try await executeRequest(request: request, configuration: configuration)
            return nil
        } catch let error as AIError {
            return error.errorDescription
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - Dispatch

    private func executeRequest(request: GenerationRequest, configuration: ProviderConfiguration) async throws -> GenerationResponse {
        switch configuration.provider {
        case .openAI:
            return try await executeOpenAICompatible(request: request, configuration: configuration,
                                                     fallbackBaseURL: "https://api.openai.com/v1")
        case .kimi:
            return try await executeOpenAICompatible(request: request, configuration: configuration,
                                                     fallbackBaseURL: "https://api.moonshot.ai/v1")
        case .custom:
            guard let base = configuration.baseURL, !base.isEmpty else { throw AIError.baseURLMissing }
            return try await executeOpenAICompatible(request: request, configuration: configuration,
                                                     fallbackBaseURL: base)
        case .anthropic:
            return try await executeAnthropicRequest(request: request, configuration: configuration)
        case .ollamaLocal, .ollamaCloud:
            return try await executeOllamaRequest(request: request, configuration: configuration)
        }
    }

    // MARK: - OpenAI-kompatible APIs (OpenAI, Kimi/Moonshot, Custom)

    private func executeOpenAICompatible(request: GenerationRequest,
                                         configuration: ProviderConfiguration,
                                         fallbackBaseURL: String) async throws -> GenerationResponse {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw AIError.apiKeyInvalid
        }

        var base = (configuration.baseURL?.isEmpty == false) ? configuration.baseURL! : fallbackBaseURL
        if base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: "\(base)/chat/completions") else {
            throw AIError.systemError("Ungültige URL: \(base)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": request.model,
            "messages": [
                ["role": "system", "content": request.systemPrompt ?? "Du bist ein professioneller Buchautor und Lektor."],
                ["role": "user", "content": request.prompt]
            ],
            "max_tokens": request.maxTokens ?? 4000,
            "temperature": request.temperature
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await perform(urlRequest)

        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let choice = result.choices.first else {
                throw AIError.systemError("Leere Antwort vom Provider")
            }
            return GenerationResponse(
                text: choice.message.content,
                tokensUsed: result.usage?.total_tokens,
                finishReason: choice.finish_reason
            )
        case 400:
            let message = decodeErrorMessage(from: data) ?? "HTTP 400"
            if message.lowercased().contains("context") || message.lowercased().contains("length") {
                throw AIError.contextTooLong
            }
            throw AIError.systemError(message)
        case 401, 403:
            throw AIError.apiKeyInvalid
        case 402:
            throw AIError.quotaExceeded
        case 404:
            throw AIError.modelUnavailable
        case 429:
            throw AIError.rateLimitExceeded
        case 500...599:
            throw AIError.providerUnavailable
        default:
            throw AIError.systemError("HTTP \(httpResponse.statusCode): \(decodeErrorMessage(from: data) ?? "")")
        }
    }

    // MARK: - Anthropic Claude (Messages API)

    private func executeAnthropicRequest(request: GenerationRequest,
                                         configuration: ProviderConfiguration) async throws -> GenerationResponse {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw AIError.apiKeyInvalid
        }

        var base = (configuration.baseURL?.isEmpty == false) ? configuration.baseURL! : "https://api.anthropic.com"
        if base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: "\(base)/v1/messages") else {
            throw AIError.systemError("Ungültige URL: \(base)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Hinweis: bewusst ohne temperature – neuere Claude-Modelle (Opus 4.7+)
        // lehnen Sampling-Parameter mit HTTP 400 ab.
        let body: [String: Any] = [
            "model": request.model,
            "max_tokens": request.maxTokens ?? 4096,
            "system": request.systemPrompt ?? "Du bist ein professioneller Buchautor und Lektor.",
            "messages": [
                ["role": "user", "content": request.prompt]
            ]
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, httpResponse) = try await perform(urlRequest)

        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            let text = result.content.first(where: { $0.type == "text" })?.text ?? ""
            let tokens = (result.usage?.input_tokens ?? 0) + (result.usage?.output_tokens ?? 0)
            return GenerationResponse(
                text: text,
                tokensUsed: tokens > 0 ? tokens : nil,
                finishReason: result.stop_reason
            )
        case 400:
            let message = decodeErrorMessage(from: data) ?? "HTTP 400"
            if message.lowercased().contains("context") || message.lowercased().contains("token") {
                throw AIError.contextTooLong
            }
            throw AIError.systemError(message)
        case 401, 403:
            throw AIError.apiKeyInvalid
        case 404:
            throw AIError.modelUnavailable
        case 413:
            throw AIError.contextTooLong
        case 429:
            throw AIError.rateLimitExceeded
        case 500...599:
            throw AIError.providerUnavailable
        default:
            throw AIError.systemError("HTTP \(httpResponse.statusCode): \(decodeErrorMessage(from: data) ?? "")")
        }
    }

    // MARK: - Ollama

    private func executeOllamaRequest(request: GenerationRequest,
                                      configuration: ProviderConfiguration) async throws -> GenerationResponse {
        var base = (configuration.baseURL?.isEmpty == false) ? configuration.baseURL! : "http://localhost:11434"
        if base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: "\(base)/api/generate") else {
            throw AIError.systemError("Ungültige URL: \(base)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        var options: [String: Any] = ["temperature": request.temperature]
        if let maxTokens = request.maxTokens {
            options["num_predict"] = maxTokens
        }
        let body: [String: Any] = [
            "model": request.model,
            "prompt": request.prompt,
            "system": request.systemPrompt ?? "",
            "stream": false,
            "options": options
        ]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, httpResponse) = try await perform(urlRequest)

            switch httpResponse.statusCode {
            case 200:
                let result = try JSONDecoder().decode(OllamaResponse.self, from: data)
                return GenerationResponse(
                    text: result.response,
                    tokensUsed: result.eval_count,
                    finishReason: result.done ? "stop" : nil
                )
            case 404:
                throw AIError.modelUnavailable
            default:
                throw AIError.systemError("Ollama HTTP \(httpResponse.statusCode)")
            }
        } catch let error as AIError {
            if error == .networkError || error == .providerUnavailable {
                throw AIError.ollamaNotRunning
            }
            throw error
        }
    }

    // MARK: - Helpers

    private func perform(_ urlRequest: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await urlSession.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                throw AIError.networkError
            }
            return (data, http)
        } catch let error as AIError {
            throw error
        } catch let error as URLError {
            switch error.code {
            case .cancelled:
                throw CancellationError()
            case .cannotConnectToHost, .cannotFindHost, .badURL:
                throw AIError.providerUnavailable
            default:
                throw AIError.networkError
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AIError.networkError
        }
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        if let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
            return envelope.error?.message
        }
        return String(data: data, encoding: .utf8).map { String($0.prefix(300)) }
    }
}

// MARK: - Response Models

struct OpenAIResponse: Codable {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

struct OpenAIChoice: Codable {
    let message: OpenAIMessage
    let finish_reason: String?
}

struct OpenAIMessage: Codable {
    let content: String
}

struct OpenAIUsage: Codable {
    let total_tokens: Int
}

struct AnthropicResponse: Codable {
    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
    struct Usage: Codable {
        let input_tokens: Int?
        let output_tokens: Int?
    }
    let content: [ContentBlock]
    let usage: Usage?
    let stop_reason: String?
}

struct OllamaResponse: Codable {
    let response: String
    let done: Bool
    let eval_count: Int?
}

struct APIErrorEnvelope: Codable {
    struct Inner: Codable {
        let message: String?
        let type: String?
    }
    let error: Inner?
}
