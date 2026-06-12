import Foundation

enum OllamaCloudModelCatalog {
    static let fallbackModels = [
        "qwen3:235b",
        "qwen3.5:122b",
        "deepseek-v3",
        "llama3.3",
        "kimi-k2.5:cloud",
        "glm-5:cloud"
    ]

    static func decodeModelNames(from data: Data) throws -> [String] {
        let response = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
        return response.models
            .map(\.name)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func mergeWithFallbacks(_ liveModels: [String]) -> [String] {
        let cleanedLive = liveModels
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter(isUsefulForLongFormCloudModel)
        return stableUnique(fallbackModels + cleanedLive)
    }

    static func bestModel(preferred: String?) -> String {
        let preferred = preferred?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if isUsefulForLongFormCloudModel(preferred) {
            return preferred
        }
        return fallbackModels.first ?? "qwen3:235b"
    }

    static func isUsefulForLongFormCloudModel(_ model: String) -> Bool {
        let lowered = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lowered.isEmpty else { return false }
        let excludedFragments = [
            "coder", "code", "vl", "vision", "embed", "embedding", "clip",
            "rerank", "guard", "moderation", "audio", "whisper", "small",
            "mini", "tiny", "3b", "7b", "8b", "14b", "30b", "32b"
        ]
        if excludedFragments.contains(where: { lowered.contains($0) }) {
            return false
        }
        let trustedFamilies = [
            "qwen3:235b", "qwen3.5:122b", "deepseek-v3", "llama3.3",
            "kimi-k2.5", "glm-5", "command-a", "mixtral-8x22b"
        ]
        if trustedFamilies.contains(where: { lowered.hasPrefix($0) }) {
            return true
        }
        return lowered.range(of: #"(^|[^0-9])([7-9][0-9]|[1-9][0-9]{2,})b($|[^0-9])"#,
                             options: .regularExpression) != nil
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
