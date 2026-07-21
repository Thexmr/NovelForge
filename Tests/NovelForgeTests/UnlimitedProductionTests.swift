import XCTest
@testable import NovelForge

@MainActor
final class UnlimitedProductionTests: XCTestCase {
    func testDefaultBookSettingsIncludeDaveImprintForKDPFrontMatter() {
        XCTAssertEqual(DefaultBookSettings.authorName, "Dave Demaré")
        XCTAssertTrue(DefaultBookSettings.imprint.contains("Wohnfelderstraße 1"))
        XCTAssertTrue(DefaultBookSettings.imprint.contains("E-Mail: davedemare9@gmail.com"))
        XCTAssertTrue(DefaultBookSettings.imprint.contains("© 2026 Dave Demaré"))
        XCTAssertFalse(DefaultBookSettings.authorBio.isEmpty)
    }

    func testUnlimitedSettingsAllowFiveHundredPageKDPBooks() {
        let settings = UnlimitedSettings(
            authorName: "Test Autor",
            language: "Deutsch",
            selectedGenres: ["Thriller"],
            style: "psychologisch",
            pageCount: 500,
            maxBooks: 0,
            parallelBooks: 10,
            formats: ["EPUB", "PDF"],
            imprint: "Test Verlag\nMusterstraße 1\n12345 Berlin",
            authorBio: "Test Autor schreibt psychologische Thriller."
        )

        XCTAssertEqual(settings.pageCount, 500)
        XCTAssertEqual(settings.targetWordCount, 125_000)
        XCTAssertEqual(settings.parallelBooks, 10)
        XCTAssertTrue(settings.resumeInterruptedBooks)
        XCTAssertTrue(settings.imprint.contains("Test Verlag"))
        XCTAssertTrue(settings.authorBio.contains("psychologische Thriller"))
    }

    func testUnlimitedRecoveryPolicyOnlySelectsMatchingUnfinishedProjects() {
        let settings = UnlimitedSettings(
            authorName: "Test Autor",
            language: "Deutsch",
            selectedGenres: ["Thriller"],
            style: "psychologisch",
            pageCount: 500,
            maxBooks: 0,
            formats: ["EPUB"],
            imprint: "",
            authorBio: ""
        )
        let project = Project(
            title: "Unterbrochen",
            authorName: "Test Autor",
            language: "Deutsch",
            genre: "Thriller",
            styleProfile: "psychologisch",
            targetPageCount: 500,
            outputFormats: ["EPUB"]
        )
        project.preferredProviderRaw = AIProvider.ollamaCloud.rawValue
        project.status = .failed

        XCTAssertTrue(UnlimitedRecoveryPolicy.shouldRecover(
            project: project,
            settings: settings,
            provider: .ollamaCloud
        ))

        project.status = .completed
        XCTAssertFalse(UnlimitedRecoveryPolicy.shouldRecover(
            project: project,
            settings: settings,
            provider: .ollamaCloud
        ))

        project.status = .failed
        project.authorName = "Andere Autorin"
        XCTAssertFalse(UnlimitedRecoveryPolicy.shouldRecover(
            project: project,
            settings: settings,
            provider: .ollamaCloud
        ))
    }

    func testUnlimitedSettingsClampParallelBookWorkersToOneThroughTen() {
        let tooLow = UnlimitedSettings(
            authorName: "Test Autor",
            language: "Deutsch",
            selectedGenres: ["Thriller"],
            style: "psychologisch",
            pageCount: 300,
            maxBooks: 0,
            parallelBooks: 0,
            formats: ["EPUB"],
            imprint: "",
            authorBio: ""
        )
        let tooHigh = UnlimitedSettings(
            authorName: "Test Autor",
            language: "Deutsch",
            selectedGenres: ["Thriller"],
            style: "psychologisch",
            pageCount: 300,
            maxBooks: 0,
            parallelBooks: 12,
            formats: ["EPUB"],
            imprint: "",
            authorBio: ""
        )

        XCTAssertEqual(tooLow.parallelBooks, 1)
        XCTAssertEqual(tooHigh.parallelBooks, 10)
    }

