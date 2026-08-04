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

        // --- Erzählperspektive ---------------------------------------------------
        // Eine Szene, die mitten im Buch in die Ich-Form kippt, fällt jedem Leser auf.
        // Eingebettete Briefe sind KEIN Bruch: „Wo wir zuletzt tanzten", Kapitel 6
        // Szene 3 rahmt Jonas' Brief korrekt in dritter Person. Ohne diese Ausnahme
        // hätte die Prüfung eine der stärksten Szenen des Buches verworfen.
        let durchgehendIch = """
        Ich schob den Schlüssel in die Tasche. Der Stoff sackte nach unten, als würde er mich \
        nach vorne ziehen. Ich blieb stehen und sah mich um. Mein Atem ging flach. Ich wusste, \
        dass ich hier nicht bleiben konnte, und mir war klar, was mich erwartete. Ich griff nach \
        meiner Jacke, zog sie über und trat hinaus. Mir war kalt. Ich dachte an meine Mutter und \
        daran, was ich ihr nie gesagt hatte. Mein Weg führte mich zum Fluss, ich ging langsam.
        """
        precondition(AutonomousContentQuality.brichtErzaehlperspektive(
            durchgehendIch, perspektive: "Personaler Erzähler (Er/Sie)"),
            "Durchgehende Ich-Erzählung muss als Perspektivbruch gelten")
        precondition(!AutonomousContentQuality.brichtErzaehlperspektive(
            durchgehendIch, perspektive: "Ich-Erzähler (Erste Person)"),
            "Bei Ich-Vorgabe darf die Prüfung nie anschlagen")

        let briefSzene = """
        Lena betrat den stillen Seesaal, ihre Schritte knackten auf den alten Dielen. Am Flügel \
        setzte sie sich, wo einst ihre Noten gelegen hatten. Der Umschlag in ihrer Hand wog schwer. \
        Sie öffnete ihn mit einem leisen Riss.

        Lena, ich schreibe dir im Zug nach Hamburg. Ich habe den Brief nicht abgeschickt. \
        Vielleicht, weil es zu spät ist. Vielleicht, weil ich Angst habe. Ich ging nicht, weil ich \
        nicht wollte. Ich ging, weil ich nicht wusste, wie ich bleiben sollte.

        Lena strich über die Zeilen, als könnte sie die Worte ungeschehen machen. Doch das Papier \
        blieb stumm. Sie legte den Brief auf die vergilbten Notenblätter und schloss den Deckel.
        """
        precondition(!AutonomousContentQuality.brichtErzaehlperspektive(
            briefSzene, perspektive: "Personaler Erzähler (Er/Sie)"),
            "Eingebetteter Brief mit Rahmen in dritter Person ist kein Perspektivbruch")

        // --- Szenengröße ----------------------------------------------------------
        // Ein Szenenziel unter ~400 Wörtern ist unerfüllbar: Gemessen am Testbuch
        // schrieb das Modell bei 287–312 Wörtern Vorgabe tatsächlich 451–696 (Faktor
        // bis 2,43). Die Folge waren 38 von 125 Warnungen eines einzigen Laufs, alle
        // aus derselben Quelle – „Verdichtung nach drei Versuchen verworfen".
        for seiten in [50, 110, 250, 500, 1000] {
            let plan = LongFormProductionPlan(pageCount: seiten)
            precondition(plan.targetWordsPerScene >= 400,
                         "\(seiten) Seiten: Szenenziel \(plan.targetWordsPerScene) Wörter ist unerfüllbar")
            precondition(plan.targetWordsPerScene <= 900,
                         "\(seiten) Seiten: Szenenziel \(plan.targetWordsPerScene) Wörter ist zu groß")
            precondition(plan.scenesPerChapter >= 2,
                         "\(seiten) Seiten: zu wenige Szenen je Kapitel")
        }

        print("NovelForge regression probe: PASS")
    }
}
