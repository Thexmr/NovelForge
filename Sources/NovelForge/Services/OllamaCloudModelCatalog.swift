import Foundation

enum OllamaCloudModelCatalog {
    static let fallbackModels = [
        "qwen3.5:397b",
        "gpt-oss:120b",
        "minimax-m3",
        "nemotron-3-ultra",
        "deepseek-v3.2",
        "deepseek-v4-pro",
        "deepseek-v4-flash",
        "mistral-large-3:675b",
        "glm-5.1",
        "glm-5"
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
        return fallbackModels.first ?? "qwen3.5:397b"
    }

    static func isUsefulForLongFormCloudModel(_ model: String) -> Bool {
        let lowered = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !lowered.isEmpty else { return false }
        return curatedModelSet.contains(lowered)
    }

    private static var curatedModelSet: Set<String> {
        Set(fallbackModels.map { $0.lowercased() })
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
