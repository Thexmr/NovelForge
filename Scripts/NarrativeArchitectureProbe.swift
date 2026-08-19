import Foundation

@main
enum NarrativeArchitectureProbe {
    private static func scene(_ number: Int, location: String, goal: String,
                              obstacle: String, turn: String) -> PlannedScene {
        PlannedScene(number: number, perspective: "Alva", location: location,
                     time: "Nacht", goal: goal, obstacle: obstacle, turn: turn)
    }

    static func main() {
        let tunnelLoop: [(kapitel: Int, szenen: [PlannedScene])] = [
            (7, [scene(1, location: "Abgeschalteter U-Bahn-Tunnel",
                       goal: "Alva flieht mit Hagedorn durch den Tunnel",
                       obstacle: "Ostwald verfolgt sie durch den Schacht",
                       turn: "Sie waehlt einen unbekannten Abzweig")]),
            (8, [scene(1, location: "Derselbe U-Bahn-Tunnel",
                       goal: "Alva will Ostwald im Tunnel entkommen",
                       obstacle: "Das Handy verraet ihren Standort an den Verfolger",
                       turn: "Sie zerstoert das Handy und flieht weiter")]),
            (9, [scene(1, location: "U-Bahn-Tunnel, Wartungsnische",
                       goal: "Alva fuehrt Hagedorn weiter auf der Flucht",
                       obstacle: "Ostwald verfolgt beide und spricht Alva an",
                       turn: "Sie verstecken sich im naechsten Schacht")]),
        ]
        precondition(!EreignisRegister.stagnierendeSequenzen(imBuchplan: tunnelLoop).isEmpty,
                     "Drei Kapitel derselben Tunnel-Flucht muessen vor der Rohfassung auffallen")

        let houseWithProgress: [(kapitel: Int, szenen: [PlannedScene])] = [
            (1, [scene(1, location: "Familienhaus, Kueche",
                       goal: "Mara oeffnet den Brief ihres Vaters",
                       obstacle: "Joris will den Umschlag an sich nehmen",
                       turn: "Sie findet die Kontonummer")]),
            (2, [scene(1, location: "Familienhaus, Arbeitszimmer",
                       goal: "Mara vergleicht die Unterschrift mit dem Vertrag",
                       obstacle: "Die Originalakte fehlt im Schrank",
                       turn: "Sie erkennt ihre eigene Unterschrift")]),
            (3, [scene(1, location: "Familienhaus, Eingang",
                       goal: "Mara uebergibt der Kommission den Vertrag",
                       obstacle: "Joris versperrt ihr die Tuer",
                       turn: "Sie sagt gegen ihn und gegen sich selbst aus")]),
        ]
        precondition(EreignisRegister.stagnierendeSequenzen(imBuchplan: houseWithProgress).isEmpty,
                     "Ein wiederkehrender Ort mit klar wechselnder Handlung ist kein Stillstand")

        let nameHeavy = (0..<22).map { index in
            "Alva erledigte Schritt \(index + 1), waehrend der Raum und ihr Ziel sich konkret veraenderten. "
                + "Danach pruefte sie die naechste Folge und traf eine neue Entscheidung."
        }.joined(separator: "\n\n")
        let nameFindings = AutonomousContentQuality.characterNameOveruseFindings(
            inChapters: [nameHeavy], characterNames: ["Alva Reineke"]
        )
        precondition(!nameFindings.isEmpty,
                     "Mechanische Namensdichte ueber viele kurze Absaetze muss erkannt werden")

        let naturalReferences = """
        Alva stellte den Becher ab. Sie wartete, bis Henning die Tuer geschlossen hatte.

        Im Flur blieb der Kaffeefleck zurueck. Erst dann nahm sie die Akte aus dem Schrank.

        Sie schrieb die Uhrzeit auf und rief ihre Schwester an.
        """
        precondition(AutonomousContentQuality.characterNameOveruseFindings(
            inChapters: [naturalReferences], characterNames: ["Alva Reineke"]
        ).isEmpty, "Natuerliche Referenzwechsel duerfen keinen Namensbefund erzeugen")

        let mixedTense = """
        Der Becher kuehlt in ihrer Hand. Alva stand im Flur und merkte erst jetzt,
        dass sie nicht atmete. Sie holte Luft, trat zum Telefon und blieb davor stehen.
        """
        precondition(!AutonomousContentQuality.narrativeTenseIssues(
            in: mixedTense, expectedTense: "Praeteritum"
        ).isEmpty, "Ein Praesens-Neustart in einer Praeteritum-Szene muss auffallen")
        let mixedTenseWithUmlaut = """
        Der Becher kühlt in ihrer Hand. Alva stand im Flur, öffnete die Tür und merkte,
        dass sie nicht atmete. Sie holte Luft, trat zum Telefon und blieb davor stehen.
        """
        precondition(!AutonomousContentQuality.narrativeTenseIssues(
            in: mixedTenseWithUmlaut, expectedTense: "Präteritum"
        ).isEmpty, "Deutsche Umlaute duerfen die Tempuspruefung nicht umgehen")

        let stablePast = """
        Der Becher kuehlte in ihrer Hand ab. Alva stand im Flur und merkte erst jetzt,
        dass sie nicht atmete. Sie holte Luft, trat zum Telefon und blieb davor stehen.
        """
        precondition(AutonomousContentQuality.narrativeTenseIssues(
            in: stablePast, expectedTense: "Praeteritum"
        ).isEmpty, "Durchgehendes Praeteritum muss freigegeben werden")

        let lateSceneBreak = String(repeating: "Alva ging durch den Flur. ", count: 90)
            + "\n\n***\n\n" + mixedTense
        precondition(!AutonomousContentQuality.narrativeTenseIssuesAcrossSections(
            in: lateSceneBreak, expectedTense: "Praeteritum"
        ).isEmpty, "Ein Tempusbruch nach einem Szenentrenner darf der Endabnahme nicht entgehen")
        let lateParagraphBreak = String(repeating: "Alva ging durch den Flur. ", count: 90)
            + "\n\n" + mixedTense
        precondition(!AutonomousContentQuality.narrativeTenseIssuesAcrossSections(
            in: lateParagraphBreak, expectedTense: "Praeteritum"
        ).isEmpty, "Ein spaeter Tempus-Neustart muss auch ohne erhaltenen Szenenmarker auffallen")

        let unresolvedEnding = PlannedChapter(
            number: 12, title: "Gelb hinter Glas",
            goal: "Alva ueberlebt, doch die zentrale Frage bleibt offen.",
            conflict: "Die Geschichte endet nicht mit einer Antwort, sondern mit der Frage selbst.",
            cause: "FOLGE AUS KAPITEL 11: Alva sitzt im Polizeirevier.",
            decision: "Alva wartet und denkt rueckwaerts.",
            outcome: "Die naechste Nacht koennte erneut beginnen; es gibt keine Aufloesung.",
            emotionalStep: "Erleichterung kippt in die Schwere des Dauernden."
        )
        precondition(!AutonomousContentQuality.finalChapterResolutionIssues(unresolvedEnding).isEmpty,
                     "Ein absichtlich unbeantwortetes Romanende darf nicht als Aufloesung gelten")

        let earnedEnding = PlannedChapter(
            number: 12, title: "Der erste Morgen",
            goal: "Alva sagt gegen Ostwald aus und beendet seine Kontrolle.",
            conflict: "Die Aussage kostet sie ihre Anonymitaet und Hagedorns Vertrauen.",
            cause: "FOLGE AUS KAPITEL 11: Die Beweise reichen fuer eine Aussage.",
            decision: "Alva nennt der Ermittlerin alle Fakten, obwohl sie selbst belastet wird.",
            outcome: "Ostwald kommt in Untersuchungshaft; Alva verlaesst das Revier bei Tageslicht.",
            emotionalStep: "Sie gibt Kontrolle auf und waehlt Verantwortung ohne schnelle Erleichterung."
        )
        precondition(AutonomousContentQuality.finalChapterResolutionIssues(earnedEnding).isEmpty,
                     "Eine konkrete, bezahlte Aufloesung muss freigegeben werden")

        let weakButRepairableEnding = PlannedChapter(
            number: 12, title: "Der letzte Brief",
            goal: "Karin stellt sich der letzten Entscheidung um den Leuchtturm.",
            conflict: "Die Wahrheit kostet sie die Kontrolle ueber das Ergebnis.",
            cause: "FOLGE AUS KAPITEL 11: Der Notverkauf beginnt am naechsten Morgen.",
            decision: "Karin liest den Brief vor und widerspricht dem Verkauf vor allen Beteiligten.",
            outcome: "Alle sehen schweigend zum dunklen Turm hinüber.",
            emotionalStep: "Karin laesst erstmals ein unkontrollierbares Ergebnis zu."
        )
        let canonicalEnding = AutonomousContentQuality.finalChapterUsingCanonicalResolution(
            weakButRepairableEnding,
            previous: nil,
            resolutionBeat: "Der Turm bleibt erhalten; Karin beginnt mit Peter ein gemeinsames Leben."
        )
        precondition(AutonomousContentQuality.finalChapterResolutionIssues(canonicalEnding).isEmpty,
                     "Ein vollstaendiger Plan muss mit seinem kanonischen Aufloesungs-Beat rettbar sein")
        precondition(canonicalEnding.outcome.contains("Der Turm bleibt erhalten"),
                     "Die letzte Instanz darf keine generische Aufloesung erfinden")
        let stillUnresolved = AutonomousContentQuality.finalChapterUsingCanonicalResolution(
            unresolvedEnding,
            previous: nil,
            resolutionBeat: "Alva wartet weiter."
        )
        precondition(!AutonomousContentQuality.finalChapterResolutionIssues(stillUnresolved).isEmpty,
                     "Ein ausdruecklich offenes Ende darf nicht automatisch ueberschrieben werden")

        let completePlan = [
            PlannedChapter(
                number: 1, title: "Der Fund",
                goal: "Alva findet die Akte und beschliesst, selbst zu ermitteln.",
                conflict: "Ostwald fordert die Akte zurueck.",
                cause: "Alva findet die Akte im Schrank.",
                decision: "Sie behaelt eine Kopie und ruft Hagedorn an.",
                outcome: "Ostwald erkennt ihren Verdacht und setzt sie unter Druck.",
                emotionalStep: "Vorsicht wird zu offenem Misstrauen."
            ),
            PlannedChapter(
                number: 2, title: "Ohne Schutz",
                goal: "Alva uebergibt Hagedorn die Kopie und verliert ihren sicheren Rueckweg.",
                conflict: "Hagedorn glaubt ihr nur gegen eine offizielle Aussage.",
                cause: "Ostwald setzt Alva unter Druck.",
                decision: "Sie sagt Hagedorn die Wahrheit ueber ihre eigene Beteiligung.",
                outcome: "Die Aussage liefert den fehlenden Zusammenhang, belastet aber Alva.",
                emotionalStep: "Misstrauen wird zur riskanten Zusammenarbeit."
            ),
            PlannedChapter(
                number: 3, title: earnedEnding.title, goal: earnedEnding.goal,
                conflict: earnedEnding.conflict,
                cause: "Die Aussage aus Kapitel 2 ermoeglicht Ostwalds Festnahme.",
                decision: earnedEnding.decision,
                outcome: "AUFLÖSUNG: " + earnedEnding.outcome
                    + " Sie verliert ihre Anonymitaet und beginnt ein neues Leben.",
                emotionalStep: earnedEnding.emotionalStep
            ),
        ]
        precondition(AutonomousContentQuality.chapterPlanReleaseIssues(
            completePlan, expectedCount: 3, isNonfiction: false
        ).isEmpty, "Ein vollstaendiger, konkreter Plan darf nicht an einer Etikett-Heuristik pausieren")

        let planWithGap = [completePlan[0], completePlan[2]]
        precondition(!AutonomousContentQuality.chapterPlanReleaseIssues(
            planWithGap, expectedCount: 3, isNonfiction: false
        ).isEmpty, "Eine explizite Kapitelluecke muss die Freigabe weiterhin blockieren")

        let unresolvedFinal = PlannedChapter(
            number: 3, title: unresolvedEnding.title, goal: unresolvedEnding.goal,
            conflict: unresolvedEnding.conflict, cause: unresolvedEnding.cause,
            decision: unresolvedEnding.decision, outcome: unresolvedEnding.outcome,
            emotionalStep: unresolvedEnding.emotionalStep
        )
        let unresolvedPlan = [completePlan[0], completePlan[1], unresolvedFinal]
        precondition(!AutonomousContentQuality.chapterPlanReleaseIssues(
            unresolvedPlan, expectedCount: 3, isNonfiction: false
        ).isEmpty, "Ein ungelöstes Ende muss die Freigabe weiterhin blockieren")

        print("NovelForge narrative architecture probe: PASS")
    }
}
