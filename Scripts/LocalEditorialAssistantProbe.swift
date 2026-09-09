import Foundation

@main
struct LocalEditorialAssistantProbe {
    static var failures = 0

    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        if condition() {
            print("  OK   \(message)")
        } else {
            failures += 1
            print("  FEHL \(message)")
        }
    }

    static func main() {
        print("LOKALER SCHNELLLEKTOR\n")
        let obsolete = "Alsbald vermochte Anna die Spuren allenthalben zu sehen."
        require(AutonomousContentQuality.archaicTellCount(obsolete) == 3,
                "veraltete Woerter werden auch am Satzanfang erkannt")
        require(!AutonomousContentQuality.teenReadabilityIssues(in: obsolete).isEmpty,
                "kurze Texte umgehen die Wortwahlpruefung nicht")
        require(AutonomousContentQuality.archaicTellCount("Es begab sich an einem Abend.") == 1,
                "ueberlappende Wortlisten zaehlen eine Wendung nur einmal")
        require(AutonomousContentQuality.archaicTellCount(
            "Der Platzhalter steht im Antlitzweg. Anna kommt bald wieder.") == 0,
                "Wortteile in modernen Woertern und Eigennamen sind keine Stilbefunde")
        require(LocalEditorialAssistant.inspect(obsolete).sentenceFindings.contains {
            $0.satz == obsolete && $0.grund.contains("Veraltete Wortwahl")
        }, "der lokale Lektor gibt den konkreten Satz an die gezielte Reparatur")

        var opening = LocalEditorialAssistant.OpeningRevisionState(
            text: "Anna wartet am Bahnhof.", issues: ["Der Grund fuer Annas Warten fehlt."])
        require(!opening.consider(text: "Ben wartet am Hafen.",
                    issues: ["Ben ist eine fremde Figur."], canAdvance: false)
                    && opening.text == "Anna wartet am Bahnhof."
                    && opening.issues == ["Der Grund fuer Annas Warten fehlt."],
                "verworfene Fassung ersetzt weder Arbeitstext noch zugehoerige Kritik")
        require(opening.consider(text: "Anna wartet auf ihre Schwester.",
                    issues: [], canAdvance: true) && opening.issues.isEmpty,
                "sichere Verbesserung aktualisiert Text und Befunde gemeinsam")
        require(!opening.consider(text: "Anna wartet.",
                    issues: ["Rueckschritt"], canAdvance: true) && opening.issues.isEmpty,
                "schlechtere Folgerunde verliert den erreichten Fortschritt nicht")

        let source = """
        KAPITZEL 1

        Mara konnte nicht umhin zu bemerken, dass der Raum eine gewisse Kälte ausstrahlte. Ihr Herz begann schneller zu schlagen, und für einen Moment schien die Zeit stillzustehen.

        „Du warst das", sagte Mara. „Sag mir warum."
        """
        let dossier = LocalEditorialAssistant.inspect(
            source,
            priorTexts: ["Jon öffnete die Tür. Der Flur war leer."],
            protagonistNames: ["Mara"],
            isOpening: false
        )

        require(dossier.text.contains("KAPITEL 1"),
                "eindeutige Rechtschreibfehler werden ohne Cloud korrigiert")
        require(!dossier.text.contains("KAPITZEL"),
                "fehlerhafte Schreibweise bleibt nicht stehen")
        require(!dossier.paragraphTargets.isEmpty,
                "nur stilistisch auffällige Absätze werden markiert")
        require(dossier.paragraphTargets.allSatisfy { !$0.reasons.isEmpty },
                "jede Cloud-Markierung hat einen konkreten lokalen Grund")
        require(dossier.needsCloudRepair,
                "auffällige Prosa löst einen gezielten Cloud-Patch aus")
        require(dossier.localCorrectionCount >= 1,
                "lokale Korrekturen werden für die Laufanzeige gezählt")

        let clean = LocalEditorialAssistant.inspect(
            "Mara schob den Schlüssel ins Schloss. Hinter der Tür hustete jemand.",
            priorTexts: [], protagonistNames: ["Mara"], isOpening: false
        )
        require(!clean.needsCloudRepair,
                "saubere kurze Prosa überspringt den Cloud-Lektor")

        let prompt = LocalEditorialAssistant.batchRepairPrompt(
            targets: Array(dossier.paragraphTargets.prefix(4)),
            chapterNumber: 1,
            chapterTitle: "Die Tür"
        )
        require(prompt.contains("BEGINN_"),
                "Bündelprompt nutzt robust abgrenzbare Absätze")
        require(prompt.contains("nur die markierten Absätze"),
                "Bündelprompt verbietet eine Ganzkapitel-Neufassung")

        guard let first = dossier.paragraphTargets.first else {
            print("\nTest kann ohne Zielabsatz nicht fortgesetzt werden")
            exit(1)
        }
        let response = """
        BEGINN_\(first.number)
        Mara bemerkte die Kälte im Raum. Ihr Puls beschleunigte sich.
        ENDE_\(first.number)
        """
        let parsed = LocalEditorialAssistant.parseBatchReplacements(
            response,
            targets: dossier.paragraphTargets
        )
        require(parsed[first.paragraphIndex]?.contains("Mara bemerkte") == true,
                "nummerierte Absatzantwort wird eindeutig zugeordnet")

        let malformed = LocalEditorialAssistant.parseBatchReplacements(
            "Hier ist die überarbeitete Fassung ohne Markierungen.",
            targets: dossier.paragraphTargets
        )
        require(malformed.isEmpty,
                "freie oder beschädigte Antworten verändern keinen Buchtext")

        require(LocalEditorialAssistant.allowsIntermediateOpeningProgress(
                    structuralIssues: [], sentenceCollisions: ["Er öffnete die Tür."]),
                "eine isolierte Satzkollision verwirft semantischen Fortschritt nicht")
        require(!LocalEditorialAssistant.allowsIntermediateOpeningProgress(
                    structuralIssues: ["neue nicht kanonische Figur"],
                    sentenceCollisions: []),
                "Kanon- oder Sicherheitsfehler bleiben harte Fortschrittssperren")
        require(LocalEditorialAssistant.openingRequiresCanonicalRebuild(
                    "Sieglinde nahm den Anruf an und ging zur Fähre.",
                    protagonistNames: ["Notburga Hinterleitner"]),
                "Altanfang ohne kanonische Hauptfigur wird als Neuaufbau erkannt")
        require(!LocalEditorialAssistant.openingRequiresCanonicalRebuild(
                    "Notburga Hinterleitner nahm den Anruf an.",
                    protagonistNames: ["Notburga Hinterleitner"]),
                "korrekter Hauptfigurenanfang bleibt eine normale Überarbeitung")
        require(LocalEditorialAssistant.shouldKeepBestOpeningCandidate(
                    sourceIssueCount: 6, candidateIssueCount: 2,
                    structurallySafe: true, blindComparisonWon: true),
                "messbar bessere sichere Öffnung darf die perfekte Null ersetzen")
        require(!LocalEditorialAssistant.shouldKeepBestOpeningCandidate(
                    sourceIssueCount: 6, candidateIssueCount: 2,
                    structurallySafe: false, blindComparisonWon: true),
                "eine bessere Bewertung überstimmt niemals die Struktursicherheit")
        require(!LocalEditorialAssistant.shouldKeepBestOpeningCandidate(
                    sourceIssueCount: 3, candidateIssueCount: 3,
                    structurallySafe: true, blindComparisonWon: true),
                "Gleichstand reicht nicht zum Ersetzen des Originals")
        require(LocalEditorialAssistant.shouldKeepBestOpeningCandidate(
                    sourceIssueCount: 4, candidateIssueCount: 4,
                    structurallySafe: true, blindComparisonWon: false,
                    sourceCanonicallyInvalid: true,
                    candidateCanonicallyValid: true),
                "ein kanonisch korrigierter Neuaufbau bleibt trotz Blindvergleich erhalten")
        require(!LocalEditorialAssistant.shouldKeepBestOpeningCandidate(
                    sourceIssueCount: 4, candidateIssueCount: 3,
                    structurallySafe: true, blindComparisonWon: true,
                    sourceCanonicallyInvalid: true,
                    candidateCanonicallyValid: false),
                "ein Neuaufbau ohne kanonische Hauptfigur darf nicht gespeichert werden")

        print("\n" + (failures == 0
            ? "ALLE PRÜFUNGEN BESTANDEN"
            : "\(failures) PRÜFUNGEN FEHLGESCHLAGEN"))
        if failures > 0 { exit(1) }
    }
}
