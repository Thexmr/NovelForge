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
        XCTAssertEqual(AIProvider.ollamaCloud.suggestedModels.first, "kimi-k2.7-code")
    }

    func testOllamaCloudKeepsCuratedModelDespiteCodeSuffix() {
        // kimi-k2.7-code schreibt verifiziert exzellente Prosa und ist kuratiert –
        // die "-code"-Sperre darf es NICHT verwerfen.
        XCTAssertTrue(OllamaCloudModelCatalog.isUsefulForLongFormCloudModel("kimi-k2.7-code"))
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: "kimi-k2.7-code"), "kimi-k2.7-code")
        // Ein echtes Coder-Modell bleibt ausgeschlossen.
        XCTAssertFalse(OllamaCloudModelCatalog.isUsefulForLongFormCloudModel("qwen3-coder:480b"))
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
            { "name": "kimi-k2.6:cloud" },
            { "name": "deepseek-v4-pro:cloud" },
            { "name": "" }
          ]
        }
        """.data(using: .utf8)!

        let names = try OllamaCloudModelCatalog.decodeModelNames(from: json)

        XCTAssertEqual(names, ["kimi-k2.6:cloud", "deepseek-v4-pro:cloud"])
    }

    func testOllamaCloudModelCatalogKeepsRealLiveModels() {
        // Echte vom Server gemeldete Schreib-Modelle dürfen NICHT herausgefiltert werden.
        let models = OllamaCloudModelCatalog.mergeWithFallbacks(["kimi-k2.6:cloud", "glm-5.1:cloud"])

        XCTAssertEqual(models.first, "kimi-k2.7-code")
        XCTAssertTrue(models.contains("kimi-k2.6:cloud"))
        XCTAssertTrue(models.contains("glm-5.1:cloud"))
    }

    func testOllamaCloudModelCatalogFiltersOnlyUnsuitableModels() {
        let models = OllamaCloudModelCatalog.mergeWithFallbacks([
            "qwen3-coder:30b",
            "qwen3-vl:235b",
            "nomic-embed-text",
            "kimi-k2.6:cloud",
            "minimax-m2.5:cloud"
        ])

        // Schreib-Modelle bleiben erhalten …
        XCTAssertTrue(models.contains("kimi-k2.6:cloud"))
        XCTAssertTrue(models.contains("minimax-m2.5:cloud"))
        // … nur Coder/Vision/Embedding werden entfernt.
        XCTAssertFalse(models.contains("qwen3-coder:30b"))
        XCTAssertFalse(models.contains("qwen3-vl:235b"))
        XCTAssertFalse(models.contains("nomic-embed-text"))
    }

    func testOllamaCloudBestModelKeepsValidPreferredModels() {
        // Ein bereits gültiges Schreib-Modell wird NIE verworfen.
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: "kimi-k2.6"), "kimi-k2.6")
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: "kimi-k2.5:cloud"), "kimi-k2.5:cloud")
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: "deepseek-v4-pro"), "deepseek-v4-pro")
        // Reale, performante Modelle bleiben erhalten (gegen ollama.com verifiziert).
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: "qwen3.5:397b"), "qwen3.5:397b")
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: "mistral-large-3:675b"), "mistral-large-3:675b")
        // Ungeeignete bzw. leere Eingaben fallen auf den Default zurück.
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: "qwen3-vl:235b"), "kimi-k2.7-code")
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: "gpt-oss:120b"), "kimi-k2.7-code")
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: ""), "kimi-k2.7-code")
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: "nomic-embed-text"), "kimi-k2.7-code")
    }

    // MARK: - Szenenplan-Robustheit

    /// Kapitelspezifischer Ersatz-Szenenplan muss die Gates bestehen – sonst
    /// scheitert (wie im 500-Seiten-Lauf) das ganze Buch an einem schwachen Kapitel.
    /// Belegt zugleich, warum die ALTE Auto-Auffüllung sich selbst verwarf.
    func testSceneGateAcceptsChapterSpecificFallbackButRejectsOldFiller() {
        let good = (1...4).map { n in
            PlannedScene(number: n, perspective: "Personaler Erzähler", location: "", time: "",
                goal: "In „Das Haus, das keine Heimat war“ erzwingt die Szene eine Entscheidung, die das Ziel der Figuren gefährdet.",
                obstacle: "Der drohende Abriss blockiert das unmittelbare Vorankommen der Szene.",
                turn: "Eine neue Wendung verschiebt die Lage und wirft eine drängende offene Frage auf.")
        }
        XCTAssertTrue(AutonomousContentQuality.hasUsableScenePlan(good, expectedCount: 4))

        let oldFiller = [PlannedScene(number: 1, perspective: "", location: "", time: "",
            goal: "Vertiefe das Kapitelziel mit einer eigenständigen Wendung: X",
            obstacle: "Der bisherige Konflikt verschärft sich.",
            turn: "Eine neue Information zwingt zur nächsten Entscheidung.")]
        XCTAssertFalse(AutonomousContentQuality.hasUsableScenePlan(oldFiller, expectedCount: 1))
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

    /// Modelle nummerieren Marker oft inline ("IDEE 1|…", "**KAPITEL 2**|…").
    /// Der Parser muss das tolerieren, sonst reißen die Qualitäts-Gates.
    func testParsersTolerateInlineNumbersAndMarkdown() {
        let ideas = StructureParser.parseIdeas("""
        IDEE 1|Die Vermieterin von nebenan|Liebesroman|Ein Architekt flieht vor einem Skandal und mietet heimlich bei seiner Erzfeindin.
        - **IDEE 2**|Salz und Asche|Historisch|Eine Salzhändlerin kämpft gegen ein Kartell.
        """)
        XCTAssertEqual(ideas.count, 2)
        XCTAssertEqual(ideas[0].title, "Die Vermieterin von nebenan")
        XCTAssertEqual(ideas[1].genre, "Historisch")

        let chapters = StructureParser.parseChapters("KAPITEL 1|Der Riss|Rosa erbt die Bäckerei|Drohender Abriss")
        XCTAssertEqual(chapters.count, 1)
        XCTAssertEqual(chapters[0].title, "Der Riss")

        // Falschtreffer-Schutz: "IDEENKERN|…" darf NICHT als IDEE durchgehen.
        XCTAssertTrue(StructureParser.parseIdeas("IDEENKERN|etwas|noch was|und mehr").isEmpty)
    }
}
