import XCTest
@testable import NovelForge

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
            costLimitPerBook: 50,
            maxBooks: 0,
            parallelBooks: 10,
            formats: ["EPUB", "PDF"],
            imprint: "Test Verlag\nMusterstraße 1\n12345 Berlin",
            authorBio: "Test Autor schreibt psychologische Thriller."
        )

        XCTAssertEqual(settings.pageCount, AppConstants.maxPageCount)
        XCTAssertEqual(settings.targetWordCount, 125_000)
        XCTAssertEqual(settings.parallelBooks, 10)
        XCTAssertTrue(settings.imprint.contains("Test Verlag"))
        XCTAssertTrue(settings.authorBio.contains("psychologische Thriller"))
    }

    func testUnlimitedSettingsClampParallelBookWorkersToOneThroughTen() {
        let tooLow = UnlimitedSettings(
            authorName: "Test Autor",
            language: "Deutsch",
            selectedGenres: ["Thriller"],
            style: "psychologisch",
            pageCount: 300,
            costLimitPerBook: 25,
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
            costLimitPerBook: 25,
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
            costLimitPerBook: 25,
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
            costLimitPerBook: 25,
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
        XCTAssertFalse(ProductionStabilityPolicy.shouldHaltUnlimitedProduction(after: AIError.costLimitReached,
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

    func testStabilityPolicyStopsAfterTooManyConsecutiveBookFailures() {
        XCTAssertFalse(ProductionStabilityPolicy.shouldHaltUnlimitedProduction(after: AIError.networkError,
                                                                               consecutiveFailures: 2))
        XCTAssertTrue(ProductionStabilityPolicy.shouldHaltUnlimitedProduction(after: AIError.networkError,
                                                                              consecutiveFailures: 3))
    }
}
