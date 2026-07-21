import Foundation

enum OllamaCloudModelCatalog {
    /// Offline-Fallback für aktuelle Ollama-Cloud-Modelle, die als allgemeine
    /// Textmodelle für Langform taugen. Die Live-Liste des Kontos hat in der UI
    /// Vorrang. Coding-only-, Embedding- und kurz vor Abschaltung stehende Modelle
    /// werden bewusst nicht angeboten.
    static let fallbackModels = [
        "kimi-k2.6",
        "mistral-large-3:675b",
        "deepseek-v4-pro",
        "qwen3.5:397b",
        "gemma4:31b",
        "glm-5.2",
        "deepseek-v4-flash",
        "glm-5.1",
        "kimi-k2.5",
        "nemotron-3-super",
        "nemotron-3-ultra",
    ]

    // kimi-k2.6: beste deutsche Prosa UND ~2× schneller als k2.7-code (im
    // Head-to-Head gemessen) – ideal für die Dauerproduktion. minimax-m2.5 wurde
    // entfernt, weil es leeren Text liefert (reines Thinking-Modell).
    static let defaultModel = "kimi-k2.6"

    /// Stärkeres „Autoren-Modell" für die eigentliche Prosa (mehr Tiefe/Ton, aber
    /// langsamer als der Default). Wird NUR für die kreativen Schritte (Szenen,
    /// Opening, Cliffhanger, Repair, Konzept, Plot) genutzt; Hilfsschritte
    /// (Zusammenfassungen, Parsing, KDP) bleiben auf dem schnellen Default-Modell.
    static let recommendedWritingModel = "mistral-large-3:675b"

    /// UserDefaults-Schlüssel für ein vom Nutzer gewähltes Autoren-Modell.
    /// Leer ⇒ `recommendedWritingModel`; "__standard__" ⇒ wie Standardmodell.
    static let writingModelDefaultsKey = "novelforge.writingModel"

    static func decodeModelNames(from data: Data) throws -> [String] {
        let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return response.models
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Ordnet die LIVE vom Server gemeldeten Modelle anhand der kuratierten
    /// Qualitätsreihenfolge. Fallbacks werden nur ohne Live-Antwort verwendet.
    /// Live-Modelle werden NICHT gegen eine starre Whitelist gefiltert – nur
    /// offensichtlich ungeeignete (Embedding, Vision, Coder, Reasoning-only,
    /// Audio) werden ausgeschlossen. So erreicht der Nutzer jedes echte, für die
    /// Buchproduktion taugliche Modell, das sein Konto anbietet.
    static func mergeWithFallbacks(_ liveModels: [String]) -> [String] {
        let cleanedLive = liveModels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter(isUsefulForLongFormCloudModel)
        guard !cleanedLive.isEmpty else { return fallbackModels }

        let liveCanonicalNames = Set(cleanedLive.map { canonicalCloudName($0.lowercased()) })
        let prioritizedKnownModels = fallbackModels.filter {
            liveCanonicalNames.contains(canonicalCloudName($0.lowercased()))
        }
        let knownCanonicalNames = Set(fallbackModels.map { canonicalCloudName($0.lowercased()) })
        let newLiveModels = cleanedLive.filter {
            !knownCanonicalNames.contains(canonicalCloudName($0.lowercased()))
        }
        return stableUniqueByCanonicalName(prioritizedKnownModels + newLiveModels)
    }

    /// Liefert ein verwendbares Modell: das gewünschte, falls es für Langform
    /// taugt, sonst den Default. Ein bereits gültiges Modell wird NIE verworfen.
    static func bestModel(preferred: String?) -> String {
        let preferred = preferred?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if isUsefulForLongFormCloudModel(preferred) {
            return preferred
        }
        return fallbackModels.first ?? defaultModel
    }

    /// Denylist statt Allowlist: alles außer Embedding-/Vision-/Coder-/Reasoning-
    /// only-/Audio-Modellen ist für Romanproduktion grundsätzlich brauchbar.
    static func isUsefulForLongFormCloudModel(_ model: String) -> Bool {
        let lowered = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lowered.isEmpty else { return false }
        let canonical = canonicalCloudName(lowered)
        if retiredOrRetiringModels.contains(canonical) { return false }
        // Kuratierte Schreib-Modelle haben Vorrang vor der allgemeinen Denylist.
        if curatedKeys.contains(lowered) { return true }
        let unsuitableMarkers = [
            "embed", "rerank", "guard", "moderation",
            "whisper", "-tts", "-stt", "audio",
            "-vl", "vision", "ocr",
            "coder", "code-", "-code", "devstral",
            "thinking", "gpt-oss", "minimax",
            "nomic", "nano"
        ]
        return !unsuitableMarkers.contains { lowered.contains($0) }
    }

    private static let curatedKeys = Set(fallbackModels.map { $0.lowercased() })

    /// Bereits entfernte oder laut Ollama-Cloud-Plan in den nächsten Tagen
    /// auslaufende Modelle. Live-Tags mit :cloud/-cloud werden kanonisiert.
    private static let retiredOrRetiringModels: Set<String> = [
        "kimi-k2-thinking", "kimi-k2:1t", "minimax-m2", "glm-4.6",
        "qwen3-next:80b", "qwen3-vl:235b", "qwen3-vl:235b-instruct",
        "cogito-2.1:671b", "rnj-1:8b", "deepseek-v3.1:671b",
        "deepseek-v3.2", "devstral-2:123b", "devstral-small-2:24b",
        "ministral-3:14b", "ministral-3:3b", "ministral-3:8b",
        "gemini-3-flash-preview", "gemma3:12b", "gemma3:27b", "gemma3:4b",
        "glm-4.7", "glm-5", "minimax-m2.1", "qwen3-coder-next",
        "qwen3-coder:480b"
    ]

    private static func canonicalCloudName(_ model: String) -> String {
        model
            .replacingOccurrences(of: ":cloud", with: "")
            .replacingOccurrences(of: "-cloud", with: "")
    }

    private static func stableUniqueByCanonicalName(_ models: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for model in models {
            let key = canonicalCloudName(model.lowercased())
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(model)
        }
        return result
    }
}

private struct OllamaTagsResponse: Decodable {
    struct Model: Decodable {
        let name: String
    }

    let models: [Model]
}
