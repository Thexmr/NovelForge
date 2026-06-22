import Foundation

/// Verkaufsfertige KDP-Metadaten, gebündelt für UI und Export.
struct KDPSalesSheet {
    let title: String
    let author: String
    let language: String
    let trimSize: String
    let series: String
    let hook: String
    let salesDescription: String
    let keywords: String
    let categories: String
    let authorProfile: String

    var hasGeneratedMetadata: Bool {
        !salesDescription.isEmpty || !keywords.isEmpty || !categories.isEmpty
    }

    /// Die KDP-Keyword-Slots (max. 7), einzeln – für die „Tags"-Ansicht beim Upload.
    var keywordSlots: [String] {
        keywords.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Die KDP-Kategorien als einzelne Pfade (max. 3).
    var categorySlots: [String] {
        categories.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Leeres Blatt – für gelöschte Projekte (kein Zugriff auf tote @Model-Relationen).
    static let empty = KDPSalesSheet(
        title: "", author: "", language: "", trimSize: "", series: "",
        hook: "", salesDescription: "", keywords: "", categories: "", authorProfile: ""
    )

    static func make(for project: Project) -> KDPSalesSheet {
        let profile = project.bookProfile
        // Bevorzugt den eigens generierten viralen KDP-Verkaufstitel; sonst der Buchtitel.
        let marketingTitle = clean(profile?.kdpTitle ?? "")
        let subtitle = clean(profile?.kdpSubtitle ?? "")
        let seriesLabel: String = {
            let name = clean(project.seriesName)
            guard !name.isEmpty else { return "" }
            return project.seriesNumber > 0 ? "\(name), Band \(project.seriesNumber)" : name
        }()
        return KDPSalesSheet(
            title: marketingTitle.isEmpty ? clean(project.title) : marketingTitle,
            author: clean(project.authorName),
            language: clean(project.language),
            trimSize: clean(project.trimSize.displayName),
            series: seriesLabel,
            hook: subtitle.isEmpty ? hook(from: profile) : subtitle,
            salesDescription: clean(profile?.kdpDescription ?? ""),
            keywords: clean(profile?.kdpKeywords ?? ""),
            categories: clean(profile?.kdpCategories ?? ""),
            authorProfile: clean(project.authorBio)
        )
    }

    var exportText: String {
        var report = "KDP-VERKAUFSBLATT\n"
        report += String(repeating: "=", count: 20) + "\n\n"
        report += "VERKAUFSTITEL:\n\(title)\n\n"
        report += "AUTOR:\n\(author)\n\n"
        report += "SPRACHE:\n\(language)\n\n"
        report += "TRIM-GRÖSSE (PRINT):\n\(trimSize)\n\n"
        if !series.isEmpty {
            report += "SERIE / REIHE:\n\(series)\n\n"
        }
        if !hook.isEmpty {
            report += "UNTERTITEL / HOOK:\n\(hook)\n\n"
        }
        if !salesDescription.isEmpty {
            report += "VERKAUFSTEXT:\n\(salesDescription)\n\n"
        }
        if !keywords.isEmpty {
            report += "KEYWORDS:\n\(keywords)\n\n"
        }
        if !categories.isEmpty {
            report += "KATEGORIEN:\n\(categories)\n\n"
        }
        if !authorProfile.isEmpty {
            report += "AUTORPROFIL:\n\(authorProfile)\n\n"
        }
        if !hasGeneratedMetadata {
            report += "Hinweis: Verkaufstext, Keywords und Kategorien werden in der Phase „KDP-Formatierung“ erstellt.\n"
        }
        return report
    }

    private static func hook(from profile: BookProfile?) -> String {
        guard let profile else { return "" }
        for value in [profile.logline, profile.readerBenefit, profile.premise, profile.synopsis] {
            let cleaned = clean(value ?? "")
            if !cleaned.isEmpty {
                return cleaned.truncated(to: 180)
            }
        }
        return ""
    }

    private static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
