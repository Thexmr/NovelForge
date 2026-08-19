import Foundation

@main
enum RegressionProbe {
    @MainActor
    static func main() {
        precondition(
            OllamaCloudModelCatalog.recommendedWritingModel == "qwen3.5:397b",
            "Qualitaet vor Kosten: kreative Buchschritte muessen das staerkere Autorenmodell nutzen"
        )
        let duplicates = ChapterEventDuplicateParser.parse(
            "DUPLICATE|2|1|Das Versteck wird erneut entdeckt.|Zeige die unmittelbare Folge."
        )
        precondition(duplicates.count == 1)
        precondition(duplicates[0].laterSceneNumber == 2)
        precondition(duplicates[0].earlierSceneNumber == 1)
        precondition(ChapterEventDuplicateParser.isConclusive("KEINE DOPPLUNG"))
        let consolidatedDuplicates = ChapterEventDuplicateParser.consolidated(
            [
                ChapterEventDuplicate(laterSceneNumber: 2, earlierSceneNumber: 1,
                                      event: "Die Lilien werden erneut bestellt.",
                                      instruction: "Beginne mit Albrechts Reaktion."),
                ChapterEventDuplicate(laterSceneNumber: 2, earlierSceneNumber: 1,
                                      event: "Maren entscheidet sich erneut fuer die Bestellung.",
                                      instruction: "Zeige stattdessen die neue Konsequenz."),
                ChapterEventDuplicate(laterSceneNumber: 9, earlierSceneNumber: 1,
                                      event: "Ungueltige Szene.",
                                      instruction: "Verwerfen."),
            ],
            validSceneNumbers: [1, 2]
        )
        precondition(consolidatedDuplicates.count == 1,
                     "Mehrere Teilbefunde desselben Szenenpaars muessen einen Reparaturauftrag ergeben")
        precondition(consolidatedDuplicates[0].event.contains("Lilien")
                        && consolidatedDuplicates[0].event.contains("entscheidet"),
                     "Der zusammengefasste Reparaturauftrag darf keinen Teilbefund verlieren")
        let boundedScenePrompt = PromptFactory.draftScene(
            language: "Deutsch", style: "klar", tonality: "warm", perspective: "Er/Sie",
            tense: "Präteritum", genre: "Liebesroman", bookTitle: "Test", chapterNumber: 2,
            chapterTitle: "Die Bestellung", chapterGoal: "Maren trifft eine Entscheidung.",
            sceneNumber: 1, sceneGoal: "Maren prueft die Allergienotiz.",
            sceneLocation: "Büro", sceneTime: "Vormittag",
            sceneObstacle: "Die Notiz belegt die Gefahr.",
            sceneTurn: "Maren fährt zu Albrecht.", scenePerspective: "Maren Jäger",
            charactersSummary: "Maren Jäger (Protagonistin)", styleRules: "Moderne Sprache.",
            storySoFar: "", previousSceneEnding: "", isFirstScene: false,
            isFinalScene: false, targetWords: 500
        )
        precondition(boundedScenePrompt.contains("ENDpunkt dieser Szene")
                        && boundedScenePrompt.contains("NICHT mehr aus"),
                     "Die geplante Wendung muss den Szenenendpunkt begrenzen und Folgehandlungen sperren")
        precondition(PromptFactory.draftingSystemCraftRules.contains("deutschen Anfuehrungszeichen"),
                     "Der Draft Writer muss die deutsche Dialogtypografie als Systemregel erhalten")

        let continuityAudit = PromptFactory.chapterEventDuplicateAudit(
            bookTitle: "Test", chapterNumber: 1, chapterTitle: "Das Album",
            scenes: "Szene 1: Mara steckt das Album ein. Szene 2: Mara findet dasselbe Album unter der Diele."
        )
        precondition(continuityAudit.localizedCaseInsensitiveContains("widerspr"),
                     "Der Kapitelpruefer muss neben Dopplungen auch Zustandswidersprueche suchen")
        precondition(continuityAudit.localizedCaseInsensitiveContains("gegenstand"),
                     "Besitz und Ort eines Gegenstands muessen Teil der Anschlusspruefung sein")

        let scopedArtifacts = AutonomousContentQuality.unexpectedStoryArtifacts(
            in: "Mara nahm das Album aus dem Beutel.",
            allowedContext: "Sie packt nur den Segeltuchbeutel und verlaesst die Wohnung."
        )
        precondition(scopedArtifacts.contains("Album"),
                     "Ein aus einer spaeteren Szene vorgezogenes Album muss den Entwurf blockieren")
        precondition(
            AutonomousContentQuality.foreignCatalogNameMentions(
                in: "Silke trat ein und stellte sich vor.",
                allowedNames: ["Isolde Keitum", "Nele Wein"],
                forbiddenNames: ["silke", "liv", "voss"]
            ) == ["silke"],
            "Ein Name aus einem Altbuch muss neu geschrieben und darf nicht blind ersetzt werden"
        )
        let nameRetryHint = AutonomousContentQuality.draftRetryPlanViolationHint(
            unexpectedCharacters: ["Nicht kanonische handelnde Figur: weber"],
            unexpectedArtifacts: []
        )
        precondition(nameRetryHint.localizedCaseInsensitiveContains("weber"),
                     "Der Retry muss den konkret abgelehnten Altbuchnamen nennen")
        precondition(nameRetryHint.localizedCaseInsensitiveContains("nicht erneut"),
                     "Der Retry muss die Wiederverwendung des abgelehnten Namens ausdruecklich verbieten")
        let planNameReplacements = StoryMemory.sichereSzenenplanNamensErsetzungen(
            ["weber"],
            vergeben: StoryMemory.verbrauchteNamen,
            streuung: UUID(uuidString: "00000000-0000-0000-0000-000000000123")!
        )
        let replacementForWeber = planNameReplacements["weber"] ?? ""
        precondition(!replacementForWeber.isEmpty && !replacementForWeber.contains(" "),
                     "Ein einzelner kollidierender Nachname im Szenenplan braucht einen einzelnen Ersatznamen")
        precondition(
            StoryMemory.namensKollisionen(
                [replacementForWeber], vergeben: StoryMemory.verbrauchteNamen
            ).isEmpty,
            "Der Szenenplan-Ersatzname muss katalogweit frei sein"
        )
        precondition(
            Set(["Albrecht", "Berger", "Brandt", "Cordes", "Dahl", "Ebert",
                 "Franke", "Gehring", "Hansen", "Heine", "Kramer", "Lorenz",
                 "Martens", "Neumann", "Peters", "Riedel", "Schuster", "Seidel",
                 "Thiele", "Winter"]).contains(replacementForWeber),
            "Eine beiläufige Nebenfigur braucht einen natürlichen, unauffälligen Nachnamen"
        )
        let livePlanReplacement = StoryMemory.sichereSzenenplanNamensErsetzungen(
            ["weber"],
            vergeben: StoryMemory.verbrauchteNamen,
            streuung: UUID(uuidString: "82CCF2D5-3C8A-4F4F-BB93-143AFADBCE32")!
        )["weber"] ?? ""
        precondition(
            Set(["Albrecht", "Berger", "Brandt", "Cordes", "Dahl", "Ebert",
                 "Franke", "Gehring", "Hansen", "Heine", "Kramer", "Lorenz",
                 "Martens", "Neumann", "Peters", "Riedel", "Schuster", "Seidel",
                 "Thiele", "Winter"]).contains(livePlanReplacement),
            "Der echte Weber-Fall darf keinen auffälligen Ersatznamen erzeugen"
        )
        precondition(
            AutonomousContentQuality.scenePlanForeignCatalogNames(
                in: "Sie ruft den Blumenlieferanten Brösel an.",
                allowedNames: ["Maren Jäger"],
                forbiddenNames: StoryMemory.verbrauchteNamen
            ).contains("brösel"),
            "Ein gesperrter Plan-Nachname muss ohne unsichere Personenerkennung erkannt werden"
        )
        precondition(
            AutonomousContentQuality.scenePlanForeignCatalogNames(
                in: "Der Weber arbeitet am Webstuhl.",
                allowedNames: [],
                forbiddenNames: ["weber"]
            ).isEmpty,
            "Ein Berufs- oder Rollenwort darf nicht als Figurenname ersetzt werden"
        )
        let sanitizedDraftName = AutonomousContentQuality.sanitizingDraftCatalogNames(
            in: "Thomas stellte den Karton auf den Tisch.",
            targetWords: 8,
            allowedNames: ["Maren Jäger"],
            forbiddenNames: StoryMemory.verbrauchteNamen,
            occupiedContext: "Maren Jäger spricht mit Lieferant Albrecht.",
            seed: UUID(uuidString: "82CCF2D5-3C8A-4F4F-BB93-143AFADBCE32")!
        )
        precondition(!sanitizedDraftName.replacements.isEmpty,
                     "Ein im Entwurf erfundener Altbuchname muss vor dem Speichern ersetzt werden")
        precondition(
            AutonomousContentQuality.hardDraftPersistenceIssues(
                sanitizedDraftName.text,
                targetWords: 8,
                allowedNames: ["Maren Jäger"],
                forbiddenNames: StoryMemory.verbrauchteNamen
            ).allSatisfy { !$0.contains("Namen aus frueheren") },
            "Nach der gezielten Namenskorrektur darf die harte Speichergrenze nicht erneut am selben Namen scheitern"
        )

        precondition(
            !AutonomousContentQuality.brokenDialogueTypography(
                in: "„Sehr aufmerksam von ihm“sagte sie."
            ).isEmpty,
            "Ein fehlendes Komma und Leerzeichen vor dem Redebegleiter muss erkannt werden"
        )
        precondition(
            !AutonomousContentQuality.brokenDialogueTypography(
                in: "„Der Weiße Anker, nicht wahr??“"
            ).isEmpty,
            "Doppelte abschließende Satzzeichen in direkter Rede muessen erkannt werden"
        )
        precondition(
            AutonomousContentQuality.brokenDialogueTypography(
                in: "„Sehr aufmerksam von ihm“, sagte sie."
            ).isEmpty,
            "Korrekte deutsche Dialogtypografie darf nicht beanstandet werden"
        )
        precondition(
            AutonomousContentQuality.humanizeProse(
                "„Sehr aufmerksam von ihm“sagte sie. „Nicht wahr??“"
            ) == "„Sehr aufmerksam von ihm“, sagte sie. „Nicht wahr?“",
            "Eindeutige Dialogfehler sollen vor dem Speichern verlustfrei korrigiert werden"
        )
        precondition(
            SpellCheckService.haeufigeFalschschreibungen["glasfaserweinen"] == "Gläsern Wein",
            "Der im Live-Manuskript gefundene sinnlose Wortzusammenzug muss korrigiert werden"
        )
        precondition(
            AutonomousContentQuality.dialogOhneAnfuehrungszeichen(
                in: "Maren ging hinüber, nahm ab, sagte nur ihren Namen."
            ).isEmpty,
            "Ein zusammengefasster Sprechakt darf nicht als kaputte direkte Rede gelten"
        )
        precondition(
            !AutonomousContentQuality.dialogOhneAnfuehrungszeichen(
                in: "Ich wiederhole die Frage, sagte Erik Brenner."
            ).isEmpty,
            "Tatsaechlich unmarkierte direkte Rede muss weiter erkannt werden"
        )
        precondition(
            AutonomousContentQuality.draftPersistenceIssues(
                "Ich wiederhole die Frage, sagte Erik Brenner. Danach verliess er den Raum.",
                targetWords: 10
            ).contains("unmarkierte direkte Rede"),
            "Unmarkierte direkte Rede darf nicht als fertige Romanszene gespeichert werden"
        )
        precondition(
            AutonomousContentQuality.verbrauchteHandlungen(
                candidate: "Das Telefon klingelte erneut. Maren nahm ab.",
                priorTexts: ["Am Morgen klingelte das Telefon, bis Maren ranging."]
            ).contains("Telefon klingelt"),
            "Ein weiterer Telefonklingel-Auftakt muss als verbrauchtes Szenenmuster gelten"
        )
        precondition(
            AutonomousContentQuality.verbrauchteHandlungen(
                candidate: "Maren ging zurück zum Fenster und sah hinaus.",
                priorTexts: ["Sie stand lange am Fenster und wartete auf Licht."]
            ).contains("ans Fenster zurückkehren"),
            "Die wiederholte Flucht ans Fenster muss buchweit erkannt werden"
        )

        let relationshipCanon = """
        Maren Jäger wurde von ihrem damaligen Ehemann Lennart Kirchner mit Silke betrogen.
        Lennart Kirchner ist Marens Exmann. Silke ist Lennarts Braut und Verlobte.
        """
        precondition(
            !AutonomousContentQuality.unsupportedPerspectiveRelationshipClaims(
                in: "Herr Brandt sah Maren an. „Ihr Bräutigam, Herr Kirchner, hat bereits unterschrieben.“",
                canon: relationshipCanon,
                perspectiveName: "Maren Jäger",
                characterNames: ["Maren Jäger", "Lennart Kirchner", "Silke"]
            ).isEmpty,
            "Der Exmann der Perspektivfigur darf nicht zu ihrem Braeutigam umgedeutet werden"
        )
        precondition(
            AutonomousContentQuality.unsupportedPerspectiveRelationshipClaims(
                in: "Silkes Bräutigam Lennart Kirchner hat bereits unterschrieben.",
                canon: relationshipCanon,
                perspectiveName: "Maren Jäger",
                characterNames: ["Maren Jäger", "Lennart Kirchner", "Silke"]
            ).isEmpty,
            "Die kanonisch belegte Brautpaar-Zuordnung muss erlaubt bleiben"
        )
        precondition(
            !AutonomousContentQuality.draftCanonIssues(
                in: "„Ihr Bräutigam, Herr Kirchner, hat bereits unterschrieben.“",
                canon: relationshipCanon,
                perspectiveName: "Maren Jäger",
                characterNames: ["Maren Jäger", "Lennart Kirchner", "Silke"]
            ).isEmpty,
            "Die gemeinsame Entwurfs-Kanonsperre muss auch romantische Rollenfehler erfassen"
        )
        precondition(
            !AutonomousContentQuality.evidenceBoundSummary(
                "Maren entdeckt, dass ihr Bräutigam Lennart Kirchner allergisch auf Lilien reagiert.",
                evidence: "Maren liest Lennarts Allergie in der Akte und bestellt trotzdem Lilien.",
                canon: relationshipCanon,
                characterNames: ["Maren Jäger", "Lennart Kirchner", "Silke"],
                perspectiveName: "Maren Jäger"
            ),
            "Eine Szenenzusammenfassung darf den Exmann nicht zum Braeutigam der Perspektivfigur machen"
        )
        precondition(
            AutonomousContentQuality.evidenceBoundSummary(
                "Maren liest die dokumentierte Lilienallergie ihres Exmannes Lennart und bestellt die Blumen trotzdem.",
                evidence: "Maren liest Lennarts Allergie in der Akte und bestellt trotzdem Lilien.",
                canon: relationshipCanon,
                characterNames: ["Maren Jäger", "Lennart Kirchner", "Silke"],
                perspectiveName: "Maren Jäger"
            ),
            "Eine kanontreue, vollstaendige Zusammenfassung muss akzeptiert werden"
        )
        precondition(
            !AutonomousContentQuality.evidenceBoundSummary(
                "Maren bestellt die Lilien, obwohl Lennart allergisch reagiert und",
                evidence: "Maren bestellt die Lilien trotz Lennarts Allergie.",
                canon: relationshipCanon,
                characterNames: ["Maren Jäger", "Lennart Kirchner", "Silke"],
                perspectiveName: "Maren Jäger"
            ),
            "Eine am Tokenlimit abgebrochene Zusammenfassung darf nicht ins Langzeitgedaechtnis gelangen"
        )
        let liveRelationshipCanon = """
        Die Hochzeitsplanerin Maren Jäger übernimmt aus finanzieller Not den Auftrag,
        die Hochzeit ihres Exmannes Lennart mit ihrer einstigen besten Freundin Silke zu planen.
        """
        precondition(
            !AutonomousContentQuality.draftCanonIssues(
                in: "„Ach, Sie wissen es noch nicht? Ihr Bräutigam, Herr Kirchner, hat die Gemeindekasse mit einer Spende bedacht.“",
                canon: liveRelationshipCanon,
                perspectiveName: "Maren Jäger",
                characterNames: ["Maren Jäger", "Lennart Kirchner", "Silke"]
            ).isEmpty,
            "Der echte Rollenwiderspruch aus Bevor ich dir verzeihe muss beim Resume erkannt werden"
        )

        // Kapitel- und Szenennummern sind Teil des Modellvertrags. Eine Luecke darf
        // nicht durch stilles Neunummerieren verschwinden: Sonst wird beispielsweise
        // das gelieferte Kapitel 3 als Kapitel 2 gespeichert und die gesamte kausale
        // Folge verschiebt sich, obwohl der Vollstaendigkeitscheck anschliessend gruen ist.
        let numberedChapters = StructureParser.parseChapters("""
        KAPITEL|1|Auftakt|AUSLOESER: Der Brief kommt an|Mara oeffnet ihn|Die Frist beginnt|Joris widerspricht|Misstrauen entsteht
        KAPITEL|3|Die Aussage|FOLGE AUS KAPITEL 2: Die Frist endet|Mara sagt aus|Joris verlaesst das Haus|Die Familie zerbricht|Trotz wird zu Schuld
        """)
        precondition(numberedChapters.map(\.number) == [1, 3],
                     "Explizite Kapitelluecken muessen sichtbar bleiben")

        let numberedScenes = StructureParser.parseScenes("""
        SZENE|1|Mara|Kueche|Morgen|Sie oeffnet den Brief|Joris greift danach|Sie liest die Kontonummer|Szene|Sie verliert sein Vertrauen|Figur
        SZENE|3|Mara|Flur|Mittag|Sie bringt den Brief hinaus|Joris versperrt die Tuer|Sie ruft die Kommission an|Szene|Sie verliert ihr Zuhause|Figur
        """)
        precondition(numberedScenes.map(\.number) == [1, 3],
                     "Explizite Szenenluecken muessen sichtbar bleiben")

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
            let wenden = [
                "Auf der Rueckseite steht Jonas' Geburtsdatum.",
                "Lena erkennt am Rand die Handschrift des Pfarrers.",
                "Unter dem Tisch entdeckt sie frische Lehmspuren.",
                "Das Schweigen schuetzt nicht Jonas, sondern Lenas Mutter.",
            ]
            return PlannedScene(number: n, perspective: "Lena", location: "Ort", time: "Zeit",
                                goal: ziel, obstacle: hindernis,
                                turn: wenden[(n - 1) % wenden.count])
        }
        let standardBeats = [
            szene(1, "EINSTIEG: Die Perspektivfigur betritt die Ausgangslage.", "Lenas Wut gegen sein Schweigen."),
            szene(2, "KOMPLIKATION: Ausgehend vom Ende der vorigen Szene ein NEUER Vorstoß.", "Lenas Wut gegen sein Schweigen."),
            szene(3, "ZUSPITZUNG: Die Folgen zwingen die Figur zu einem Schritt.", "Lenas Wut gegen sein Schweigen."),
            szene(4, "WENDE UND ÜBERGANG: Eine Entscheidung bringt das Kapitel zum Höhepunkt.", "Lenas Wut gegen sein Schweigen."),
        ]
        precondition(AutonomousContentQuality.istGenerischerSzenenplan(standardBeats),
                     "Standard-Beats müssen als unbrauchbar erkannt werden")
        precondition(
            !AutonomousContentQuality.szenenplanMaengel(
                standardBeats, erwarteteAnzahl: 4
            ).isEmpty,
            "Ein synthetischer Standardplan darf niemals in die Rohfassung gelangen"
        )

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
        let repeatedAddressPlan = [
            PlannedScene(
                number: 1, perspective: "Maren Jäger", location: "Büro", time: "Vormittag",
                goal: "Maren recherchiert Lennarts aktuelle Lebensumstände und seine neue Adresse.",
                obstacle: "Sie tippt Lennarts Adresse auswendig ein und merkt, dass sie ihn nie vergessen hat.",
                turn: "Sie findet den Blumenlieferanten Albrecht und kündigt ihre handschriftliche Bestellung an."
            ),
            PlannedScene(
                number: 2, perspective: "Maren Jäger", location: "Küche", time: "Abend",
                goal: "Maren legt die Lilienbestellung bei Albrecht als zentrales Dekoelement fest.",
                obstacle: "Die handschriftliche Bestellung verlangt erneut Lennarts Adresse, die Maren auswendig kennt.",
                turn: "Albrecht erhält die Bestellung und Maren verstärkt anschließend ihre Überwachung."
            ),
        ]
        precondition(
            !AutonomousContentQuality.duplicatedSceneBeats(repeatedAddressPlan).isEmpty,
            "Anders formulierte Szenen mit derselben Adresse und Bestellung muessen im Plan kollidieren"
        )
        precondition(
            AutonomousContentQuality.szenenplanMaengel(
                konkret, erwarteteAnzahl: 4
            ).isEmpty,
            "Vier konkrete unterschiedliche Szenen muessen freigegeben werden"
        )
        let zuKurzesZiel = [
            konkret[0],
            PlannedScene(number: 2, perspective: "Lena", location: "Kueche",
                         time: "Abend", goal: "Sie wartet",
                         obstacle: "Jonas schweigt weiter", turn: "Sie verlaesst ihn"),
            konkret[2], konkret[3],
        ]
        precondition(
            AutonomousContentQuality.szenenplanMaengel(
                zuKurzesZiel, erwarteteAnzahl: 4
            ).contains { $0.contains("Szene 2") && $0.contains("Ziel zu kurz") },
            "Der Neuplanungs-Prompt braucht den exakten mangelhaften Szenenbereich"
        )
        precondition(!AutonomousContentQuality.unexpectedStoryArtifacts(
            in: "Lena prueft das Dokument.",
            allowedContext: "Lena muss den Verkauf stoppen."
        ).isEmpty, "Der Artefakt-Hinweis muss fuer das Lektorat erhalten bleiben")
        precondition(AutonomousContentQuality.persistedScenePlanIsUsable(
            konkret, expectedCount: 4
        ), "Ein bereits angenommener konkreter Szenenplan darf nicht spaeter an Warnungen scheitern")
        var legacyConcreteLoop = konkret
        legacyConcreteLoop[1] = szene(
            2,
            "Lena findet hinter dem losen Stein den Leinenbeutel mit dem Kinderfoto.",
            "Jonas behauptet, das Foto gehoere ihm und fordert den Beutel zurueck."
        )
        precondition(!AutonomousContentQuality.szenenplanMaengel(
            legacyConcreteLoop, erwarteteAnzahl: 4
        ).isEmpty,
        "Ein neuer Szenenplan mit vier gleichen Handlungszielen muss weiter abgelehnt werden")
        precondition(AutonomousContentQuality.persistedScenePlanIsUsable(
            legacyConcreteLoop, expectedCount: 4
        ),
        "Ein vollstaendiger Altplan darf beim Resume nicht wegen neuer Aehnlichkeitsheuristiken geloescht werden")
        precondition(!AutonomousContentQuality.persistedScenePlanIsUsable(
            Array(legacyConcreteLoop.prefix(3)), expectedCount: 4
        ),
        "Ein unvollstaendiger Altplan darf auch beim Resume nicht freigegeben werden")
        precondition(LongFormProductionPlan.effectiveScenesPerChapter(
            defaultCount: 2,
            persistedCounts: [4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4],
            hasWrittenProse: true
        ) == 4,
        "Ein begonnenes Buch muss seine etablierte Szenenzahl ueber ein App-Update behalten")
        precondition(LongFormProductionPlan.effectiveScenesPerChapter(
            defaultCount: 2,
            persistedCounts: [4, 4, 1],
            hasWrittenProse: true
        ) == 4,
        "Ein teilweise angelegtes Kapitel darf den dominanten Altbuch-Rhythmus nicht veraendern")
        precondition(LongFormProductionPlan.effectiveScenesPerChapter(
            defaultCount: 2,
            persistedCounts: [4, 4, 4],
            hasWrittenProse: false
        ) == 2,
        "Ein neues Buch muss die aktuelle Szenenplanung verwenden")
        precondition(
            !AutonomousContentQuality.szenenplanMaengel(
                Array(konkret.prefix(3)), erwarteteAnzahl: 4
            ).isEmpty,
            "Ein zu kurzer Plan darf nicht gespeichert werden"
        )
        let falscheNummern = [
            konkret[0],
            PlannedScene(number: 1, perspective: konkret[1].perspective,
                         location: konkret[1].location, time: konkret[1].time,
                         goal: konkret[1].goal, obstacle: konkret[1].obstacle,
                         turn: konkret[1].turn),
            konkret[2], konkret[3],
        ]
        precondition(
            !AutonomousContentQuality.szenenplanMaengel(
                falscheNummern, erwarteteAnzahl: 4
            ).isEmpty,
            "Doppelte oder lueckenhafte Szenennummern muessen blockieren"
        )
        let doppelterBeat = [
            konkret[0], konkret[1], konkret[2],
            PlannedScene(number: 4, perspective: konkret[0].perspective,
                         location: konkret[0].location, time: konkret[0].time,
                         goal: konkret[0].goal, obstacle: konkret[0].obstacle,
                         turn: konkret[0].turn),
        ]
        precondition(
            !AutonomousContentQuality.szenenplanMaengel(
                doppelterBeat, erwarteteAnzahl: 4
            ).isEmpty,
            "Ein intern wiederholter Szenen-Beat muss vor der Rohfassung blockieren"
        )

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

