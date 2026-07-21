import XCTest
import SwiftData
@testable import NovelForge

/// Tests für Pipeline-Invarianten und Sicherheitsgarantien.
@MainActor
final class LogicTests: XCTestCase {

    /// In-Memory-SwiftData-Container für Tests, die echte @Model-Beziehungen
    /// brauchen (z.B. project.bookProfile). Ohne Container trappt das Setzen
    /// einer Relationship.
    @MainActor
    private func makeInMemoryContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Schema([Project.self, BookProfile.self, StoryBible.self, CharacterProfile.self,
                         LocationProfile.self, Chapter.self, StoryScene.self,
                         PipelineJob.self, QualityReport.self, ChatMessage.self]),
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
    }

    @MainActor
    func testPersistentModelsRoundTripRelationshipsAndCascadeDelete() throws {
        let container = try makeInMemoryContainer()
        let context = container.mainContext
        let project = Project(title: "Persistenztest", authorName: "Autor", language: "Deutsch",
                              genre: "Thriller", styleProfile: "präzise",
                              targetPageCount: 240, outputFormats: ["EPUB", "PDF"])
        let chapter = Chapter(chapterNumber: 1, title: "Auftakt", goal: "Konflikt eröffnen",
                              targetWordCount: 2_500)
        let scene = StoryScene(sceneNumber: 1, perspective: "Mara", location: "Berlin",
                               goal: "Hinweis finden", targetWordCount: 900)

        project.chapters = [chapter]
        chapter.project = project
        chapter.scenes = [scene]
        scene.chapter = chapter
        context.insert(project)
        context.insert(chapter)
        context.insert(scene)
        try context.save()

        let fetchedProjects = try context.fetch(FetchDescriptor<Project>())
        let fetchedChapters = try context.fetch(FetchDescriptor<Chapter>())
        let fetchedScenes = try context.fetch(FetchDescriptor<StoryScene>())
        XCTAssertEqual(fetchedProjects.first?.preferredProviderRaw, AIProvider.ollamaCloud.rawValue)
        XCTAssertEqual(fetchedProjects.first?.chapters?.first?.title, "Auftakt")
        XCTAssertTrue(fetchedChapters.first?.project === fetchedProjects.first)
        XCTAssertTrue(fetchedScenes.first?.chapter === fetchedChapters.first)

        context.delete(project)
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<Project>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<Chapter>()).isEmpty)
        XCTAssertTrue(try context.fetch(FetchDescriptor<StoryScene>()).isEmpty)
    }

    // MARK: - Sicherheit

    func testPublicContentGuardBlocksDisclosureWithoutBlockingAlsKind() {
        XCTAssertTrue(PublicContentGuard.disclosureViolation(
            in: "Dieses Werk wurde mit Unterstützung von Künstlicher Intelligenz (KI) erstellt."
        ))
        XCTAssertTrue(PublicContentGuard.disclosureViolation(
            in: "This book is AI-generated."
        ))
        XCTAssertTrue(PublicContentGuard.disclosureViolation(
            in: "Als KI kann ich dieses Kapitel nicht schreiben."
        ))
        XCTAssertFalse(PublicContentGuard.disclosureViolation(
            in: "Als Kind lief Mira jeden Morgen an diesem Haus vorbei."
        ))
        XCTAssertFalse(PublicContentGuard.disclosureViolation(
            in: "Der Roman handelt von künstlicher Intelligenz und Verantwortung."
        ))
    }

    @MainActor
    func testPublicationReadinessBlocksTruncatedAndUnresolvedCriticalContent() throws {
        let container = try makeInMemoryContainer()
        let project = Project(title: "Prüfbuch", authorName: "Autor", language: "Deutsch",
                              genre: "Thriller", styleProfile: "direkt",
                              targetPageCount: 1, outputFormats: ["EPUB"])
        project.targetWordCount = 100
        project.imprint = "Muster-Impressum"
        project.authorBio = "Autorprofil"
        container.mainContext.insert(project)

        let profile = BookProfile(premise: "Prämisse", theme: "Thema",
                                  targetAudience: "Erwachsene", tonality: "direkt",
                                  narrativePerspective: "personal", tense: "Präteritum")
        profile.kdpTitle = "Die letzte Tür"
        profile.kdpDescription = "Ein spannender Verkaufstext."
        profile.kdpKeywords = "Thriller, Geheimnis, Spannung"
        profile.kdpCategories = "Thriller"
        profile.project = project
        project.bookProfile = profile
        container.mainContext.insert(profile)

        let chapter = Chapter(chapterNumber: 1, title: "Die Tür", goal: "Entscheidung",
                              targetWordCount: 100)
        chapter.finalText = Array(repeating: "Wort", count: 99).joined(separator: " ") + " Ende."
        chapter.actualWordCount = 100
        chapter.status = .finalized
        chapter.project = project
        project.chapters = [chapter]
        container.mainContext.insert(chapter)

        XCTAssertTrue(PublicationReadiness.completionBlockingIssues(project: project).isEmpty)
        XCTAssertTrue(PublicationReadiness.cachedCompletionBlockingIssues(project: project).isEmpty)

        chapter.finalText = "[Diese Szene muss noch ausgeschrieben werden – bitte im Manuskript neu erzeugen.]"
        chapter.updatedAt = chapter.updatedAt.addingTimeInterval(1)
        XCTAssertTrue(PublicationReadiness.exportBlockingIssues(project: project)
            .contains { $0.contains("Produktions- oder Platzhaltertext") })
        XCTAssertTrue(PublicationReadiness.cachedExportBlockingIssues(project: project)
            .contains { $0.contains("Produktions- oder Platzhaltertext") })
        chapter.finalText = Array(repeating: "Wort", count: 99).joined(separator: " ") + " Ende."
        chapter.updatedAt = chapter.updatedAt.addingTimeInterval(1)

        profile.kdpKeywords = ""
        XCTAssertTrue(PublicationReadiness.completionBlockingIssues(project: project)
            .contains { $0.contains("KDP-Metadaten fehlen") })
        XCTAssertTrue(PublicationReadiness.cachedCompletionBlockingIssues(project: project)
            .contains { $0.contains("KDP-Metadaten fehlen") })
        profile.kdpKeywords = "Thriller, Geheimnis, Spannung"

        chapter.finalText = Array(repeating: "Wort", count: 99).joined(separator: " ") + " mitten im"
        chapter.updatedAt = chapter.updatedAt.addingTimeInterval(1)
        XCTAssertTrue(PublicationReadiness.completionBlockingIssues(project: project)
            .contains { $0.contains("Abgeschnittene Kapitelenden") })
        XCTAssertTrue(PublicationReadiness.cachedCompletionBlockingIssues(project: project)
            .contains { $0.contains("Abgeschnittene Kapitelenden") })
        chapter.finalText = Array(repeating: "Wort", count: 99).joined(separator: " ") + " Ende."
        chapter.updatedAt = chapter.updatedAt.addingTimeInterval(1)

        let report = QualityReport(checkedArea: "Kapitel 1", checkType: "Konsistenz",
                                   result: "Zeitlinie widerspricht sich", severity: .critical,
                                   recommendation: "Zeitlinie reparieren")
        report.project = project
        project.qualityReports = [report]
        container.mainContext.insert(report)

        XCTAssertTrue(PublicationReadiness.completionBlockingIssues(project: project)
            .contains { $0.contains("1 kritisch") })

        let repair = PipelineJob(agentName: "Repair Editor", phase: .manuscriptRevision,
                                 chapterNumber: 1)
        repair.status = .completed
        repair.createdAt = report.createdAt.addingTimeInterval(1)
        repair.project = project
        project.pipelineJobs = [repair]
        container.mainContext.insert(repair)

        XCTAssertTrue(PublicationReadiness.completionBlockingIssues(project: project)
            .contains { $0.contains("1 kritisch") },
            "Ein beliebiger späterer Reparatur-Job darf den konkreten Befund nicht verdecken.")

        report.autoFixed = true
        XCTAssertFalse(PublicationReadiness.completionBlockingIssues(project: project)
            .contains { $0.contains("Qualitätsbefunde") })
    }

    func testRewriteRejectsTokenLimitedResponseEvenWithSentenceEnding() {
        let source = String(repeating: "Ein vollständiger Satz. ", count: 60)
        XCTAssertFalse(AutonomousContentQuality.isAcceptableRewrite(
            source: source,
            candidate: source,
            finishReason: "length"
        ))
        XCTAssertTrue(AutonomousContentQuality.isAcceptableRewrite(
            source: source,
            candidate: source,
            finishReason: "stop"
        ))
    }

    func testGlobalRepairIssueExpandsToEveryNamedChapter() {
        let parsed = RepairIssueParser.parse(
            "REPAIR|Kritisch|Gesamtmanuskript|Zeitlinie|Kapitel 18 widerspricht Kapitel 49 und Kapitel 55|Todesursache vereinheitlichen"
        )
        let expanded = RepairIssueParser.expandingGlobalChapterReferences(parsed)

        XCTAssertEqual(expanded.compactMap(\.chapterNumber), [18, 49, 55])
    }

    func testDraftSceneRejectsTextAboveOneHundredTwentyFivePercent() {
        let accepted = Array(repeating: "Wort", count: 99).joined(separator: " ") + " Ende."
        let oversized = Array(repeating: "Wort", count: 126).joined(separator: " ") + "."

        XCTAssertTrue(AutonomousContentQuality.acceptsDraftScene(accepted, targetWords: 100))
        XCTAssertFalse(AutonomousContentQuality.acceptsDraftScene(oversized, targetWords: 100))
    }

    func testContinuationMergePreservesFinalPunctuation() {
        let repeated = "Ein langer abgeschlossener Satz bildet hier den sicheren Übergang."
        let merged = AutonomousContentQuality.mergingContinuation(
            base: repeated,
            continuation: repeated + " Danach öffnete sie die Tür."
        )

        XCTAssertEqual(merged, repeated + "\n\nDanach öffnete sie die Tür.")
        XCTAssertTrue(AutonomousContentQuality.hasCompleteSentenceEnding(merged))
    }

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

    func testOllamaCloudExcludesCodingFocusedModels() {
        XCTAssertFalse(OllamaCloudModelCatalog.isUsefulForLongFormCloudModel("kimi-k2.7-code"))
        XCTAssertEqual(OllamaCloudModelCatalog.bestModel(preferred: "kimi-k2.7-code"), "kimi-k2.6")
        XCTAssertFalse(OllamaCloudModelCatalog.isUsefulForLongFormCloudModel("qwen3-coder:480b"))
    }

    func testOllamaCloudExcludesRetiredAndImminentlyRetiringModels() {
        XCTAssertFalse(OllamaCloudModelCatalog.isUsefulForLongFormCloudModel("kimi-k2:1t"))
        XCTAssertFalse(OllamaCloudModelCatalog.isUsefulForLongFormCloudModel("deepseek-v3.2:cloud"))
        XCTAssertFalse(OllamaCloudModelCatalog.isUsefulForLongFormCloudModel("glm-4.7"))
        XCTAssertTrue(OllamaCloudModelCatalog.isUsefulForLongFormCloudModel("glm-5.2"))
        XCTAssertTrue(OllamaCloudModelCatalog.isUsefulForLongFormCloudModel("gemma4:31b"))
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

    func testOllamaLengthDoneReasonIsNotMisreportedAsStop() throws {
        let data = """
        {
          "message": { "content": "Der Satz endet mitten im", "thinking": null },
          "done": true,
          "done_reason": "length",
          "eval_count": 40
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
        let normalized = NormalizedOllamaResponse(
            text: decoded.message.content,
            done: decoded.done,
            doneReason: decoded.done_reason,
            eval_count: decoded.eval_count,
            thinking: decoded.message.thinking
        )

        XCTAssertEqual(normalized.finishReason, "length")
        XCTAssertTrue(AutonomousContentQuality.finishReasonIndicatesTruncation(normalized.finishReason))
    }

    func testOllamaCloudModelCatalogKeepsRealLiveModels() {
        let models = OllamaCloudModelCatalog.mergeWithFallbacks([
            "kimi-k2.6:cloud",
            "glm-5.1:cloud",
            "brand-new-prose:cloud",
        ])

        XCTAssertEqual(models, ["kimi-k2.6", "glm-5.1", "brand-new-prose:cloud"])
        XCTAssertFalse(models.contains("qwen3.5"), "Nicht gemeldete Fallbacks dürfen live nicht erscheinen")
    }

    func testOllamaCloudModelCatalogUsesFallbacksOnlyWhenLiveListIsEmpty() {
        XCTAssertEqual(OllamaCloudModelCatalog.mergeWithFallbacks([]),
                       OllamaCloudModelCatalog.fallbackModels)
    }

    func testOllamaCloudModelCatalogFiltersOnlyUnsuitableModels() {
        let models = OllamaCloudModelCatalog.mergeWithFallbacks([
            "qwen3-coder:30b",
            "qwen3-vl:235b",
            "nomic-embed-text",
            "nemotron-3-nano:30b",
            "kimi-k2.6:cloud",
            "minimax-m2.5:cloud"
        ])

        // Schreib-Modelle bleiben erhalten …
        XCTAssertTrue(models.contains("kimi-k2.6"))
        // … Coder/Vision/Embedding und das leer liefernde minimax werden entfernt.
        XCTAssertFalse(models.contains("qwen3-coder:30b"))
        XCTAssertFalse(models.contains("qwen3-vl:235b"))
        XCTAssertFalse(models.contains("nomic-embed-text"))
        XCTAssertFalse(models.contains("nemotron-3-nano:30b"))
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

    func testDraftQualityPenaltyRewardsConcreteProse() {
        let formulaic = "Für einen Moment hielt sie den Atem an. Ihr Herz schlug schneller."
        let concrete = "Sie schob den Riegel vor und stellte den nassen Schuh gegen die Tür."

        XCTAssertGreaterThan(
            AutonomousContentQuality.draftQualityPenalty(formulaic),
            AutonomousContentQuality.draftQualityPenalty(concrete)
        )
        XCTAssertEqual(
            Set(AutonomousContentQuality.aiTellMatches(in: formulaic)),
            Set(["für einen moment", "ihr herz schlug schneller", "sie hielt den atem an"])
        )
        XCTAssertEqual(
            AutonomousContentQuality.circumlocutionMatches(in: "Sie sah etwas, das sie nicht benennen konnte."),
            ["etwas, das", "nicht benennen"]
        )
    }

    func testClarityContractRejectsDenseVaguenessAndAcceptsConcreteAction() {
        let vagueBeat = "Sie spürte etwas in ihr, das sie nicht benennen konnte, als würde eine unsichtbare Kraft auf sie warten. "
        let vague = String(repeating: vagueBeat, count: 12)
        let concreteBeat = "Lena schloss das Fenster, legte den Brief auf den Tisch und fragte Jonas nach dem fehlenden Schlüssel. "
        let concrete = String(repeating: concreteBeat, count: 12)

        let vagueAssessment = AutonomousContentQuality.clarityAssessment(vague)
        let concreteAssessment = AutonomousContentQuality.clarityAssessment(concrete)

        XCTAssertFalse(vagueAssessment.isAcceptable)
        XCTAssertGreaterThan(vagueAssessment.vagueReferences, 0)
        XCTAssertGreaterThan(vagueAssessment.hypotheticalComparisons, 0)
        XCTAssertGreaterThan(vagueAssessment.filterReactions, 0)
        XCTAssertTrue(concreteAssessment.isAcceptable)
        XCTAssertGreaterThan(
            AutonomousContentQuality.draftQualityPenalty(vague),
            AutonomousContentQuality.draftQualityPenalty(concrete)
        )
    }

    func testClarityContractAllowsOnePurposefulComparison() {
        let concrete = String(repeating: "Mara prüfte die Adresse, rief den Hausmeister an und notierte seine Antwort. ", count: 18)
            + "Der leere Stuhl stand am Fenster, als hätte ihn jemand gerade verlassen."

        XCTAssertTrue(AutonomousContentQuality.clarityAssessment(concrete).isAcceptable)
    }

    func testSceneFittingRatioAllowsLargeButTargetSizedCondensation() {
        let ratio = SceneFittingSizing.minimumSourceRatio(
            sourceWords: 983,
            targetWords: 449
        )

        XCTAssertLessThan(ratio, 0.50)
        XCTAssertGreaterThanOrEqual(ratio, 0.25)
        XCTAssertGreaterThan(Double(449) / 983.0, ratio)
        XCTAssertEqual(
            SceneFittingSizing.minimumSourceRatio(sourceWords: 600, targetWords: 500),
            0.50,
            accuracy: 0.0001
        )
    }

    func testRecoveryPolicyOnlyAutoResumesAppInterruptions() {
        XCTAssertTrue(ProductionRecoveryPolicy.shouldAutoResume(
            result: "Die App wurde während Draft Writer (Kapitel 3, Szene 2) beendet. Der gespeicherte Stand ist vollständig und kann fortgesetzt werden.",
            projectStatus: .paused
        ))
        XCTAssertFalse(ProductionRecoveryPolicy.shouldAutoResume(
            result: "Produktion pausiert; gespeicherter Stand bleibt erhalten.",
            projectStatus: .paused
        ))
        XCTAssertFalse(ProductionRecoveryPolicy.shouldAutoResume(
            result: "Die App wurde während Export beendet.",
            projectStatus: .completed
        ))
    }

    func testImmediateSentenceRepeatsCollapseWithoutChangingLaterRefrain() {
        let sentence = "Sie legte den Schlüssel langsam auf den Tisch."
        let input = "\(sentence) \(sentence) Dazwischen verging eine Stunde. \(sentence)"

        XCTAssertEqual(
            AutonomousContentQuality.collapsingImmediateRepeats(input),
            "\(sentence) Dazwischen verging eine Stunde. \(sentence)"
        )
    }

    func testImmediateRepeatCleanupHandlesLongNonRepeatingProse() {
        let input = (0..<2_000)
            .map { "Satz Nummer \($0) beschreibt einen jeweils anderen konkreten Vorgang." }
            .joined(separator: " ")

        XCTAssertEqual(AutonomousContentQuality.collapsingImmediateRepeats(input), input)
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

    // MARK: - Genre ernst nehmen (kein Berufs-/Alltagsplot)

    func testBookIdeasForbidsJobPlotsAndDemandsGenreFidelity() {
        let prompt = PromptFactory.bookIdeas(genre: "Erotik", language: "Deutsch")
        XCTAssertTrue(prompt.contains("GENRE ERNST NEHMEN"))
        XCTAssertTrue(prompt.lowercased().contains("nicht um einen beruf"))
        XCTAssertTrue(prompt.contains("Begehren"))
    }

    func testConceptPromptInjectsGenreCoreSoGenreIsTakenSeriously() {
        let prompt = PromptFactory.concept(
            title: "Berühr mich, wenn du dich traust", genre: "Erotik", subgenre: nil,
            language: "Deutsch", style: "sinnlich", tonality: "intim",
            audience: "Erwachsene", perspective: "Ich-Erzählerin", tense: "Präsens",
            pageCount: 280, ideaSeed: "Zwei Rivalen teilen sich verdeckt ein Doppelleben."
        )
        XCTAssertTrue(prompt.contains("GENRE-HANDWERK"))
        XCTAssertTrue(prompt.contains("kreist NICHT um einen Beruf"))
    }

    /// Belegt die Korrektur des beobachteten Fehlers: ein „Liebesroman", der als
    /// Techno-Thriller mit Stalker-Love-Interest endete. Beziehung = Motor,
    /// Love Interest rootbar, kein Stalker.
    func testRomanceGenreCraftMakesRelationshipTheEngineAndForbidsStalkerHero() {
        let romance = PromptFactory.genreCraft("Liebesroman")
        XCTAssertTrue(romance.contains("LIEBESGESCHICHTE ist die Haupthandlung"))
        XCTAssertTrue(romance.contains("Beziehungsfrage"))
        XCTAssertTrue(romance.lowercased().contains("stalker"))

        let erotik = PromptFactory.genreCraft("Erotik")
        XCTAssertTrue(erotik.contains("BEZIEHUNG"))
        XCTAssertTrue(erotik.lowercased().contains("rootbar"))
        XCTAssertTrue(erotik.lowercased().contains("einvernehmlich"))
    }

    /// „Komische Sterne" / Markdown im geschriebenen Text müssen verschwinden,
    /// aber der Szenentrenner „***" (vom Export gebraucht) muss erhalten bleiben.
    func testStripsMarkdownButKeepsSceneSeparator() {
        let input = """
        Sie sah ihn **lange** an und sagte *nichts*.

        ***

        Am Morgen war alles _anders_. Ein Wort. ❤
        """
        let out = AutonomousContentQuality.strippingInlineFormatting(input)
        // Die Prosazeile darf KEIN Sternchen mehr enthalten (der „***"-Trenner ist
        // eine eigene Zeile und bleibt erhalten – er enthält naturgemäß „**").
        XCTAssertFalse((out.components(separatedBy: "\n").first ?? "").contains("*"))
        XCTAssertFalse(out.contains("**lange**"))
        XCTAssertFalse(out.contains("_anders_"))
        XCTAssertFalse(out.contains("❤"))
        XCTAssertTrue(out.contains("lange"))
        XCTAssertTrue(out.contains("nichts"))
        XCTAssertTrue(out.contains("anders"))
        // Szenentrenner bleibt als eigene Zeile erhalten.
        XCTAssertTrue(out.components(separatedBy: "\n").contains(where: {
            $0.trimmingCharacters(in: .whitespaces) == "***"
        }))
    }

    func testDenylistCatchesVagueInteriorityTell() {
        let text = String(repeating: "Sie stand am Fenster und sah hinaus. ", count: 30)
            + "Da war etwas, das sie nicht benennen konnte."
        XCTAssertGreaterThanOrEqual(AutonomousContentQuality.aiTellCount(text), 1)
    }

    /// Repetition-Scan echter Bücher: verbatim überstrapazierte Standard-Beats
    /// (Lesefluss-Killer) müssen vom weichen Gate erkannt werden.
    func testDenylistCatchesOverusedRepeatedBeats() {
        XCTAssertGreaterThanOrEqual(
            AutonomousContentQuality.aiTellCount("Er öffnete den Mund, schloss ihn. Sie drehte sich nicht um."), 2)
        XCTAssertGreaterThanOrEqual(
            AutonomousContentQuality.aiTellCount("Du warst Kaskade, sagte sie. Keine Frage."), 1)
    }

    /// Sanitizer darf legitime Prosa/Dialog NICHT löschen (Lesefluss), aber harte
    /// durchgesickerte Anweisungen weiterhin entfernen.
    func testSanitizerKeepsAmbiguousDialogueButStripsHardInstruction() {
        let dialogue = "Schreibe die Szene neu, sagte der Regisseur und ging."
        XCTAssertEqual(AutonomousContentQuality.strippingPromptArtifacts(dialogue), dialogue)

        let leaked = "Sie trat ans Fenster. Gib ausschließlich den fertigen Prosatext der Szene aus. Draußen regnete es."
        let cleaned = AutonomousContentQuality.strippingPromptArtifacts(leaked)
        XCTAssertFalse(cleaned.lowercased().contains("gib ausschließlich"))
        XCTAssertTrue(cleaned.contains("Sie trat ans Fenster."))
        XCTAssertTrue(cleaned.contains("Draußen regnete es."))
    }

    /// Konzeptphase: Liebes-/Erotikbücher bekommen den Genre-Vertrag (zentrale
    /// Beziehungsfrage, Streich-Test, Happy End), andere Genres NICHT.
    func testConceptInjectsRomanceGenreContractOnlyForRomance() {
        let romance = PromptFactory.concept(
            title: "Vielleicht im nächsten Sommer", genre: "Liebesroman", subgenre: nil,
            language: "Deutsch", style: "warm", tonality: "sehnsüchtig", audience: "Erwachsene",
            perspective: "Ich-Erzählerin", tense: "Präteritum", pageCount: 300,
            ideaSeed: "Zwei Nachbarn, ein Sommer, ein altes Versprechen.")
        XCTAssertTrue(romance.contains("GENRE-VERTRAG"))
        XCTAssertTrue(romance.contains("Streich-Test"))
        XCTAssertTrue(romance.lowercased().contains("happy end"))

        let thriller = PromptFactory.concept(
            title: "Zähl nicht bis zehn", genre: "Thriller", subgenre: nil,
            language: "Deutsch", style: "düster", tonality: "kühl", audience: "Erwachsene",
            perspective: "Personaler Erzähler", tense: "Präteritum", pageCount: 300,
            ideaSeed: "Eine Verhandlerin und ein Countdown.")
        XCTAssertFalse(thriller.contains("GENRE-VERTRAG"))
    }

    // MARK: - Kreative Kapiteltitel (kein „Aufbruch N" mehr)

    /// Belegt den Fix: Ein einzelnes schwaches Kapitel darf NICHT den ganzen Plan
    /// verwerfen (sonst bekamen alle 50 Kapitel generische „Aufbruch N"-Titel).
    /// Echte Titel bleiben erhalten, nur die schwache Stelle wird repariert.
    func testRepairedChapterPlanKeepsRealTitlesAndOnlyFixesWeakChapters() {
        let planned = [
            PlannedChapter(number: 1, title: "Der Schalter, der klemmte",
                goal: "Lina trennt manuell das Netz und entdeckt einen frisch manipulierten Schalter.",
                conflict: "Sabotage unter Zeitdruck"),
            PlannedChapter(number: 2, title: "Kapitel 2", goal: "x", conflict: ""),
            PlannedChapter(number: 3, title: "Das Aggregat im Keller",
                goal: "Finn zögert und lässt die Zange fallen, statt das Letzte zu zerstören.",
                conflict: "Er kann sie nicht vernichten")
        ]
        let repaired = PipelineOrchestrator.repairedChapterPlan(planned, count: 3)
        XCTAssertEqual(repaired.count, 3)
        XCTAssertEqual(repaired[0].title, "Der Schalter, der klemmte")
        XCTAssertEqual(repaired[2].title, "Das Aggregat im Keller")
        XCTAssertNotEqual(repaired[1].title, "Kapitel 2")
        XCTAssertFalse(AutonomousContentQuality.isGenericPlaceholder(repaired[1].title))
        XCTAssertGreaterThanOrEqual(repaired[1].goal.wordCount, 5)
        XCTAssertGreaterThanOrEqual(repaired[1].conflict.wordCount, 3)
    }

    func testChapterPlanPromptDemandsCreativeChapterTitles() {
        let p = PromptFactory.chapterPlan(title: "Wenn der Strom fällt", genre: "Liebesroman",
            plot: "Akt 1 bis 3.", chapterCount: 30, wordsPerChapter: 2500)
        XCTAssertTrue(p.contains("KAPITELTITEL kreativ"))
        XCTAssertTrue(p.contains("STRENG VERBOTEN"))
        XCTAssertTrue(p.contains("doppelbödig"))
    }

    /// Bestehende Bücher mit generischen „Aufbruch/Eskalation N"-Titeln zeigen im
    /// Export/Inhaltsverzeichnis ein neutrales „Kapitel N"; echte Titel bleiben.
    func testChapterDisplayTitleReplacesGenericPlaceholdersOnly() {
        let generic = Chapter(chapterNumber: 7, title: "Aufbruch 7", goal: "Ziel", targetWordCount: 2000)
        XCTAssertEqual(generic.displayTitle, "Kapitel 7")
        let esk = Chapter(chapterNumber: 12, title: "Eskalation 12", goal: "Ziel", targetWordCount: 2000)
        XCTAssertEqual(esk.displayTitle, "Kapitel 12")
        let empty = Chapter(chapterNumber: 5, title: "", goal: "Ziel", targetWordCount: 2000)
        XCTAssertEqual(empty.displayTitle, "Kapitel 5")
        let real = Chapter(chapterNumber: 3, title: "Honig auf der Klinge", goal: "Ziel", targetWordCount: 2000)
        XCTAssertEqual(real.displayTitle, "Honig auf der Klinge")
    }

    // MARK: - Bestseller-Sog (Page-Turner) + kühnere Titel

    func testPageTurnerRulesCoverTheKeyTechniques() {
        let rules = PromptFactory.pageTurnerRules
        XCTAssertTrue(rules.contains("OFFENE SCHLEIFE"))
        XCTAssertTrue(rules.contains("MIKROSPANNUNG"))
        XCTAssertTrue(rules.contains("WITHHOLDING"))
        XCTAssertTrue(rules.contains("VERZÖGERUNG"))
    }

    func testBookTitleRulesDemandViralYetClearAndBanWeird() {
        let p = PromptFactory.bookIdeas(genre: "Liebesroman", language: "Deutsch")
        XCTAssertTrue(p.contains("EXTREM stark und viral"))  // maximale Sogkraft gefordert
        XCTAssertTrue(p.contains("sofort verständlich"))      // aber klar, nicht kryptisch
        XCTAssertTrue(p.contains("STRENG VERBOTEN"))          // komische/kryptische Titel verboten
        XCTAssertTrue(p.contains("BAUARTEN"))
        XCTAssertTrue(p.contains("NUR MUSTER")) // Beispieltitel dürfen nicht kopiert werden
    }

    func testBookIdeasWeavesAuthorSeedWhenProvided() {
        let withSeed = PromptFactory.bookIdeas(genre: "Liebesroman", language: "Deutsch",
            authorSeed: "Eine Pianistin erbt ein Haus, in dem nachts jemand spielt.")
        XCTAssertTrue(withSeed.contains("AUTOREN-IDEE"))
        XCTAssertTrue(withSeed.contains("Eine Pianistin erbt ein Haus"))
        // Ohne Seed kein Seed-Block.
        let noSeed = PromptFactory.bookIdeas(genre: "Liebesroman", language: "Deutsch")
        XCTAssertFalse(noSeed.contains("AUTOREN-IDEE"))
    }

    func testGenreCraftHandlesRomantasy() {
        let r = PromptFactory.genreCraft("Romantasy")
        XCTAssertTrue(r.contains("Romantasy"))
        XCTAssertTrue(r.lowercased().contains("fantastische"))
    }

    func testGripRulesEnforceMomentumStakesAndAntiMoodpiece() {
        let r = PromptFactory.gripRules
        XCTAssertTrue(r.contains("SZENEN-GATE"))
        XCTAssertTrue(r.contains("LAGE-DELTA"))
        XCTAssertTrue(r.contains("ENTDECKUNG STATT EMPFINDUNG"))
        XCTAssertTrue(r.contains("EINSATZ STEIGT"))
    }

    /// Echte Kapitelnamen aus dem Inhalt: der Titel-Prompt nutzt die Zusammenfassung
    /// und verbietet generische Platzhalter.
    func testChapterTitlePromptUsesContentAndBansGenericNames() {
        let p = PromptFactory.chapterTitle(bookTitle: "Wenn der Strom fällt", genre: "Liebesroman",
            chapterNumber: 7, summary: "Lina entdeckt einen manipulierten Schalter und ahnt Sabotage.")
        XCTAssertTrue(p.contains("Lina entdeckt einen manipulierten Schalter"))
        XCTAssertTrue(p.contains("STRENG VERBOTEN"))
        XCTAssertTrue(p.contains("Aufbruch"))
    }

    // MARK: - Anti-KI-Stil (Detektor-Resistenz)

    func testHumanCraftRulesCoverBurstinessParagraphEndingsAndTricolon() {
        let rules = PromptFactory.humanCraftRules
        XCTAssertTrue(rules.contains("SATZLÄNGE"))
        XCTAssertTrue(rules.contains("ABSATZ-ENDEN"))
        XCTAssertTrue(rules.contains("TRIKOLA"))
        let revise = PromptFactory.reviseChapter(language: "Deutsch", style: "düster",
            tonality: "kühl", chapterNumber: 3, chapterTitle: "Bruch", text: "Beispieltext.")
        XCTAssertTrue(revise.contains("MENSCHLICH SCHREIBEN"))
    }

    func testSoundsLikeAIFlagsFloskelDenseProseButNotCleanProse() {
        let aiProse = ([
            "Ihr Herz schlug bis zum Hals.",
            "Ein Schauer lief ihr über den Rücken.",
            "In diesem Moment verstand sie alles.",
            "Eine Mischung aus Angst und Hoffnung durchströmte sie.",
            "Etwas in ihr zerbrach."
        ].joined(separator: " ") + " ")
            + String(repeating: "Sie ging weiter durch die leere Halle und dachte nach. ", count: 20)
        XCTAssertGreaterThanOrEqual(AutonomousContentQuality.aiTellCount(aiProse), 4)
        XCTAssertTrue(AutonomousContentQuality.soundsLikeAI(aiProse))

        let cleanProse = String(repeating: "Marek zählte die Stufen. Achtzehn. Oben klemmte die Tür, also trat er dagegen. Der Flur war kalt. ", count: 8)
        XCTAssertEqual(AutonomousContentQuality.aiTellCount(cleanProse), 0)
        XCTAssertFalse(AutonomousContentQuality.soundsLikeAI(cleanProse))
    }

    // MARK: - Cover-Studio

    @MainActor
    func testCoverPromptIsBuiltFromBookIdentityAndKDPContext() throws {
        let ctx = try makeInMemoryContainer().mainContext
        let project = Project(title: "Zähl nicht bis zehn", authorName: "Dave Demaré",
                              language: "Deutsch", genre: "Thriller",
                              styleProfile: "psychologisch, düster",
                              targetPageCount: 320, outputFormats: ["EPUB"])
        ctx.insert(project)
        project.authorBio = "Dave Demaré schreibt psychologische Thriller mit hohem emotionalem Druck."

        let profile = BookProfile(premise: "Eine Verhandlerin muss einen Countdown stoppen, der ihre eigene Schuld offenlegt.",
                                  theme: "Schuld", targetAudience: "Thriller-Leser",
                                  tonality: "düster, nervös",
                                  narrativePerspective: "Personaler Erzähler",
                                  tense: "Präteritum")
        ctx.insert(profile)
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

    func testImageProviderPresetsResolve() {
        XCTAssertGreaterThanOrEqual(CoverImageSettings.providers.count, 4)
        XCTAssertEqual(CoverImageSettings.preset("flux").baseURL, "https://api.bfl.ai")
        XCTAssertEqual(CoverImageSettings.preset("fal").model, "fal-ai/flux/dev")
        XCTAssertEqual(CoverImageSettings.preset("unbekannt").id, "openai")
    }

    /// Jeder „echte" Anbieter bietet mehrere Bildmodelle zur Auswahl, damit man frei
    /// zwischen allen gängigen Cover-Modellen wählen kann.
    func testImageModelChoicesCoverMultipleModelsPerProvider() {
        XCTAssertGreaterThanOrEqual(CoverImageSettings.modelChoices(for: "openai").count, 2)
        XCTAssertGreaterThanOrEqual(CoverImageSettings.modelChoices(for: "flux").count, 4)
        XCTAssertGreaterThanOrEqual(CoverImageSettings.modelChoices(for: "fal").count, 6)
        XCTAssertTrue(CoverImageSettings.modelChoices(for: "flux").contains("flux-pro-1.1-ultra"))
        XCTAssertTrue(CoverImageSettings.modelChoices(for: "stability").contains("ultra"))
        XCTAssertTrue(CoverImageSettings.modelChoices(for: "custom").isEmpty)
    }

    /// Sinnlichkeitsgrad: ein Wert steuert Generierungs-Ausführlichkeit UND KDP-Einordnung.
    func testSpiceLevelDirectivesScaleAndZeroIsNeutral() {
        XCTAssertTrue(SpiceLevel.generationDirective(0).isEmpty, "0 = nicht angegeben → kein Block")
        XCTAssertTrue(SpiceLevel.kdpGuidance(0).isEmpty)
        for lvl in SpiceLevel.range {
            XCTAssertTrue(SpiceLevel.generationDirective(lvl).contains("SINNLICHKEITSGRAD"))
        }
        // niedrige Stufe = zurückhaltend, hohe Stufe = explizit + Inhaltshinweis
        XCTAssertTrue(SpiceLevel.kdpGuidance(1).lowercased().contains("dezent"))
        XCTAssertTrue(SpiceLevel.kdpGuidance(5).lowercased().contains("erotik"))
        XCTAssertTrue(SpiceLevel.kdpGuidance(4).lowercased().contains("erwachsene"))
        XCTAssertEqual(SpiceLevel.pickerLabel(4), "Stufe 4 – Explizit")
    }

    /// Der gewählte Sinnlichkeitsgrad muss real in Generierungs- und KDP-Prompt einfließen.
    func testSpiceLevelFlowsIntoPrompts() {
        let kdp = PromptFactory.kdpMetadata(
            title: "Titel", author: "Autor", genre: "Liebesroman", audience: "Erwachsene",
            synopsis: "Inhalt", language: "Deutsch", tropes: "", spiceLevel: 4)
        XCTAssertTrue(kdp.contains("SINNLICHKEITSGRAD: 4/5"))
        let scene = PromptFactory.draftScene(
            language: "Deutsch", style: "warm", tonality: "intim", perspective: "Ich",
            tense: "Präsens", genre: "Liebesroman", bookTitle: "Titel", chapterNumber: 1,
            chapterTitle: "K1", chapterGoal: "Ziel", sceneNumber: 1, sceneGoal: "Ziel",
            sceneLocation: "Ort", sceneTime: "Nacht", sceneObstacle: "Hindernis",
            sceneTurn: "Wendung", scenePerspective: "", charactersSummary: "Figuren",
            styleRules: "Regeln", storySoFar: "", previousSceneEnding: "",
            isFirstScene: true, isFinalScene: false, targetWords: 1500, spiceLevel: 4)
        XCTAssertTrue(scene.contains("SINNLICHKEITSGRAD 4/5"))
    }

    /// Stil-DNA: reproduzierbar pro Seed, aber über verschiedene Seeds hinweg
    /// unterschiedlich – das ist der Kern des Schutzes gegen Amazon-„Programmatic Content".
    func testNarrativeSignatureIsDeterministicPerSeedAndVariesAcrossSeeds() {
        let a1 = NarrativeSignature.make(seed: 12345)
        let a2 = NarrativeSignature.make(seed: 12345)
        XCTAssertEqual(a1, a2, "Gleicher Seed muss dieselbe Stil-DNA ergeben (stabil über den Lauf).")

        // Über viele verschiedene Seeds entstehen klar unterschiedliche Signaturen.
        var seen = Set<String>()
        for seed in UInt64(1)...UInt64(40) {
            seen.insert(NarrativeSignature.make(seed: seed).directive)
        }
        XCTAssertGreaterThan(seen.count, 20, "Die Stil-DNA muss über Bücher hinweg stark streuen.")
    }

    func testNarrativeSignatureStableSeedIsConsistent() {
        XCTAssertEqual(NarrativeSignature.stableSeed("Buch A|Thriller"),
                       NarrativeSignature.stableSeed("Buch A|Thriller"))
        XCTAssertNotEqual(NarrativeSignature.stableSeed("Buch A|Thriller"),
                          NarrativeSignature.stableSeed("Buch B|Thriller"))
    }

    /// Der Direktiv-Block trägt die Einzigartigkeits-Anweisung und respektiert
    /// die im Wizard gewählte Perspektive/Zeitform als Override.
    func testNarrativeSignatureDirectiveCarriesUniquenessAndHonorsOverride() {
        let sig = NarrativeSignature.make(seed: 999)
        XCTAssertTrue(sig.directive.contains("STIL-DNA"))
        XCTAssertTrue(sig.directive.contains("Programmatic Content"))
        let overridden = sig.directiveText(povOverride: "Ich-Erzählerin", tenseOverride: "Präsens")
        XCTAssertTrue(overridden.contains("Ich-Erzählerin"))
        XCTAssertTrue(overridden.contains("Präsens"))
    }

    /// Die Stil-DNA muss in die zentralen Generierungs-Prompts einfließen, damit
    /// Struktur und Stimme pro Buch variieren (nicht nur Metadaten).
    func testStyleSignatureFlowsIntoGenerationPrompts() {
        let marker = "STIL-DNA DIESES BUCHES"
        let signature = NarrativeSignature.make(seed: 7).directive
        let concept = PromptFactory.concept(
            title: "Titel", genre: "Liebesroman", subgenre: nil, language: "Deutsch",
            style: "warm", tonality: "intim", audience: "Erwachsene",
            perspective: "Ich", tense: "Präsens", pageCount: 300, ideaSeed: "Seed",
            tropes: "", bookSignature: signature)
        XCTAssertTrue(concept.contains(marker))
        let plot = PromptFactory.plot(title: "Titel", genre: "Liebesroman", style: "warm",
            concept: "Konzept", pageCount: 300, chapterCount: 30, bookSignature: signature)
        XCTAssertTrue(plot.contains(marker))
        let plan = PromptFactory.chapterPlan(title: "Titel", genre: "Liebesroman",
            plot: "Plot", chapterCount: 30, wordsPerChapter: 2500, bookSignature: signature)
        XCTAssertTrue(plan.contains(marker))
    }

    func testCoverImageSettingsDecodesWithoutProviderKey() throws {
        // Ältere gespeicherte Einstellungen ohne "provider" dürfen nicht scheitern.
        let legacy = #"{"baseURL":"https://x/v1","model":"m","size":"1024x1536","quality":"high"}"#
        let s = try JSONDecoder().decode(CoverImageSettings.self, from: Data(legacy.utf8))
        XCTAssertEqual(s.provider, "openai")
        XCTAssertEqual(s.model, "m")
    }

    /// Gewählter Ansatz „Artwork + scharfer Text-Overlay": das Bildmodell darf KEINEN
    /// Text ins Bild rendern (KI-Text wird verzerrt). Titel/Autor kommen als Overlay.
    @MainActor
    func testCoverPromptRequestsTextFreeArtworkForOverlay() throws {
        let ctx = try makeInMemoryContainer().mainContext
        let project = Project(title: "Zähl nicht bis zehn", authorName: "Dave Demaré",
                              language: "Deutsch", genre: "Thriller",
                              styleProfile: "düster", targetPageCount: 320,
                              outputFormats: ["EPUB"])
        ctx.insert(project)
        let prompt = CoverDesignService.buildPrompt(for: project)
        XCTAssertTrue(prompt.contains("illustration only, no text"))
        XCTAssertTrue(prompt.contains("razor-sharp typographic overlay"))
        XCTAssertTrue(prompt.contains("negative space"))
        // KDP-Kontext bleibt erhalten.
        XCTAssertTrue(prompt.contains("Amazon KDP"))
        XCTAssertTrue(prompt.contains("2:3"))
    }

    /// Der Text-Overlay skaliert lange Titel kleiner, damit sie nicht überlaufen.
    /// (Reine Layout-Logik, ohne Grafik-Kontext – CI-sicher.)
    func testCoverTitleFontSizeShrinksForLongerTitles() {
        let short = CoverComposer.titleFontSize(for: "Nyx")
        let long = CoverComposer.titleFontSize(for: "Ein ziemlich langer Romantitel der umbrechen muss")
        XCTAssertGreaterThan(short, long)
    }

    // MARK: - Buchqualitäts-Runde (N-Gramm-Scan, Rewrite-Abnahme, Finale-Prompts)

    /// Buchweit wiederholte Formulierungen werden erkannt; Einmal-Formulierungen nicht.
    /// (WELCHES Fragment der wiederholten Passage gemeldet wird, ist durch Kappung+Dedup
    /// bewusst nicht festgelegt – entscheidend ist, DASS die Passage auffällt.)
    func testOverusedPhrasesFindsCrossChapterRepeats() {
        let tic = "ein Schauer lief ihr kalt den Rücken hinunter"
        let chapters = (1...4).map { i in
            "Kapitel \(i) beginnt völlig anders und erzählt eigene Dinge. " + tic
                + " Danach ging die Handlung Nummer \(i) ganz eigenständig weiter."
        }
        let hits = AutonomousContentQuality.overusedPhrases(inChapters: chapters)
        XCTAssertFalse(hits.isEmpty, "Wiederkehrende Passagen müssen gefunden werden")
        XCTAssertTrue(hits.contains { $0.lowercased().contains("schauer") || $0.lowercased().contains("hinunter") },
                      "Ein Fragment der wiederholten Floskel muss gemeldet werden: \(hits)")
    }

    func testOverusedPhrasesIgnoresUniqueProse() {
        let chapters = [
            "Marta zählte die Möwen am Hafenbecken und verfluchte die Flut.",
            "Jonas reparierte den Vergaser, während der Regen aufs Wellblech trommelte.",
            "Im Archiv roch es nach kaltem Staub und vergessenen Jahrzehnten."
        ]
        XCTAssertTrue(AutonomousContentQuality.overusedPhrases(inChapters: chapters).isEmpty)
    }

    /// Abgeschnittene Rewrites (zu kurz, ohne Satzschluss, verlorene Szenentrenner)
    /// werden abgelehnt; saubere Rewrites akzeptiert.
    func testIsAcceptableRewriteRejectsTruncatedAnswers() {
        let source = String(repeating: "Ein ganzer Satz steht hier. ", count: 40) + "\n\n***\n\n"
            + String(repeating: "Auch hier stehen ganze Sätze. ", count: 40)
        let truncated = String(repeating: "Ein ganzer Satz steht hier. ", count: 30) + "und dann brach es mitten im"
        XCTAssertFalse(AutonomousContentQuality.isAcceptableRewrite(source: source, candidate: truncated))
        let losesSeparator = String(repeating: "Ein ganzer Satz steht hier. ", count: 75) + "Ende gut."
        XCTAssertFalse(AutonomousContentQuality.isAcceptableRewrite(source: source, candidate: losesSeparator))
        let good = String(repeating: "Ein besserer Satz steht hier. ", count: 38) + "\n\n***\n\n"
            + String(repeating: "Auch hier stehen bessere Sätze. ", count: 38) + "Ende gut."
        XCTAssertTrue(AutonomousContentQuality.isAcceptableRewrite(source: source, candidate: good))
    }

    /// Das Schlusskapitel wird als Auszahlung geplant (kein erzwungener Haken),
    /// normale Kapitel behalten die Haken-Pflicht.
    func testScenePlanFinalChapterPlansResolutionInsteadOfHook() {
        let normal = PromptFactory.scenePlan(bookTitle: "B", chapterNumber: 3, chapterTitle: "K",
                                             chapterGoal: "Ziel", chapterConflict: "Konflikt",
                                             perspective: "Er", plotContext: "Plot", targetWords: 2000)
        XCTAssertTrue(normal.contains("starken Haken"))
        let finale = PromptFactory.scenePlan(bookTitle: "B", chapterNumber: 40, chapterTitle: "Ende",
                                             chapterGoal: "Ziel", chapterConflict: "Konflikt",
                                             perspective: "Er", plotContext: "Plot", targetWords: 2000,
                                             isFinalChapter: true)
        XCTAssertTrue(finale.contains("SCHLUSSKAPITEL"))
        XCTAssertFalse(finale.contains("starken Haken"))
    }

    /// Die letzte Szene erhält keine Sog-/Cliffhanger-Regeln mehr.
    func testDraftSceneFinalSceneDropsHookRules() {
        func scene(final: Bool) -> String {
            PromptFactory.draftScene(
                language: "Deutsch", style: "klar", tonality: "warm", perspective: "Er",
                tense: "Präteritum", genre: "Liebesroman", bookTitle: "B", chapterNumber: 40,
                chapterTitle: "Ende", chapterGoal: "Ziel", sceneNumber: 4, sceneGoal: "Ziel",
                sceneLocation: "Ort", sceneTime: "Abend", sceneObstacle: "H", sceneTurn: "W",
                scenePerspective: "", charactersSummary: "F", styleRules: "R", storySoFar: "S",
                previousSceneEnding: "", isFirstScene: false, isFinalScene: final, targetWords: 900)
        }
        XCTAssertTrue(scene(final: false).contains("SOG (dezent)"))
        XCTAssertFalse(scene(final: true).contains("SOG (dezent)"))
        XCTAssertTrue(scene(final: true).contains("KEINE neue Frage"))
    }

    /// Revision erhält Kontext (Genre, Figuren, Anschluss, Wiederholungs-Liste).
    func testReviseChapterCarriesContextBlocks() {
        let prompt = PromptFactory.reviseChapter(
            language: "Deutsch", style: "d", tonality: "t", chapterNumber: 2,
            chapterTitle: "K", text: "Text.",
            genreBrief: "KERNVERSPRECHEN: X", charactersSummary: "Mia (Heldin)",
            previousEnding: "So endete Kapitel 1.", nextOpening: "So beginnt Kapitel 3.",
            overusedPhrases: "- die Luft zwischen ihnen knisterte")
        XCTAssertTrue(prompt.contains("KERNVERSPRECHEN"))
        XCTAssertTrue(prompt.contains("Mia (Heldin)"))
        XCTAssertTrue(prompt.contains("ANSCHLUSS"))
        XCTAssertTrue(prompt.contains("ÜBERSTRAPAZIERTE"))
    }

    func testReviseChapterRequestsTargetedCompressionForOversizedSource() {
        let oversized = String(repeating: "Wort ", count: 5_500) + "Ende."
        let prompt = PromptFactory.reviseChapter(
            language: "Deutsch",
            style: "klar",
            tonality: "spannend",
            chapterNumber: 8,
            chapterTitle: "Die Grenze",
            text: oversized,
            targetWords: 2_500
        )

        XCTAssertTrue(prompt.contains("auf ca. 2500 Wörter"))
        XCTAssertTrue(prompt.contains("Handlung vollständig"))
        XCTAssertFalse(prompt.contains("Umfang bei (±10%)"))
    }

    func testReviseChapterKeepsNormalSizedSourceNearItsLength() {
        let normal = String(repeating: "Wort ", count: 2_500) + "Ende."
        let prompt = PromptFactory.reviseChapter(
            language: "Deutsch",
            style: "klar",
            tonality: "spannend",
            chapterNumber: 8,
            chapterTitle: "Die Grenze",
            text: normal,
            targetWords: 2_500
        )

        XCTAssertTrue(prompt.contains("Umfang bei (±10%)"))
        XCTAssertFalse(prompt.contains("auf ca. 2500 Wörter"))
    }

    func testChapterRevisionSizingAcceptsRequiredDeepCompression() {
        let sourceWords = 6_354
        let targetWords = 2_500

        XCTAssertTrue(ChapterRevisionSizing.isOversized(
            sourceWords: sourceWords,
            targetWords: targetWords
        ))
        XCTAssertEqual(ChapterRevisionSizing.desiredOutputWords(
            sourceWords: sourceWords,
            targetWords: targetWords
        ), targetWords)
        XCTAssertEqual(ChapterRevisionSizing.maxOutputTokens(
            sourceWords: sourceWords,
            targetWords: targetWords
        ), 7_500)

        let minimumRatio = ChapterRevisionSizing.minimumSourceRatio(
            sourceWords: sourceWords,
            targetWords: targetWords
        )
        let targetCandidateRatio = Double(targetWords) / Double(sourceWords)
        XCTAssertLessThan(minimumRatio, targetCandidateRatio)
        XCTAssertGreaterThanOrEqual(minimumRatio, 0.20)
    }

    // MARK: - Polarisierende Titel, Lesesog, Alltagssprache

    /// Polarisierende Titel (Tabu/Anschuldigung/Besitz) schlagen gefällige Titel im Score.
    func testTitleViralityRewardsPolarizingTitles() {
        let polar = AutonomousContentQuality.titleViralityScore("Du gehörst mir")
        let tame = AutonomousContentQuality.titleViralityScore("Der Sommer am See")
        XCTAssertGreaterThan(polar, tame)
    }

    /// Akademisches Fachvokabular wird deterministisch erkannt (Dave: „Mediävistiker" sagt niemand).
    func testJargonDetectionFlagsAcademicVocabulary() {
        let jargon = "Der Mediävistiker deutete den Wasserfleck kartographisch."
        XCTAssertGreaterThanOrEqual(AutonomousContentQuality.jargonTellCount(jargon), 2)
        XCTAssertEqual(AutonomousContentQuality.jargonTellCount("Sie tranken Kaffee und stritten über Geld."), 0)
        // Zwei Fachwörter in einem langen Text lösen die Neufassung aus.
        let filler = String(repeating: "Sie ging die Straße entlang und dachte an gestern. ", count: 20)
        XCTAssertTrue(AutonomousContentQuality.soundsLikeAI(filler + jargon))
        XCTAssertFalse(AutonomousContentQuality.soundsLikeAI(filler + "Sie tranken Kaffee."))
    }

    /// Die Handwerksregeln verbieten Fachvokabular ausdrücklich (Prompt-Ebene).
    func testHumanCraftRulesForbidAcademicJargon() {
        XCTAssertTrue(PromptFactory.humanCraftRules.contains("ALLTAGSSPRACHE"))
        XCTAssertTrue(PromptFactory.humanCraftRules.contains("Mediävistiker"))
    }

    /// Ruhig auslaufende Kapitelenden werden erkannt; Frage/kurzer Schlag/Rede gelten als stark.
    func testHasWeakChapterEndingDetectsCalmEndings() {
        let filler = String(repeating: "Sie ging weiter durch die Stadt und sah sich die Fenster an. ", count: 15)
        let weak = filler + "Der Abend legte sich ruhig über die Dächer der kleinen Stadt und alles wurde still und friedlich an diesem langen Tag."
        XCTAssertTrue(AutonomousContentQuality.hasWeakChapterEnding(weak))
        let question = filler + "Aber warum hatte er die Tür nicht abgeschlossen?"
        XCTAssertFalse(AutonomousContentQuality.hasWeakChapterEnding(question))
        let punch = filler + "Dann sah sie das Blut."
        XCTAssertFalse(AutonomousContentQuality.hasWeakChapterEnding(punch))
    }

    /// Gehäufte Umschreibungen (Benennungs-Vermeidung, Korrekturfiguren) machen den Text
    /// unverständlich und lösen die Neufassung aus; klare Prosa bleibt unangetastet.
    func testCircumlocutionDensityTriggersRewrite() {
        let filler = String(repeating: "Sie ging weiter durch die Stadt und sah sich die Fenster an. ", count: 15)
        let crypto = "Es war das, was sie nie sagten. Kein Umzug, sondern eine Auslöschung. "
            + "Es blieb so etwas wie Wärme, etwas, das sie nicht benennen konnte."
        XCTAssertGreaterThanOrEqual(AutonomousContentQuality.circumlocutionCount(crypto), 4)
        XCTAssertTrue(AutonomousContentQuality.soundsLikeAI(filler + crypto))
        XCTAssertFalse(AutonomousContentQuality.soundsLikeAI(filler))
        XCTAssertTrue(PromptFactory.humanCraftRules.contains("UMSCHREIBUNGEN STRENG BEGRENZEN"))
    }

    func testRepeatedSentenceCollisionsDetectPriorAndLocalDuplicates() {
        let repeated = "Livia spürte, wie sich ihr Magen vor Angst und Anspannung zusammenzog"
        let prior = "Am Fenster wartete sie. \(repeated). Danach ging das Licht aus."
        let candidate = "Sie trat in den Flur. \(repeated). \(repeated). Niemand antwortete."

        let collisions = AutonomousContentQuality.repeatedSentenceCollisions(
            candidate: candidate,
            priorTexts: [prior]
        )

        XCTAssertEqual(collisions.count, 1)
        XCTAssertEqual(collisions.first, repeated)
    }

    func testRepeatedSentenceCollisionsIgnoreShortNaturalSentences() {
        let candidate = "Sie nickte. Sie nickte. Dann öffnete sie vorsichtig die schwere Haustür."

        XCTAssertTrue(AutonomousContentQuality.repeatedSentenceCollisions(
            candidate: candidate,
            priorTexts: ["Sie nickte. Es blieb still."]
        ).isEmpty)
    }

    func testBlockingRepeatedSentencesFlagsDistinctiveSentenceTwice() {
        let repeated = "Ihre Finger krallten sich fest in den kalten Türrahmen"
        let chapters = [
            "Der Flur war leer. \(repeated). Sie wartete.",
            "Im oberen Stock knarrte Holz. \(repeated). Dann kam jemand."
        ]

        XCTAssertEqual(
            AutonomousContentQuality.blockingRepeatedSentences(inChapters: chapters),
            [repeated]
        )
    }

    // MARK: - Bestseller-Runde (Figurenstimmen, Gefühlsbogen, Beziehungstemperatur)

    /// Sprechweise und markantes Äußeres werden aus der FIGUR-Zeile geparst.
    func testParseCharactersReadsSpeechAndAppearance() {
        let line = "FIGUR|Mara|Protagonistin|29|Ärztin|Wahrheit finden|Verlust|Stolz|kurze Sätze, nie Entschuldigungen|rote Locken, Narbe am Kinn"
        let parsed = StructureParser.parseCharacters(line)
        XCTAssertEqual(parsed.first?.speech, "kurze Sätze, nie Entschuldigungen")
        XCTAssertEqual(parsed.first?.appearance, "rote Locken, Narbe am Kinn")
        // Alte 8-Feld-Zeilen bleiben gültig (Felder leer).
        let old = StructureParser.parseCharacters("FIGUR|Tom|Antagonist|41|Anwalt|Macht|Kontrollverlust|Eitelkeit")
        XCTAssertEqual(old.first?.speech, "")
    }

    /// Der Emotionale Schritt aus dem Kapitelplan wird ins Kapitelziel gefaltet.
    func testParseChaptersFoldsEmotionalStepIntoGoal() {
        let line = "KAPITEL|3|Der Riss|Sie findet den Brief|Vertrauen gegen Beweis|Misstrauen kippt in erstes Vertrauen"
        let parsed = StructureParser.parseChapters(line)
        XCTAssertTrue(parsed.first?.goal.contains("Emotionaler Schritt: Misstrauen kippt") == true)
        // Ohne Emotions-Feld bleibt das Ziel unverändert.
        let old = StructureParser.parseChapters("KAPITEL|3|Der Riss|Sie findet den Brief|Vertrauen gegen Beweis")
        XCTAssertEqual(old.first?.goal, "Sie findet den Brief")
    }

    /// Die Beziehungstemperatur steigt über das Buch von 2 auf 10; Romance-Genres werden erkannt.
    func testRomanceHeatLadderEscalates() {
        XCTAssertEqual(AutonomousContentQuality.romanceHeatTarget(chapterIndex: 0, chapterCount: 40), 2)
        XCTAssertEqual(AutonomousContentQuality.romanceHeatTarget(chapterIndex: 39, chapterCount: 40), 10)
        let mid = AutonomousContentQuality.romanceHeatTarget(chapterIndex: 20, chapterCount: 40)
        XCTAssertTrue((5...8).contains(mid))
        XCTAssertTrue(AutonomousContentQuality.isRomanceGenre("Dark Romance"))
        XCTAssertTrue(AutonomousContentQuality.isRomanceGenre("Liebesroman"))
        XCTAssertFalse(AutonomousContentQuality.isRomanceGenre("Psychothriller"))
    }
}
