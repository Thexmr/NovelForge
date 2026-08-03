import Foundation

@main
enum RegressionProbe {
    static func main() {
        let duplicates = ChapterEventDuplicateParser.parse(
            "DUPLICATE|2|1|Das Versteck wird erneut entdeckt.|Zeige die unmittelbare Folge."
        )
        precondition(duplicates.count == 1)
        precondition(duplicates[0].laterSceneNumber == 2)
        precondition(duplicates[0].earlierSceneNumber == 1)
        precondition(ChapterEventDuplicateParser.isConclusive("KEINE DOPPLUNG"))

        let references = ChapterSceneReferenceParser.parse(
            "Kapitel 3, Szene 1 & Kapitel 3, Szene 2"
        )
        precondition(references == [
            ChapterSceneReference(chapterNumber: 3, sceneNumber: 1),
            ChapterSceneReference(chapterNumber: 3, sceneNumber: 2),
        ])

        precondition(ProductionCompletionPolicy.shouldRequireReview(
            chapterTexts: ["Kapitel eins.", "Kapitel zwei."],
            readinessShortfall: true,
            retriesExhausted: true
        ))
        precondition(!ProductionCompletionPolicy.shouldRequireReview(
            chapterTexts: ["Kapitel eins.", ""],
            readinessShortfall: true,
            retriesExhausted: true
        ))

        // --- Wurzel der doppelt erzählten Szenen ---------------------------------
        // Gemessen an Buch 7: Ein Drittel aller Szenen bekam Standard-Beats und bei
        // allen vier Szenen eines Kapitels dasselbe Hindernis. Solche Pläne sind die
        // Ursache der Doppler und durch keine spätere Reparatur behebbar – Kapitel 2,
        // Szene 4 wurde achtmal neu geschrieben und blieb ein Doppler.
        func szene(_ n: Int, _ ziel: String, _ hindernis: String) -> PlannedScene {
            PlannedScene(number: n, perspective: "Lena", location: "Ort", time: "Zeit",
                         goal: ziel, obstacle: hindernis, turn: "Wende")
        }
        let standardBeats = [
            szene(1, "EINSTIEG: Die Perspektivfigur betritt die Ausgangslage.", "Lenas Wut gegen sein Schweigen."),
            szene(2, "KOMPLIKATION: Ausgehend vom Ende der vorigen Szene ein NEUER Vorstoß.", "Lenas Wut gegen sein Schweigen."),
            szene(3, "ZUSPITZUNG: Die Folgen zwingen die Figur zu einem Schritt.", "Lenas Wut gegen sein Schweigen."),
            szene(4, "WENDE UND ÜBERGANG: Eine Entscheidung bringt das Kapitel zum Höhepunkt.", "Lenas Wut gegen sein Schweigen."),
        ]
        precondition(AutonomousContentQuality.istGenerischerSzenenplan(standardBeats),
                     "Standard-Beats müssen als unbrauchbar erkannt werden")

        let konkret = [
            szene(1, "Lena findet hinter dem losen Stein den Leinenbeutel mit dem Kinderfoto.",
                  "Der Stein sitzt fest, jemand beobachtet sie vom Tor."),
            szene(2, "Jonas behauptet, das Foto gehöre ihm.", "Er sagt nicht, woher er es kennt."),
            szene(3, "Lena bricht in die Hütte ein, um den zweiten Beutel zu suchen.",
                  "Die Tür ist von innen verriegelt."),
            szene(4, "Der Pfarrer gesteht, das Foto vor zehn Jahren versteckt zu haben.",
                  "Er verlangt Schweigen als Gegenleistung."),
        ]
        precondition(!AutonomousContentQuality.istGenerischerSzenenplan(konkret),
                     "Konkreter Plan darf nicht als generisch gelten")

        // Gleiches Hindernis bei nur zwei Szenen ist kein Muster – kein Fehlalarm.
        precondition(!AutonomousContentQuality.istGenerischerSzenenplan([
            szene(1, "Lena öffnet die Bodenluke.", "Dunkelheit"),
            szene(2, "Jonas zieht sie zurück.", "Dunkelheit"),
        ]))

        // --- Genre-Abdrift erkennt Etabliertes an --------------------------------
        // Buch 7, Kapitel 1 enthielt „eine flüchtige Gestalt" vor dem Fenster. Jede
        // Reparatur, die daran anknüpfte, galt als Genre-Abdrift und war chancenlos.
        let etabliert = "Draußen glaubte sie eine flüchtige Gestalt vor dem Fenster zu sehen."
        precondition(AutonomousContentQuality.scenePlanGenreDriftMarkers(
            "Am Waldrand stand eine Gestalt und beobachtete sie heimlich.",
            genre: "Liebesroman", canon: "Eine Liebesgeschichte im Dorf."
        ).isEmpty == false, "Neue Thriller-Motive müssen anschlagen")
        precondition(AutonomousContentQuality.scenePlanGenreDriftMarkers(
            "Wieder sah sie die Gestalt vor dem Fenster stehen.",
            genre: "Liebesroman", canon: etabliert
        ).isEmpty, "Etabliertes Motiv darf nicht als Abdrift gelten")
        precondition(AutonomousContentQuality.scenePlanGenreDriftMarkers(
            "Die Gestalt vor dem Fenster erhob die Axt wie eine Waffe.",
            genre: "Liebesroman", canon: etabliert
        ).isEmpty == false, "Neues Motiv im selben Satz muss weiterhin anschlagen")

        print("NovelForge regression probe: PASS")
    }
}
