import XCTest
@testable import NovelForge

@MainActor
final class NonfictionModeTests: XCTestCase {
    func testBookContentTypeRecognizesCuratedNonfictionGenres() {
        for genre in ["Sachbuch", "Ratgeber", "Praxisbuch", "Biografie", "Gesundheitsratgeber"] {
            XCTAssertEqual(BookContentType.infer(from: genre), .nonfiction, genre)
        }
        XCTAssertEqual(BookContentType.infer(from: "Psychothriller"), .fiction)
        XCTAssertEqual(BookContentType.infer(from: "Romantasy"), .fiction)
    }

    func testHighRiskNonfictionTopicsAreDetected() {
        XCTAssertTrue(NonfictionSafety.isHighRisk(genre: "Finanzratgeber"))
        XCTAssertTrue(NonfictionSafety.isHighRisk(genre: "Gesundheit", premise: "Depression behandeln"))
        XCTAssertTrue(NonfictionSafety.isHighRisk(genre: "Rechtsratgeber"))
        XCTAssertFalse(NonfictionSafety.isHighRisk(genre: "Kreativratgeber"))
    }

    func testNonfictionIdeaPromptUsesReaderProblemInsteadOfNovelPlot() {
        let prompt = PromptFactory.bookIdeas(genre: "Ratgeber", language: "Deutsch")
        XCTAssertTrue(prompt.contains("LESERPROBLEM"))
        XCTAssertTrue(prompt.contains("NUTZENVERSPRECHEN"))
        XCTAssertTrue(prompt.contains("keine erfundenen"))
        XCTAssertFalse(prompt.contains("Kernwunde der Hauptfigur"))
    }

    func testFictionIdeaPromptKeepsNarrativeContract() {
        let prompt = PromptFactory.bookIdeas(genre: "Thriller", language: "Deutsch")
        XCTAssertTrue(prompt.contains("zentralen Konflikt"))
        XCTAssertTrue(prompt.contains("Kernwunde der Hauptfigur"))
        XCTAssertFalse(prompt.contains("LESERPROBLEM"))
    }

    func testNonfictionDraftPromptRejectsInventedEvidence() {
        let prompt = PromptFactory.draftScene(
            language: "Deutsch", style: "klar", tonality: "ermutigend",
            perspective: "Du-Ansprache", tense: "Präsens", genre: "Praxisbuch",
            bookTitle: "Ordnung, die bleibt", chapterNumber: 2, chapterTitle: "Der erste Schritt",
            chapterGoal: "Leser richtet eine einfache Routine ein", sceneNumber: 1,
            sceneGoal: "Routine praktisch erklären", sceneLocation: "Abschnitt",
            sceneTime: "Schritt 1", sceneObstacle: "zu viele Aufgaben",
            sceneTurn: "konkrete Checkliste", scenePerspective: "Leser",
            charactersSummary: "", styleRules: "", storySoFar: "", previousSceneEnding: "",
            isFirstScene: false, isFinalScene: false, targetWords: 900
        )
        XCTAssertTrue(prompt.contains("Fakten, Studien, Statistiken"))
        XCTAssertTrue(prompt.contains("CHECKLISTE"))
        XCTAssertFalse(prompt.contains("professioneller Romanautor"))
    }

    func testNonfictionPlanCanUseLongerChaptersThanDefaultNovelPlan() {
        let novel = LongFormProductionPlan(pageCount: 500)
        let nonfiction = LongFormProductionPlan(pageCount: 500, wordsPerChapterGoal: 3_800)
        XCTAssertLessThan(nonfiction.chapterCount, novel.chapterCount)
        XCTAssertEqual(nonfiction.targetWordCount, novel.targetWordCount)
    }

    func testRepeatedSentenceGateIgnoresShortPhrasesButFindsTemplateCopies() {
        let repeated = "Die Tür fiel hinter ihr ins Schloss, bevor sie den Umschlag öffnete."
        let chapters = (1...3).map { _ in "Hallo. \(repeated) Danach geschah etwas anderes." }
        let hits = AutonomousContentQuality.repeatedSentences(inChapters: chapters)
        XCTAssertEqual(hits.count, 1)
        XCTAssertTrue(hits[0].contains("Tür fiel"))
    }

    func testResearchManifestRoundTripsAndBuildsBibliography() throws {
        let source = ResearchSource(title: "Testquelle", url: "https://example.org/source",
                                    publisher: "Fachverlag", published: "2026",
                                    excerpt: "Ein prüfbarer Auszug.", kind: .scholarly)
        let bundle = ResearchBundle(query: "Testthema", researchedAt: Date(), sources: [source])
        let encoded = try NonfictionResearchService.encodeManifest(bundle)
        let decoded = try XCTUnwrap(NonfictionResearchService.decodeManifest(encoded))
        XCTAssertEqual(decoded.sources.count, 1)
        XCTAssertTrue(decoded.bibliography.contains("https://example.org/source"))
        XCTAssertTrue(decoded.hasScholarlySource)
    }

    func testAuthorBioPromptAndParserDoNotInviteInventedCredentials() {
        let prompt = PromptFactory.authorBioSuggestions(
            authorName: "Dana Beispiel", facts: "Schreibt praktische Familienratgeber.",
            genre: "Ratgeber", language: "Deutsch"
        )
        XCTAssertTrue(prompt.contains("Erfinde niemals Beruf, Ausbildung"))
        let parsed = AuthorBioParser.parse("BIO|Dana Beispiel schreibt praktische Familienratgeber für einen klareren Alltag und verbindet verständliche Sprache mit unmittelbar anwendbaren Ideen für Familien.\n")
        XCTAssertEqual(parsed.count, 1)
    }

    func testCitationValidationRejectsInventedSourceNumbers() {
        let text = "Die Aussage ist belegt [Q2]. Diese Nummer existiert nicht [Q8]."
        XCTAssertEqual(NonfictionSafety.citationNumbers(in: text), [2, 8])
        XCTAssertEqual(NonfictionSafety.invalidCitationNumbers(in: text, sourceCount: 4), [8])
    }
}