    func testUnlimitedSettingsLimitParallelLaunchesByRemainingBookCount() {
        let settings = UnlimitedSettings(
            authorName: "Test Autor",
            language: "Deutsch",
            selectedGenres: ["Thriller"],
            style: "psychologisch",
            pageCount: 300,
            maxBooks: 7,
            parallelBooks: 10,
            formats: ["EPUB"],
            imprint: "",
            authorBio: ""
        )

        XCTAssertEqual(settings.launchSlots(completedBooks: 0, activeBooks: 0), 7)
        XCTAssertEqual(settings.launchSlots(completedBooks: 3, activeBooks: 2), 2)
        XCTAssertEqual(settings.launchSlots(completedBooks: 7, activeBooks: 0), 0)
    }

    func testUnlimitedSettingsCycleSelectedGenresInsteadOfRepeatingOneGenre() {
        let settings = UnlimitedSettings(
            authorName: "Test Autor",
            language: "Deutsch",
            selectedGenres: ["Thriller", "Fantasy", "Krimi"],
            style: UnlimitedSettings.randomToken,
            pageCount: 300,
            maxBooks: 0,
            parallelBooks: 1,
            formats: ["EPUB"],
            imprint: "",
            authorBio: ""
        )

        XCTAssertEqual(settings.genreForBook(at: 0), "Thriller")
        XCTAssertEqual(settings.genreForBook(at: 1), "Fantasy")
        XCTAssertEqual(settings.genreForBook(at: 2), "Krimi")
        XCTAssertEqual(settings.genreForBook(at: 3), "Thriller")
    }

    func testUnlimitedSettingsCycleAndSanitizeIdeaSeeds() {
        let s = UnlimitedSettings(
            authorName: "Test", language: "Deutsch", selectedGenres: ["Thriller"],
            style: "düster", pageCount: 200, maxBooks: 0, parallelBooks: 1,
            formats: ["EPUB"], imprint: "", authorBio: "",
            ideaSeeds: ["Idee eins", "   ", "Idee zwei"])
        XCTAssertEqual(s.ideaSeeds, ["Idee eins", "Idee zwei"]) // Leerzeile gefiltert
        XCTAssertEqual(s.ideaForBook(at: 0), "Idee eins")
        XCTAssertEqual(s.ideaForBook(at: 1), "Idee zwei")
        XCTAssertEqual(s.ideaForBook(at: 2), "Idee eins") // rotiert

        let empty = UnlimitedSettings(
            authorName: "Test", language: "Deutsch", selectedGenres: ["Thriller"],
            style: "düster", pageCount: 200, maxBooks: 0, parallelBooks: 1,
            formats: ["EPUB"], imprint: "", authorBio: "")
        XCTAssertNil(empty.ideaForBook(at: 0))
    }

    func testGenrePoolIncludesNewGenres() {
        for g in ["Romantasy", "Urban Fantasy", "Dystopie", "Cozy Mystery",
                  "Psychothriller", "Western", "Steampunk", "Familiensaga"] {
            XCTAssertTrue(UnlimitedSettings.genrePool.contains(g), "Genre fehlt im Pool: \(g)")
        }
    }

    func testGenrePoolIsLargeAndUnique() {
        XCTAssertGreaterThanOrEqual(UnlimitedSettings.genrePool.count, 40)
        XCTAssertEqual(Set(UnlimitedSettings.genrePool).count, UnlimitedSettings.genrePool.count,
                       "Genre-Pool enthält Duplikate")
    }

    func testTitleViralityPrefersShortPunchyTitles() {
        let strong = AutonomousContentQuality.titleViralityScore("Sag, dass du bleibst")
        let weak = AutonomousContentQuality.titleViralityScore(
            "Ein ganz gewöhnlicher Tag im Leben einer Frau in der großen Stadt")
        XCTAssertGreaterThan(strong, weak)
        XCTAssertEqual(AutonomousContentQuality.titleViralityScore(""), 0)
    }

