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
        XCTAssertEqual(AIProvider.ollamaCloud.suggestedModels.first, "kimi-k2.6")
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

        XCTAssertEqual(models.first, "kimi-k2.6")
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
        // … Coder/Vision/Embedding und das leer liefernde minimax werden entfernt.
        XCTAssertFalse(models.contains("qwen3-coder:30b"))
        XCTAssertFalse(models.contains("qwen3-vl:235b"))
        XCTAssertFalse(models.contains("nomic-embed-text"))
        XCTAssertFalse(models.contains("minimax-m2.5:cloud"))
    }

    func testDisplayWordCountPrefersStoredCountForLargeChapters() {
        let chapter = Chapter(chapterNumber: 1, title: "Langkapitel",
                              goal: "Ziel", targetWordCount: 5000)
        chapter.actualWordCount = 4321
        chapter.finalText = Array(repeating: "Wort", count: 12_000).joined(separator: " ")

        XCTAssertEqual(chapter.displayWordCount, 4321)
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
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: "qwen3-vl:235b"), "kimi-k2.6")
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: "gpt-oss:120b"), "kimi-k2.6")
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: ""), "kimi-k2.6")
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: "nomic-embed-text"), "kimi-k2.6")
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

    /// Vertrag des Kapitel-Fallbacks: die synthetisierte Form muss die Gates
    /// bestehen, sonst hilft das Auffangen bei der Kapitelplanung nichts.
    func testFallbackChapterShapePassesGate() {
        let chapters = (1...6).map { i in
            PlannedChapter(number: i, title: "Aufbruch \(i)",
                goal: "Treibe den Hauptkonflikt in der Aufbruch-Phase durch eine eigenständige Eskalation spürbar voran.",
                conflict: "Ein konkretes Hindernis stellt sich dem Ziel dieses Kapitels entgegen.")
        }
        XCTAssertTrue(AutonomousContentQuality.hasUsableChapterPlan(chapters))
    }

    // MARK: - Prompt-Leak-Sanitizer

    /// Durchgesickerte Prompt-Anweisungen/Labels müssen aus der Prosa verschwinden,
    /// echte Erzählsätze müssen bleiben (gemeldeter Fehler aus „Erdbeerstreuselliebe").
    func testStripsLeakedPromptInstructionsButKeepsProse() {
        let leaked = """
        Rosa öffnete die Tür der Bäckerei und der Duft von Vanille schlug ihr entgegen.

        Knüpfe nahtlos daran an – ohne das Geschehene zu wiederholen oder zusammenzufassen.

        „Du bist also zurück“, sagte Finn leise.
        Ort: Bäckerei
        Zielumfang: ca. 600 Wörter
        Sie nickte, ohne ihn anzusehen.
        """
        let clean = AutonomousContentQuality.strippingPromptArtifacts(leaked)

        XCTAssertFalse(clean.contains("Knüpfe nahtlos daran an"))
        XCTAssertFalse(clean.contains("Ort: Bäckerei"))
        XCTAssertFalse(clean.lowercased().contains("zielumfang"))

        XCTAssertTrue(clean.contains("Duft von Vanille"))
        XCTAssertTrue(clean.contains("„Du bist also zurück“"))
        XCTAssertTrue(clean.contains("Sie nickte, ohne ihn anzusehen."))

        // Normale Prosa mit den Wörtern „Ziel"/„Stil" mitten im Satz bleibt unangetastet.
        let normal = "Ihr Ziel war es zu fliehen. Der Stil des Hauses gefiel ihr."
        XCTAssertEqual(AutonomousContentQuality.strippingPromptArtifacts(normal), normal)
    }

    /// KI-typische Gedankenstriche müssen verschwinden, Zahlenbereiche bleiben,
    /// damit das Buch nicht „nach KI" aussieht.
    func testHumanizeProseRemovesAiDashesButKeepsNumberRanges() {
        let input = "Sie sah ihn an — lange. Der Kuchen, frisch gebacken – noch warm. Siehe Seiten 12–13."
        let out = AutonomousContentQuality.humanizeProse(input)

        XCTAssertFalse(out.contains("—"))
        XCTAssertFalse(out.contains(" – "))
        XCTAssertTrue(out.contains("12–13"))            // Zahlenbereich bleibt
        XCTAssertTrue(out.contains("Sie sah ihn an, lange."))
        XCTAssertTrue(out.contains("frisch gebacken, noch warm."))
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

    /// Der virale Genre-Winkel muss pro Genre unterschiedliche Themen-/Titel-Hinweise
    /// liefern und in den Ideen-Prompt eingebettet sein – das treibt kreativere,
    /// genre-typische Titel und Bestseller-Hooks.
    func testGenreViralAngleIsGenreSpecific() {
        let thriller = PromptFactory.genreViralAngle("Thriller")
        let romance = PromptFactory.genreViralAngle("Liebesroman")
        let fantasy = PromptFactory.genreViralAngle("Fantasy")
        let dark = PromptFactory.genreViralAngle("Dark Romance")

        XCTAssertTrue(thriller.contains("Thriller"))
        XCTAssertTrue(thriller.lowercased().contains("twist"))
        XCTAssertTrue(romance.lowercased().contains("trope"))
        XCTAssertTrue(fantasy.lowercased().contains("romantasy"))
        XCTAssertTrue(dark.lowercased().contains("einvernehmlich"))

        // Winkel müssen sich klar unterscheiden (kein generischer Einheitsbrei).
        XCTAssertNotEqual(thriller, romance)
        XCTAssertNotEqual(fantasy, dark)
    }

    func testBookIdeasPromptDemandsCreativeTitlesAndEmbedsViralAngle() {
        let prompt = PromptFactory.bookIdeas(genre: "Thriller", language: "Deutsch")
        // Genre-Winkel ist eingebettet …
        XCTAssertTrue(prompt.contains("VIRALES THEMA"))
        // … und die kreativen Titel-Regeln samt Klischee-Verbot sind präsent.
        XCTAssertTrue(prompt.contains("TITEL-PFLICHT"))
        XCTAssertTrue(prompt.contains("High-Concept"))
        XCTAssertTrue(prompt.contains("IDEE|Titel|Genre|"))
    }

    /// Einzelbuch: ein vom Nutzer vorgegebener Titel + Genre müssen verbindlich
    /// in die Generierung eingehen und dürfen nicht ersetzt werden. (Im Auto-Modus
    /// ist der Titel ein selbst erfundener viraler Titel – dieselbe Bindung greift.)
    func testConceptPromptBindsGivenTitleAndGenre() {
        let prompt = PromptFactory.concept(
            title: "Zähl nicht bis zehn", genre: "Thriller", subgenre: "Psychothriller",
            language: "Deutsch", style: "psychologisch", tonality: "düster",
            audience: "Erwachsene", perspective: "Personaler Erzähler", tense: "Präteritum",
            pageCount: 320, ideaSeed: "Eine Geiselnehmerin zwingt eine Verhandlerin zu einem Countdown."
        )
        XCTAssertTrue(prompt.contains("Zähl nicht bis zehn"))
        XCTAssertTrue(prompt.contains("VERBINDLICH"))
        XCTAssertTrue(prompt.contains("Ändere oder ersetze den"))
        XCTAssertTrue(prompt.contains("Psychothriller"))
    }

    // MARK: - Cover-Studio

    func testCoverPromptIsBuiltFromBookIdentityAndKDPContext() {
        let project = Project(title: "Zähl nicht bis zehn", authorName: "Dave Demaré",
                              language: "Deutsch", genre: "Thriller",
                              styleProfile: "psychologisch, düster",
                              targetPageCount: 320, outputFormats: ["EPUB"])
        project.authorBio = "Dave Demaré schreibt psychologische Thriller mit hohem emotionalem Druck."

        let profile = BookProfile(premise: "Eine Verhandlerin muss einen Countdown stoppen, der ihre eigene Schuld offenlegt.",
                                  theme: "Schuld", targetAudience: "Thriller-Leser",
                                  tonality: "düster, nervös",
                                  narrativePerspective: "Personaler Erzähler",
                                  tense: "Präteritum")
        profile.logline = "Eine Geiselnehmerin zwingt eine Verhandlerin, vor laufender Kamera mitzuzählen."
        profile.synopsis = "Der Countdown beginnt harmlos und wird zur öffentlichen Beichte."
        profile.kdpDescription = "Ein psychologischer Thriller über Schuld, Kontrolle und einen Countdown ohne Ausweg."
        project.bookProfile = profile

        let prompt = CoverDesignService.buildPrompt(for: project)

        XCTAssertTrue(prompt.contains("Zähl nicht bis zehn"))
        XCTAssertTrue(prompt.contains("Dave Demaré"))
        XCTAssertTrue(prompt.contains("Thriller"))
        XCTAssertTrue(prompt.contains("Countdown"))
        XCTAssertTrue(prompt.contains("Amazon KDP"))
        XCTAssertTrue(prompt.contains("2:3"))
        XCTAssertTrue(prompt.contains("keine KI-Hinweise"))
    }

    func testCoverVisibleTextNeverAddsAIDisclosure() {
        let project = Project(title: "Salz und Asche", authorName: "Dave Demaré",
                              language: "Deutsch", genre: "Historischer Roman",
                              styleProfile: "atmosphärisch", targetPageCount: 300,
                              outputFormats: ["EPUB"])

        let visibleText = CoverDesignService.visibleCoverText(for: project)

        XCTAssertTrue(visibleText.contains("Salz und Asche"))
        XCTAssertTrue(visibleText.contains("Dave Demaré"))
        XCTAssertFalse(visibleText.lowercased().contains("ki"))
        XCTAssertFalse(visibleText.lowercased().contains("ai"))
    }

    func testCoverImageSettingsNeverEncodeAPIKey() throws {
        var settings = CoverImageSettings()
        settings.apiKey = "test_bildmodell_geheim"
        settings.baseURL = "https://api.openai.com/v1"
        settings.model = "gpt-image-2"

        let data = try JSONEncoder().encode(settings)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertFalse(json.contains("geheim"))
        XCTAssertFalse(json.contains("apiKey"))
        XCTAssertNil(try JSONDecoder().decode(CoverImageSettings.self, from: data).apiKey)
    }
}
