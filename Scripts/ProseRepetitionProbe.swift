import Foundation

@main
enum ProseRepetitionProbe {
    static func main() {
        let prior = [String](repeating: "Ihre Hand lag auf dem Tisch. Die Stimme blieb ruhig. Ihre Finger bewegten sich.", count: 7)
            .joined(separator: " ")
        let hits = AutonomousContentQuality.verliebteWoerter(
            candidate: "Ihre Hand verschwand in der Tasche. Die Stimme brach. Ein Finger zuckte.",
            priorTexts: [prior], grenze: 5
        )
        precondition(hits.contains(where: { $0.hasPrefix("hand") }),
                     "Uebernutzte Haende muessen als Prosakruecke erkannt werden")
        precondition(hits.contains(where: { $0.hasPrefix("stimme") }),
                     "Uebernutzte Stimmen muessen als Prosakruecke erkannt werden")
        precondition(hits.contains(where: { $0.hasPrefix("finger") }),
                     "Uebernutzte Finger muessen als Prosakruecke erkannt werden")

        let names = AutonomousContentQuality.verliebteWoerter(
            candidate: "Liv ging hinaus.",
            priorTexts: [[String](repeating: "Liv sagte es.", count: 20).joined(separator: " ")],
            grenze: 5, figurennamen: ["Liv Ellert"]
        )
        precondition(names.isEmpty, "Kanonische Figurennamen duerfen nie als Lieblingswort blockieren")

        let localHammering = AutonomousContentQuality.localContentWordOveruse(in: """
        Der Schluessel war warm. Das warme Metall lag in ihrer Hand. Noch immer warm,
        dachte sie, waehrend die Waerme in ihrer Hand blieb. Warm bedeutete, dass jemand
        gerade hier gewesen war.
        """)
        precondition(localHammering.contains(where: { $0.hasPrefix("warm") }),
                     "Ein einzelnes Motiv darf innerhalb derselben Szene nicht gehaemmert werden")
        precondition(AutonomousContentQuality.localContentWordOveruse(
            in: "Der Schluessel war warm. Spaeter legte sie ihn auf den Tisch."
        ).isEmpty, "Eine sparsame bewusste Motivwiederaufnahme muss erlaubt bleiben")
        let naturalPrefixes = AutonomousContentQuality.localContentWordOveruse(in: """
        Eine Schwester wartete unter dem Vordach. Nach einer Stunde wurde das schwere Tor
        geöffnet. Ihr Schwager schwieg, während eine Schwalbe unter dem Sims verschwand.
        Nach dem Essen trug eine Angestellte schwere Kisten unter die Treppe. Die Schwester
        nahm ihre Handschuhe und ging nach draußen. Eine Lampe hing über ihrer Hand.
        """)
        for falseStem in ["schw", "eine", "nach", "unte"] {
            precondition(!naturalPrefixes.contains(where: { $0.hasPrefix(falseStem) }),
                         "Unverwandte Woerter duerfen nicht zum Stamm \(falseStem) verschmelzen")
        }
        let connectiveWords = AutonomousContentQuality.localContentWordOveruse(in: """
        Ihre Schwester wartete, bevor ihre Mutter kam. Bevor ihre Mutter antwortete,
        nahm ihre Schwester den Mantel. Ihre Mutter blieb, bevor ihre Schwester ging.
        """)
        for falseStem in ["ihre", "bevo"] {
            precondition(!connectiveWords.contains(where: { $0.hasPrefix(falseStem) }),
                         "Funktionswort darf keinen Reparatur-Loop ausloesen: \(falseStem)")
        }
        let fragmentary = """
        Sie öffnete die Tür. Treppe, spiralförmig nach oben. Rechts der Gang zur Wohnung,
        Tür offen. Bett unter einer staubgrauen Plane. In der Küche kein Wasser, keine
        Heizung. Nur der Wind am Dach. Sie setzte sich auf den Stuhl.
        """
        precondition(AutonomousContentQuality.proseSentenceFragments(in: fragmentary).count >= 4,
                     "Eine gehaeufte Telegrammstil-Passage muss als Satzfragment-Prosa auffallen")
        let fragmentRepairs = AutonomousContentQuality.reparierbareStilSaetze(in: fragmentary)
        precondition(fragmentRepairs.filter {
            $0.grund.localizedCaseInsensitiveContains("Satzfragment")
        }.count >= 3,
        "Die Satz-Chirurgie muss gehaeufte Fragmente tatsaechlich zur Reparatur uebergeben")
        let fluent = """
        Sie öffnete die Tür und sah die Wendeltreppe vor sich. Rechts führte ein Gang zur
        Wohnung, deren Tür offen stand. Das Bett lag unter einer staubgrauen Plane. In der
        Küche gab es weder Wasser noch Heizung. Am Dach rüttelte nur der Wind.
        """
        precondition(AutonomousContentQuality.proseSentenceFragments(in: fluent).isEmpty,
                     "Vollstaendige, leicht lesbare Saetze duerfen nicht beanstandet werden")

        let repairSource = "„Du kommst mit“, sagte Mara. Jonas blieb am Fenster."
        let repairTicks = [
            (satz: "„Du kommst mit“, sagte Mara.", grund: "Stil-Tick"),
            (satz: "Jonas blieb am Fenster.", grund: "Stil-Tick"),
        ]
        let repaired = AutonomousContentQuality.applyingSentenceRepairs(
            to: repairSource,
            findings: repairTicks,
            response: """
            ERSATZ|1|„Komm mit“, sagte Mara.
            ERSATZ|1|„Du kommst mit“, sagte Mara.
            ERSATZ|2|Jonas wartete am Fenster.
            ERSATZ|2|Jonas wartete am Fenster.
            """
        )
        precondition(repaired.replacedCount == 2,
                     "Jede Satznummer darf hoechstens einmal als ersetzt zaehlen")
        precondition(repaired.text == "„Komm mit“, sagte Mara. Jonas wartete am Fenster.",
                     "Nur die erste gueltige eindeutige Ersetzung je Satz darf angewendet werden")

        let brokenDialogue = AutonomousContentQuality.applyingSentenceRepairs(
            to: repairSource,
            findings: repairTicks,
            response: "ERSATZ|1|„Komm mit?“?„, sagte Mara."
        )
        precondition(brokenDialogue.replacedCount == 0 && brokenDialogue.text == repairSource,
                     "Eine Satzreparatur mit beschaedigter Dialogtypografie muss verworfen werden")

        let mantraChapters = [
            "Mira hob den Arm. Die Narbe am Handgelenk brannte wieder. Dann ging sie.",
            "Am Bahnhof verdeckte Mira die Narbe am Handgelenk mit dem Aermel.",
            "Die Narbe am Handgelenk erinnerte sie im Gericht an den Schwur.",
            "Als die Narbe am Handgelenk sichtbar wurde, verstummte ihr Bruder.",
        ]
        let phraseBlocks = AutonomousContentQuality.blockingRepeatedPhrases(
            inChapters: mantraChapters
        )
        precondition(phraseBlocks.contains(where: {
            $0.localizedCaseInsensitiveContains("narbe am handgelenk")
        }), "Ein buchweit gehaemmertes Motiv muss die Veroeffentlichung blockieren")

        let emergingMantra = [
            "Mira verdeckte die Narbe am Handgelenk. Spaeter rieb sie erneut die Narbe am Handgelenk.",
            "Vor Gericht betrachtete Mira die Narbe am Handgelenk.",
        ]
        precondition(AutonomousContentQuality.blockingRepeatedPhrases(
            inChapters: emergingMantra,
            minimumChapters: 2,
            minimumOccurrences: 3
        ).contains(where: { $0.localizedCaseInsensitiveContains("narbe am handgelenk") }),
        "Die Produktion muss eine entstehende Lieblingsphrase vor dem vierten Einsatz erkennen")
        precondition(AutonomousContentQuality.repeatedPhraseCollisions(
            candidate: emergingMantra[1], priorTexts: [emergingMantra[0]]
        ).contains(where: { $0.localizedCaseInsensitiveContains("narbe am handgelenk") }),
        "Der Szenen-Gate muss genau die neu hinzugefuegte Lieblingsphrase zurueckweisen")

        let intentionalEcho = [
            "Am Anfang sagte sie: Das Band luegt nicht.",
            "Im Mittelteil fand sie den versteckten Brief.",
            "Am Ende verstand sie: Das Band luegt nicht.",
        ]
        precondition(AutonomousContentQuality.blockingRepeatedPhrases(
            inChapters: intentionalEcho
        ).isEmpty, "Ein zweimaliges bewusstes Echo muss erlaubt bleiben")

        let ordinarySyntax = [
            "Sie wusste, dass sie heute gehen musste.",
            "Er wusste, dass er den Schluessel verloren hatte.",
            "Mara wusste, dass sie ihm nicht folgen durfte.",
            "Jon wusste, dass er die Wahrheit sagen musste.",
        ]
        precondition(AutonomousContentQuality.blockingRepeatedPhrases(
            inChapters: ordinarySyntax
        ).isEmpty, "Reine grammatische Satzgerueste duerfen nicht als Textbaustein gelten")

        let hammeredName = """
        Mara oeffnete den Brief. Mara legte ihn auf den Tisch. Mara sah zum Fenster. Mara wartete,
        bis der Wagen hielt. Mara nahm ihre Jacke. Mara ging zur Tuer. Mara drehte sich noch einmal
        um. Mara steckte den Brief ein und verliess das Haus.
        """
        precondition(
            !AutonomousContentQuality.characterNameOveruseFindings(
                inChapters: [hammeredName], characterNames: ["Mara Feld"]
            ).isEmpty,
            "Gehaemmerte Figurennamen muessen als maschinelles Muster erkannt werden"
        )
        let naturalNames = """
        Mara oeffnete den Brief und legte ihn auf den Tisch. Am Fenster hielt ein Wagen. Sie nahm
        ihre Jacke, wartete noch einen Moment und ging dann zur Tuer. Dort drehte Mara sich um,
        steckte den Brief ein und verliess das Haus, bevor ihr Bruder zurueckkam.
        """
        precondition(
            AutonomousContentQuality.characterNameOveruseFindings(
                inChapters: [naturalNames], characterNames: ["Mara Feld"]
            ).isEmpty,
            "Natuerliche Namensnennung mit eindeutigen Pronomen darf nicht blockieren"
        )

        let vagueMachineProse = Array(repeating: """
        Etwas in ihr veraenderte sich, ohne dass sie sagen konnte, was es war. Es war,
        als wuerde etwas in ihr auf eine Art reagieren, die sie nicht benennen konnte.
        """, count: 10).joined(separator: " ")
        precondition(
            AutonomousContentQuality.soundsLikeAI(vagueMachineProse),
            "Gehaufte vage Benennungsvermeidung muss in der Endfassung blockieren"
        )
        let concreteModernProse = Array(repeating: """
        Mara legte den Brief auf den Tisch und strich die falsche Zahl durch. Ihr Bruder
        las die Rechnung, stellte zwei konkrete Fragen und rief danach den Notar an.
        """, count: 8).joined(separator: " ")
        precondition(
            !AutonomousContentQuality.soundsLikeAI(concreteModernProse),
            "Konkrete, klare Handlung darf nicht als maschinelle Prosa gelten"
        )
        print("NovelForge prose repetition probe: PASS")
    }
}
