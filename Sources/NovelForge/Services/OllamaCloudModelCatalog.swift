import Foundation

enum OllamaCloudModelCatalog {
    static let fallbackModels = [
        "qwen3:235b",
        "qwen3.5:122b",
        "qwen3-vl:235b",
        "deepseek-v3",
        "llama3.3",
        "qwen3:30b",
        "qwen3-coder:30b",
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
        return stableUnique(fallbackModels + cleanedLive)
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