    func testCoverImagePromptsRequestThreeTextFreeKDPConcepts() {
        let prompt = PromptFactory.coverImagePrompts(
            title: "Sag, dass du bleibst", author: "Test Autor",
            genre: "Dark Romance", subgenre: "", language: "Deutsch",
            mood: "düster", storySignals: "Prämisse: zwei Menschen, eine letzte Nacht.")
        XCTAssertTrue(prompt.contains("PROMPT 1"))
        XCTAssertTrue(prompt.contains("PROMPT 3"))
        XCTAssertTrue(prompt.contains("2:3"))
        XCTAssertTrue(prompt.contains("KEIN Text"))
    }

    func testKDPBlurbPolishPromptDemandsStrongerSalesCopy() {
        let prompt = PromptFactory.kdpBlurbPolish(
            blurb: "Ein ruhiger Roman über das Leben.",
            title: "Die letzte Nacht", genre: "Thriller",
            audience: "Thriller-Fans", language: "Deutsch")
        XCTAssertTrue(prompt.contains("verbesserten Verkaufstext"))
        XCTAssertTrue(prompt.contains("150-200"))
        XCTAssertTrue(prompt.contains("Hook"))
    }

    func testViralTitlesPromptDemandsClickyShortTitles() {
        let p = PromptFactory.viralTitles(genre: "Dark Romance",
                                          premise: "Zwei Menschen, eine letzte Nacht.",
                                          language: "Deutsch")
        XCTAssertTrue(p.contains("VIRALE"))
        XCTAssertTrue(p.contains("TITEL: "))
        XCTAssertTrue(p.contains("2-6 Wörter"))
        XCTAssertTrue(p.contains("Dark Romance"))
    }

    func testExpandedGenrePoolHasManyMoreGenres() {
        XCTAssertGreaterThanOrEqual(UnlimitedSettings.genrePool.count, 100)
        for g in ["LitRPG", "Dark Academia", "Domestic Thriller", "Reverse Harem", "Solarpunk"] {
            XCTAssertTrue(UnlimitedSettings.genrePool.contains(g), "Genre fehlt: \(g)")
        }
        XCTAssertEqual(Set(UnlimitedSettings.genrePool).count, UnlimitedSettings.genrePool.count,
                       "Genre-Pool enthält Duplikate")
    }

    @MainActor
    func testSingleBookWizardUsesSameGenrePoolAsAutonomousMode() {
        XCTAssertEqual(NewBookWizardView.availableGenres, UnlimitedSettings.genrePool)
        XCTAssertTrue(NewBookWizardView.availableGenres.contains("Dark Romance"))
        XCTAssertTrue(NewBookWizardView.availableGenres.contains("Romantasy"))
        XCTAssertTrue(NewBookWizardView.availableGenres.contains("Dystopie"))
        XCTAssertTrue(NewBookWizardView.availableGenres.contains("Cozy Mystery"))
    }

    func testStoryMemoryBuildsAvoidanceBriefFromPriorBooks() {
        let entries = [
            StoryMemoryEntry(title: "Die letzte Schleuse",
                             genre: "Thriller",
                             premise: "Eine Ingenieurin entdeckt Sabotage an einem Staudamm."),
            StoryMemoryEntry(title: "Salz und Asche",
                             genre: "Historischer Roman",
                             premise: "Eine Salzhändlerin kämpft gegen ein Kartell.")
        ]

        let brief = StoryMemory.makeAvoidanceBrief(entries: entries,
                                                   selectedGenres: ["Thriller", "Historischer Roman"],
                                                   limit: 10)

        XCTAssertTrue(brief.contains("Die letzte Schleuse"))
        XCTAssertTrue(brief.contains("Salz und Asche"))
        XCTAssertTrue(brief.contains("nicht wiederholen"))
    }

