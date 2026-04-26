import Foundation

enum AIProvider: String, Codable, CaseIterable, Identifiable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic Claude"
    case ollamaLocal = "Ollama lokal"
    case ollamaCloud = "Ollama Cloud"
    case kimi = "Kimi/K2 Cloud"
    case custom = "Benutzerdefiniert"
    
    var id: String { rawValue }
    
    var supportsLocalExecution: Bool {
        switch self {
        case .ollamaLocal:
            return true
        default:
            return false
        }
    }
    
    var requiresAPIKey: Bool {
        switch self {
        case .ollamaLocal:
            return false
        default:
            return true
        }
    }
}

struct ProviderConfiguration: Codable, Identifiable {
    var id: UUID
    var provider: AIProvider
    var apiKey: String?
    var baseURL: String?
    var isActive: Bool
    var defaultModel: String?
    var fallbackModel: String?
    var costLimit: Double?
    var priority: Int
    
    init(provider: AIProvider) {
        self.id = UUID()
        self.provider = provider
        self.isActive = false
        self.priority = 0
    }
}

struct AIModel: Codable, Identifiable {
    var id: String { name }
    var name: String
    var provider: AIProvider
    var contextLength: Int
    var capabilities: [ModelCapability]
    var costPer1KTokens: Double?
    var isLocal: Bool
    var isFavorite: Bool
}

enum ModelCapability: String, Codable {
    case text = "Text"
    case code = "Code"
    case image = "Bild"
    case file = "Datei"
    case tools = "Tools"
    case longContext = "Langer Kontext"
}

struct GenerationRequest {
    let prompt: String
    let systemPrompt: String?
    let model: String
    let provider: AIProvider
    let maxTokens: Int?
    let temperature: Double
    let stream: Bool
}

struct GenerationResponse {
    let text: String
    let tokensUsed: Int?
    let finishReason: String?
    let error: AIError?
}

enum AIError: Error, LocalizedError, Equatable {
    case apiKeyInvalid
    case providerUnavailable
    case modelUnavailable
    case networkError
    case rateLimitExceeded
    case quotaExceeded
    case ollamaNotRunning
    case fileTooLarge
    case contextTooLong
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
             (.ollamaNotRunning, .ollamaNotRunning),
             (.fileTooLarge, .fileTooLarge),
             (.contextTooLong, .contextTooLong),
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
            return "API-Key ungültig oder abgelaufen"
        case .providerUnavailable:
            return "Provider nicht erreichbar"
        case .modelUnavailable:
            return "Modell nicht verfügbar"
        case .networkError:
            return "Netzwerkfehler - keine Internetverbindung"
        case .rateLimitExceeded:
            return "Rate Limit erreicht - zu viele Anfragen"
        case .quotaExceeded:
            return "Kostenlimit überschritten"
        case .ollamaNotRunning:
            return "Ollama-Server läuft nicht"
        case .fileTooLarge:
            return "Datei zu groß"
        case .contextTooLong:
            return "Eingabe überschreitet Kontextfenster"
        case .systemError(let msg):
            return "Systemfehler: \(msg)"
        case .unknown:
            return "Unbekannter Fehler"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .apiKeyInvalid:
            return "Bitte prüfen Sie den gespeicherten API-Key in den Provider-Einstellungen oder führen Sie einen Verbindungstest durch."
        case .providerUnavailable:
            return "Prüfen Sie Ihre Internetverbindung oder wählen Sie einen anderen Provider als Fallback."
        case .modelUnavailable:
            return "Wählen Sie ein anderes Modell oder prüfen Sie die Modellverfügbarkeit."
        case .networkError:
            return "Stellen Sie sicher, dass eine Internetverbindung besteht."
        case .rateLimitExceeded:
            return "Warten Sie einen Moment und versuchen Sie es erneut, oder reduzieren Sie die Anfragerate."
        case .quotaExceeded:
            return "Erhöhen Sie das Kostenlimit oder wechseln Sie zu einem anderen Provider."
        case .ollamaNotRunning:
            return "Starten Sie den Ollama-Server und stellen Sie sicher, dass das Modell installiert ist."
        case .fileTooLarge:
            return "Reduzieren Sie die Dateigröße oder teilen Sie den Inhalt auf."
        case .contextTooLong:
            return "Kürzen Sie die Eingabe oder wählen Sie ein Modell mit größerem Kontextfenster."
        case .systemError:
            return "Starten Sie die App neu oder kontaktieren Sie den Support."
        case .unknown:
            return "Versuchen Sie die Aktion erneut."
        }
    }
}