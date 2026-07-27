import Foundation

/// Einheitliche Anbindung aller KI-Provider.
/// Die Konfiguration (API-Key, Basis-URL, Modell) wird pro Aufruf übergeben –
/// es gibt keinen versteckten globalen Zustand mehr.
actor ProviderGateway {
    static let shared = ProviderGateway()

    private let urlSession: URLSession
    private let maxRetries = 5
    private var unavailableOllamaCloudModels = Set<String>()
    /// Zwischenspeicher der LIVE bei Ollama vorhandenen Modellnamen, je Basis-URL.
    private var liveOllamaModels: [String: [String]] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        self.urlSession = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Übersetzt einen gewünschten Modellnamen in den Namen, unter dem der Server das
    /// Modell TATSÄCHLICH führt.
    ///
    /// Ollama meldet Cloud-Modelle mit Suffix („kimi-k2.6:cloud"), die kuratierten
    /// Listen der App führen sie ohne. Ein Aufruf mit dem Namen ohne Suffix scheitert
    /// mit „model not found" – und weil in der Ausweichliste ALLE Namen ohne Suffix
    /// stehen, scheiterte die ganze Kette. Auf einem Rechner mit ausschließlich
    /// Cloud-Modellen konnte die App dadurch gar nichts erzeugen.
    private func resolveOllamaModel(_ wanted: String, configuration: ProviderConfiguration) async -> String {
        let wanted = wanted.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wanted.isEmpty else { return wanted }
        let key = configuration.baseURL ?? configuration.provider.defaultBaseURL ?? ""

        var live = liveOllamaModels[key]
        if live == nil {
            live = try? await listOllamaModels(configuration: configuration)
            if let live { liveOllamaModels[key] = live }
        }
        guard let live, !live.isEmpty else { return wanted }

        // 1) Exakter Treffer – nichts zu tun.
        if live.contains(where: { $0.caseInsensitiveCompare(wanted) == .orderedSame }) { return wanted }
        // 2) Gleicher Name, anderes Suffix (kimi-k2.6 ⇄ kimi-k2.6:cloud).
        let gesucht = OllamaCloudModelCatalog.canonicalCloudName(wanted.lowercased())
        if let treffer = live.first(where: {
            OllamaCloudModelCatalog.canonicalCloudName($0.lowercased()) == gesucht
        }) { return treffer }
        // 3) Nichts Passendes: unverändert lassen, damit die bestehende Ausweichlogik greift.
        return wanted
    }

    func generateText(request: GenerationRequest, configuration: ProviderConfiguration) async throws -> GenerationResponse {
        var attempt = 0
        var activeRequest = request
        if request.provider == .ollamaCloud || request.provider == .ollamaLocal {
            let aufgeloest = await resolveOllamaModel(request.model, configuration: configuration)
            if aufgeloest != request.model {
                activeRequest = replacingModel(in: activeRequest, with: aufgeloest)
            }
        }
        if request.provider == .ollamaCloud,
           unavailableOllamaCloudModels.contains(request.model.lowercased()),
           let fallback = nextOllamaCloudModel(configuration: configuration,
                                               excluding: unavailableOllamaCloudModels) {
            activeRequest = replacingModel(in: request, with: fallback)
        }
        while true {
            try Task.checkCancellation()
            do {
                return try await executeRequest(request: activeRequest, configuration: configuration)
            } catch let error as AIError {
                if error == .modelUnavailable, activeRequest.provider == .ollamaCloud {
                    unavailableOllamaCloudModels.insert(activeRequest.model.lowercased())
                    if let fallback = nextOllamaCloudModel(
                        configuration: configuration,
                        excluding: unavailableOllamaCloudModels
                    ) {
                        // Auch den Ersatz auflösen – sonst läuft die Kette in dieselbe
                        // Suffix-Falle wie das ursprüngliche Modell.
                        let aufgeloest = await resolveOllamaModel(fallback, configuration: configuration)
                        activeRequest = replacingModel(in: activeRequest, with: aufgeloest)
                        continue
                    }
                }
                attempt += 1
                let retryable = ProductionStabilityPolicy.isRetryableProviderError(error)
                guard retryable && attempt < maxRetries else { throw error }
                let delay = ProductionStabilityPolicy.providerRetryDelay(
                    attempt: attempt,
                    jitter: Double.random(in: 0.85...1.15)
                )
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func nextOllamaCloudModel(configuration: ProviderConfiguration,
                                      excluding unavailable: Set<String>) -> String? {
        let configured = configuration.defaultModel?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let candidates = [configured] + OllamaCloudModelCatalog.fallbackModels
        return candidates.first { model in
            !model.isEmpty
                && OllamaCloudModelCatalog.isUsefulForLongFormCloudModel(model)
                && !unavailable.contains(model.lowercased())
        }
    }

    private func replacingModel(in request: GenerationRequest, with model: String) -> GenerationRequest {
        GenerationRequest(prompt: request.prompt,
                          systemPrompt: request.systemPrompt,
                          model: model,
                          provider: request.provider,
                          maxTokens: request.maxTokens,
                          temperature: request.temperature)
    }

    func listModels(configuration: ProviderConfiguration) async throws -> [String] {
        switch configuration.provider {
        case .ollamaCloud, .ollamaLocal:
            return try await listOllamaModels(configuration: configuration)
        default:
            return configuration.provider.suggestedModels
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
                text: choice.message.content ?? "",
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
            // Leerer Antworttext (nur Nicht-Text-Blöcke oder max_tokens vor dem ersten
            // Text-Block) NICHT als Erfolg durchreichen – sonst würde leerer Inhalt als
            // fertige Szene/Chat-Antwort gespeichert. Klarer Fehler (wie im Ollama-Pfad).
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw AIError.systemError(
                    "Anthropic lieferte keinen Antworttext (stop_reason: \(result.stop_reason ?? "unbekannt")). "
                    + "Bitte erneut versuchen oder ein anderes Modell wählen."
                )
            }
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
        var base = (configuration.baseURL?.isEmpty == false)
            ? configuration.baseURL!
            : (configuration.provider.defaultBaseURL ?? "http://localhost:11434")
        if base.hasSuffix("/") { base.removeLast() }
        let endpoint = configuration.provider == .ollamaCloud ? "chat" : "generate"
        guard let url = URL(string: "\(base)/api/\(endpoint)") else {
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
        // Thinking deaktivieren: Reasoning-Modelle (Kimi, Qwen, DeepSeek …) verbrauchen
        // sonst das gesamte num_predict-Budget für Denkschritte und liefern ein
        // leeres response-Feld zurück.
        let body: [String: Any]
        if configuration.provider == .ollamaCloud {
            body = [
                "model": request.model,
                "messages": [
                    ["role": "system", "content": request.systemPrompt ?? ""],
                    ["role": "user", "content": request.prompt]
                ],
                "stream": false,
                "think": false,
                "options": options
            ]
        } else {
            body = [
                "model": request.model,
                "prompt": request.prompt,
                "system": request.systemPrompt ?? "",
                "stream": false,
                "think": false,
                "options": options
            ]
        }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, httpResponse) = try await perform(urlRequest)

            switch httpResponse.statusCode {
            case 200:
                let result = try decodeOllamaGenerationResponse(data, provider: configuration.provider)
                if result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let thinking = result.thinking, !thinking.isEmpty {
                    // Modell hat trotz think:false das gesamte Token-Budget für
                    // Denkschritte verbraucht – klarer Fehler statt leerem Text.
                    throw AIError.systemError(
                        "Modell \(request.model) lieferte nur Denkschritte und keinen Antworttext. "
                        + "Bitte ein Modell ohne Thinking-Modus wählen."
                    )
                }
                return GenerationResponse(
                    text: result.text,
                    tokensUsed: result.eval_count,
                    finishReason: result.finishReason
                )
            case 401, 403:
                throw AIError.apiKeyInvalid
            case 404:
                throw AIError.modelUnavailable
            case 429:
                throw AIError.rateLimitExceeded
            case 500...599:
                throw AIError.providerUnavailable
            default:
                throw AIError.systemError("Ollama HTTP \(httpResponse.statusCode): \(decodeErrorMessage(from: data) ?? "")")
            }
        } catch let error as AIError {
            if error == .networkError || error == .providerUnavailable {
                if configuration.provider == .ollamaCloud {
                    throw AIError.providerUnavailable
                }
                throw AIError.ollamaNotRunning
            }
            throw error
        }
    }

    private func decodeOllamaGenerationResponse(_ data: Data, provider: AIProvider) throws -> NormalizedOllamaResponse {
        if provider == .ollamaCloud {
            let result = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
            return NormalizedOllamaResponse(
                text: result.message.content,
                done: result.done,
                doneReason: result.done_reason,
                eval_count: result.eval_count,
                thinking: result.message.thinking
            )
        }
        let result = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return NormalizedOllamaResponse(
            text: result.response,
            done: result.done,
            doneReason: result.done_reason,
            eval_count: result.eval_count,
            thinking: result.thinking
        )
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

    private func listOllamaModels(configuration: ProviderConfiguration) async throws -> [String] {
        if configuration.provider.requiresAPIKey {
            guard configuration.apiKey?.isEmpty == false else { throw AIError.apiKeyInvalid }
        }

        var base = (configuration.baseURL?.isEmpty == false)
            ? configuration.baseURL!
            : (configuration.provider.defaultBaseURL ?? "http://localhost:11434")
        if base.hasSuffix("/") { base.removeLast() }
        guard let url = URL(string: "\(base)/api/tags") else {
            throw AIError.systemError("Ungültige URL: \(base)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        if let apiKey = configuration.apiKey, !apiKey.isEmpty {
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let (data, httpResponse) = try await perform(urlRequest)
        switch httpResponse.statusCode {
        case 200:
            let names = try OllamaCloudModelCatalog.decodeModelNames(from: data)
            if configuration.provider == .ollamaCloud {
                return OllamaCloudModelCatalog.mergeWithFallbacks(names)
            }
            return names
        case 401, 403:
            throw AIError.apiKeyInvalid
        case 429:
            throw AIError.rateLimitExceeded
        case 500...599:
            throw AIError.providerUnavailable
        default:
            throw AIError.systemError("HTTP \(httpResponse.statusCode): \(decodeErrorMessage(from: data) ?? "")")
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
    // Optional: einige Provider liefern content: null (Filter-/Refusal-/abgebrochene
    // Antworten). Nicht-optional ließe das JSON-Decoding einer erfolgreichen
    // HTTP-200-Antwort scheitern (roher DecodingError statt nutzbarem Text).
    let content: String?
}

struct OpenAIUsage: Codable {
    // Optional: manche OpenAI-kompatiblen/Custom-Provider liefern ein usage-Objekt
    // ohne total_tokens (nur prompt_/completion_tokens). Nicht-optional würde eine
    // gültige 200-Antwort am Decoding scheitern lassen.
    let total_tokens: Int?
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
    let done_reason: String?
    let eval_count: Int?
    let thinking: String?
}

struct OllamaChatResponse: Codable {
    struct Message: Codable {
        let content: String
        let thinking: String?
    }
    let message: Message
    let done: Bool
    let done_reason: String?
    let eval_count: Int?
}

struct NormalizedOllamaResponse {
    let text: String
    let done: Bool
    let doneReason: String?
    let eval_count: Int?
    let thinking: String?

    var finishReason: String? {
        doneReason ?? (done ? "stop" : nil)
    }
}

struct APIErrorEnvelope: Codable {
    struct Inner: Codable {
        let message: String?
        let type: String?
    }
    let error: Inner?
}