        // --- Rechtschreibung: Falschschreibungen aus gültigen Teilwörtern ---------
        // „Ziffernblatt" besteht aus „Ziffern" + „Blatt" – beide korrekt, die
        // Zusammensetzung nicht. Solche Wörter winkt jede Kompositum-Prüfung durch.
        // Gemessen an „Das Gewicht von Seide": dreimal unbeanstandet im fertigen Text,
        // während die Prüfung im ganzen Buch nur EINE Korrektur meldete.
        precondition(SpellCheckService.haeufigeFalschschreibungen["ziffernblatt"] == "Zifferblatt")
        precondition(SpellCheckService.haeufigeFalschschreibungen["standart"] == "Standard")
        precondition(SpellCheckService.haeufigeFalschschreibungen["schäft"] == "Schaft")
        precondition(SpellCheckService.haeufigeFalschschreibungen["gewebts"] == "Gewebes")
        precondition(SpellCheckService.tageszeitenFehler(in: "Sie kam gestern abend zurück.")
                        .contains { $0.korrekt == "gestern Abend" },
                     "Kleingeschriebene Tageszeit muss erkannt werden")
        precondition(SpellCheckService.tageszeitenFehler(in: "Sie kam gestern Abend zurück.").isEmpty,
                     "Korrekte Schreibweise darf nicht anschlagen")
        let definiteSpelling = SpellCheckService.eindeutigeFehler(
            in: "Das ist der Standart. Sie kam gestern abend zurueck."
        )
        precondition(definiteSpelling.contains(where: { $0.localizedCaseInsensitiveContains("Standard") }),
                     "Eindeutige Falschschreibung muss die Endabnahme blockieren koennen")
        precondition(definiteSpelling.contains(where: { $0.contains("gestern Abend") }),
                     "Kleingeschriebene Tageszeit muss als eindeutiger Fehler gelten")
        precondition(SpellCheckService.eindeutigeFehler(
            in: "Das ist der Standard. Sie kam gestern Abend zurück."
        ).isEmpty, "Korrekter Text darf keinen harten Rechtschreibbefund erzeugen")
        let korrigiert = SpellCheckService.korrigiereEindeutigeFehler(
            in: "Der Standart war nähmlich falsch. Sie kam gestern abend zurück."
        )
        precondition(korrigiert.contains("Der Standard war nämlich falsch."),
                     "Zweifelsfreie Falschschreibungen muessen ohne Modell korrigiert werden")
        precondition(korrigiert.contains("gestern Abend"),
                     "Tageszeiten muessen deterministisch grossgeschrieben werden")
        let echterTageszeitFehler = SpellCheckService.korrigiereEindeutigeFehler(
            in: "Wir treffen uns morgen vormittag vor dem Haus."
        )
        precondition(echterTageszeitFehler.contains("morgen Vormittag"),
                     "Der im letzten Manuskript gefundene Fehler muss sicher korrigiert werden")
        precondition(SpellCheckService.eindeutigeFehler(in: korrigiert).isEmpty,
                     "Nach der sicheren Korrektur darf kein harter Rechtschreibbefund bleiben")
        let korrigierteUeberschrift = SpellCheckService.korrigiereEindeutigeFehler(
            in: "KAPITZEL 4: Der falsche Standart"
        )
        precondition(korrigierteUeberschrift == "KAPITEL 4: Der falsche Standard",
                     "Eindeutige Fehler in Kapitelueberschriften muessen korrigiert werden")
        let fachwortPlural = SpellCheckService.pruefe(
            text: "Sie ordnete die Schäfte am Webstuhl.", eigennamen: []
        )
        precondition(!fachwortPlural.contains(where: { $0.wort.lowercased() == "schäft" }),
                     "Eine gueltige gebeugte Form darf nicht als benannter Tippfehler gelten")
        let now = Date()
        precondition(KDPUploadService.isExportFresh(
            exportedAt: now, manuscriptUpdatedAt: now.addingTimeInterval(-5)
        ), "Eine neue EPUB darf wiederverwendet werden")
        precondition(!KDPUploadService.isExportFresh(
            exportedAt: now.addingTimeInterval(-5), manuscriptUpdatedAt: now
        ), "Eine EPUB vor der letzten Manuskriptaenderung muss neu exportiert werden")

