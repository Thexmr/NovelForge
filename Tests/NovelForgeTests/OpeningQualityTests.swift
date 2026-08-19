import XCTest
@testable import NovelForge

final class OpeningQualityTests: XCTestCase {
    func testMysteryStackIsRejectedBeforePersonalContext() {
        let text = """
        Am Morgen lag ein anonymer Brief auf dem Tisch. Daneben vibriert eine unbekannte Nachricht,
        die nur ein unbekanntes Foto enthält. In der alten Akte steht eine Drohung ohne Absender.
        Mara wusste, dass sie die verschlossene Tür nicht öffnen durfte.
        """

        let issues = AutonomousContentQuality.openingMysteryStackIssues(in: text)

        XCTAssertEqual(issues.count, 1)
        XCTAssertTrue(issues[0].contains("Mystery-Requisiten"))
        XCTAssertTrue(AutonomousContentQuality.finalOpeningIssues(
            in: text, protagonistNames: ["Mara"]
        ).contains { $0.contains("Mystery-Requisiten") })
    }

    func testGroundedHumanStartDoesNotTriggerMysteryStack() {
        let text = """
        Lea war zehn Minuten zu früh, was bei ihrer Schwester keine gute Idee war. Sie wartete im
        Café am Bahnhof, um mit Vera den Verkauf des Elternhauses zu unterschreiben. Auf dem Tisch
        lag die Mappe mit dem Vertrag, und Lea nahm sich vor, diesmal nicht über die alten Streits
        zu sprechen. Als Vera nicht kam, fragte Lea sich, ob sie wieder nur weglief.
        """

        XCTAssertTrue(AutonomousContentQuality.openingMysteryStackIssues(in: text).isEmpty)
        XCTAssertFalse(AutonomousContentQuality.finalOpeningIssues(
            in: text, protagonistNames: ["Lea", "Vera"]
        ).contains { $0.contains("Mystery-Requisiten") })
    }

    func testOpeningPromptDemandsGroundedSituationBeforeDisruption() {
        let prompt = PromptFactory.openingHook(
            language: "Deutsch", bookTitle: "Test", genre: "Psychologischer Thriller",
            chapterText: "Lea wartete im Café auf ihre Schwester."
        )

        XCTAssertTrue(prompt.contains("Alltagssituation"))
        XCTAssertTrue(prompt.contains("Rätsel-Stapel"))
        XCTAssertTrue(prompt.contains("persönlichen Konflikt"))
    }
}
