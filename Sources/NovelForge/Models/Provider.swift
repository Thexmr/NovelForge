import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic Claude"
    case ollamaLocal = "Ollama lokal"
    case ollamaCloud = "Ollama Cloud"
    case kimi = "Kimi/K2 Cloud"
    case custom = "Benutzerdefiniert"

    var id: String { rawValue }

    var supportsLocalExecution: Bool {
        self == .ollamaLocal
    }

    var requiresAPIKey: Bool {
        self != .ollamaLocal
    }

    /// Sinnvolle Standardmodelle pro Provider für die Modellauswahl in der UI.
    var suggestedModels: [String] {
        switch self {
        case .openAI:
            return ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo"]
        case .anthropic:
            return ["claude-opus-4-8", "claude-sonnet-4-6", "claude-haiku-4-5"]
        case .ollamaLocal:
            return ["llama3.1", "qwen2.5", "mistral-nemo"]
        case .ollamaCloud:
            return OllamaCloudModelCatalog.fallbackModels
        case .kimi:
            return ["kimi-k2-0711-preview", "moonshot-v1-128k", "moonshot-v1-32k"]
        case .custom:
            return []
        }
    }

    var defaultBaseURL: String? {
        switch self {
        case .openAI:
            return "https://api.openai.com/v1"
        case .anthropic:
            return "https://api.anthropic.com"
        case .ollamaLocal:
            return "http://localhost:11434"
        case .ollamaCloud:
            return "https://ollama.com"
        case .kimi:
            return "https://api.moonshot.ai/v1"
        case .custom:
            return nil
        }
    }

    var needsBaseURLInput: Bool {
        self == .custom
    }
}

/// Konfiguration eines Providers. Der API-Key wird bewusst NICHT mitkodiert
/// (CodingKeys ohne apiKey) – er liegt ausschließlich in der macOS Keychain
/// und wird zur Laufzeit nachgeladen.
struct ProviderConfiguration: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var provider: AIProvider
    var apiKey: String? = nil
    var baseURL: String?
    var isActive: Bool
    var defaultModel: String?
    var costLimit: Double?

    enum CodingKeys: String, CodingKey {
        case id, provider, baseURL, isActive, defaultModel, costLimit
    }

    init(provider: AIProvider) {
        self.id = UUID()
        self.provider = provider
        self.isActive = false
        self.defaultModel = provider.suggestedModels.first
        self.baseURL = provider.defaultBaseURL
        self.costLimit = nil
    }
}

struct GenerationRequest: Sendable {
    let prompt: String
    let systemPrompt: String?
    let model: String
    let provider: AIProvider
    let maxTokens: Int?
    let temperature: Double
}

struct GenerationResponse: Sendable {
    let text: String
    let tokensUsed: Int?
    let finishReason: String?
}

/// Grobe Mischpreise (Ein-/Ausgabe kombiniert) pro 1.000 Tokens in USD.
/// Dient nur der Kostenschätzung und -begrenzung, nicht der Abrechnung.
enum ModelPricing {
    static let blendedPer1K: [String: Double] = [
        "claude-opus-4-8": 0.015,
        "claude-sonnet-4-6": 0.009,
        "claude-haiku-4-5": 0.003,
        "gpt-4o-mini": 0.0003,
        "gpt-4o": 0.0075,
        "gpt-4-turbo": 0.02,
        "moonshot-v1": 0.003,
        "kimi": 0.003
    ]

    static func ratePer1K(model: String) -> Double {
        let lowered = model.lowercased()
        // Längste passende Präfixe zuerst, damit z.B. gpt-4o-mini nicht als gpt-4o zählt.
        let sorted = blendedPer1K.sorted { $0.key.count > $1.key.count }
        for (prefix, rate) in sorted where lowered.hasPrefix(prefix) {
            return rate
        }
        return 0
    }

    static func estimatedCost(model: String, tokens: Int) -> Double {
        Double(tokens) / 1000.0 * ratePer1K(model: model)
    }
}

