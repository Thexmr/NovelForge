import XCTest
@testable import NovelForge

/// Nagelt die Abbruchbedingungen der Endabnahme-Reparatur fest.
///
/// Hintergrund: An einem fertig geschriebenen Buch (46 Kapitel, 100.260 Wörter) lief
/// die Reparatur bis Runde 329 über 3 Stunden 51 Minuten – Anzeige durchgehend
/// „0 von 1 behoben". Der Token-Zähler stand dabei seit dreieinhalb Stunden exakt
/// still: Es wurde gar kein Modell mehr aufgerufen. Die verbliebene Beanstandung
/// gehörte zu keiner der drei reparierbaren Arten, die innere Schleife brach deshalb
/// sofort ab – und die äußere Runde startete dieselbe Prüfung 15 Sekunden später
/// erneut. Übrig blieben Volltextscans über das ganze Manuskript bei 100 % CPU-Last.
final class ReadinessLoopTests: XCTestCase {

    func testNurDieDreiBehebbarenArtenRechtfertigenEineWiederholung() {
        // Genau diese drei kann die Reparatur anfassen.
        XCTAssertTrue(PipelineOrchestrator.hatReparierbareBeanstandung(
            ["Offene Qualitätsbefunde: 2 kritisch, 1 Fehler."]))
        XCTAssertTrue(PipelineOrchestrator.hatReparierbareBeanstandung(
            ["Kapitel 12 liegt über Zielumfang."]))
        XCTAssertTrue(PipelineOrchestrator.hatReparierbareBeanstandung(
            ["3 wiederholte ganze Sätze im Manuskript."]))
    }

    func testUnbehebbaresLoestKeineWiederholungAus() {
        // Das sind die Fälle, in denen sich der Lauf festgefressen hat: Kein
        // Reparaturschritt kann daran etwas ändern, also darf auch nicht wiederholt
        // werden – sonst dreht die äußere Runde endlos leer.
        let unbehebbar = [
            ["Impressum fehlt."],
            ["Klappentext fehlt."],
            ["Noch offene Pipeline-Jobs: 1."],
            ["Buchtitel ist ein Platzhalter, Genre-Label oder bekanntes Schablonenmuster."],
            ["Keine Kapitel vorhanden."],
        ]
        for fall in unbehebbar {
            XCTAssertFalse(PipelineOrchestrator.hatReparierbareBeanstandung(fall),
                           "\(fall) darf keine Reparaturrunde auslösen")
        }
    }

    func testGemischtWirdWiederholtSolangeEtwasBehebbaresDabeiIst() {
        // Ein unbehebbarer Punkt neben einem behebbaren blockiert die Reparatur nicht.
        XCTAssertTrue(PipelineOrchestrator.hatReparierbareBeanstandung(
            ["Impressum fehlt.", "2 wiederholte ganze Sätze im Manuskript."]))
    }

    func testLeereListeIstKeineBeanstandung() {
        XCTAssertFalse(PipelineOrchestrator.hatReparierbareBeanstandung([]))
    }

    func testDieBeidenFehlermarkenSindUnterscheidbar() {
        // Entscheidend: Der „nicht behebbar"-Fehler darf NICHT als wiederholbarer
        // Engpass durchgehen, sonst ist die Endlosschleife wieder da.
        let wiederholbar = AIError.systemError(
            "\(PipelineOrchestrator.readinessShortfallMarker): 2 wiederholte ganze Sätze.")
        let endgueltig = AIError.systemError(
            "\(PipelineOrchestrator.readinessUnfixableMarker): Impressum fehlt.")

        XCTAssertTrue(PipelineOrchestrator.isReadinessShortfall(wiederholbar))
        XCTAssertFalse(PipelineOrchestrator.isReadinessShortfall(endgueltig),
                       "Unbehebbares löste erneut eine Reparaturrunde aus")
    }

    func testOffenePunkteWerdenFuerDieAnzeigeHerausgeschaelt() {
        // Die Oberfläche zeigte über Stunden nur „0 von 1 behoben", ohne je zu sagen,
        // WELCHER Punkt offen war.
        let fehler = AIError.systemError(
            "\(PipelineOrchestrator.readinessShortfallMarker): Impressum fehlt.")
        let text = PipelineOrchestrator.offenePunkteText(fehler)
        XCTAssertEqual(text, "Impressum fehlt.")
        XCTAssertFalse(text.contains(PipelineOrchestrator.readinessShortfallMarker))
    }

    func testLangePunkteListeWirdFuerDieAnzeigeGekuerzt() {
        let lang = String(repeating: "Impressum fehlt. ", count: 40)
        let text = PipelineOrchestrator.offenePunkteText(
            AIError.systemError("\(PipelineOrchestrator.readinessShortfallMarker): \(lang)"))
        XCTAssertLessThanOrEqual(text.count, 160)
        XCTAssertTrue(text.hasSuffix("…"))
    }

    func testZeitgrenzeIstGesetztUndBegrenztDenBeobachtetenFall() {
        // Der beobachtete Lauf hatte nach 3 h 51 min noch immer nicht aufgehört.
        XCTAssertLessThan(PipelineOrchestrator.maxRepairDurationSeconds, 3 * 3600,
                          "Zeitgrenze muss unter der beobachteten Hängedauer liegen")
        XCTAssertGreaterThan(PipelineOrchestrator.maxRepairDurationSeconds, 10 * 60,
                             "Zu knapp – echte Reparaturen brauchen Zeit")
        // Und die Rundenzahl darf nicht wieder ins Unbegrenzte wachsen.
        XCTAssertLessThanOrEqual(PipelineOrchestrator.maxQualityRepairRounds, 10)
    }
}
