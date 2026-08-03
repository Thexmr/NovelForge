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
/// Am MainActor, weil die geprüften Typen (PipelineOrchestrator, ProofService,
/// SpellCheckService) dort isoliert sind. Ohne das schlägt schon das Kompilieren
/// fehl – und das fiel lange nicht auf, weil der Test-Schritt der CI
/// `continue-on-error` setzt und dieser Mac kein XCTest hat.
@MainActor
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

    func testAbnahmeUndReparaturBeurteilenSatzdopplerGleich() {
        // Der teuerste Fehler des Ganzen: Die Abnahme blockierte nach einer eigenen
        // Filterregel, die Reparatur räumte nach blockingRepeatedSentences auf. Die
        // Reparatur verschont bewusst Wiederholungen INNERHALB eines Kapitels und kurze
        // Sätze in BENACHBARTEN Kapiteln – die Abnahme kannte diese Ausnahmen nicht.
        // Sie fand also Punkte, die kein Reparaturschritt je anfassen würde: ein Patt,
        // das sich nicht auflösen kann. Genau das ergab 329 Runden ohne einen einzigen
        // Modellaufruf.
        //
        // Zwei Kapitel, dieselbe kurze Zeile nebeneinander – ein Leitmotiv, kein Fehler.
        let leitmotiv = "Lena blieb stehen, die Hand an der Klinke."
        let kapitel = [
            "Der Flur roch nach kaltem Rauch. \(leitmotiv) Dahinter war es still.",
            "Sie kam am Abend zurück. \(leitmotiv) Diesmal drückte sie sie herunter.",
        ]
        XCTAssertTrue(AutonomousContentQuality.blockingRepeatedSentences(inChapters: kapitel).isEmpty,
                      "Kurzes Leitmotiv in Nachbarkapiteln darf die Freigabe nicht blockieren")
    }

    func testWeitAuseinanderliegendeLangeDopplerBlockierenWeiterhin() {
        // Die Lockerung darf keine echten Copy-Paste-Doppler durchlassen.
        let lang = "Der Regen schlug seit Stunden gegen die Scheiben des alten Bahnhofsgebäudes."
        var kapitel = Array(repeating: "Ein unauffälliger Absatz ohne Wiederholungen.", count: 9)
        kapitel[0] = "Sie wartete. \(lang) Niemand kam."
        kapitel[8] = "Jahre später. \(lang) Wieder kam niemand."
        XCTAssertFalse(AutonomousContentQuality.blockingRepeatedSentences(inChapters: kapitel).isEmpty,
                       "Langer wortgleicher Satz über acht Kapitel Abstand muss blockieren")
    }

    func testZeitgrenzeIstGesetztUndBegrenztDenBeobachtetenFall() {
        // Der beobachtete Lauf hatte nach 3 h 51 min noch immer nicht aufgehört.
        XCTAssertLessThan(PipelineOrchestrator.maxRepairDurationSeconds, 3 * 3600,
                          "Zeitgrenze muss unter der beobachteten Hängedauer liegen")
        XCTAssertGreaterThan(PipelineOrchestrator.maxRepairDurationSeconds, 10 * 60,
                             "Zu knapp – echte Reparaturen brauchen Zeit")
        // Und die Rundenzahl darf nicht wieder ins Unbegrenzte wachsen.
        XCTAssertLessThanOrEqual(PipelineOrchestrator.maxQualityRepairRounds, 3,
                                 "Gemessen wurde in 329 Runden null behobene Punkte – mehr als drei Anläufe sind belegbar sinnlos")
    }

    func testVollstaendigesManuskriptWirdNachReparaturgrenzeNichtZumProduktionsfehler() {
        XCTAssertTrue(ProductionCompletionPolicy.shouldRequireReview(
            chapterTexts: ["Ein vollständiges erstes Kapitel.", "Ein vollständiges zweites Kapitel."],
            readinessShortfall: true,
            retriesExhausted: true
        ))
        XCTAssertFalse(ProductionCompletionPolicy.shouldRequireReview(
            chapterTexts: ["Ein vollständiges Kapitel.", ""],
            readinessShortfall: true,
            retriesExhausted: true
        ))
    }

    func testReviewStatusIsVisibleAndNotAFailure() {
        XCTAssertEqual(ProjectStatus.needsReview.displayName, "Prüfung erforderlich")
        XCTAssertNotEqual(ProjectStatus.needsReview, .failed)
    }
}
