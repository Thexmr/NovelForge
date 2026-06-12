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
}