        // --- Lesbarkeit -----------------------------------------------------------
        // Bandwurmsätze und Stakkato-Ketten sind die beiden Muster, an denen ein
        // durchschnittlicher Leser abbricht. Gemessen an „Das Gewicht von Seide":
        // 53 Sätze über 30 Wörter mit mehr als vier Einschüben, der längste mit 70
        // Wörtern und 18 Einschüben.
        let bandwurm = """
        Er stand da und sah ihre Hand zittern und wusste, dass sie etwas gehört hatte, \
        Markus, Reutner, die Mühle, die Schulden, einen Plan, der sich bereits bildete, \
        schwer, kalt, notwendig, doch nicht die Hälfte, die sie selbst betraf, und auch \
        nicht das, was er ihr niemals sagen würde, nicht heute, nicht morgen, niemals.
        """
        precondition(AutonomousContentQuality.schwerLesbareSaetze(in: bandwurm).count == 1,
                     "Bandwurmsatz muss erkannt werden")

        let flüssig = """
        Sie stellte die Tasse ab. Der Kaffee war kalt geworden, aber das merkte sie erst \
        jetzt. Draußen fuhr ein Wagen vorbei, langsam, als suche der Fahrer eine Hausnummer.
        """
        precondition(AutonomousContentQuality.schwerLesbareSaetze(in: flüssig).isEmpty,
                     "Flüssiger Text darf nicht als schwer lesbar gelten")
        precondition(AutonomousContentQuality.stakkatoKetten(in: flüssig) == 0)

