import AppKit
import Foundation

struct CoverImageSettings: Codable, Equatable, Sendable {
    static let defaultBaseURL = "https://api.openai.com/v1"
    static let defaultModel = "gpt-image-2"
    static let modelOptions = ["gpt-image-2", "gpt-image-1", "dall-e-3"]
    static let sizeOptions = ["1024x1536", "1024x1024", "1536x1024"]
    static let qualityOptions = ["high", "medium", "low"]

    var apiKey: String? = nil
    var baseURL: String = Self.defaultBaseURL
    var model: String = Self.defaultModel
    var size: String = "1024x1536"
    var quality: String = "high"

    enum CodingKeys: String, CodingKey {
        case baseURL, model, size, quality
    }

    var normalizedBaseURL: String {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { trimmed = Self.defaultBaseURL }
        if trimmed.hasSuffix("/") { trimmed.removeLast() }
        return trimmed
    }

    var apiQualityValue: String {
        if model.lowercased().contains("dall-e") {
            return quality == "high" ? "hd" : "standard"
        }
        return quality
    }
}

@MainActor
final class CoverImageSettingsStore: ObservableObject {
    static let shared = CoverImageSettingsStore()

    @Published var settings = CoverImageSettings()

    private static let storageKey = "novelforge.coverImageSettings.v1"

    init() {
        load()
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode(CoverImageSettings.self, from: data) {
            settings = normalized(decoded)
        } else {
            settings = CoverImageSettings()
        }
    }

    func save() {
        settings = normalized(settings)
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func saveAPIKey(_ apiKey: String) {
        KeychainService.saveAPIKey(apiKey, for: .openAI)
    }

    func apiKey() -> String? {
        KeychainService.getAPIKey(for: .openAI)
    }

    func hasAPIKey() -> Bool {
        KeychainService.hasStoredAPIKey(for: .openAI)
    }

    func runtimeSettings() -> CoverImageSettings {
        var runtime = normalized(settings)
        runtime.apiKey = apiKey()
        return runtime
    }

    private func normalized(_ value: CoverImageSettings) -> CoverImageSettings {
        var normalized = value
        if normalized.baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.baseURL = CoverImageSettings.defaultBaseURL
        }
        if normalized.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.model = CoverImageSettings.defaultModel
        }
        if normalized.size.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.size = "1024x1536"
        }
        if normalized.quality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            normalized.quality = "high"
        }
        normalized.apiKey = nil
        return normalized
    }
}

enum CoverDesignService {
    static let coverImageFileName = "Cover.png"
    static let coverPromptFileName = "Cover-Prompt.txt"

    static func visibleCoverText(for project: Project) -> String {
        """
        \(project.title)
        \(project.authorName)
        """
    }

    static func buildPrompt(for project: Project) -> String {
        let profile = project.bookProfile
        let chapterContext = chapterBrief(for: project)
        let visualMood = visualMoodLine(project: project)
        let kdpDescription = clean(profile?.kdpDescription)
        let synopsis = clean(profile?.synopsis)
        let logline = clean(profile?.logline)
        let premise = clean(profile?.premise)
        let theme = clean(profile?.theme)
        let tonality = clean(profile?.tonality)
        let audience = clean(profile?.targetAudience)

        return """
        Create premium front-cover ARTWORK (illustration only, no text) for a polished commercial Amazon KDP bestseller book cover.

        BOOK IDENTITY
        Title: \(project.title)
        Author: \(project.authorName)
        Genre: \(project.genre)\(project.subgenre.map { " / \($0)" } ?? "")
        Language: \(project.language)
        Style profile: \(project.styleProfile)
        Target length: \(project.targetPageCount) pages

        STORY SIGNALS
        Logline: \(logline)
        Premise: \(premise)
        Theme: \(theme)
        Tone: \(tonality)
        Audience: \(audience)
        KDP description: \(kdpDescription)
        Synopsis: \(synopsis)
        Chapter context: \(chapterContext)

        COVER DIRECTION
        Format: portrait 2:3 front cover, suitable for Amazon KDP thumbnail and full-size preview.
        Visual mood: \(visualMood)
        Design level: high-end publishing house, cinematic but not generic stock art, strong focal point, readable hierarchy, professional typography, clean negative space.
        Typography: render NO text, NO lettering, NO title, NO author name, NO words or numbers anywhere in the image. Title and author are added afterwards as a separate, razor-sharp typographic overlay, so the artwork itself must contain absolutely no letters.
        Composition for overlay: leave clean, low-detail negative space in the upper third (where the title will sit) and the lower quarter (for the author name); keep the central focal subject between them, with calm low-contrast areas behind the future text so overlaid type stays perfectly legible.
        Disclosure rule: keine KI-Hinweise, no "AI generated" labels, no process notes, no production badges.
        Avoid: any text/typography/letters, weak job-title cliches, random profession imagery unless central to the story, cheap AI-glow, overbusy collage, malformed faces/hands, watermarks, logos, mockup frames, badges, and any AI disclosure text.
        Important: The cover must feel specifically designed for this book, not like a generic genre template; prioritize the central conflict, symbolic object, emotional wound, and market promise.
        """
    }

