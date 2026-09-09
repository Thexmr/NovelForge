import Foundation

@main
enum NarrativeQualityProbe {
    static func main() {
        let immediateOpening = """
        Mara riss den Umschlag auf, obwohl ihr Bruder ihn ihr aus der Hand ziehen wollte. In zehn
        Minuten begann die Anhoerung, und der Brief konnte ihr Haus retten oder den letzten Menschen
        vertreiben, der noch zu ihr hielt. Sie las die erste Zeile und wusste, dass sie jetzt waehlen
        musste: schweigen oder vor allen anderen die Wahrheit sagen.
        """
        precondition(AutonomousContentQuality.anfangTiefeMaengel(in: immediateOpening).isEmpty,
                     "Ein gegenwaertiger, persoenlicher Hook darf kein Todestrauma brauchen")
        precondition(
            AutonomousContentQuality.finalOpeningIssues(
                in: immediateOpening,
                protagonistNames: ["Mara"]
            ).isEmpty,
            "Ein konkreter Anfang mit Hauptfigur, Einsatz und Entscheidung muss freigegeben werden"
        )
        let weakOpening = """
        Der Regen lag ueber der Stadt. Nebel hing zwischen den Haeusern, und das Licht war grau.
        Frueher hatte hier alles anders ausgesehen. Damals waren die Sommer laenger gewesen.
        Die Strasse fuehrte zum alten Platz, waehrend irgendwo eine Uhr schlug.
        """
        precondition(
            !AutonomousContentQuality.finalOpeningIssues(
                in: weakOpening,
                protagonistNames: ["Mara"]
            ).isEmpty,
            "Kulisse, Rueckblick und fehlende Hauptfigur duerfen nicht als Romananfang passieren"
        )
        let unnamedButClearOpening = """
        Sie riss den Umschlag auf. Zu spaet. Der Termin begann. Niemand wartete. Vier kurze
        Saetze, dann zwang sie sich zur Ruhe und las den einzigen Absatz, der ihr Haus noch
        retten konnte. Wenn sie den Brief jetzt verschwieg, verlor ihr Bruder morgen alles.
        Wenn sie ihn vorlegte, wuerde er erfahren, wer den Vertrag wirklich unterschrieben
        hatte. Sie steckte das Papier ein, oeffnete die Saaltuer und nahm den freien Stuhl
        gegenueber der Kommission. Auf dem Tisch lagen drei Akten, ein Glas Wasser und der
        Vertrag, den ihr Bruder gestern noch fuer vernichtet gehalten hatte. Der Vorsitzende
        blätterte schweigend bis zur letzten Seite. Erst als er ihren Namen aufrief, hob sie
        den Blick. Mara wusste, dass es keinen Rueckweg mehr gab.
        """
        precondition(
            AutonomousContentQuality.stakkatoKetten(in: unnamedButClearOpening) == 1,
            "Der Testtext muss genau eine bewusste kurze Spannungspassage enthalten"
        )
        precondition(
            !unnamedButClearOpening.split(whereSeparator: \.isWhitespace).prefix(90)
                .joined(separator: " ").localizedCaseInsensitiveContains("Mara"),
            "Der Test muss die Hauptfigur zuerst ueber Handlung statt ueber ihren Namen einfuehren"
        )
        precondition(
            AutonomousContentQuality.finalOpeningIssues(
                in: unnamedButClearOpening,
                protagonistNames: ["Mara"]
            ).isEmpty,
            "Klare personale Handlung darf Namen und einen einzelnen Stakkato-Akzent spaeter setzen"
        )
        let repeatedStaccatoOpening = """
        Mara nahm den Brief. Die Tuer fiel zu. Der Wagen hielt. Ein Mann stieg aus.
        Sie kannte ihn aus dem Prozess, in dem ihr Bruder fast die letzte Chance auf
        einen Freispruch verloren hatte. Er sah her. Mara blieb stehen. Der Mann winkte.
        Niemand sprach ein Wort. Wenn sie jetzt weglief, verlor ihr Bruder auch das Haus.
        Sie steckte den Brief ein und ging dem Mann entgegen.
        """
        let repeatedStaccatoIssues = AutonomousContentQuality.finalOpeningIssues(
            in: repeatedStaccatoOpening,
            protagonistNames: ["Mara"]
        )
        precondition(
            repeatedStaccatoIssues.contains { $0.localizedCaseInsensitiveContains("kurzen Saetzen") },
            "Mehrfach abgehackter Satzrhythmus muss gezielt benannt und blockiert werden"
        )
        precondition(
            !repeatedStaccatoIssues.contains { $0.localizedCaseInsensitiveContains("Bandwurm") },
            "Ein reiner Stakkato-Befund darf nicht faelschlich als Bandwurmsatz gemeldet werden"
        )

        let readable = """
        Mara oeffnete den Brief. Ihr Bruder wartete neben der Tuer. Sie kannte seine Antwort schon,
        doch heute wollte sie sie von ihm selbst hoeren. Der Flur war leer. Aus dem Saal drang eine
        Stimme. Mara faltete das Papier zusammen und steckte es ein. Noch konnte sie gehen. Dann
        wuerde das Haus verkauft, und ihr Bruder muesste allein erklaeren, warum. Sie blieb. Er sah
        sie an. Keiner von beiden sagte etwas. Die Tuer zum Saal oeffnete sich. Mara trat ein.
        """
        precondition(AutonomousContentQuality.fehlendeSatzvarianz(in: readable) == nil,
                     "Gut lesbare kurze und mittlere Saetze duerfen keine Schachtelsaetze erzwingen")
        precondition(AutonomousContentQuality.teenReadabilityIssues(in: readable).isEmpty,
                     "Klare moderne Prosa muss fuer Leser ab 15 freigegeben werden")
        precondition(
            AutonomousContentQuality.isPersistableDraftText(readable, targetWords: 240),
            "Vollstaendige klare Prosa muss als geschriebene Szene gespeichert werden duerfen"
        )
        let unnecessarilyDifficult = Array(repeating: """
        Die epistemologische Rekontextualisierung der Angelegenheit, welche Mara angesichts der
        aequidistanten Positionierung saemtlicher Beteiligter nunmehr vorzunehmen gedachte, erwies
        sich als eine hermeneutische Herausforderung, deren mannigfaltige Implikationen sie trotz
        der fortschreitenden institutionellen Konsolidierung nicht ohne weitere Reflexion zu
        erfassen vermochte.
        """, count: 6).joined(separator: " ")
        precondition(!AutonomousContentQuality.teenReadabilityIssues(in: unnecessarilyDifficult).isEmpty,
                     "Akademische Bandwurmsaetze muessen die Lesbarkeit ab 15 blockieren")
        let formerPlaceholder = """
        [Diese Szene muss noch ausgeschrieben werden - bitte im Manuskript neu erzeugen.]
        Geplanter Inhalt: Mara konfrontiert ihren Bruder mit dem Brief.
        """
        precondition(
            !AutonomousContentQuality.isPersistableDraftText(formerPlaceholder, targetWords: 240),
            "Produktions- und Platzhaltertext darf niemals als geschriebene Szene gelten"
        )

        let completeButStylisticallyWeak = """
        Mara zog den Brief aus der Tasche und legte ihn auf den Tisch. Ihr Bruder blieb am
        Fenster stehen, obwohl draußen längst nichts mehr zu sehen war. Sie hielt den Atem an.
        Für einen Moment schien die Zeit stillzustehen. Dann schob sie ihm die erste Seite hin.
        Er las ihren Namen, das Datum und die Summe, die ihr Vater vor zwölf Jahren überwiesen
        hatte. Mara wartete auf eine Frage. Stattdessen nahm er den Stuhl gegenüber und setzte
        sich. Im Flur ging jemand vorbei. Die Schritte wurden leiser, bis nur noch das Summen
        der Lampe blieb. Ihr Herz hämmerte. Sie sagte, dass sie den Brief am Morgen erhalten
        hatte. Er fragte, wer noch davon wusste. Mara nannte die Anwältin und den Vorsitzenden.
        Ihr Bruder strich die Seite glatt. Danach las er den Absatz ein zweites Mal und zeigte
        auf die Unterschrift. Mara erkannte die Buchstaben sofort. Es war ihre eigene. Sie
        setzte sich ebenfalls und erklärte, wann sie das Formular unterschrieben hatte. Damals
        hatte ihr Vater behauptet, es gehe nur um die Versicherung des Hauses. Ihr Bruder
        schob den Brief zurück. Er wollte wissen, ob sie morgen vor der Kommission aussagen
        würde. Mara antwortete nicht sofort. Dann sagte sie ja. Draußen hielt ein Wagen, eine
        Tür schlug, und im Treppenhaus näherten sich Schritte. Ihr Bruder faltete den Brief und
        gab ihn ihr zurück. Diesmal sah er sie an. Sie sollte die Wahrheit erzählen, sagte er,
        aber nicht für ihn. Mara steckte den Brief ein und öffnete die Wohnungstür.
        """
        precondition(
            AutonomousContentQuality.soundsLikeAI(completeButStylisticallyWeak),
            "Der Testtext muss als stilistisch auffaellig erkannt werden"
        )
        let persistenceIssues = AutonomousContentQuality.draftPersistenceIssues(
            completeButStylisticallyWeak, targetWords: 300
        )
        precondition(
            AutonomousContentQuality.isPersistableDraftText(
                completeButStylisticallyWeak, targetWords: 300
            ),
            "Vollstaendige sichere Prosa darf wegen eines weichen Stilbefunds nicht verworfen werden: \(persistenceIssues)"
        )

        let concept = PromptFactory.concept(
            title: "Der Brief im Saal", genre: "Gegenwartsroman", subgenre: nil,
            language: "Deutsch", style: "klar", tonality: "emotional", audience: "Erwachsene",
            perspective: "personale dritte Person", tense: "Praeteritum", pageCount: 300,
            ideaSeed: "Zwei Geschwister muessen eine alte Entscheidung gemeinsam verantworten."
        )
        for harmful in ["Ohne Wunde keine Motivation", "ein Mensch, der starb oder verschwand"] {
            precondition(!concept.localizedCaseInsensitiveContains(harmful),
                         "Konzept darf kein standardisiertes Verlusttrauma erzwingen: \(harmful)")
        }
        precondition(concept.localizedCaseInsensitiveContains("nicht zwingend ein Trauma"))

        precondition(
            !AutonomousContentQuality.konzeptMaengel(
                praemisse: "Mara muss die Wahrheit sagen.",
                logline: "Eine Frau kaempft um ihr Haus.",
                expose: "Der Konflikt eskaliert und wird am Ende geloest.",
                thema: "", zielgruppe: "", istSachbuch: false
            ).isEmpty,
            "Ein generisches Kurzkonzept darf nicht zur Plotplanung gelangen"
        )
        let structuredConceptSynopsis = """
        Mara Feld bereitet die Versteigerung ihres Elternhauses vor und macht ihren Bruder Joris
        fuer den Verlust verantwortlich. Kurz vor der Anhoerung erhaelt sie einen Brief des Vaters,
        der auf ein verborgenes Konto verweist. Mara reicht den Brief ein und entdeckt, dass ihre
        eigene Unterschrift unter dem entscheidenden Vertrag steht. Joris verweigert die Hilfe,
        weil Mara ihn jahrelang oeffentlich beschuldigt hat. Ihre Kollegin Senta sucht mit ihr nach
        dem Originalvertrag, zieht sich aber zurueck, als Mara erneut eine Luege benutzt. In der
        Romanmitte erkennt Mara, dass der Vater beide Geschwister gegeneinander ausgespielt hat.
        Um Joris zu entlasten, muss sie sich selbst belasten. Vor der Kommission legt sie den Vertrag
        offen. Das Haus geht verloren, doch die falsche Anschuldigung endet. Joris verspricht keine
        Versoehnung. Mara beginnt, den angerichteten Schaden ohne Ausrede wiedergutzumachen.
        """
        let conceptIssues = AutonomousContentQuality.konzeptMaengel(
            praemisse: "Am Tag der Versteigerung entdeckt Mara Feld, dass ihre eigene Unterschrift den Familienbetrug ermoeglichte, den sie jahrelang ihrem Bruder vorgeworfen hat.",
            logline: "Um das Elternhaus zu retten, muss Mara vor der Kommission jene Wahrheit beweisen, die sie selbst zur Schuldigen macht.",
            expose: structuredConceptSynopsis,
            thema: "Kann Verantwortung eine Beziehung retten, auch wenn sie den gemeinsamen Besitz kostet?",
            zielgruppe: "Erwachsene Leserinnen und Leser emotionaler Gegenwartsromane",
            istSachbuch: false
        )
        precondition(conceptIssues.isEmpty,
                     "Ein vollstaendiges konkretes Konzept muss freigegeben werden: \(conceptIssues)")

        let ideaPrompt = PromptFactory.bookIdeas(
            genre: "Gegenwartsroman", language: "Deutsch", avoidanceBrief: "",
            authorSeed: "", trendBriefing: "", titelKritik: ""
        )
        for forcedWound in ["Kernwunde", "universelle emotionale Wunde"] {
            precondition(!ideaPrompt.localizedCaseInsensitiveContains(forcedWound),
                         "Ideenfindung darf keine wiederkehrende Wunden-Schablone erzwingen")
        }
        let romanceConcept = PromptFactory.concept(
            title: "Was zwischen uns steht", genre: "Liebesroman", subgenre: nil,
            language: "Deutsch", style: "klar", tonality: "warm", audience: "Erwachsene",
            perspective: "personale dritte Person", tense: "Praeteritum", pageCount: 300,
            ideaSeed: "Zwei Menschen muessen lernen, einander ehrlich zu begegnen."
        )
        precondition(!romanceConcept.localizedCaseInsensitiveContains("rootbare Figur angelegt: eine Wunde"),
                     "Romance darf keine tragische Standardbiografie verlangen")

        let goodGoals = [
            "Mara oeffnet den Brief und erkennt den drohenden Verlust.",
            "Der Inhalt zwingt Mara zu einer ersten oeffentlichen Entscheidung.",
            "Ihr Bruder verweigert die Zusammenarbeit und verschaerft den Konflikt.",
            "Mara bindet sich irreversibel an die Anhoerung.",
            "Ein Teilerfolg legt eine groessere Luege frei.",
            "Am Midpoint kippt die Deutung des Briefes und ihr bisheriger Plan zerbricht.",
            "Mara handelt mit neuem Ziel und verliert eine Verbuendete.",
            "Die Folgen ihrer Entscheidung erreichen ihre Familie.",
            "Der letzte Ausweg scheitert und zwingt sie zur Wahrheit.",
            "In der Krise entscheidet Mara, welchen Preis sie selbst zahlt.",
            "Im Hoehepunkt konfrontiert sie ihren Bruder vor der Kommission.",
            "Die Aufloesung beantwortet die Hauptfrage und zeigt die neue Normalitaet."
        ]
        let emotional = [
            "Mara verdraengt ihre Verantwortung und hofft auf einen Ausweg.",
            "Sie laesst erstmals Zweifel an ihrer alten Entscheidung zu.",
            "Der Widerstand ihres Bruders macht sie trotzig und unvorsichtig.",
            "Sie uebernimmt oeffentlich Verantwortung, obwohl sie Angst vor den Folgen hat.",
            "Der Teilerfolg gibt ihr Hoffnung, aber auch Misstrauen gegen sich selbst.",
            "Die neue Wahrheit zerstoert ihre bisherige Rechtfertigung.",
            "Mara sucht nicht mehr Entlastung, sondern eine ehrliche Loesung.",
            "Sie erkennt, wie ihre Entscheidung die Familie weiter verletzt hat.",
            "Nach dem Scheitern ist sie bereit, den persoenlichen Preis zu tragen.",
            "In der Krise entscheidet sie sich gegen Selbstschutz und fuer Offenheit.",
            "Sie stellt sich ihrem Bruder ohne Ausrede und nimmt seine Antwort an.",
            "Mara lebt mit den Folgen, ohne ihre Verantwortung erneut zu verdraengen."
        ]
        let goodPlanIssues = AutonomousContentQuality.kapitelplanMaengel(
            ziele: goodGoals, schritte: emotional
        )
        precondition(goodPlanIssues.isEmpty,
                     "Ein vollstaendiger Bogen muss die Planabnahme bestehen: \(goodPlanIssues)")

        let explicitMidpointWins = goodGoals.enumerated().map { index, goal in
            if index == 1 {
                return "Eine Erinnerung kippt Maras Bild von der Anhoerung, ohne den Hauptkonflikt neu auszurichten."
            }
            return goal
        }
        let explicitMidpointIssues = AutonomousContentQuality.kapitelplanMaengel(
            ziele: explicitMidpointWins, schritte: emotional
        )
        precondition(
            !explicitMidpointIssues.contains { $0.contains("Midpoint liegt in Kapitel 2") },
            "Ein allgemeines 'kippt' darf den ausdruecklich bezeichneten Midpoint nicht ueberschreiben: \(explicitMidpointIssues)"
        )

        let shallowPlot = """
        Mara erhaelt einen Brief und muss sich ihrer Vergangenheit stellen. Der Konflikt wird
        immer groesser. Freunde helfen ihr, waehrend ein Gegner sie aufhalten will. Es gibt
        mehrere Wendungen und am Ende eine Konfrontation. Mara veraendert sich und findet eine
        Loesung. Eine Nebenfigur hat ebenfalls Probleme. Die Geschichte endet emotional.
        """
        precondition(
            !AutonomousContentQuality.plotArchitekturMaengel(
                shallowPlot, istSachbuch: false
            ).isEmpty,
            "Ein kurzer generischer Abriss darf die Romanproduktion nicht starten"
        )

        let structuredPlot = """
        AUSGANGSLAGE UND AUSLOESER: Mara Feld lebt davon, Konflikte fuer andere zu ordnen,
        waehrend sie die eigene Mitschuld an der bevorstehenden Versteigerung des Elternhauses
        verschweigt. Am Morgen der Anhoerung erhaelt sie einen Brief ihres verstorbenen Vaters.
        Darin steht eine Kontonummer, die beweisen koennte, dass ihr Bruder Joris die Familie
        betrogen hat. Die fruehe Stoerung zwingt sie, zwischen dem Schutz ihres Bruders und dem
        Haus zu waehlen. Die zentrale dramatische Frage lautet: Kann Mara die Wahrheit sagen,
        ohne die letzte lebendige Beziehung ihrer Familie zu zerstoeren?

        ERSTE ENTSCHEIDUNG: Mara reicht den Brief gegen Joris' ausdruecklichen Willen bei der
        Kommission ein. Diese irreversible Entscheidung stoppt die Versteigerung fuer zwei Tage,
        macht sie aber selbst zur Verdaechtigen. Jede weitere Komplikation folgt daraus: Eine
        Unterschrift erweist sich als ihre eigene, eine Zeugin widerruft, und Mara verliert den
        Zugang zum Konto. Die Nebenhandlung um ihre Kollegin Senta spiegelt Maras Ausfluechte;
        Senta weigert sich erstmals, eine weitere Luege fuer sie zu decken.

        ZENTRALE WENDE: In der Romanmitte erkennt Mara, dass Joris das Geld nicht genommen,
        sondern auf Anweisung des Vaters versteckt hat. Ziel und Bedeutung kippen wirklich:
        Mara muss nun ihre eigene Unterschrift erklaeren. Sie sucht nicht laenger einen Schuldigen,
        sondern den damaligen Vertrag. Dafuer zahlt sie einen konkreten Preis und gesteht Senta,
        dass sie die Familie jahrelang mit einer falschen Version der Nacht zusammengehalten hat.

        FINALE UND AUFLOESUNG: In der finalen Konfrontation legt Mara den Vertrag selbst vor,
        obwohl er sie das Haus kosten wird. Joris bestaetigt ihre Aussage, verweigert ihr aber die
        schnelle Versoehnung. Die Kommission beendet das Verfahren; das Haus wird verkauft, doch
        die falsche Anschuldigung ist ausgeraeumt. Im Nachklang beginnt Mara, den Schaden praktisch
        wiedergutzumachen. Senta hilft ihr erst wieder, nachdem Mara ohne Ausrede Verantwortung
        uebernimmt. Die Hauptfrage ist beantwortet: Wahrheit rettet nicht den Besitz, aber sie gibt
        den Geschwistern erstmals die Moeglichkeit zu einer ehrlichen Beziehung.
        """
        let architectureIssues = AutonomousContentQuality.plotArchitekturMaengel(
            structuredPlot, istSachbuch: false
        )
        precondition(
            architectureIssues.isEmpty,
            "Ein konkreter vollstaendiger Romanplot muss freigegeben werden: \(architectureIssues)"
        )

        let wrongOrder = [
            "Die Aufloesung zeigt sofort die neue Normalitaet.",
            "Der Hoehepunkt beendet den Konflikt.",
            "Danach beginnt erst der Alltag der Figur.",
            "Eine erste Wende startet den Konflikt.",
            "Die Figur sammelt Informationen.",
            "Ein Hindernis wird groesser.",
            "Der Plan scheitert teilweise.",
            "Eine neue Spur erscheint.",
            "Die Figur trifft eine Entscheidung.",
            "Der Midpoint veraendert am Ende die Spielregeln.",
            "Die Hauptfigur erkennt erstmals den Einsatz.",
            "Eine offene Frage ersetzt das Ende."
        ]
        precondition(!AutonomousContentQuality.kapitelplanMaengel(
            ziele: wrongOrder, schritte: emotional
        ).isEmpty, "Dramaturgische Marken in falscher Reihenfolge muessen abgelehnt werden")

        let genericFallback = PipelineOrchestrator.repairedChapterPlan([], count: 12)
        precondition(!AutonomousContentQuality.hasUsableChapterPlan(genericFallback),
                     "Ein generischer Ersatzplan darf keine Romanproduktion starten")

        let causalPlan = [
            PlannedChapter(
                number: 1, title: "Der Brief",
                goal: "Mara oeffnet den Brief vor der Anhoerung.",
                conflict: "Joris will den Inhalt verbergen.",
                cause: "AUSLOESER: Der Brief des Vaters trifft zehn Minuten vor der Anhoerung ein.",
                decision: "Mara entscheidet, den versiegelten Umschlag vor Joris zu oeffnen.",
                outcome: "Der Kontohinweis macht Joris zum Verdaechtigen und setzt eine Frist.",
                emotionalStep: "Mara wechselt von Selbstschutz zu erstem Misstrauen gegen Joris."
            ),
            PlannedChapter(
                number: 2, title: "Zwei Tage",
                goal: "Mara reicht den Kontohinweis bei der Kommission ein.",
                conflict: "Joris droht, ihre eigene Rolle offenzulegen.",
                cause: "FOLGE AUS KAPITEL 1: Der Kontohinweis kann die Versteigerung nur bei sofortiger Einreichung stoppen.",
                decision: "Mara entscheidet sich gegen Joris und uebergibt den Brief der Kommission.",
                outcome: "Die Versteigerung ruht zwei Tage, waehrend Mara selbst zur Verdaechtigen wird.",
                emotionalStep: "Ihr Misstrauen kippt in Trotz, obwohl erste Schuldangst entsteht."
            ),
            PlannedChapter(
                number: 3, title: "Ihre Unterschrift",
                goal: "Mara sucht den Originalvertrag im Archiv.",
                conflict: "Senta verweigert eine weitere Luege als Vorwand.",
                cause: "FOLGE AUS KAPITEL 2: Die Kommission findet Maras Unterschrift und verlangt das Original.",
                decision: "Mara gesteht Senta einen Teil der Wahrheit und bittet offen um Hilfe.",
                outcome: "Senta gibt den Archivzugang frei, setzt aber eine Grenze fuer weitere Luegen.",
                emotionalStep: "Trotz wird zu verletzlicher Ehrlichkeit gegenueber Senta."
            ),
            PlannedChapter(
                number: 4, title: "Was Wahrheit kostet",
                goal: "Mara legt den Vertrag in der finalen Anhoerung offen.",
                conflict: "Der Vertrag rettet Joris, kostet Mara aber das Haus.",
                cause: "FOLGE AUS KAPITEL 3: Der Archivfund beweist zugleich Joris' Unschuld und Maras Verantwortung.",
                decision: "Mara entscheidet sich im Hoehepunkt fuer die vollstaendige Wahrheit.",
                outcome: "Die Aufloesung beendet die Anschuldigung; das Haus wird verkauft und Joris hoert ihr erstmals zu.",
                emotionalStep: "Mara ersetzt Selbstschutz durch Verantwortung ohne Anspruch auf Vergebung."
            )
        ]
        let causalIssues = AutonomousContentQuality.kapitelKausalitaetsMaengel(causalPlan)
        precondition(causalIssues.isEmpty,
                     "Eine lueckenlose Entscheidungs-Folgen-Kette muss bestehen: \(causalIssues)")

        let episodicPlan = causalPlan.enumerated().map { index, chapter in
            PlannedChapter(
                number: chapter.number, title: chapter.title,
                goal: chapter.goal, conflict: chapter.conflict,
                cause: index == 0 ? chapter.cause : "Ein neues Problem taucht unerwartet auf.",
                decision: chapter.decision, outcome: chapter.outcome,
                emotionalStep: chapter.emotionalStep
            )
        }
        precondition(
            !AutonomousContentQuality.kapitelKausalitaetsMaengel(episodicPlan).isEmpty,
            "Episodische Kapitel ohne benannte Folge des Vorgaengers muessen abgelehnt werden"
        )
        let parsedCausal = StructureParser.parseChapters("""
        KAPITEL|1|Der Brief|AUSLOESER: Der Brief trifft vor der Anhoerung ein.|Mara entscheidet, ihn vor Joris zu oeffnen.|Der Kontohinweis setzt eine Frist und macht Joris verdaechtig.|Joris will den Inhalt verbergen.|Selbstschutz kippt in erstes Misstrauen gegen Joris.
        KAPITEL|2|Zwei Tage|FOLGE AUS KAPITEL 1: Der Hinweis muss sofort eingereicht werden.|Mara entscheidet, den Brief der Kommission zu geben.|Die Versteigerung ruht, aber Mara wird selbst verdaechtigt.|Joris droht mit Maras eigener Rolle.|Misstrauen kippt in Trotz und erste Schuldangst.
        """)
        precondition(parsedCausal.count == 2)
        precondition(parsedCausal[0].cause.hasPrefix("AUSLOESER:"))
        precondition(parsedCausal[1].cause.hasPrefix("FOLGE AUS KAPITEL 1:"))
        precondition(parsedCausal[1].goal.contains("Aktive Entscheidung:"))
        precondition(parsedCausal[1].emotionalStep.contains("Schuldangst"))

        let legacyPlan = StructureParser.parseChapters(
            "KAPITEL|1|Ein Tag|Mara sucht einen Brief.|Joris schweigt.|Mara wird misstrauisch."
        )
        precondition(
            legacyPlan.first?.cause.isEmpty == true,
            "Das alte Format darf nicht als kausal vollstaendiger neuer Plan erscheinen"
        )

        print("NovelForge narrative quality probe: PASS")
    }
}