        let stakkato = "Sie ging. Er blieb. Die Tür fiel zu. Nichts bewegte sich. Dann kam der Regen und alles wurde still."
        precondition(AutonomousContentQuality.stakkatoKetten(in: stakkato) >= 1,
                     "Kette aus vier Kurzsätzen muss erkannt werden")

        // --- Dialoganteil ---------------------------------------------------------
        // Gemessen an „Das Gewicht von Seide": 2,3 % wörtliche Rede im ganzen Buch,
        // sieben von zwölf Kapiteln ohne ein einziges Anführungszeichen. Ein Buch aus
        // reiner Beschreibung und Innenschau ermüdet stärker als jeder lange Satz.
        let mitDialog = """
        Sie stellte die Tasse ab. „Er kommt nicht", sagte sie. Erik hob den Kopf. \
        „Woher willst du das wissen?" – „Weil er nie kommt, wenn es darauf ankommt."
        """
        precondition(AutonomousContentQuality.dialoganteil(in: mitDialog)
                        >= AutonomousContentQuality.dialogUntergrenze,
                     "Szene mit normalem Dialog darf nicht beanstandet werden")

        let ohneDialog = "Der Regen prasselte gegen die Fenster. Sie sah hinaus und dachte an den Sommer."
        precondition(AutonomousContentQuality.dialoganteil(in: ohneDialog)
                        < AutonomousContentQuality.dialogUntergrenze,
                     "Reine Beschreibung muss als dialogarm gelten")