    func testStoryMemoryDetectsLikelyDuplicateIdeas() {
        let existing = [
            StoryMemoryEntry(title: "Die letzte Schleuse",
                             genre: "Thriller",
                             premise: "Eine Ingenieurin entdeckt Sabotage an einem Staudamm und kämpft gegen einen Konzern.")
        ]
        let duplicate = ParsedIdea(title: "Die Schleuse",
                                   genre: "Thriller",
                                   premise: "Eine Ingenieurin entdeckt Sabotage an einem Staudamm.")
        let different = ParsedIdea(title: "Nachtzug nach Norden",
                                   genre: "Thriller",
                                   premise: "Ein Schlafwagenschaffner findet einen verschwundenen Zeugen.")

        XCTAssertTrue(StoryMemory.isLikelyDuplicate(duplicate, existing: existing))
        XCTAssertFalse(StoryMemory.isLikelyDuplicate(different, existing: existing))
    }

    func testAutonomousQualityRejectsEmptyIdeasAndGenericPlanning() {
        XCTAssertFalse(AutonomousContentQuality.hasUsableIdea(nil))
        XCTAssertFalse(AutonomousContentQuality.hasUsableIdea(
            ParsedIdea(title: "Roman-Roman", genre: "Roman", premise: "")
        ))
        XCTAssertTrue(AutonomousContentQuality.hasUsableIdea(
            ParsedIdea(title: "Der Nachtarchivar",
                       genre: "Thriller",
                       premise: "Ein Archivar entdeckt, dass gelöschte Akten nachts von selbst zurückkehren und eine Mordserie vorhersagen.")
        ))

        let placeholderChapters = [
            PlannedChapter(number: 1, title: "Kapitel 1",
                           goal: "Setze den Plot konsequent fort.", conflict: "")
        ]
        XCTAssertFalse(AutonomousContentQuality.hasUsableChapterPlan(placeholderChapters))
    }

    func testAutonomousQualityRejectsOccupationalTitleCliches() {
        XCTAssertFalse(AutonomousContentQuality.hasUsableIdea(
            ParsedIdea(title: "Die Imkerin von Ulrichstein",
                       genre: "Roman",
                       premise: "Eine Frau entdeckt in ihrer Heimat ein Familiengeheimnis und muss entscheiden, ob sie die Wahrheit öffentlich macht.")
        ))
        XCTAssertFalse(AutonomousContentQuality.hasUsableIdea(
            ParsedIdea(title: "Die Kassiererin von Reykjavik",
                       genre: "Krimi",
                       premise: "Eine Frau findet einen Hinweis auf ein Verbrechen und gerät zwischen alte Schuld und eine gefährliche Entscheidung.")
        ))
        XCTAssertFalse(AutonomousContentQuality.hasUsableIdea(
            ParsedIdea(title: "Das Schweigen der Imkerin",
                       genre: "Roman",
                       premise: "Eine Frau entdeckt in ihrer Heimat ein Familiengeheimnis und muss entscheiden, ob sie die Wahrheit öffentlich macht.")
        ))
        XCTAssertFalse(AutonomousContentQuality.hasUsableIdea(
            ParsedIdea(title: "Das Geheimnis der Bäckerin",
                       genre: "Roman",
                       premise: "Eine Frau entdeckt in ihrer Backstube eine Spur zu einem alten Verrat und muss Familie gegen Wahrheit abwägen.")
        ))
        XCTAssertTrue(AutonomousContentQuality.hasUsableIdea(
            ParsedIdea(title: "Wenn der Regen schweigt",
                       genre: "Roman",
                       premise: "Eine Frau kehrt in eine Stadt zurück, in der ein alter Unfall nie aufgeklärt wurde, und muss zwischen Loyalität und Wahrheit wählen.")
        ))
    }

    func testBookIdeasPromptDemandsKDPViralMarketFitWithoutCopyingExamples() {
        let prompt = PromptFactory.bookIdeas(genre: "Thriller", language: "Deutsch")

        XCTAssertTrue(prompt.contains("Amazon-KDP-Suchergebnis"))
        XCTAssertTrue(prompt.contains("Thumbnail"))
        XCTAssertTrue(prompt.contains("BookTok"))
        XCTAssertTrue(prompt.contains("NUR MUSTER, NICHT KOPIEREN"))
        XCTAssertTrue(prompt.contains("Berufs-Ort-Klischee"))
    }

