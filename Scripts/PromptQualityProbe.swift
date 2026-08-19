import Foundation

@main
enum PromptQualityProbe {
    static func main() {
        let rules = PromptFactory.humanCraftRules
        for harmful in [
            "Mindestens jeder fünfzehnte Satz",
            "Füllwörter sind erlaubt und erwünscht",
            "MENSCHLICHE DENKFEHLER",
            "KÖRPER VERGESSEN VERBOTEN",
            "BANALES OHNE BEDEUTUNG"
        ] {
            precondition(!rules.localizedCaseInsensitiveContains(harmful),
                         "Mechanische Menschlichkeits-Simulation muss entfernt sein: \(harmful)")
        }
        precondition(rules.localizedCaseInsensitiveContains("Satzlänge folgt"))
        precondition(rules.localizedCaseInsensitiveContains("kausal"))
        precondition(rules.localizedCaseInsensitiveContains("Szenenziel"))
        let sensory = AutonomousContentQuality.sinnesUndAssoziationsBrief(
            chapterNumber: 2, sceneNumber: 3
        )
        for harmful in ["ASSOZIATIONS-PFLICHT", "BANALE ABLENKUNG", "nichts mit der Handlung zu tun"] {
            precondition(!sensory.localizedCaseInsensitiveContains(harmful),
                         "Erzwungene Seltsamkeit muss aus dem Szenenprompt verschwinden: \(harmful)")
        }
        precondition(sensory.localizedCaseInsensitiveContains("Figur"))
        precondition(sensory.localizedCaseInsensitiveContains("Handlung"))

        let draftSystem = PromptFactory.draftingSystemCraftRules
        precondition(draftSystem.localizedCaseInsensitiveContains("funktionale Prosa"),
                     "Der Schreiber muss einfache Trageprosa ausdruecklich erlauben")
        precondition(draftSystem.localizedCaseInsensitiveContains("nicht jeder Satz"),
                     "Nicht jede Zeile darf auf Bedeutung oder Effekt getrimmt werden")
        precondition(draftSystem.localizedCaseInsensitiveContains("Satzfragmente"),
                     "Der Schreibauftrag muss gehaeuften Telegrammstil ausdruecklich vermeiden")
        let romanceCraft = PromptFactory.genreCraft("Liebesroman")
        precondition(!romanceCraft.localizedCaseInsensitiveContains("pro Begegnung mindestens"),
                     "Romantik darf nicht mit einer mechanischen Sinnesdetail-Quote erzeugt werden")

        let namelessConcept = PromptFactory.concept(
            title: "Test", genre: "Liebesroman", subgenre: nil, language: "Deutsch",
            style: "modern", tonality: "warm", audience: "Erwachsene",
            perspective: "Personal", tense: "Praeteritum", pageCount: 250,
            ideaSeed: "Eine Restauratorin trifft ihre Jugendliebe am Leuchtturm."
        )
        precondition(namelessConcept.localizedCaseInsensitiveContains("noch KEINE Personennamen"),
                     "Das Konzept darf die zentrale Namensvergabe nicht vorwegnehmen")
        let namedConcept = PromptFactory.concept(
            title: "Test", genre: "Liebesroman", subgenre: nil, language: "Deutsch",
            style: "modern", tonality: "warm", audience: "Erwachsene",
            perspective: "Personal", tense: "Praeteritum", pageCount: 250,
            ideaSeed: "Die Physiotherapeutin Liv Ellert kehrt zurueck. Dort trifft Liv ihren Bruder Tjark."
        )
        precondition(namedConcept.localizedCaseInsensitiveContains("Ergaenze keinen Vor- oder Nachnamen"),
                     "Seed-Namen muessen im Konzept exakt stabil bleiben")

        let plotPrompt = PromptFactory.plot(
            title: "Test", genre: "Liebesroman", style: "modern",
            concept: "Eine Heimkehrerin trifft ihre Jugendliebe wieder.",
            pageCount: 50, chapterCount: 12
        )
        precondition(plotPrompt.contains("PLOT_ENDE"),
                     "Jede frische Plotantwort braucht einen eindeutigen Abschlussmarker")
        precondition(plotPrompt.localizedCaseInsensitiveContains("höchstens 1.800 Wörter")
                     || plotPrompt.localizedCaseInsensitiveContains("hoechstens 1.800 Woerter"),
                     "Die Plotarchitektur braucht ein begrenztes Ausgabebudget statt Endlosprosa")
        precondition(plotPrompt.localizedCaseInsensitiveContains("Beruf")
                     && plotPrompt.localizedCaseInsensitiveContains("unverändert"),
                     "Der Plot darf feste Konzeptfakten wie den Beruf nicht austauschen")
        let canonAudit = PromptFactory.plotCanonAudit(
            concept: "Die Hauptfigur ist Grafikdesignerin.",
            plot: "Die Hauptfigur gibt ihre Arbeit als Übersetzerin auf."
        )
        precondition(canonAudit.contains("Grafikdesignerin")
                     && canonAudit.contains("Übersetzerin"))
        precondition(canonAudit.contains("WIDERSPRUCH|"),
                     "Die Plot-Kanonpruefung braucht ein deterministisch lesbares Format")
        precondition(
            PlotCanonAuditParser.parse(
                "WIDERSPRUCH|Beruf wechselte von Grafikdesignerin zu Übersetzerin."
            ) == ["Beruf wechselte von Grafikdesignerin zu Übersetzerin."],
            "Ein konkreter Kanonwiderspruch muss den naechsten Plotversuch steuern"
        )
        precondition(PlotCanonAuditParser.parse("OK").isEmpty,
                     "Ein bestaetigter konsistenter Plot darf weiterlaufen")
        let verifiedSource = "Konzept: Grafikdesignerin. Plot: Übersetzerin."
        precondition(
            VerifiedCanonAuditParser.parse(
                "WIDERSPRUCH|Hauptfigur|Beruf|Grafikdesignerin|Übersetzerin",
                source: verifiedSource
            ) == ["Hauptfigur / Beruf: Grafikdesignerin <> Übersetzerin"],
            "Nur zwei im Kanon belegte Fakten duerfen einen Widerspruch ausloesen"
        )
        precondition(
            VerifiedCanonAuditParser.parse(
                "WIDERSPRUCH|Hauptfigur|Name|Marta|Theresa",
                source: verifiedSource
            ).isEmpty,
            "Halluzinierte Namen des Pruefmodells duerfen keinen Retry ausloesen"
        )
        precondition(
            VerifiedCanonAuditParser.parse(
                "WIDERSPRUCH|Hauptfigur|Beruf|freie Grafikdesignerin|"
                    + "entwirft ein Logo für das geplante Atelier",
                source: "Sie ist freie Grafikdesignerin und entwirft ein Logo für das geplante Atelier."
            ).isEmpty,
            "Eine berufstypische Tätigkeit ist kein zweiter Beruf"
        )
        precondition(
            VerifiedCanonAuditParser.parse(
                "WIDERSPRUCH|Peter Reuter|Beziehung zu Ingeborg Deckers|"
                    + "Ingeborg Deckers vertraute ihm den Turm an|"
                    + "die Mutter zieht nicht ins Pflegeheim",
                source: "Ingeborg Deckers vertraute ihm den Turm an. Später entscheidet sich: "
                    + "die Mutter zieht nicht ins Pflegeheim, sondern in die Leuchtturmwohnung."
            ).isEmpty,
            "Zwei belegte, aber logisch unverbundene Beziehungssaetze duerfen keinen Retry ausloesen"
        )
        let ensembleAudit = PromptFactory.characterCanonAudit(
            concept: "Eine Grafikdesignerin trifft einen Zimmermann.",
            plot: "Die Nachbarin hilft; eine Investorin will den Turm kaufen.",
            characters: "FIGUR|Tereza Kliem|Nachbarin|Leuchtturmpächterin|...\n"
                + "FIGUR|Ruzena Hantusch|Antagonistin|Projektkoordinatorin|"
                + "will den Turm für ihre Investoren-Freundin Tereza kaufen"
        )
        precondition(ensembleAudit.contains("Tereza Kliem")
                     && ensembleAudit.contains("Investoren-Freundin"))
        precondition(ensembleAudit.contains("WIDERSPRUCH|"),
                     "Das Figurenensemble braucht einen maschinenlesbaren Kanonabgleich")
        precondition(
            AutonomousContentQuality.plotCompletionIssues(
                "BEAT|Ausloeser|Der Brief kommt.\nPLOT_ENDE", finishReason: "stop"
            ).isEmpty,
            "Ein technisch sauber abgeschlossener Plot muss freigegeben werden"
        )
        precondition(
            !AutonomousContentQuality.plotCompletionIssues(
                "BEAT|Ausloeser|Der Brief kommt.", finishReason: "stop"
            ).isEmpty,
            "Ein Plot ohne Abschlussmarker darf nach dem Retry-Loop nicht gespeichert werden"
        )
        precondition(
            !AutonomousContentQuality.plotCompletionIssues(
                "BEAT|Ausloeser|Der Brief kommt.\nPLOT_ENDE", finishReason: "length"
            ).isEmpty,
            "Ein am Tokenlimit beendeter Plot bleibt trotz Marker technisch unvollstaendig"
        )
        precondition(
            !AutonomousContentQuality.plotCompletionIssues(
                "BEAT|Ausloeser|Der Brief kommt und dann", finishReason: nil
            ).isEmpty,
            "Der reale mitten im Satz gespeicherte Plot muss reproduzierbar blockieren"
        )

        let draftPrompt = PromptFactory.draftScene(
            language: "Deutsch", style: "modern", tonality: "nah",
            perspective: "Personaler Erzaehler", tense: "Praeteritum",
            genre: "Thriller", bookTitle: "Test", chapterNumber: 2,
            chapterTitle: "Der Anruf", chapterGoal: "Mara muss Joris erreichen.",
            sceneNumber: 1, sceneGoal: "Mara ruft Joris an.",
            sceneLocation: "Kueche", sceneTime: "Abend",
            sceneObstacle: "Er weicht aus.", sceneTurn: "Er legt auf.",
            scenePerspective: "Mara", charactersSummary: "Mara Feld, Joris Feld",
            styleRules: "", storySoFar: "Mara fand den Brief.",
            previousSceneEnding: "Sie nahm das Telefon.",
            isFirstScene: false, isFinalScene: false, targetWords: 800
        )
        for mechanicalRule in [
            "Höchstens zwei von drei Fragen", "Hoechstens zwei von drei Fragen",
            "Etwa ein Viertel bis ein Drittel", "Emotion NIE benennen",
            "EIN Vergleich je zehn Buchseiten", "Jede Szene braucht eine Stelle"
        ] {
            precondition(!draftPrompt.localizedCaseInsensitiveContains(mechanicalRule),
                         "Mechanische Prosaquote muss aus dem Szenenauftrag verschwinden: \(mechanicalRule)")
        }

        let romanPlan = PromptFactory.scenePlan(
            bookTitle: "Test", chapterNumber: 2, chapterTitle: "Die Entscheidung",
            chapterGoal: "Mara muss den einzigen sicheren Weg verlassen.",
            chapterConflict: "Der direkte Weg gefaehrdet ihren Bruder.",
            perspective: "Personaler Erzaehler", plotContext: "Romanplot",
            targetWords: 2400, scenesPerChapter: 4
        )
        precondition(romanPlan.localizedCaseInsensitiveContains("genau 4 Szenen"),
                     "Romanprompt und Szenenzahl-Gate muessen denselben Vertrag verwenden")
        precondition(!romanPlan.localizedCaseInsensitiveContains("bei Bedarf mehr"),
                     "Der Prompt darf keine spaeter abgelehnte Mehrzahl erlauben")

        let rememberedPlan = PromptFactory.scenePlan(
            bookTitle: "Test", chapterNumber: 8, chapterTitle: "Der Ausgang",
            chapterGoal: "Mara muss aus dem Tunnel entkommen.",
            chapterConflict: "Der Ausgang ist versperrt.",
            perspective: "Personaler Erzaehler", plotContext: "Romanplot",
            targetWords: 2400, scenesPerChapter: 4,
            priorSceneLedger: "K7: Mara floh bereits durch den Nordtunnel.",
            chapterRoadmap: "K9: Mara stellt den Verfolger im Hafen."
        )
        precondition(rememberedPlan.contains("Mara floh bereits durch den Nordtunnel"),
                     "Die Szenenplanung muss verbrauchte Ereignisse aus Vorkapiteln kennen")
        precondition(rememberedPlan.contains("Mara stellt den Verfolger im Hafen"),
                     "Die Szenenplanung muss das naechste Kapitel und Buchende vorbereiten")

        let finalRepair = PromptFactory.repairFinalChapter(
            bookTitle: "Test", genre: "Thriller", chapterNumber: 12,
            planSummary: "K11: Mara betritt das Lager. K12: Die Frage bleibt offen.",
            currentChapter: "KAPITEL|12|Im Lager|Mara kommt an|Sie wartet|Die Frage bleibt offen|Gefahr|Angst",
            resolutionBeat: "Der Taeter wird ueberfuehrt; Mara verliert ihre Stellung.",
            canonicalStory: "Mara jagt den Taeter und riskiert ihre Stellung."
        )
        precondition(finalRepair.localizedCaseInsensitiveContains("nur eine Zeile"))
        precondition(finalRepair.contains("KAPITEL|12|"))
        precondition(finalRepair.contains("Der Taeter wird ueberfuehrt"))
        precondition(finalRepair.localizedCaseInsensitiveContains("zentrale Frage"))

        let stagnationRepair = PromptFactory.scenePlanStagnationRepair(
            reason: "Kapitel 6-8 wiederholen Suche/Fund am selben Leuchtturm."
        )
        precondition(stagnationRepair.localizedCaseInsensitiveContains("kapitelende"))
        precondition(stagnationRepair.localizedCaseInsensitiveContains("keinen weiteren fund"))
        precondition(stagnationRepair.localizedCaseInsensitiveContains("entscheidung")
                     && stagnationRepair.localizedCaseInsensitiveContains("konfrontation"))

        let logicCheck = PromptFactory.sceneLogicCheck(
            chapterNumber: 1, sceneNumber: 2,
            sceneGoal: "Mara will das Album unter der Diele finden.",
            sceneLocation: "Leuchtturm", sceneTime: "Abend",
            sceneObstacle: "Die Diele klemmt.",
            sceneTurn: "Sie hebt das Album auf.",
            charactersState: "Mara ist am Leuchtturm.",
            previousSceneSummary: "Mara hat das Album bereits eingepackt.",
            previousSceneEnding: "Das Album lag in ihrem Beutel.",
            storySoFar: "K1/S1: Mara nahm das Album mit."
        )
        precondition(logicCheck.localizedCaseInsensitiveContains("Mara hat das Album bereits eingepackt"))
        precondition(logicCheck.localizedCaseInsensitiveContains("Die Diele klemmt"))
        precondition(logicCheck.localizedCaseInsensitiveContains("Wendung"))
        precondition(logicCheck.localizedCaseInsensitiveContains("nicht erneut"),
                     "Jede Folgeszene braucht eine ausdrueckliche Nicht-Wiederholungspruefung")

        let sachPlan = PromptFactory.scenePlan(
            bookTitle: "Test", chapterNumber: 2, chapterTitle: "Die Methode",
            chapterGoal: "Der Leser kann die Methode anwenden.",
            chapterConflict: "Ein typischer Denkfehler verhindert die Umsetzung.",
            perspective: "Leser", plotContext: "SACHBUCH-ARCHITEKTUR",
            targetWords: 2400, scenesPerChapter: 4
        )
        precondition(sachPlan.localizedCaseInsensitiveContains("genau 4 Abschnitte"),
                     "Sachbuchprompt und Abschnittszahl-Gate muessen denselben Vertrag verwenden")

        let characterPrompt = PromptFactory.characters(
            title: "Testroman", genre: "Thriller",
            plot: "Mara muss eine alte Luege aufdecken."
        )
        precondition(!characterPrompt.localizedCaseInsensitiveContains("Lieblingsausdruck"),
                     "Figurenplanung darf keine spaeter gehaemmerten Catchphrases verlangen")
        precondition(!characterPrompt.localizedCaseInsensitiveContains("2-3 unveränderliche Merkmale"),
                     "Figurenplanung darf keine Requisiten-Checkliste fuer jede Szene erzeugen")
        precondition(characterPrompt.localizedCaseInsensitiveContains("keine Catchphrase"),
                     "Dialogstimmen muessen ohne wiederholte Signalwoerter geplant werden")
        precondition(characterPrompt.localizedCaseInsensitiveContains("relationale Rolle"),
                     "Figurenprofile muessen Schwester, Mutter oder Jugendliebe eindeutig zuordnen")

        let summaryEvidence = """
        Karin findet ihre Schwester nicht am Kai. Am Leuchtturm verweigert Karin die
        Unterschrift und beschließt, in der Wärterwohnung zu bleiben.
        """
        precondition(AutonomousContentQuality.evidenceBoundSummary(
            "Karin findet ihre Schwester nicht und verweigert am Leuchtturm die Unterschrift.",
            evidence: summaryEvidence,
            canon: "Karin ist die Hauptfigur.",
            characterNames: ["Karin Esser"]
        ), "Eine rein belegte Zusammenfassung muss erlaubt sein")
        precondition(!AutonomousContentQuality.evidenceBoundSummary(
            "Die Szene etabliert die mysteriöse Vernichtung ihrer Schwester.",
            evidence: summaryEvidence,
            canon: "Karin ist die Hauptfigur.",
            characterNames: ["Karin Esser"]
        ), "Ein Digest darf keine mysterioese Vernichtung halluzinieren")

        let openingPrompt = PromptFactory.openingHook(
            language: "Deutsch", bookTitle: "Testroman", genre: "Thriller",
            chapterText: "Mara wartet im Flur auf den Anruf."
        )
        precondition(openingPrompt.localizedCaseInsensitiveContains("Orientierung"),
                     "Der Romananfang muss Leser zuerst sicher in Figur und Situation verankern")
        precondition(openingPrompt.localizedCaseInsensitiveContains("kein erzwungener Schock"),
                     "Ein professioneller Anfang darf keinen beliebigen Schock-Hook erzwingen")
        precondition(openingPrompt.localizedCaseInsensitiveContains("keine Stakkato"),
                     "Der Blick-ins-Buch-Pass muss abgehackte Hook-Prosa ausdruecklich verhindern")

        let dash = AutonomousContentQuality.humanizeProse("Sie stockte – dann ging sie weiter.")
        precondition(dash.contains("–"),
                     "Ein legitimer Gedankenstrich darf nicht mechanisch in ein Komma verwandelt werden")
        let quoteBoundary = AutonomousContentQuality.humanizeProse(
            "„Ich muss hinein“Sie sagte es noch einmal."
        )
        precondition(quoteBoundary == "„Ich muss hinein.“ Sie sagte es noch einmal.",
                     "Fehlende Satzzeichen und Leerzeichen nach direkter Rede muessen korrigiert werden")
        precondition(AutonomousContentQuality.brokenDialogueTypography(in: """
        „Was für Briefe sind das?“?„
        „Da bist du ja“, sagte er.“, sagte Dörte. „Du kommst gerade rechtzeitig.“.„
        """).count == 2,
        "Kaputte Anfuehrungszeichen und doppelte Redebegleiter muessen erkannt werden")
        precondition(AutonomousContentQuality.brokenDialogueTypography(in: """
        „Was für Briefe sind das?“
        „Da bist du ja“, sagte Dörte. „Du kommst gerade rechtzeitig.“
        """).isEmpty,
        "Korrekte deutsche Dialogtypografie darf nicht beanstandet werden")

        let styleJudge = PromptFactory.styleTicJudge(
            bookTitle: "Testroman", chapterNumber: 1, chapterTitle: "Ankunft",
            chapterText: "Mara betritt das Haus."
        )
        precondition(styleJudge.localizedCaseInsensitiveContains("niemals Satzfragmente"),
                     "Der Stil-Lektor darf Telegrammstil nicht als Rhythmusvariation empfehlen")

        let plannedSummary = AutonomousContentQuality.plannedSceneSummary(
            perspective: "Karin Esser",
            goal: "Karin will den Leuchtturm betreten.",
            obstacle: "Trude verweigert ihr den Schluessel.",
            turn: "Karin entscheidet, im Waerterhaus zu bleiben."
        )
        for fact in ["Karin Esser", "Trude", "Waerterhaus"] {
            precondition(plannedSummary.localizedCaseInsensitiveContains(fact),
                         "Die sichere Szenenerinnerung muss den geplanten Fakt behalten: \(fact)")
        }
        let chapterDigest = AutonomousContentQuality.extractiveChapterDigest(sceneSummaries: [
            plannedSummary,
            "Perspektive: Karin Esser. Ziel: Karin untersucht die Wohnung. Wendung: Sie findet den Brief."
        ])
        precondition(chapterDigest.contains("Waerterhaus") && chapterDigest.contains("Brief"),
                     "Der lokale Kapitel-Digest muss Handlung aus allen Szenen bewahren")
        precondition(!chapterDigest.contains(" … "),
                     "Der Kapitel-Digest darf keine mitten im Satz abgeschnittenen Schnipsel enthalten")

        let longChapter = "ANFANGSEREIGNIS "
            + String(repeating: "konkrete Handlung mit Folge. ", count: 1_200)
            + " SCHLUSSENTSCHEIDUNG"
        let digestPrompt = PromptFactory.finalChapterDigest(
            chapterNumber: 18, chapterTitle: "Der Preis",
            chapterText: longChapter, isNonfiction: false
        )
        precondition(digestPrompt.contains("ANFANGSEREIGNIS"))
        precondition(digestPrompt.contains("SCHLUSSENTSCHEIDUNG"),
                     "Der Endfassungs-Digest eines langen Kapitels muss auch das Ende lesen")
        precondition(digestPrompt.contains("MITTELTEIL GEKUERZT"))

        let longArc = String(repeating: "Kapitelbogen mit Entscheidung und kausaler Folge. ",
                             count: 260) + "FINALE_AUFLOESUNG"
        let goldenPrompt = PromptFactory.goldenEval(
            bookTitle: "Test", genre: "Thriller", digests: longArc,
            excerpts: "Anfang Mitte Schluss", isNonfiction: false
        )
        precondition(goldenPrompt.contains("FINALE_AUFLOESUNG"),
                     "Die Golden-Eval darf den spaeten Gesamtbogen nicht bei 6000 Zeichen abschneiden")
        precondition(goldenPrompt.localizedCaseInsensitiveContains("mindestens 8"))
        precondition(goldenPrompt.localizedCaseInsensitiveContains("jede einzelne"))
        precondition(
            goldenPrompt.localizedCaseInsensitiveContains(
                "Rechtschreibung, Grammatik und Zeichensetzung"
            ),
            "Die Schlussbewertung muss sprachliche Korrektheit als eigene Dimension benoten"
        )
        print("NovelForge prompt quality probe: PASS")
    }
}
