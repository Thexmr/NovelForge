import Foundation

/// Verhindert, dass Produktions- oder Modellhinweise in kunden sichtbaren Dateien landen.
enum PublicContentGuard {
    static func validate(project: Project) throws {
        let issues = blockingIssues(project: project)
        guard issues.isEmpty else {
            throw AIError.systemError(
                "Export blockiert: Produktionshinweis in \(issues.joined(separator: ", ")). " +
                "Bitte den betroffenen Text prüfen und bereinigen."
            )
        }
    }

    static func blockingIssues(project: Project, includeChapters: Bool = true) -> [String] {
        var fields: [(label: String, text: String)] = [
            ("Buchtitel", project.title),
            ("Autorprofil", project.authorBio),
            ("Impressum", project.imprint)
        ]

        if let profile = project.bookProfile {
            fields.append(contentsOf: [
                ("KDP-Titel", profile.kdpTitle),
                ("KDP-Untertitel", profile.kdpSubtitle),
                ("KDP-Beschreibung", profile.kdpDescription),
                ("KDP-Keywords", profile.kdpKeywords),
                ("KDP-Kategorien", profile.kdpCategories),
                ("Cover-Prompts", profile.coverPrompts)
            ])
        }

        if includeChapters {
            fields.append(contentsOf: (project.chapters ?? []).compactMap { chapter in
                guard let text = chapter.bestText else { return nil }
                return ("Kapitel \(chapter.chapterNumber)", text)
            })
        }

        return fields.compactMap { disclosureViolation(in: $0.text) ? $0.label : nil }
    }

    static func disclosureViolation(in text: String) -> Bool {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return disclosurePatterns.contains { pattern in
            text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private static let disclosurePatterns = [
        #"(?s)\b(?:dieses|das)\s+(?:buch|werk|manuskript|kapitel|text|inhalt)\b.{0,120}\b(?:ki|künstlich(?:e|er|en|em|es)\s+intelligenz|ai)\b.{0,120}\b(?:erstellt|generiert|geschrieben|produziert|unterstützt)\b"#,
        #"(?s)\b(?:mit|mithilfe|unter\s+einsatz|mit\s+unterstützung)\s+(?:von\s+)?(?:ki|künstlich(?:e|er|en|em|es)\s+intelligenz|ai)\b.{0,80}\b(?:erstellt|generiert|geschrieben|produziert)\b"#,
        #"\b(?:ai[- ]generated|ki[- ]generiert(?:e|er|en|em|es)?|generated\s+(?:by|with)\s+ai)\b"#,
        #"\b(?:ki[- ]unterstützung|ki[- ]offenlegung)\b"#,
        #"\bals\s+(?:ki|sprachmodell|language\s+model)\b"#,
        #"\bich\s+bin\s+(?:ein|eine)\s+(?:ki|sprachmodell|language\s+model)\b"#,
        #"\bnovelforge\b"#
    ]
}
