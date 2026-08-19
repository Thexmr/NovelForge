import Foundation

@main
enum CharacterCanonProbe {
    static func main() {
        let premise = "Die Physiotherapeutin Liv Ellert kehrt an die Nordsee zurueck. Dort trifft Liv ihren Bruder Tjark."
        let names = CharacterCanonAudit.personNames(in: premise)
        precondition(names.contains("Liv Ellert"), "Vollstaendiger Figurenname aus der Praemisse fehlt")
        precondition(names.contains("Tjark"), "Einzelner Figurenname aus der Praemisse fehlt")
        precondition(!names.contains("Dort"), "Satzstarter darf nicht als Figurenname gelten")
        precondition(!names.contains("Bruder"), "Rollenwort darf nicht als Figurenname gelten")
        precondition(!CharacterCanonAudit.personNames(
            in: "Ihr Schwager wartete vor der Tür und rief später noch einmal an."
        ).contains(where: { $0.localizedCaseInsensitiveContains("Schwager") }),
        "Schwager ist ein Rollenwort und darf nie als ungeplante Figur gelten")
        precondition(CharacterCanonAudit.personNames(
            in: "Der Termin ist Donnerstag um neun Uhr. Danach wartet sie am Kai."
        ).isEmpty,
        "Zeitangaben und Wochentage duerfen nicht als ungeplante Figuren gelten")
        precondition(!CharacterCanonAudit.personNames(
            in: "Konflikt: Neid"
        ).contains(where: { $0.localizedCaseInsensitiveContains("Neid") }),
        "Ein Gefuehlsbegriff darf die Plotplanung nicht als erfundene Figur stoppen")

        let harmlessScene = String(repeating:
            "Karin wartet unter dem Vordach, bis ihr Schwager den Ring vom Boden aufhebt. ",
            count: 8
        ) + "Dann gehen beide schweigend ins Haus."
        precondition(AutonomousContentQuality.hardDraftPersistenceIssues(
            harmlessScene,
            targetWords: 200,
            allowedNames: ["Karin Esser"],
            forbiddenNames: ["liv", "voss"]
        ).isEmpty,
        "Heuristische Rollen- und Requisitenbefunde duerfen einen fertigen Entwurf nicht verwerfen")

        let reusedNameScene = String(repeating:
            "Karin wartet im Flur und hört Liv Voss im Nebenzimmer sprechen. ",
            count: 8
        ) + "Dann schließt sie leise die Tür."
        precondition(AutonomousContentQuality.hardDraftPersistenceIssues(
            reusedNameScene,
            targetWords: 200,
            allowedNames: ["Karin Esser"],
            forbiddenNames: ["liv", "voss"]
        ).contains(where: { $0.contains("Namen aus frueheren Buechern") }),
        "Tatsaechlich wiederverwendete Katalognamen muessen hart gesperrt bleiben")

        let technicalNounScene = String(repeating:
            "Karin prüfte den Brenner im Leuchtturm und drehte die Gaszufuhr vorsichtig zu. ",
            count: 8
        ) + "Danach schloss sie die Wartungsklappe."
        precondition(AutonomousContentQuality.hardDraftPersistenceIssues(
            technicalNounScene,
            targetWords: 200,
            allowedNames: ["Karin Esser"],
            forbiddenNames: ["brenner", "liv", "voss"]
        ).isEmpty,
        "Ein Sachwort darf nicht allein wegen eines gleichlautenden alten Nachnamens blockieren")

        let resumeForbidden = StoryMemory.forbiddenNamePartsForCanonCheck(
            ["jonas", "liv", "voss"],
            establishedNames: ["Jonas Weyer"],
            hasWrittenProse: true
        )
        precondition(!resumeForbidden.contains("jonas")
                     && resumeForbidden.contains("liv")
                     && resumeForbidden.contains("voss"),
        "Beim Fortsetzen darf ein eigener bereits geschriebener Kanonname nicht mit sich selbst kollidieren")
        precondition(StoryMemory.forbiddenNamePartsForCanonCheck(
            ["jonas", "liv", "voss"],
            establishedNames: ["Jonas Weyer"],
            hasWrittenProse: false
        ).contains("jonas"),
        "Vor dem ersten Prosatext muss die katalogweite Namenssperre unveraendert gelten")
        var resumeRegistry = StoryMemory.CatalogNameRegistry()
        precondition(resumeRegistry.reserve(
            ["Jonas Weyer"], projects: [], for: UUID(),
            grandfatheredNames: ["Jonas Weyer"]
        ).isEmpty,
        "Das Laufzeitregister muss den eigenen etablierten Namen beim Resume reservieren koennen")
        var freshRegistry = StoryMemory.CatalogNameRegistry()
        precondition(!freshRegistry.reserve(
            ["Jonas Weyer"], projects: [], for: UUID()
        ).isEmpty,
        "Ein neues Buch darf einen global gesperrten Namen weiterhin nicht reservieren")

        let roleCanon = """
        Die Hauptfigur Karin kehrt auf die Insel zurück. Der Antagonist ist ihre Schwester,
        die den Leuchtturm verkaufen will. Die Mutter wurde bei der Planung nicht gefragt.
        """
        let roleNames = ["Karin Esser", "Trude Bültmann", "Ingeborg Deckers", "Peter Reuter"]
        let roles = [
            "Karin Esser": "Protagonistin",
            "Trude Bültmann": "Antagonistin",
            "Ingeborg Deckers": "Mutter/Subplot-Trägerin",
            "Peter Reuter": "Jugendliebe/Deuteragonist"
        ]
        let relationships = [
            "Karin Esser": "Peter Reuter: Jugendliebe",
            "Trude Bültmann": "beauftragt Wertgutachter und Notar",
            "Ingeborg Deckers": "Peter Reuter: vertraute ihm den Turm an",
            "Peter Reuter": "Karin Esser: Jugendliebe"
        ]
        precondition(CharacterCanonAudit.canonicalNamesReferenced(
            in: "Die Schwester hat den Wertgutachter schon kommen lassen.",
            names: roleNames,
            rolesByName: roles,
            relationshipsByName: relationships,
            canon: roleCanon
        ) == ["Trude Bültmann"],
        "Eine relationale Plotrolle muss auf das dafuer angelegte Figurenprofil zeigen")
        let roleContract = CharacterCanonAudit.roleIdentityContract(
            names: roleNames,
            rolesByName: roles,
            relationshipsByName: relationships,
            canon: roleCanon
        )
        precondition(roleContract.contains("Trude Bültmann")
                     && roleContract.localizedCaseInsensitiveContains("Schwester"),
                     "Der Schreibkontext muss die aufgeloeste Rollenidentitaet ausdruecklich nennen")

        let genitiveNames = CharacterCanonAudit.personNames(
            in: "Erik Brenner blieb am Kai. Nach Eriks Abreise wartete Alina allein."
        )
        precondition(genitiveNames.contains("Erik Brenner"))
        precondition(!genitiveNames.contains(where: { $0.localizedCaseInsensitiveContains("Abreise") }),
                     "Ein Substantiv nach einem Namensgenitiv darf nicht Teil des Namens werden")
        let loneGenitive = CharacterCanonAudit.personNames(
            in: "Lina Kesslers verschollene Schwester hinterliess eine Jacke. Vor dem Schlaf sah sie Augen."
        )
        precondition(loneGenitive.contains("Lina Kessler"),
                     "Ein allein stehender Genitivname muss auf den Kanonnamen zurueckgefuehrt werden")
        for falseName in ["verschollene", "Jacke", "Vor", "Schlaf", "Augen"] {
            precondition(!loneGenitive.contains(where: {
                $0.localizedCaseInsensitiveContains(falseName)
            }), "Gewoehnliches Plotwort darf keine Pflichtfigur werden: \(falseName)")
        }
        precondition(CharacterCanonAudit.personNames(in: "Peter Voss ging hinaus.").contains("Peter Voss"),
                     "Ein echter Nachname auf s darf nicht als Genitiv gekuerzt werden")
        let apostrophePossessive = CharacterCanonAudit.personNames(
            in: "Jonas Weyer blieb auf der Insel. Jonas' Freiheit war ihm wichtig. "
                + "Jonas’ Bruder Finn Weyer lebte ebenfalls dort."
        )
        precondition(apostrophePossessive.contains("Jonas Weyer")
                     && !apostrophePossessive.contains(where: {
                         $0 == "Jona" || $0.hasPrefix("Jona ")
                     }),
        "Ein Eigenname auf s mit Genitiv-Apostroph darf nicht zu einer Scheinfrau gekuerzt werden")
        let plotSentenceStarters = CharacterCanonAudit.personNames(
            in: "Zu weiß für Holz. Papier. Verbranntes Papier. Die Schwester las ihn. "
                + "Las Worte, die sie nicht kannte."
        )
        precondition(!plotSentenceStarters.contains("Papier"),
                     "Ein alleinstehendes Substantiv im Plot darf nicht als Figur gelten")
        precondition(!plotSentenceStarters.contains("Las"),
                     "Ein satzinitiales Verb im Plot darf nicht als Figur gelten")
        let roleOnlyPlot = CharacterCanonAudit.personNames(
            in: "Die Hauptfigur trifft ihre Jugendliebe. Der Gegenspieler spricht mit dem Notar."
        )
        precondition(roleOnlyPlot.isEmpty,
                     "Rollenbezeichnungen aus einem namenlosen Plot duerfen keine Pflichtnamen werden")
        precondition(CharacterCanonAudit.nameParts("Kein").isEmpty,
                     "Das satzinitiale Negationswort Kein darf nie zum Personennamen werden")
        let groundedRelationships = AutonomousContentQuality.groundedRelationships(
            "Tomasz Meschke: Jugendliebe; Nadezda Bartusch: Rivalin",
            canon: "Tomasz Meschke ist die Jugendliebe. Nadezda Bartusch arbeitet gegen sie.",
            characterNames: ["Marta Zschornack", "Tomasz Meschke", "Nadezda Bartusch"],
            subject: "Marta Zschornack"
        )
        precondition(groundedRelationships.contains("Jugendliebe")
                     && groundedRelationships.contains("Rivalin"),
                     "Nicht-familiäre Beziehungen zwischen bekannten Figuren duerfen nicht verschwinden")
        precondition(AutonomousContentQuality.groundedRelationships(
            "Tomasz Meschke: Vater",
            canon: "Tomasz Meschke ist die Jugendliebe.",
            characterNames: ["Marta Zschornack", "Tomasz Meschke"],
            subject: "Marta Zschornack"
        ).isEmpty, "Eine erfundene Verwandtschaft muss weiterhin blockiert werden")
        let realConceptGenitive = CharacterCanonAudit.personNames(
            in: "Der Antagonist ist Silke, Maras ehemalige beste Freundin und jetzige Inselaerztin."
        )
        precondition(realConceptGenitive.contains("Mara"),
                     "Der Genitiv 'Maras ehemalige Freundin' muss auf Mara zurueckgefuehrt werden")
        precondition(!realConceptGenitive.contains("Maras"),
                     "Der deutsche Genitiv darf keine Scheinfrau namens Maras erzeugen")
        precondition(CharacterCanonAudit.missingRequiredNames(
            required: ["Mara Keitum", "Maras", "Jonas", "Silke"],
            candidateNames: ["Mara Keitum", "Jonas Albers", "Silke Janssen"]
        ).isEmpty, "Eine bereits belegte Figur darf durch ihre Genitivform nicht erneut fehlen")
        precondition(CharacterCanonAudit.missingRequiredNames(
            required: ["Jonas"], candidateNames: ["Jona Feld"]
        ) == ["Jonas"], "Ein echter Name auf s darf nicht als Genitiv verkuerzt werden")

        let manuscript = """
        Die Hand lag auf der Tuer. Liv wartete am Fenster. Als Arne eintrat, schwieg Liv.
        Arne legte den Brief ab. Das Wasser rauschte. Liv sah Arne an.
        """
        let catalog = CharacterCanonAudit.catalogNameParts(
            bibleNames: [], narrativeTexts: [manuscript]
        )
        precondition(catalog.contains("liv"), "Tatsaechlicher Manuskriptname Liv muss gesperrt werden")
        precondition(catalog.contains("arne"), "Tatsaechlicher Manuskriptname Arne muss gesperrt werden")
        precondition(!catalog.contains("hand"), "Gewoehnliches Substantiv darf nicht als Name gesperrt werden")
        precondition(!catalog.contains("tuer"), "Gewoehnliches Substantiv darf nicht als Name gesperrt werden")

        let actingNames = CharacterCanonAudit.actingCharacterNameParts(
            narrativeTexts: [
                "Liv sagte nichts. Arne legte den Brief ab. Liv fragte nach. "
                    + "Kronborg lag im Nebel. Arne antwortete leise."
            ], minimumOccurrences: 2
        )
        precondition(actingNames.contains("liv") && actingNames.contains("arne"))
        precondition(!actingNames.contains("kronborg"),
                     "Ein wiederholt genannter Ort darf nicht als handelnde Figur gelten")
        let commonNouns = CharacterCanonAudit.actingCharacterNameParts(
            narrativeTexts: [
                "Der Atem ging schnell. Das Auto stand draussen. Das Display zeigte nichts. "
                    + "Doch dann kam das Boot. Am Fenster stand Licht. Der Atem ging wieder schnell. "
                    + "Das Auto stand still."
            ], minimumOccurrences: 1
        )
        precondition(commonNouns.isEmpty,
                     "Atem, Auto, Display, Boot und Satzstarter duerfen keine Figuren sein")
        precondition(CharacterCanonAudit.unexpectedActingCharacterParts(
            in: "Liv ging nach Kronborg. Kronborg. Sagte Liv nichts?",
            allowedNames: ["Liv Ellert"]
        ).isEmpty, "Ein Verb im naechsten Satz darf das vorige Wort nicht zur Figur machen")
        precondition(CharacterCanonAudit.unexpectedActingCharacterParts(
            in: "Liv sagte nichts. Arne legte den Brief ab. Arne antwortete leise. Kronborg lag im Nebel.",
            allowedNames: ["Liv Ellert"]
        ) == ["arne"], "Nur wirklich handelnde, nicht kanonische Figuren duerfen blockieren")

        let missing = CharacterCanonAudit.missingRequiredNames(
            required: ["Liv Ellert", "Tjark"],
            candidateNames: ["Freja Holbek", "Tjare Wessel", "Bo Holbek"]
        )
        precondition(missing == ["Liv Ellert", "Tjark"],
                     "Ein widerspruechliches Figurenensemble muss komplett abgelehnt werden")
        precondition(CharacterCanonAudit.missingRequiredNames(
            required: ["Liv Ellert", "Tjark"],
            candidateNames: ["Liv Ellert", "Tjark Wessel", "Bo Holbek"]
        ).isEmpty, "Kanonische Namen duerfen mit ergaenztem Nachnamen akzeptiert werden")
        precondition(CharacterCanonAudit.missingRequiredNames(
            required: ["Isolde Keitum"],
            candidateNames: ["Isolde Lindqvist", "Alois Keitum"]
        ) == ["Isolde Keitum"],
        "Teile eines Vollnamens duerfen nicht ueber zwei Profile verteilt den Kanon vortaeuschen")
        precondition(CharacterCanonAudit.missingRequiredNames(
            required: ["Liv"],
            candidateNames: ["Alva Reineke", "Henning Ostwald", "Ostwald Livs"]
        ) == ["Liv"],
        "Ein zusammengerutschtes Profil wie 'Ostwald Livs' darf Liv nicht als eigene Figur vortaeuschen")
        let adjacentPossessiveNames = CharacterCanonAudit.personNames(
            in: "Henning Ostwald wartet. Alva sieht, wie Ostwald Livs Handy ortet und sofort zur Tuer geht."
        )
        precondition(adjacentPossessiveNames.contains("Liv"),
                     "Livs muss im Satz als eigenstaendiger Genitivname erkannt werden: \(adjacentPossessiveNames)")
        precondition(!adjacentPossessiveNames.contains(where: {
            $0.localizedCaseInsensitiveContains("Ostwald Liv")
        }), "Zwei benachbarte Figuren duerfen nicht zu 'Ostwald Livs' verschmelzen")
        precondition(!CharacterCanonAudit.personNames(
            in: "Hagedorn beobachtete ihren Vater nachts im Wald. Im Wald lag ein Messer."
        ).contains("Wald"), "Ein gewoehnlicher Schauplatz darf keine Pflichtfigur werden")
        precondition(
            CharacterCanonAudit.isLocationCharacterRole("Nebenfigur, Schauplatz"),
            "Ein Schauplatz darf nie als Figurenprofil gespeichert werden"
        )
        precondition(
            !CharacterCanonAudit.isLocationCharacterRole("Nebenfigur, Katalysator"),
            "Eine echte Figurenrolle darf nicht entfernt werden"
        )
        let parsedProfiles = StructureParser.parseCharacters("""
        FIGUR|Wald|Nebenfigur, Schauplatz|—|—|—|—|—
        FIGUR|Mara Feld|Protagonistin|34|Restauratorin|Den Vertrag finden|Den Bruder verlieren|Misstrauen
        """)
        precondition(parsedProfiles.map(\.name) == ["Mara Feld"],
                     "Der Figurenparser darf einen Ort nicht als Person uebernehmen")

        let ensembleNames = [
            "Isolde Keitum", "Isolde Lindqvist", "Nele Wein", "Mara Herz", "Salz"
        ]
        precondition(
            CharacterCanonAudit.duplicateGivenNameConflicts(
                in: ensembleNames,
                requiredNames: ["Isolde Keitum", "Lindqvist", "Nele Wein"]
            ) == ["Isolde"],
            "Ein erfundener zweiter Isolde-Vorname muss vor dem Speichern blockieren"
        )
        precondition(
            Set(CharacterCanonAudit.unauthorizedSupplementaryNames(
                candidateNames: ensembleNames,
                requiredNames: ["Isolde Keitum", "Lindqvist", "Nele Wein"],
                assignedSupplementaryNames: ["Tamme Cordes"]
            )) == Set(["Mara Herz", "Salz"]),
            "Zusatzfiguren duerfen nur aus der katalogweit vergebenen Namensliste stammen"
        )
        let safeSupplementaryReplacement = CharacterCanonAudit.supplementaryNameReplacements(
            candidateNames: ["Ludwig Obermeier", "Maren Nissen"],
            requiredNames: [],
            assignedSupplementaryNames: ["Hauke Thomsen", "Maren Nissen"]
        )
        precondition(safeSupplementaryReplacement == ["Ludwig Obermeier": "Hauke Thomsen"],
                     "Ein erfundener Zusatzname muss vor der Prosa sicher zugewiesen werden")
        precondition(CharacterCanonAudit.supplementaryNameReplacements(
            candidateNames: ["Ludwig Obermeier", "Peter Voss"],
            requiredNames: [],
            assignedSupplementaryNames: ["Hauke Thomsen"]
        ) == nil, "Ohne genug freie Namen darf keine halbe Umbenennung stattfinden")
        let genderedReplacement = NamensGenerator.geschlechtsgerechteErsetzungen(
            candidateNames: ["Theresa Huber", "Korbinian Zehentner"],
            rolesByName: [
                "Theresa Huber": "Hauptfigur, Grafikdesignerin",
                "Korbinian Zehentner": "Jugendliebe, Zimmerer"
            ],
            occupationsByName: [
                "Theresa Huber": "Grafikdesignerin",
                "Korbinian Zehentner": "Zimmerer"
            ],
            requiredNames: [],
            assigned: [
                .init(vorname: "Dieter", nachname: "Esser", region: "Test"),
                .init(vorname: "Agathe", nachname: "Bültmann", region: "Test")
            ]
        )
        precondition(genderedReplacement == [
            "Theresa Huber": "Agathe Bültmann",
            "Korbinian Zehentner": "Dieter Esser"
        ], "Automatische Namenszuweisung muss Geschlecht und Rolle respektieren")
        precondition(NamensGenerator.geschlecht(
            vonRolle: "Jugendliebe/Restaurator", beruf: "Restaurator"
        ) == .maennlich, "Eine maskuline Berufsrolle braucht einen maennlichen Namen")
        precondition(NamensGenerator.geschlecht(
            vonRolle: "Hauptfigur", beruf: "Grafikdesignerin"
        ) == .weiblich, "Eine feminine Berufsrolle braucht einen weiblichen Namen")
        let assignedGenderSwap = NamensGenerator.geschlechtsgerechteErsetzungen(
            candidateNames: ["Cecylia Duda", "Dariusz Jasinski"],
            rolesByName: [
                "Cecylia Duda": "Jugendliebe/Restaurator",
                "Dariusz Jasinski": "Hauptfigur/Grafikdesignerin"
            ],
            occupationsByName: [
                "Cecylia Duda": "Restaurator",
                "Dariusz Jasinski": "Grafikdesignerin"
            ],
            requiredNames: [],
            assigned: [
                .init(vorname: "Cecylia", nachname: "Duda", region: "Test"),
                .init(vorname: "Dariusz", nachname: "Jasinski", region: "Test")
            ]
        )
        precondition(assignedGenderSwap == [
            "Cecylia Duda": "Dariusz Jasinski",
            "Dariusz Jasinski": "Cecylia Duda"
        ], "Auch bereits zugewiesene, aber vertauschte Namen muessen sicher getauscht werden")
        precondition(CharacterCanonAudit.missingRelationshipTargets(
            subject: "Dorota Cieslak",
            relationships: "Cecylia Duda: Jugendliebe; Dariusz Jasinski: Gegenspieler",
            characterNames: [
                "Dorota Cieslak", "Cecylia Duda", "Gabriela Gorski", "Dariusz Jasinski"
            ]
        ) == ["Gabriela Gorski"],
        "Jede zentrale Figur muss im Beziehungsnetz der anderen vorkommen")
        precondition(CharacterCanonAudit.relationshipGraphIssues(
            relationshipsBySubject: [
                "Marta Ryba": "Mirko Domin: Jugendliebe",
                "Mirko Domin": "Marta Ryba: Jugendliebe; Nadezda Czorny: Schwester",
                "Nadezda Czorny": "Mirko Domin: Bruder"
            ],
            characterNames: ["Marta Ryba", "Mirko Domin", "Nadezda Czorny"]
        ).isEmpty,
        "Ein zusammenhaengendes Beziehungsnetz braucht keine kuenstliche Jeder-mit-jedem-Kante")
        precondition(!CharacterCanonAudit.relationshipGraphIssues(
            relationshipsBySubject: [
                "Marta Ryba": "Mirko Domin: Jugendliebe",
                "Mirko Domin": "Marta Ryba: Jugendliebe",
                "Nadezda Czorny": "Bogumil Barthel: Schwester",
                "Bogumil Barthel": "Nadezda Czorny: Bruder"
            ],
            characterNames: [
                "Marta Ryba", "Mirko Domin", "Nadezda Czorny", "Bogumil Barthel"
            ]
        ).isEmpty,
        "Voneinander getrennte Figurengruppen muessen weiterhin abgelehnt werden")
        let cleanedRelationshipMap = AutonomousContentQuality.groundedRelationshipsBySubject(
            [
                "Marta Ryba": "Ludwig: Jugendliebe; Mirko Domin: Restaurator",
                "Mirko Domin": "Marta Ryba: Jugendliebe"
            ],
            canon: "Marta Ryba ist die Hauptfigur. Mirko Domin ist Restaurator.",
            characterNames: ["Marta Ryba", "Mirko Domin"]
        )
        precondition(
            cleanedRelationshipMap["Marta Ryba"] == "Mirko Domin: Restaurator"
                && !(cleanedRelationshipMap["Marta Ryba"] ?? "").contains("Ludwig"),
            "Alte Modellnamen muessen vor der Ensemblepruefung aus Beziehungen verschwinden"
        )
        let safeRelationshipFeedback = CharacterCanonAudit.relationshipRetryFeedback(
            missingTargets: ["Mirko Domin"], unexpectedParts: ["ludwig"]
        )
        let safeRelationshipFeedbackText = safeRelationshipFeedback.joined(separator: " ")
        precondition(safeRelationshipFeedbackText.contains("Mirko Domin")
                     && !safeRelationshipFeedbackText.lowercased().contains("ludwig"),
                     "Ein abgelehnter Modellname darf nicht in den naechsten Prompt zurueckfliessen")
        let unrelatedNames = NamensGenerator.namen(
            anzahl: 8,
            gesperrt: [],
            streuung: UUID(uuidString: "10000000-0000-0000-0000-000000000001")!,
            eineFamilie: false
        )
        precondition(Set(unrelatedNames.map(\.nachname)).count == unrelatedNames.count,
                     "Automatisch benannte Liebesfiguren duerfen nicht zufaellig wie Geschwister wirken")
        precondition(unrelatedNames.filter { $0.geschlecht == .weiblich }.count >= 4
                     && unrelatedNames.filter { $0.geschlecht == .maennlich }.count >= 4,
                     "Der reservierte Pool braucht genug weibliche und maennliche Namen")
        precondition(
            NamensGenerator.stabilerSeed(
                UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
            ) == 72_057_594_037_927_936,
            "Der Namenspool darf nicht von Swifts pro Prozess randomisiertem hashValue abhaengen"
        )
        precondition(
            CharacterCanonAudit.duplicateGivenNameConflicts(
                in: ["Mara Feld", "Mara Voss"],
                requiredNames: ["Mara Feld", "Mara Voss"]
            ).isEmpty,
            "Zwei im Primaerkanon ausdruecklich benannte gleichnamige Menschen bleiben zulaessig"
        )

        let unknownPeople = CharacterCanonAudit.unexpectedMentionedPersonParts(
            in: "Petersen legte auf. Linda Keitum stellte den Hoerer ab.",
            allowedNames: ["Isolde Keitum", "Nele Wein"]
        )
        precondition(unknownPeople.contains("petersen") && unknownPeople.contains("linda"),
                     "Neu erfundene benannte Menschen muessen schon im Szenenentwurf auffallen: \(unknownPeople)")
        precondition(
            CharacterCanonAudit.nameIntegrityIssues(
                allowedNames: ["Mara"],
                candidateText: "Mara Brenner kehrt zurueck und trifft Jonas Voss.",
                forbiddenNames: ["brenner", "voss", "liv"]
            ).count >= 2,
            "Konzept und Plot duerfen weder einen Nachnamen ergaenzen noch neue Lieblingsnamen einfuehren"
        )
        precondition(
            CharacterCanonAudit.nameIntegrityIssues(
                allowedNames: ["Mara"],
                candidateText: "Mara kehrt zurueck und trifft ihre Jugendliebe.",
                forbiddenNames: ["brenner", "voss", "liv"]
            ).isEmpty,
            "Ein exakt erhaltener Seed-Name und unbenannte Rollen muessen erlaubt bleiben"
        )
        precondition(
            CharacterCanonAudit.nameIntegrityIssues(
                allowedNames: [],
                candidateText: "Die Restauratorin trifft ihre Jugendliebe am Leuchtturm.",
                forbiddenNames: ["brenner", "voss", "liv"]
            ).isEmpty,
            "Ein namenloser Konzeptentwurf darf nicht durch Rollenwoerter blockiert werden"
        )
        let legacyAliasRepair = CharacterCanonAudit.legacyPossessiveAliasReplacements(
            characterNames: ["Malte Ostwald", "Henning Ostwald", "Hagedorn", "Ostwald Livs", "Wald"],
            relationshipsByName: [
                "Malte Ostwald": "",
                "Henning Ostwald": "Hagedorn: Tochter, Instrument",
                "Hagedorn": "Henning Ostwald: Vater"
            ]
        )
        precondition(legacyAliasRepair == ["Liv": "Hagedorn"],
                     "Der alte Tochtername muss eindeutig auf den aktuellen Kanonnamen zeigen")

        let renamed = CharacterCanonAudit.replacingNames(
            in: "Liv Ellert kehrt zurueck. Tjark fragt Liv, warum Ellert geschwiegen hat.",
            replacements: ["Liv Ellert": "Anke Jansen", "Tjark": "Hauke"]
        )
        precondition(renamed == "Anke Jansen kehrt zurueck. Hauke fragt Anke, warum Jansen geschwiegen hat.",
                     "Eine Kanon-Umbenennung muss Vollname und spaetere Kurzformen gemeinsam ersetzen: \(renamed)")
        precondition(!renamed.lowercased().contains("liv") && !renamed.lowercased().contains("ellert"),
                     "Der alte Name darf in keiner Kanonquelle zurueckbleiben")
        precondition(CharacterCanonAudit.replacingNames(
            in: "Livs Handy lag neben Liv. Hans' Mappe blieb zu.",
            replacements: ["Liv": "Hagedorn", "Hans": "Marek"]
        ) == "Hagedorns Handy lag neben Hagedorn. Mareks Mappe blieb zu.",
        "Auch Genitiv- und Apostrophformen muessen grammatisch konsistent umbenannt werden")

        let perspectiveRoles = [
            "Karin Esser": "Protagonistin",
            "Peter Reuter": "Jugendliebe/Deuteragonist",
            "Trude Bültmann": "Antagonistin"
        ]
        precondition(CharacterCanonAudit.canonicalPerspectiveName(
            "Peter", names: Array(perspectiveRoles.keys), rolesByName: perspectiveRoles
        ) == "Peter Reuter",
        "Ein eindeutiger Vorname muss auf den kanonischen Vollnamen zeigen")
        precondition(CharacterCanonAudit.canonicalPerspectiveName(
            "Personaler Erzähler (Er/Sie)",
            names: Array(perspectiveRoles.keys), rolesByName: perspectiveRoles
        ) == "Karin Esser",
        "Ein Erzaehlmodus im Perspektivfeld muss auf die Protagonistin zurueckfallen")
        precondition(CharacterCanonAudit.canonicalPerspectiveName(
            "Liv Voss", names: Array(perspectiveRoles.keys), rolesByName: perspectiveRoles
        ) == "Karin Esser",
        "Ein fremder Perspektivname darf nicht in die Rohfassung gelangen")

        var registry = StoryMemory.CatalogNameRegistry()
        let firstWorker = UUID()
        let secondWorker = UUID()
        precondition(
            registry.reserve(
                ["Siva Nolden"], projects: [], for: firstWorker
            ).isEmpty,
            "Der erste parallele Worker muss einen freien Namen atomisch reservieren koennen"
        )
        precondition(
            registry.reserve(
                ["Siva Nolden"], projects: [], for: firstWorker
            ).isEmpty,
            "Ein Worker darf seinen eigenen bereits reservierten Kanonnamen wiederverwenden"
        )
        precondition(
            !registry.reserve(
                ["Siva Nolden"], projects: [], for: secondWorker
            ).isEmpty,
            "Ein zweiter Worker darf denselben noch nicht gespeicherten Namen nicht reservieren"
        )
        precondition(
            !registry.reserve(
                ["Sivia Nolden"], projects: [], for: secondWorker
            ).isEmpty,
            "Auch eine klangnahe Variante eines parallel reservierten Namens muss blockieren"
        )
        precondition(
            registry.reserve(
                ["Wiebke Harms"], projects: [], for: secondWorker
            ).isEmpty,
            "Ein katalogweit neuer Name muss fuer den zweiten Worker reservierbar bleiben"
        )
        precondition(
            !registry.reserve(
                ["Peter Voss"], projects: [], persisted: ["voss"], for: UUID()
            ).isEmpty,
            "Ein aus einem geloeschten Projekt dauerhaft gespeicherter Name muss gesperrt bleiben"
        )
        let persistedClaims = [
            firstWorker.uuidString: ["siva", "nolden"],
            secondWorker.uuidString: ["wiebke", "harms"]
        ]
        precondition(
            StoryMemory.persistedNameParts(
                in: persistedClaims, excluding: firstWorker
            ) == ["wiebke", "harms"],
            "Beim Fortsetzen darf ein Projekt nicht an seinen eigenen dauerhaften Namen scheitern"
        )
        precondition(
            StoryMemory.persistedNameParts(
                in: persistedClaims, excluding: UUID()
            ) == ["siva", "nolden", "wiebke", "harms"],
            "Ein neues Projekt muss alle dauerhaft vergebenen Namen sehen"
        )

        let draftCharacter = CharacterProfile(name: "Mara Feld", role: "Protagonistin")
        draftCharacter.age = "34"
        draftCharacter.occupation = "Restauratorin"
        draftCharacter.goal = "Den gefaelschten Vertrag beweisen"
        draftCharacter.relationships = "Schwester von Nele"
        draftCharacter.speechPattern = "Kurze Saetze, sagt immer 'ehrlich gesagt'"
        draftCharacter.importantFacts = "Äußeres: Narbe am Handgelenk; roter Mantel, immer getragen\n"
            + "[STAND K4] WEISS: Nele hat gelogen | STIMMUNG: misstrauisch | ZULETZT: im Archiv"
        let draftingSummary = CharacterCanonAudit.draftingCharacterSummary([draftCharacter])
        precondition(draftingSummary.contains("Mara Feld"))
        precondition(draftingSummary.contains("Nele hat gelogen"),
                     "Der aktuelle Figurenstand muss im Schreibkontext erhalten bleiben")
        precondition(!draftingSummary.localizedCaseInsensitiveContains("ehrlich gesagt"),
                     "Eine Catchphrase darf nicht in jede Szene eingespeist werden")
        precondition(!draftingSummary.localizedCaseInsensitiveContains("Narbe am Handgelenk"),
                     "Ein Aussehensmerkmal darf nicht zur mechanischen Szenenrequisite werden")
        precondition(!draftingSummary.localizedCaseInsensitiveContains("roter Mantel"),
                     "Dauerrequisiten muessen aus dem eigentlichen Prosakontext verschwinden")

        var storyRegistry = StoryMemory.StoryIdeaRegistry()
        let firstIdea = ParsedIdea(
            title: "Das Salz unter der Haut",
            genre: "Psychothriller",
            premise: "Eine Heimkehrerin sucht ihre verschwundene Schwester und entdeckt ein Familiengeheimnis."
        )
        let parallelDuplicate = ParsedIdea(
            title: "Die Schwester im Nebel",
            genre: "Psychothriller",
            premise: "Nach ihrer Rueckkehr sucht eine Frau die vermisste Schwester und stoesst auf das Geheimnis ihrer Familie."
        )
        let distinctIdea = ParsedIdea(
            title: "Sieben Minuten Stille",
            genre: "Psychothriller",
            premise: "Eine Notrufdisponentin erkennt in anonymen Anrufen ein Muster, das ihren eigenen Erinnerungen widerspricht."
        )
        precondition(
            storyRegistry.claim(firstIdea, existing: [], persisted: []),
            "Der erste parallele Worker muss eine neue Geschichte atomisch reservieren koennen"
        )
        precondition(
            !storyRegistry.claim(parallelDuplicate, existing: [], persisted: []),
            "Ein zweiter Worker darf dieselbe noch nicht gespeicherte Geschichte nicht reservieren"
        )
        precondition(
            storyRegistry.claim(distinctIdea, existing: [], persisted: []),
            "Eine wirklich andere Geschichte muss parallel reservierbar bleiben"
        )
        var restartedRegistry = StoryMemory.StoryIdeaRegistry()
        precondition(
            !restartedRegistry.claim(
                firstIdea,
                existing: [],
                persisted: [StoryMemoryEntry(
                    title: firstIdea.title,
                    genre: firstIdea.genre,
                    premise: firstIdea.premise
                )]
            ),
            "Eine Geschichte aus einem geloeschten Projekt muss nach Neustart gesperrt bleiben"
        )

        let existingCommandTitle = StoryMemoryEntry(
            title: "Sprich, bevor du stirbst",
            genre: "Psychothriller",
            premise: "Eine Zeugin muss den Urheber einer alten Tonaufnahme finden."
        )
        let recycledCommandTitle = ParsedIdea(
            title: "Schweig, wenn sie dich sieht",
            genre: "Horror",
            premise: "Auf einer abgelegenen Insel veraendert eine Glocke jede Nacht die Erinnerungen der Bewohner."
        )
        precondition(
            StoryMemory.isLikelyDuplicate(
                recycledCommandTitle, existing: [existingCommandTitle]
            ),
            "Eine zweite Befehls-/Bedingungs-Titelschablone muss katalogweit blockiert werden"
        )
        let genuinelyDifferentTitle = ParsedIdea(
            title: "Die dreizehnte Glocke",
            genre: "Horror",
            premise: recycledCommandTitle.premise
        )
        precondition(
            !StoryMemory.isLikelyDuplicate(
                genuinelyDifferentTitle, existing: [existingCommandTitle]
            ),
            "Ein syntaktisch anderer Titel zu einer anderen Geschichte muss erlaubt bleiben"
        )

        print("NovelForge character canon probe: PASS")
    }
}