    static func promptURL(for project: Project) throws -> URL {
        try ExportEngine.exportDirectory(for: project).appendingPathComponent(coverPromptFileName)
    }

    static func imageURL(for project: Project) throws -> URL {
        try ExportEngine.exportDirectory(for: project).appendingPathComponent(coverImageFileName)
    }

    @discardableResult
    static func writePrompt(_ prompt: String, for project: Project) throws -> URL {
        let url = try promptURL(for: project)
        try prompt.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func existingPrompt(for project: Project) -> String? {
        guard let url = try? promptURL(for: project) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func existingImageURL(for project: Project) -> URL? {
        guard let url = try? imageURL(for: project),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    private static func chapterBrief(for project: Project) -> String {
        let chapters = (project.chapters ?? [])
            .sorted { $0.chapterNumber < $1.chapterNumber }
            .prefix(5)
        let lines = chapters.map { chapter in
            let summary = clean(chapter.summary)
            let goal = clean(chapter.goal)
            let conflict = clean(chapter.conflict)
            return "Chapter \(chapter.chapterNumber) - \(chapter.title): \(summary.isEmpty ? goal : summary) Conflict: \(conflict)"
        }
        return lines.isEmpty ? "No chapter summaries yet; infer from concept and KDP description." : lines.joined(separator: " | ")
    }

    private static func visualMoodLine(project: Project) -> String {
        let genre = project.genre.lowercased()
        if genre.contains("thriller") || genre.contains("krimi") {
            return "controlled tension, sharp contrast, a single unsettling clue, danger implied rather than explained"
        }
        if genre.contains("romance") || genre.contains("liebes") {
            return "emotional intimacy, longing, elegant warmth, relationship tension without kitsch"
        }
        if genre.contains("fantasy") || genre.contains("romantasy") {
            return "mythic atmosphere, symbolic magic, tactile world detail, epic scale with one memorable icon"
        }
        if genre.contains("histor") {
            return "period texture, restrained drama, tactile materials, historically grounded atmosphere"
        }
        if genre.contains("horror") {
            return "quiet dread, negative space, unsettling texture, one disturbing symbolic focal point"
        }
        if genre.contains("science") || genre.contains("sci-fi") {
            return "speculative precision, luminous technology, human stakes, cinematic depth"
        }
        return "marketable literary atmosphere, a strong symbol, clear emotional promise, premium editorial restraint"
    }

    private static func clean(_ value: String?) -> String {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not specified" : trimmed.truncated(to: 900)
    }
}

actor CoverImageGateway {
    static let shared = CoverImageGateway()

    private let urlSession: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 900
        self.urlSession = URLSession(configuration: config)
    }

    func generateImage(prompt: String, destination: URL, settings: CoverImageSettings) async throws -> URL {
        guard let apiKey = settings.apiKey, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.apiKeyInvalid
        }
        guard let url = URL(string: "\(settings.normalizedBaseURL)/images/generations") else {
            throw AIError.systemError("Ungültige Bild-API-URL: \(settings.normalizedBaseURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "model": settings.model,
            "prompt": prompt,
            "size": settings.size,
            "quality": settings.apiQualityValue,
            "n": 1
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await perform(request)
        switch response.statusCode {
        case 200:
            let imageData = try await decodeImageData(from: data)
            try imageData.write(to: destination, options: .atomic)
            return destination
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
            throw AIError.systemError("Bild-API HTTP \(response.statusCode): \(decodeErrorMessage(from: data) ?? "")")
        }
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AIError.networkError }
            return (data, http)
        } catch let error as AIError {
            throw error
        } catch let error as URLError {
            if error.code == .cancelled { throw CancellationError() }
            throw AIError.networkError
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AIError.networkError
        }
    }

    private func decodeImageData(from data: Data) async throws -> Data {
        let response = try JSONDecoder().decode(ImageGenerationResponse.self, from: data)
        guard let first = response.data.first else {
            throw AIError.systemError("Bild-API lieferte keine Bilddaten")
        }
        if let base64 = first.b64_json, let decoded = Data(base64Encoded: base64) {
            return decoded
        }
        if let urlString = first.url, let url = URL(string: urlString) {
            let (remoteData, remoteResponse) = try await urlSession.data(from: url)
            guard let http = remoteResponse as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw AIError.networkError
            }
            return remoteData
        }
        throw AIError.systemError("Bild-API lieferte weder Base64 noch URL")
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        if let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data) {
            return envelope.error?.message
        }
        return String(data: data, encoding: .utf8).map { String($0.prefix(300)) }
    }
}

private struct ImageGenerationResponse: Codable {
    struct ImageData: Codable {
        let b64_json: String?
        let url: String?
        let revised_prompt: String?
    }
    let data: [ImageData]
}
