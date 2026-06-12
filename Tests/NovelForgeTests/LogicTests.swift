import XCTest
@testable import NovelForge

/// Tests für Pipeline-Invarianten und Sicherheitsgarantien.
final class LogicTests: XCTestCase {

    // MARK: - Sicherheit

    /// Regressionsschutz: Der API-Key darf NIEMALS mitserialisiert werden
    /// (er gehört ausschließlich in die Keychain).
    func testProviderConfigurationNeverEncodesAPIKey() throws {
        var config = ProviderConfiguration(provider: .openAI)
        config.apiKey = "sk-streng-geheim-12345"

        let data = try JSONEncoder().encode(config)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("geheim"), "API-Key wurde serialisiert – Sicherheitsverletzung!")
        XCTAssertFalse(json.contains("apiKey"))

        let decoded = try JSONDecoder().decode(ProviderConfiguration.self, from: data)
        XCTAssertNil(decoded.apiKey)
        XCTAssertEqual(decoded.provider, .openAI)
    }

    func testOllamaCloudIsReadyWithoutManualBaseURL() {
        XCTAssertEqual(AIProvider.ollamaCloud.defaultBaseURL, "https://ollama.com")
        XCTAssertFalse(AIProvider.ollamaCloud.needsBaseURLInput)
        XCTAssertEqual(ProviderConfiguration(provider: .ollamaCloud).baseURL, "https://ollama.com")
    }

    func testOllamaCloudDefaultsToBestLongFormModel() {
        XCTAssertEqual(AIProvider.ollamaCloud.suggestedModels.first, "qwen3:235b")
    }

    func testNewProjectsDefaultToOllamaCloud() {
        let project = Project(title: "Test", authorName: "Autor", language: "Deutsch",
                              genre: "Thriller", styleProfile: "düster",
                              targetPageCount: 120, outputFormats: ["EPUB"])

        XCTAssertEqual(project.preferredProviderRaw, AIProvider.ollamaCloud.rawValue)
    }

    func testOllamaCloudModelCatalogDecodesTagsResponse() throws {
        let json = """
        {
          "models": [
            { "name": "llama3.3" },
            { "name": "qwen3:235b" },
            { "name": "" }
          ]
        }
        """.data(using: .utf8)!

        let names = try OllamaCloudModelCatalog.decodeModelNames(from: json)

        XCTAssertEqual(names, ["llama3.3", "qwen3:235b"])
    }

    func testOllamaCloudModelCatalogMergesLiveModelsWithFallbacks() {
        let models = OllamaCloudModelCatalog.mergeWithFallbacks(["custom-cloud:70b", "qwen3:235b"])

        XCTAssertEqual(models.first, "qwen3:235b")
        XCTAssertTrue(models.contains("custom-cloud:70b"))
        XCTAssertEqual(models.filter { $0 == "qwen3:235b" }.count, 1)
    }

    // MARK: - Pipeline-Invarianten

    /// Die Phasen-Gewichte müssen sich exakt zu 1.0 summieren,
    /// sonst stimmt die Fortschrittsanzeige nicht.
    func testPhaseWeightsSumToOne() {
        let total = PipelinePhase.executionOrder.reduce(0.0) { $0 + $1.weight }
        XCTAssertEqual(total, 1.0, accuracy: 0.0001)
    }

    /// Der Projektfortschritt muss über die Statusfolge streng wachsen
    /// und bei „Abgeschlossen“ 1.0 erreichen.
    func testStatusProgressIsMonotonicallyIncreasing() {
        let order: [ProjectStatus] = [
            .created, .conceptDevelopment, .structurePlanning, .chapterPlanning,
            .scenePlanning, .drafting, .chapterRevision, .manuscriptRevision,
            .proofreading, .copyrightCheck, .kdpFormatting, .export, .completed
        ]
        let fractions = order.map { $0.progressFraction }
        for index in 1..<fractions.count {
            XCTAssertGreaterThan(fractions[index], fractions[index - 1],
                                 "Fortschritt fällt zwischen \(order[index - 1]) und \(order[index])")
        }
        XCTAssertEqual(ProjectStatus.completed.progressFraction, 1.0)
    }

    func testEveryStatusHasGermanDisplayName() {
        let all: [ProjectStatus] = [
            .created, .conceptDevelopment, .structurePlanning, .chapterPlanning,
            .scenePlanning, .drafting, .chapterRevision, .manuscriptRevision,
            .proofreading, .copyrightCheck, .kdpFormatting, .export,
            .completed, .failed, .paused
        ]
        for status in all {
            XCTAssertFalse(status.displayName.isEmpty)
        }
    }

    // MARK: - Ideen-Parser

    func testIdeaParser() {
        let text = """
        Hier sind drei Vorschläge:
        IDEE|Die letzte Schleuse|Thriller|Eine Ingenieurin entdeckt Sabotage am Staudamm. Niemand glaubt ihr – bis das Wasser steigt.
        IDEE|Salz und Asche|Historischer Roman|Eine Salzhändlerin im Hanse-Hamburg kämpft gegen ein Kartell. Ihr einziger Verbündeter ist ihr ärgster Konkurrent.
        IDEE|Nachtfenster|Krimi|Ein blinder Zeuge hört einen Mord. Der Täter weiß, dass er gehört wurde.
        """
        let ideas = StructureParser.parseIdeas(text)
        XCTAssertEqual(ideas.count, 3)
        XCTAssertEqual(ideas[0].title, "Die letzte Schleuse")
        XCTAssertEqual(ideas[1].genre, "Historischer Roman")
        XCTAssertTrue(ideas[2].premise.contains("blinder Zeuge"))
    }

    func testIdeaParserIgnoresInvalidLines() {
        XCTAssertTrue(StructureParser.parseIdeas("IDEE|nur ein Feld").isEmpty)
        XCTAssertTrue(StructureParser.parseIdeas("Keine Marker hier").isEmpty)
    }
}