    func testAutonomousQualityRejectsMetaDraftsAsWrittenScenes() {
        let missingSceneReply = "Der Text der Szene fehlt in deiner Nachricht. Bitte füge ihn nach SZENE ein."
        let tinyReply = "Sie ging hinaus. Ende."
        let prose = Array(repeating: "Die Tür knarrte, während Mara den Umschlag fester hielt.", count: 60)
            .joined(separator: " ")

        XCTAssertFalse(AutonomousContentQuality.acceptsDraftScene(missingSceneReply, targetWords: 625))
        XCTAssertFalse(AutonomousContentQuality.acceptsDraftScene(tinyReply, targetWords: 625))
        XCTAssertTrue(AutonomousContentQuality.acceptsDraftScene(prose, targetWords: 120))
    }

    func testLongFormPlanSplitsFiveHundredPagesIntoManageableScenes() {
        let plan = LongFormProductionPlan(pageCount: 500)

        XCTAssertEqual(plan.targetWordCount, 125_000)
        XCTAssertEqual(plan.chapterCount, 50)
        XCTAssertGreaterThanOrEqual(plan.scenesPerChapter, 4)
        XCTAssertLessThanOrEqual(plan.targetWordsPerScene, 900)
        XCTAssertGreaterThanOrEqual(plan.totalPlannedScenes, 200)
    }

    func testLongFormPlanScalesToThousandPages() {
        XCTAssertEqual(AppConstants.maxPageCount, 1000)
        let plan = LongFormProductionPlan(pageCount: 1000)

        XCTAssertEqual(plan.targetWordCount, 250_000)
        XCTAssertEqual(plan.chapterCount, 80)
        XCTAssertEqual(plan.scenesPerChapter, 5)
        XCTAssertEqual(plan.totalPlannedScenes, 400)
        XCTAssertLessThanOrEqual(plan.targetWordsPerScene, 900)

        // 1000 wird nicht mehr auf 500 gedeckelt.
        let settings = UnlimitedSettings(
            authorName: "A", language: "Deutsch", selectedGenres: ["Roman"], style: "episch",
            pageCount: 1000, maxBooks: 0, parallelBooks: 1, formats: ["EPUB"],
            imprint: "", authorBio: ""
        )
        XCTAssertEqual(settings.pageCount, 1000)
        XCTAssertEqual(settings.targetWordCount, 250_000)
    }

    func testDraftTokenBudgetSupportsLongScenesWithoutTinyCaps() {
        XCTAssertEqual(LongFormProductionPlan.draftMaxTokens(forTargetWords: 600), 2400)
        XCTAssertEqual(LongFormProductionPlan.draftMaxTokens(forTargetWords: 1_200), 4800)
        XCTAssertEqual(LongFormProductionPlan.draftMaxTokens(forTargetWords: 3_000), 8000)
    }

    func testProductionTimingReportsPerBookRunDurations() {
        let timing = ProductionTiming(
            currentBookStartedAt: Date(timeIntervalSince1970: 1_000),
            now: Date(timeIntervalSince1970: 1_900),
            completedBookDurations: [3_600, 5_400],
            completedScenes: 20,
            totalScenes: 100,
            recentSceneDurations: [45, 45, 45]
        )

        XCTAssertEqual(timing.elapsedText, "15 min")
        XCTAssertEqual(timing.remainingText, "1 h")
        XCTAssertEqual(timing.estimatedTotalText, "1 h 15 min")
        XCTAssertEqual(timing.averageBookText, "1 h 15 min")
    }

