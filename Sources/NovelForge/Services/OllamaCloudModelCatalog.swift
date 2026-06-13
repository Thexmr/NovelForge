import Foundation

enum OllamaCloudModelCatalog {
    /// Echte, auf ollama.com verfügbare Cloud-Modelle (bare Namen – die Direkt-API
    /// akzeptiert sie ohne ":cloud"-Suffix). kimi-k2.6 steht bewusst zuerst:
    /// es liefert die beste deutschsprachige Langform-Prosa und ist Default.
    static let fallbackModels = [
        "kimi-k2.6",
        "kimi-k2.5",
        "deepseek-v4-pro",
        "deepseek-v4-flash",
        "glm-5.1",
        "glm-5",
        "minimax-m2.5",
        "qwen3.5"
    ]

    static let defaultModel = "kimi-k2.6"

    static func decodeModelNames(from data: Data) throws -> [String] {
        let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return response.models
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Führt die kuratierten Fallbacks mit den LIVE vom Server gemeldeten Modellen
    /// zusammen. Wichtig: Live-Modelle werden NICHT gegen eine starre Whitelist
    /// gefiltert – nur offensichtlich ungeeignete (Embedding, Vision, Coder, Reranker)
    /// werden ausgeschlossen. So erreicht der Nutzer jedes echte Schreib-Modell,
    /// das sein Konto anbietet.
    static func mergeWithFallbacks(_ liveModels: [String]) -> [String] {
        let cleanedLive = liveModels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter(isUsefulForLongFormCloudModel)
        return stableUnique(fallbackModels + cleanedLive)
    }

    /// Liefert ein verwendbares Modell: das gewünschte, falls es für Langform taugt,
    /// sonst den Default (kimi-k2.6). Ein bereits gültiges Modell wird NIE verworfen.
    static func bestModel(preferred: String?) -> String {
        let preferred = preferred?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if isUsefulForLongFormCloudModel(preferred) {
            return preferred
        }
        return fallbackModels.first ?? defaultModel
    }

    /// Denylist statt Allowlist: alles außer Embedding-/Vision-/Coder-/Reranker-/
    /// Audio-Modellen ist für Romanproduktion grundsätzlich brauchbar.
    static func isUsefulForLongFormCloudModel(_ model: String) -> Bool {
        let lowered = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lowered.isEmpty else { return false }
        let unsuitableMarkers = [
            "embed", "rerank", "guard", "moderation",
            "whisper", "-tts", "-stt", "audio",
            "-vl", "vision", "ocr", "coder", "code-",
            "nomic"
        ]
        return !unsuitableMarkers.contains { lowered.contains($0) }
    }

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