        // --- Titel ----------------------------------------------------------------
        // Recherchiert an den aktuellen deutschen Bestsellerlisten: Jeder Verkaufstitel
        // hat warme Alltagswörter und mindestens einen Anker – Ort, Zeitangabe oder
        // Beziehungswort. „Das Gewicht von Seide" (Testbuch) hat keinen davon.
        for bestseller in ["Ein Wiedersehen im Sommer", "Zwischen Ende und Anfang",
                           "Das kleine Zuhause in Prag", "Warte auf mich am Meer",
                           "All das Ungesagte zwischen uns", "Unser Tag ist heute",
                           "Der Geschmack von Sommer und Karamell"] {
            precondition(!AutonomousContentQuality.titelWirktVerkopft(bestseller),
                         "Bestsellertitel „\(bestseller)“ darf nicht verworfen werden")
        }
        for verkopft in ["Das Gewicht von Seide", "Die Farbe des Schweigens",
                         "Der Klang von Asche", "Fragmente"] {
            precondition(AutonomousContentQuality.titelWirktVerkopft(verkopft),
                         "Verkopfter Titel „\(verkopft)“ muss erkannt werden")
        }

        // --- Titel: kein Abkupfern ------------------------------------------------
        // Die Titel-Prompts nennen echte Bestseller als Muster – genau deshalb muss
        // eine Kopie maschinell auffallen. Buchtitel geniessen Werktitelschutz.
        for kopie in ["Ein Wiedersehen im Sommer", "Ein Wiedersehen im Winter",
                      "Das kleine Zuhause in Wien", "Der Teufel trägt Prada"] {
            precondition(AutonomousContentQuality.istKopieBekannterTitel(kopie),
                         "Kopie „\(kopie)“ muss blockiert werden")
        }
        for eigen in ["Die Nacht, in der du bliebst", "Bevor der Regen kam",
                      "Was zwischen uns steht", "Als das Meer uns fand",
                      "Unser letzter August in Lissabon"] {
            precondition(!AutonomousContentQuality.istKopieBekannterTitel(eigen),
                         "Eigenständiger Titel „\(eigen)“ darf nicht blockiert werden")
        }
        precondition(AutonomousContentQuality.titelAblehnungsgrund("Was zwischen uns steht 2") != nil,
                     "Nummerierte Duplikat-Titel duerfen nicht veroeffentlicht werden")

        print("NovelForge regression probe: PASS")
    }
}
