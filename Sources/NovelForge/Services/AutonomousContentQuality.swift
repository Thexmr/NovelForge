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

    /// Entfernt durchgesickerte Prompt-Anweisungen und -Labels aus generierter
    /// Prosa. LLMs kopieren gelegentlich Instruktionen wie
    /// „Knüpfe nahtlos daran an – ohne das Geschehene zu wiederholen …" oder
    /// Labels wie „Ort:" / „Zielumfang:" wörtlich in den Text – das darf NIE im
    /// fertigen Buch landen. Arbeitet zeilenweise (Leaks erscheinen praktisch
    /// immer als eigene Zeile/Absatz) und ist konservativ: nur unverwechselbare
    /// Instruktions-Fragmente und Prompt-Labels werden entfernt, niemals normale
    /// Erzählsätze.
    static func strippingPromptArtifacts(_ text: String) -> String {
        let phraseMarkers = [
            "knüpfe nahtlos daran an",
            "ohne das geschehene zu wiederholen",
            "ohne das geschehene zu wiederholen oder zusammenzufassen",
            "wörtliches ende der vorherigen szene",
            "bisherige handlung",
            "letzte szenen im detail",
            "bisherige kapitel",
            "genre-handwerk",
            "verbotene floskeln",
            "sog-techniken",
            "keine überschriften",
            "meta-kommentar",
            "langform-pflicht",
            "schreibe ausschließlich auf",
            "schreibe die szene",
            "der erste satz ist der wichtigste",
            "erste szene des buches",
            "letzte szene des buches",
            "beginne mitten in der bewegung",
            "zeigen statt behaupten",
            "dialog mit subtext",
            "bestseller-standard",
            "knüpfe daran an"
        ]
        let labelPrefixes = [
            "stil:", "stilregeln:", "kapitelziel:", "sprache:", "tonalität:",
            "perspektive:", "erzählperspektive:", "zeitform:", "ort:", "zeit:",
            "ziel:", "hindernis:", "wendung am ende:", "wendung:", "figuren:",
            "szene:", "thema:", "zielumfang", "zielwörter", "zielwortzahl",
            "zielumfang:"
        ]
        let kept = text.components(separatedBy: .newlines).filter { line in
            let l = line.trimmingCharacters(in: .whitespaces).lowercased()
            if l.isEmpty { return true }
            if phraseMarkers.contains(where: { l.contains($0) }) { return false }
            if labelPrefixes.contains(where: { l.hasPrefix($0) }) { return false }
            return true
        }
        var result = kept.joined(separator: "\n")
        while result.contains("\n\n\n") {
            result = result.replacingOccurrences(of: "\n\n\n", with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
