import XCTest
@testable import NovelForge

final class ChapterEditorialScorecardTests: XCTestCase {
    private func completeScene(text: String) -> StoryScene {
        let scene = StoryScene(
            sceneNumber: 1, perspective: "Mara", location: "Bahnhof",
            goal: "Den Koffer vor dem Zug sichern", targetWordCount: 180
        )
        scene.text = text
        scene.obstacle = "Der Zug fährt ab und ein Fremder blockiert den Bahnsteig."
        scene.emotionalChange = "Mara entscheidet sich gegen die Flucht und bleibt."
        scene.status = .written
        return scene
    }

    func testCompleteConcreteChapterPassesEditorialScorecard() {
        let text = String(repeating:
            "Mara sprang über die Stufen. Der Koffer klemmte zwischen zwei Bänken. "
                + "Der Schaffner pfiff. Sie riss den Griff hoch und rannte zum letzten Waggon. ", count: 5)
        let card = ChapterEditorialScorecard.evaluate(
            chapterNumber: 1, text: text,
            goal: "Mara sichert den Koffer vor dem Zug.",
            conflict: "Ein Fremder versperrt ihr den Weg.",
            targetWordCount: text.wordCount,
            scenes: [completeScene(text: text)]
        )

        XCTAssertEqual(card.verdict, .ready)
        XCTAssertGreaterThanOrEqual(card.overall, ChapterEditorialScorecard.passThreshold)
        XCTAssertEqual(card.sceneCraft, 1.0, accuracy: 0.0001)
        XCTAssertGreaterThanOrEqual(card.momentum, 0.75)
    }

    func testMissingTurnAndConsequenceRequiresRevision() {
        let text = String(repeating:
            "Mara beobachtete den Bahnsteig und wartete. Der Fremde stand am anderen Ende. ", count: 8)
        let scene = StoryScene(
            sceneNumber: 1, perspective: "Mara", location: "Bahnhof",
            goal: "Den Fremden am Bahnsteig beobachten", targetWordCount: text.wordCount
        )
        scene.text = text
        scene.obstacle = "Der Fremde bleibt außer Reichweite."
        scene.status = .written

        let card = ChapterEditorialScorecard.evaluate(
            chapterNumber: 2, text: text,
            goal: "Mara beobachtet den Fremden am Bahnsteig.",
            conflict: "Der Fremde bleibt für Mara unerreichbar.",
            targetWordCount: text.wordCount, scenes: [scene]
        )

        XCTAssertEqual(card.verdict, .revise)
        XCTAssertLessThan(card.momentum, 0.75)
        XCTAssertTrue(card.findings.contains { $0.contains("Wendung oder Folge") })
    }

    func testFormulaicReactionClusterRequiresRevision() {
        let text = String(repeating:
            "Mara drehte sich um. Sie schüttelte den Kopf. Mara schloss die Augen. "
                + "Mara spürte, wie sich etwas in ihr verschob. ", count: 7)
        let card = ChapterEditorialScorecard.evaluate(
            chapterNumber: 2, text: text,
            goal: "Mara stellt den Fremden zur Rede.",
            conflict: "Der Fremde verweigert jede Antwort.",
            targetWordCount: text.wordCount,
            scenes: [completeScene(text: text)]
        )

        XCTAssertEqual(card.verdict, .revise)
        XCTAssertLessThan(card.prose, 0.75)
        XCTAssertFalse(card.findings.isEmpty)
    }

    func testTooShortChapterIsMarkedIncomplete() {
        let card = ChapterEditorialScorecard.evaluate(
            chapterNumber: 3, text: "Mara ging zur Tür.",
            goal: "Mara geht zur Tür.", conflict: "Die Tür ist verschlossen.",
            targetWordCount: 100, scenes: []
        )

        XCTAssertEqual(card.verdict, .incomplete)
        XCTAssertEqual(card.overall, 0)
    }
}