enum AIError: Error, LocalizedError, Equatable {
    case apiKeyInvalid
    case providerUnavailable
    case modelUnavailable
    case networkError
    case rateLimitExceeded
    case quotaExceeded
    case costLimitReached
    case ollamaNotRunning
    case fileTooLarge
    case contextTooLong
    case baseURLMissing
    case systemError(String)
    case unknown

    static func == (lhs: AIError, rhs: AIError) -> Bool {
        switch (lhs, rhs) {
        case (.apiKeyInvalid, .apiKeyInvalid),
             (.providerUnavailable, .providerUnavailable),
             (.modelUnavailable, .modelUnavailable),
             (.networkError, .networkError),
             (.rateLimitExceeded, .rateLimitExceeded),
             (.quotaExceeded, .quotaExceeded),
             (.costLimitReached, .costLimitReached),
             (.ollamaNotRunning, .ollamaNotRunning),
             (.fileTooLarge, .fileTooLarge),
             (.contextTooLong, .contextTooLong),
             (.baseURLMissing, .baseURLMissing),
             (.unknown, .unknown):
            return true
        case (.systemError(let lhsMsg), .systemError(let rhsMsg)):
            return lhsMsg == rhsMsg
        default:
            return false
        }
    }

    var errorDescription: String? {
        switch self {
        case .apiKeyInvalid:
            return "API-Key ungültig, fehlt oder abgelaufen"
        case .providerUnavailable:
            return "Provider nicht erreichbar"
        case .modelUnavailable:
            return "Modell nicht verfügbar"
        case .networkError:
            return "Netzwerkfehler – keine Verbindung zum Provider"
        case .rateLimitExceeded:
            return "Rate Limit erreicht – zu viele Anfragen"
        case .quotaExceeded:
            return "Kontingent des Providers erschöpft"
        case .costLimitReached:
            return "Kostenlimit für dieses Buch erreicht"
        case .ollamaNotRunning:
            return "Ollama-Server läuft nicht"
        case .fileTooLarge:
            return "Datei zu groß"
        case .contextTooLong:
            return "Eingabe überschreitet das Kontextfenster des Modells"
        case .baseURLMissing:
            return "Basis-URL fehlt für diesen Provider"
        case .systemError(let msg):
            return "Fehler: \(msg)"
        case .unknown:
            return "Unbekannter Fehler"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .apiKeyInvalid:
            return "Prüfen Sie den gespeicherten API-Key in den Provider-Einstellungen oder führen Sie einen Verbindungstest durch."
        case .providerUnavailable:
            return "Prüfen Sie Ihre Internetverbindung oder versuchen Sie es später erneut."
        case .modelUnavailable:
            return "Wählen Sie ein anderes Modell oder prüfen Sie die Modellverfügbarkeit beim Provider."
        case .networkError:
            return "Stellen Sie sicher, dass eine Internetverbindung besteht."
        case .rateLimitExceeded:
            return "Warten Sie einen Moment – die Pipeline versucht es automatisch erneut."
        case .quotaExceeded:
            return "Prüfen Sie Ihr Guthaben bzw. Abo beim Provider."
        case .costLimitReached:
            return "Erhöhen Sie das Kostenlimit des Projekts oder setzen Sie die Produktion mit einem günstigeren Modell fort."
        case .ollamaNotRunning:
            return "Starten Sie den Ollama-Server (ollama serve) und stellen Sie sicher, dass das Modell installiert ist."
        case .fileTooLarge:
            return "Reduzieren Sie die Dateigröße oder teilen Sie den Inhalt auf."
        case .contextTooLong:
            return "Wählen Sie ein Modell mit größerem Kontextfenster."
        case .baseURLMissing:
            return "Hinterlegen Sie die Basis-URL des Providers in den Einstellungen."
        case .systemError:
            return "Versuchen Sie es erneut. Bleibt der Fehler bestehen, starten Sie die App neu."
        case .unknown:
            return "Versuchen Sie die Aktion erneut."
        }
    }
}
