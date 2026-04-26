import Foundation

@preconcurrency protocol ProviderGatewayProtocol: Sendable {
    func generateText(request: GenerationRequest) async throws -> GenerationResponse
    func listModels(provider: AIProvider) async throws -> [AIModel]
    func testConnection(configuration: ProviderConfiguration) async -> Bool
    func estimateCost(prompt: String, model: AIModel) -> Double?
}

@preconcurrency actor ProviderGateway: ProviderGatewayProtocol {
    static let shared = ProviderGateway()
    
    private var activeProviders: [ProviderConfiguration] = []
    private var urlSession: URLSession
    private var retryCount: Int = 3
    private var retryDelay: UInt64 = 2_000_000_000 // 2 seconds
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        self.urlSession = URLSession(configuration: config)
    }
    
    func setActiveProviders(_ providers: [ProviderConfiguration]) {
        self.activeProviders = providers.filter { $0.isActive }.sorted { $0.priority < $1.priority }
    }
    
    func generateText(request: GenerationRequest) async throws -> GenerationResponse {
        var lastError: AIError?
        
        for provider in activeProviders where provider.provider == request.provider {
            do {
                let response = try await executeWithRetry(request: request, configuration: provider)
                return response
            } catch let error as AIError {
                lastError = error
                if error == .quotaExceeded || error == .apiKeyInvalid {
                    continue // Try next provider
                }
                throw error
            }
        }
        
        if let error = lastError {
            throw error
        }
        
        throw AIError.providerUnavailable
    }
    
    private func executeWithRetry(request: GenerationRequest, configuration: ProviderConfiguration) async throws -> GenerationResponse {
        var attempts = 0
        
        while attempts < retryCount {
            do {
                return try await executeRequest(request: request, configuration: configuration)
            } catch let error as AIError {
                attempts += 1
                if attempts >= retryCount {
                    throw error
                }
                if error == .rateLimitExceeded || error == .networkError {
                    try await Task.sleep(nanoseconds: retryDelay * UInt64(attempts))
                    continue
                }
                throw error
            }
        }
        
        throw AIError.unknown
    }
    
    private func executeRequest(request: GenerationRequest, configuration: ProviderConfiguration) async throws -> GenerationResponse {
        switch configuration.provider {
        case .openAI:
            return try await executeOpenAIRequest(request: request, configuration: configuration)
        case .ollamaLocal, .ollamaCloud:
            return try await executeOllamaRequest(request: request, configuration: configuration)
        case .anthropic:
            return try await executeAnthropicRequest(request: request, configuration: configuration)
        case .kimi:
            return try await executeKimiRequest(request: request, configuration: configuration)
        case .custom:
            return try await executeCustomRequest(request: request, configuration: configuration)
        }
    }
    
    private func executeOpenAIRequest(request: GenerationRequest, configuration: ProviderConfiguration) async throws -> GenerationResponse {
        guard let apiKey = configuration.apiKey, !apiKey.isEmpty else {
            throw AIError.apiKeyInvalid
        }
        
        let baseURL = configuration.baseURL ?? "https://api.openai.com/v1"
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            throw AIError.systemError("Invalid URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": request.model,
            "messages": [
                ["role": "system", "content": request.systemPrompt ?? "Du bist ein professioneller Buchautor und Editor."],
                ["role": "user", "content": request.prompt]
            ],
            "max_tokens": request.maxTokens ?? 4000,
            "temperature": request.temperature,
            "stream": request.stream
        ]
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await urlSession.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError
        }
        
        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            guard let choice = result.choices.first else {
                throw AIError.systemError("No response content")
            }
            return GenerationResponse(
                text: choice.message.content,
                tokensUsed: result.usage?.total_tokens,
                finishReason: choice.finish_reason,
                error: nil
            )
        case 401:
            throw AIError.apiKeyInvalid
        case 429:
            throw AIError.rateLimitExceeded
        case 500...599:
            throw AIError.providerUnavailable
        default:
            throw AIError.systemError("HTTP \(httpResponse.statusCode)")
        }
    }
    
    private func executeOllamaRequest(request: GenerationRequest, configuration: ProviderConfiguration) async throws -> GenerationResponse {
        let baseURL = configuration.baseURL ?? "http://localhost:11434"
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw AIError.systemError("Invalid URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "model": request.model,
            "prompt": request.prompt,
            "system": request.systemPrompt ?? "",
            "stream": false,
            "options": [
                "temperature": request.temperature
            ]
        ]
        
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await urlSession.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AIError.networkError
            }
            
            if httpResponse.statusCode == 404 {
                throw AIError.modelUnavailable
            }
            
            guard httpResponse.statusCode == 200 else {
                throw AIError.systemError("Ollama HTTP \(httpResponse.statusCode)")
            }
            
            let result = try JSONDecoder().decode(OllamaResponse.self, from: data)
            return GenerationResponse(
                text: result.response,
                tokensUsed: result.eval_count,
                finishReason: result.done ? "stop" : nil,
                error: nil
            )
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.ollamaNotRunning
        }
    }
    
    private func executeAnthropicRequest(request: GenerationRequest, configuration: ProviderConfiguration) async throws -> GenerationResponse {
        // Implementierung für Anthropic Claude
        throw AIError.providerUnavailable
    }
    
    private func executeKimiRequest(request: GenerationRequest, configuration: ProviderConfiguration) async throws -> GenerationResponse {
        // Implementierung für Kimi/K2 Cloud
        throw AIError.providerUnavailable
    }
    
    private func executeCustomRequest(request: GenerationRequest, configuration: ProviderConfiguration) async throws -> GenerationResponse {
        // Implementierung für benutzerdefinierte OpenAI-kompatible APIs
        throw AIError.providerUnavailable
    }
    
    func listModels(provider: AIProvider) async throws -> [AIModel] {
        switch provider {
        case .openAI:
            return [
                AIModel(name: "gpt-4o", provider: .openAI, contextLength: 128000, capabilities: [.text, .code, .image, .tools], costPer1KTokens: 0.005, isLocal: false, isFavorite: false),
                AIModel(name: "gpt-4o-mini", provider: .openAI, contextLength: 128000, capabilities: [.text, .code, .image], costPer1KTokens: 0.00015, isLocal: false, isFavorite: false),
                AIModel(name: "gpt-4-turbo", provider: .openAI, contextLength: 128000, capabilities: [.text, .code, .tools, .longContext], costPer1KTokens: 0.01, isLocal: false, isFavorite: false)
            ]
        case .ollamaLocal, .ollamaCloud:
            return [
                AIModel(name: "llama3.1", provider: .ollamaLocal, contextLength: 128000, capabilities: [.text, .code], costPer1KTokens: 0.0, isLocal: true, isFavorite: false),
                AIModel(name: "mistral-nemo", provider: .ollamaLocal, contextLength: 128000, capabilities: [.text, .code], costPer1KTokens: 0.0, isLocal: true, isFavorite: false),
                AIModel(name: "qwen2.5", provider: .ollamaLocal, contextLength: 128000, capabilities: [.text, .code], costPer1KTokens: 0.0, isLocal: true, isFavorite: false)
            ]
        default:
            return []
        }
    }
    
    func testConnection(configuration: ProviderConfiguration) async -> Bool {
        do {
            let request = GenerationRequest(
                prompt: "Test",
                systemPrompt: nil,
                model: configuration.defaultModel ?? "gpt-4o-mini",
                provider: configuration.provider,
                maxTokens: 10,
                temperature: 0.0,
                stream: false
            )
            _ = try await executeRequest(request: request, configuration: configuration)
            return true
        } catch {
            return false
        }
    }
    
    nonisolated func estimateCost(prompt: String, model: AIModel) -> Double? {
        guard let costPer1K = model.costPer1KTokens else { return nil }
        let estimatedTokens = prompt.count / 4 // Grobe Schätzung: 4 Zeichen pro Token
        return Double(estimatedTokens) / 1000.0 * costPer1K
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

struct OllamaResponse: Codable {
    let response: String
    let done: Bool
    let eval_count: Int?
}