    func testStabilityPolicyStopsUnlimitedProductionOnOperatorRequiredErrors() {
        XCTAssertTrue(ProductionStabilityPolicy.shouldHaltUnlimitedProduction(after: AIError.apiKeyInvalid,
                                                                              consecutiveFailures: 1))
        XCTAssertTrue(ProductionStabilityPolicy.shouldHaltUnlimitedProduction(after: AIError.quotaExceeded,
                                                                              consecutiveFailures: 1))
        XCTAssertTrue(ProductionStabilityPolicy.shouldHaltUnlimitedProduction(after: AIError.baseURLMissing,
                                                                              consecutiveFailures: 1))
        XCTAssertTrue(ProductionStabilityPolicy.shouldHaltUnlimitedProduction(after: AIError.modelUnavailable,
                                                                              consecutiveFailures: 1))
        XCTAssertFalse(ProductionStabilityPolicy.shouldHaltUnlimitedProduction(after: AIError.providerUnavailable,
                                                                               consecutiveFailures: 1))
    }

    func testStabilityPolicyUsesCappedBackoffForTransientBookFailures() {
        XCTAssertEqual(ProductionStabilityPolicy.retryDelay(forConsecutiveFailures: 0), 0)
        XCTAssertEqual(ProductionStabilityPolicy.retryDelay(forConsecutiveFailures: 1), 5)
        XCTAssertEqual(ProductionStabilityPolicy.retryDelay(forConsecutiveFailures: 2), 15)
        XCTAssertEqual(ProductionStabilityPolicy.retryDelay(forConsecutiveFailures: 3), 45)
        XCTAssertEqual(ProductionStabilityPolicy.retryDelay(forConsecutiveFailures: 8), 300)
    }

    func testStabilityPolicyKeepsRetryingTransientBookFailures() {
        XCTAssertFalse(ProductionStabilityPolicy.shouldHaltUnlimitedProduction(after: AIError.networkError,
                                                                               consecutiveFailures: 2))
        XCTAssertFalse(ProductionStabilityPolicy.shouldHaltUnlimitedProduction(after: AIError.networkError,
                                                                                 consecutiveFailures: 30))
    }

    func testStabilityPolicyResumesSameBookAfterTransientProviderFailures() {
        XCTAssertTrue(ProductionStabilityPolicy.shouldResumeInterruptedBook(after: AIError.providerUnavailable))
        XCTAssertTrue(ProductionStabilityPolicy.shouldResumeInterruptedBook(after: AIError.networkError))
        XCTAssertTrue(ProductionStabilityPolicy.shouldResumeInterruptedBook(after: AIError.rateLimitExceeded))
        XCTAssertTrue(ProductionStabilityPolicy.shouldResumeInterruptedBook(after: AIError.ollamaNotRunning))
        XCTAssertFalse(ProductionStabilityPolicy.shouldResumeInterruptedBook(after: AIError.apiKeyInvalid))
        XCTAssertFalse(ProductionStabilityPolicy.shouldResumeInterruptedBook(after: AIError.quotaExceeded))
        XCTAssertFalse(ProductionStabilityPolicy.shouldResumeInterruptedBook(
            after: NSError(domain: "NovelForgeTests", code: 1)
        ))
    }

    func testReadinessShortfallRemainsRetryableForAutonomousProduction() {
        let error = AIError.systemError(
            "\(PipelineOrchestrator.readinessShortfallMarker): Offene Qualitätsbefunde: 1 kritisch, 0 Fehler."
        )

        XCTAssertTrue(PipelineOrchestrator.isReadinessShortfall(error))
        XCTAssertFalse(PipelineOrchestrator.isReadinessShortfall(AIError.apiKeyInvalid))
    }

    func testProviderRetryUsesExponentialBackoffWithBoundedJitter() {
        XCTAssertTrue(ProductionStabilityPolicy.isRetryableProviderError(.networkError))
        XCTAssertTrue(ProductionStabilityPolicy.isRetryableProviderError(.rateLimitExceeded))
        XCTAssertFalse(ProductionStabilityPolicy.isRetryableProviderError(.apiKeyInvalid))
        XCTAssertEqual(ProductionStabilityPolicy.providerRetryDelay(attempt: 1, jitter: 1), 2)
        XCTAssertEqual(ProductionStabilityPolicy.providerRetryDelay(attempt: 2, jitter: 1), 4)
        XCTAssertEqual(ProductionStabilityPolicy.providerRetryDelay(attempt: 5, jitter: 1), 32)
    }
}
