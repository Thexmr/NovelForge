import Foundation

enum OllamaCloudModelCatalog {
    /// Kuratierte, real existierende Ollama-Cloud-Modelle, die für deutschsprachige
    /// Langform-Romanproduktion verifiziert gut performen (gegen ollama.com direkt
    /// getestet: liefern zuverlässig Fließtext, kein reiner Thinking-Output).
    /// kimi-k2.6 steht bewusst zuerst – beste Prosa und Default.
    /// Reasoning-only-Modelle (gpt-oss, *-thinking) und Code-/Vision-/Embedding-
    /// Modelle sind bewusst ausgeschlossen, weil sie hier leere/ungeeignete
    /// Ergebnisse liefern.
    static let fallbackModels = [
        "kimi-k2.6",
        "kimi-k2.7-code",
        "kimi-k2.5",
        "kimi-k2:1t",
        "deepseek-v4-pro",
        "deepseek-v4-flash",
        "deepseek-v3.2",
        "glm-5.1",
        "glm-5",
        "glm-4.7",
        "qwen3.5:397b",
        "qwen3.5",
        "nemotron-3-ultra",
        "mistral-large-3:675b"
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

    /// Führt die kuratierten Modelle mit den LIVE vom Server gemeldeten zusammen.
    /// Live-Modelle werden NICHT gegen eine starre Whitelist gefiltert – nur
    /// offensichtlich ungeeignete (Embedding, Vision, Coder, Reasoning-only,
    /// Audio) werden ausgeschlossen. So erreicht der Nutzer jedes echte, für die
    /// Buchproduktion taugliche Modell, das sein Konto anbietet.
    static func mergeWithFallbacks(_ liveModels: [String]) -> [String] {
        let cleanedLive = liveModels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter(isUsefulForLongFormCloudModel)
        return stableUnique(fallbackModels + cleanedLive)
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
        // Kuratierte, verifizierte Schreib-Modelle haben Vorrang vor der Denylist –
        // z.B. kimi-k2.7-code, das trotz "-code"-Namen exzellente Prosa liefert.
        if curatedKeys.contains(lowered) { return true }
        let unsuitableMarkers = [
            "embed", "rerank", "guard", "moderation",
            "whisper", "-tts", "-stt", "audio",
            "-vl", "vision", "ocr",
            "coder", "code-", "-code", "devstral",
            "thinking", "gpt-oss", "minimax",
            "nomic"
        ]
        return !unsuitableMarkers.contains { lowered.contains($0) }
    }

    private static let curatedKeys = Set(fallbackModels.map { $0.lowercased() })

    private static func stableUnique(_ models: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for model in models {
            let key = model.lowercased()
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
