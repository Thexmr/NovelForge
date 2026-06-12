import XCTest
@testable import NovelForge

final class UnlimitedProductionTests: XCTestCase {
    func testUnlimitedSettingsAllowFiveHundredPageKDPBooks() {
        let settings = UnlimitedSettings(
            authorName: "Test Autor",
            language: "Deutsch",
            selectedGenres: ["Thriller"],
            style: "psychologisch",
            pageCount: 500,
            costLimitPerBook: 50,
            maxBooks: 0,
            formats: ["EPUB", "PDF"],
            imprint: "Test Verlag\nMusterstraße 1\n12345 Berlin"
        )

        XCTAssertEqual(settings.pageCount, AppConstants.maxPageCount)
        XCTAssertEqual(settings.targetWordCount, 125_000)
        XCTAssertTrue(settings.imprint.contains("Test Verlag"))
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
            formats: ["EPUB"],
            imprint: ""
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
}
