import Foundation

enum AutonomousContentQuality {
    static func hasUsableIdea(_ idea: ParsedIdea?) -> Bool {
        guard let idea else { return false }
        let title = idea.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let premise = idea.premise.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.count >= 4, premise.wordCount >= 10 else { return false }
        return !isGenericPlaceholder(title) && !containsMetaRequest(premise)
    }

    static func hasUsableChapterPlan(_ chapters: [PlannedChapter]) -> Bool {
        guard chapters.count >= 3 else { return false }
        return chapters.allSatisfy { chapter in
            !isGenericPlaceholder(chapter.title)
                && !isGenericPlaceholder(chapter.goal)
                && chapter.goal.wordCount >= 5
                && chapter.conflict.wordCount >= 3
        }
    }

    static func hasUsableScenePlan(_ scenes: [PlannedScene], expectedCount: Int) -> Bool {
        guard scenes.count >= expectedCount else { return false }
        return scenes.allSatisfy { scene in
            scene.goal.wordCount >= 5
                && scene.obstacle.wordCount >= 3
                && scene.turn.wordCount >= 3
                && !isGenericPlaceholder(scene.goal)
        }
    }

    static func acceptsDraftScene(_ text: String, targetWords: Int) -> Bool {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return false }
        guard !containsMetaRequest(cleaned) else { return false }
        let minimum = max(80, Int(Double(targetWords) * 0.55))
        return cleaned.wordCount >= minimum
    }

    static func isGenericPlaceholder(_ text: String) -> Bool {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if normalized.isEmpty { return true }
        if normalized.range(of: #"^kapitel\s+\d+$"#, options: .regularExpression) != nil {
            return true
        }
        let patterns = [
            "roman-roman",
            "setze den plot konsequent fort",
            "führe das kapitelziel weiter",
            "vertiefe das kapitelziel",
            "nächstes buch",
            "untitled"
        ]
        return patterns.contains { normalized == $0 || normalized.hasPrefix($0) }
    }

    static func containsMetaRequest(_ text: String) -> Bool {
        let normalized = text.lowercased()
        let patterns = [
            "bitte füge",
            "bitte gib",
            "fehlt in deiner",
            "nicht übermittelt",
            "nicht im prompt enthalten",
            "keine szene bereitgestellt",
            "szene fehlt",
            "szenentext fehlt",
            "ich kann die szene leider nicht schreiben",
            "ich benötige noch",
            "fehlende angaben",
            "als sprachmodell",
            "als ki-modell",
            "kann ich nicht schreiben",
            "kann ich nicht erstellen",
            "kann ich nicht verfassen",
            "kann ich nicht generieren",
            "kann ich nicht beantworten",
            "kann ich dieser anfrage nicht"
        ]
        if patterns.contains(where: { normalized.contains($0) }) { return true }
        // "als ki" nur als eigenständiges Wort – sonst matcht es "als Kind",
        // "als Kino" usw. und verwirft korrekte Romantexte.
        return normalized.range(of: #"\bals ki\b"#, options: .regularExpression) != nil
    }

    /// Unverwechselbare Instruktions-Fragmente aus den Prompts. Tauchen sie im
    /// generierten Text auf, hat das Modell eine Anweisung in die Prosa kopiert.
    static let promptInstructionMarkers = [
        "knüpfe nahtlos daran an",
        "knüpfe daran an",
        "setze die szene unmittelbar fort",
        "ohne das geschehene zu wiederholen",
        "wörtliches ende der vorherigen szene",
        "bisherige handlung",
        "letzte szenen im detail",
        "bisherige kapitel",
        "genre-handwerk",
        "verbotene floskeln",
        "sog-techniken",
        "keine überschriften",
        "keine meta-kommentare",
        "meta-kommentar",
        "langform-pflicht",
        "schreibe ausschließlich auf",
        "schreibe die szene",
        "schreibe szene",
        "der erste satz ist der wichtigste",
        "erste szene des buches",
        "letzte szene des buches",
        "beginne mitten in der bewegung",
        "zeigen statt behaupten",
        "dialog mit subtext",
        "bestseller-standard",
        "gib ausschließlich den fertigen prosatext",
        "übernimm niemals anweisungen",
        "hinweise aus diesem auftrag",
        "fertigen prosatext der szene",
        "zielumfang"
    ]

    /// Prompt-Labels, die als eigene Zeile auftauchen, wenn das Modell die
    /// Szenen-Vorgabe abschreibt.
    static let promptLabelPrefixes = [
        "stil:", "stilregeln:", "kapitelziel:", "sprache:", "tonalität:",
        "perspektive:", "erzählperspektive:", "zeitform:", "ort:", "zeit:",
        "ziel:", "hindernis:", "wendung am ende:", "wendung:", "figuren:",
        "szene:", "thema:", "zielumfang:", "zielwörter:", "zielwortzahl:",
        "genre:", "tonalität:", "kapitel:", "- ort:", "- zeit:", "- ziel:",
        "- hindernis:", "- wendung"
    ]

    /// Hat das Modell eine Prompt-Anweisung/-Label in die Prosa durchsickern lassen?
    /// Wird beim Schreiben genutzt, um eine betroffene Szene NEU zu generieren.
    static func containsPromptArtifacts(_ text: String) -> Bool {
        let lowered = text.lowercased()
        if promptInstructionMarkers.contains(where: { lowered.contains($0) }) { return true }
        for line in text.components(separatedBy: .newlines) {
            let l = line.trimmingCharacters(in: .whitespaces).lowercased()
            if promptLabelPrefixes.contains(where: { l.hasPrefix($0) }) { return true }
        }
        return false
    }

    /// Entfernt durchgesickerte Prompt-Anweisungen/-Labels aus generierter Prosa –
    /// SATZGENAU, damit auch ein mitten im Absatz eingebetteter Anweisungssatz
    /// verschwindet, ohne die umgebende Erzählung zu beschädigen. Reine Label-Zeilen
    /// (z.B. „Ort: Bäckerei") werden komplett entfernt. Das darf NIE im Buch landen.
    static func strippingPromptArtifacts(_ text: String) -> String {
        var keptLines: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            if trimmed.isEmpty { keptLines.append(line); continue }
            // Ganze Label-/Vorgabe-Zeile entfernen.
            if promptLabelPrefixes.contains(where: { lower.hasPrefix($0) }) { continue }
            // Innerhalb der Zeile nur die Anweisungs-SÄTZE entfernen.
            let cleaned = removingInstructionSentences(from: line)
            if !cleaned.trimmingCharacters(in: .whitespaces).isEmpty {
                keptLines.append(cleaned)
            }
        }
        var result = keptLines.joined(separator: "\n")
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Macht die Prosa „menschlicher": entfernt Gedankenstriche (—, – als
    /// Stilmittel), die ein typisches KI-Erkennungsmerkmal sind, und ersetzt sie
    /// durch natürliche Interpunktion. Zahlenbereiche (z.B. „12–13") bleiben
    /// unangetastet. Räumt anschließend doppelte Satzzeichen/Leerzeichen auf.
    static func humanizeProse(_ text: String) -> String {
        var t = text
        // En-Dash als Gedankenstrich (zwischen Wörtern) → Komma.
        // Zahlenbereiche wie „12–13" bleiben unangetastet (verlangen Buchstaben).
        t = t.replacingOccurrences(
            of: "(?<=\\p{L})\\s*–\\s*(?=\\p{L})", with: ", ", options: .regularExpression)
        // Em-Dash ist nie ein Zahlenbereich → immer durch Komma ersetzen.
        t = t.replacingOccurrences(of: "\\s*—\\s*", with: ", ", options: .regularExpression)
        // Aufräumen: Leerzeichen vor Satzzeichen, doppelte Kommas, führende Kommas,
        // doppelte Leerzeichen.
        t = t.replacingOccurrences(of: "\\s+([,.;:!?])", with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: ",\\s*,", with: ",", options: .regularExpression)
        t = t.replacingOccurrences(of: "(?m)^\\s*,\\s*", with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        return t
    }

    private static func removingInstructionSentences(from line: String) -> String {
        let lower = line.lowercased()
        guard promptInstructionMarkers.contains(where: { lower.contains($0) }) else {
            return line // kein Anweisungs-Fragment → Zeile unverändert lassen
        }
        var kept: [String] = []
        line.enumerateSubstrings(in: line.startIndex..<line.endIndex, options: [.bySentences, .localized]) { sub, _, _, _ in
            guard let sub else { return }
            let s = sub.lowercased()
            if !promptInstructionMarkers.contains(where: { s.contains($0) }) {
                kept.append(sub)
            }
        }
        let rebuilt = kept.joined()
        // Falls die Satzsegmentierung nichts trennen konnte, die ganze Zeile verwerfen.
        return rebuilt.trimmingCharacters(in: .whitespaces).isEmpty ? "" : rebuilt
    }
}
