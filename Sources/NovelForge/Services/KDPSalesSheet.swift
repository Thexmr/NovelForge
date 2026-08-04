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

    // MARK: - Verkaufstext-Qualitäts-Gate

    /// Prüft einen KDP-Verkaufstext auf GENERIK — die Art Text, die LLMs ohne
    /// Gegenwehr immer wieder ausgeben und die auf Amazon nicht verkauft:
    /// Floskeln statt Konflikt, Allgemeinplätze statt konkretem Haken.
    ///
    /// Bewusst konservativ: Jeder Befund nennt einen konkreten, behebbaren Mangel.
    /// Ein guter Blurb kann trotzdem schräg sein – das Gate misst nur das, was
    /// eindeutig maschinell fassbar ist. Leeres Array = bestanden.
    static func blurbIssues(_ text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ["Verkaufstext ist leer"] }
        var issues: [String] = []
        let lowered = trimmed.lowercased()

        // 1) FLOSKELN. Genau die Phrasen, die in jedem ungelenkten KI-Blurb stehen –
        //    sie sagen nichts über DIESES Buch und verraten die Maschine sofort.
        let floskeln = [
            "fesselnder roman", "fesselnde geschichte", "mitreißende geschichte",
            "mitreißender roman", "packend von der ersten seite", "packend von anfang",
            "ein muss für fans", "muss für alle fans", "lässt einen nicht mehr los",
            "nicht mehr aus der hand", "herz und humor", "voller überraschungen",
            "voller unerwarteter wendungen", "spannung pur", "tiefgründig und berührend",
            "pageturner", "page-turner", "unputdownable", "gripping tale",
            "a rollercoaster of emotions", "must-read", "keeps you on the edge"
        ]
        let getroffen = floskeln.filter { lowered.contains($0) }
        if !getroffen.isEmpty {
            issues.append("Marketing-Floskeln statt konkreter Inhalt: „\(getroffen.prefix(3).joined(separator: "“, „"))“")
        }

        // 2) GENERISCHER EINSTIEG. Der erste Satz entscheidet; beginnt er mit
        //    „Ein fesselnder Roman über …" / „Tauche ein in …", steht da Generik.
        let ersteZeile = trimmed.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
        let generischeEinstiege = [
            #"^(ein|eine)\s+(fesselnder|fesselnde|mitreißender|mitreißende|packender|packende|berührender|berührende|bewegender|bewegende|spannender|spannende)\s+(roman|geschichte|krimi|thriller|werk)\b"#,
            #"^(tauche? ein|tauchen sie ein|dive into)\b"#,
            #"^(erlebe|erleben sie|begleite|begleiten sie)\s+(eine|einen)?\s*(unvergessliche|mitreißende|fesselnde)\b"#
        ]
        for muster in generischeEinstiege {
            if ersteZeile.lowercased().range(of: muster, options: .regularExpression) != nil {
                issues.append("Generischer Einstieg („\(String(ersteZeile.prefix(60)))…“) – der erste Satz braucht den konkreten Haken des Buchs")
                break
            }
        }

        // 3) KEINE SPANNUNGSFRAGE. Bestseller-Blurbs enden auf eine Frage oder ein
        //    offenes Versprechen, das den Klick auslöst. Fehlt jede Frage, endet der
        //    Text meist mit einer Inhaltsangabe statt mit Zug.
        if !trimmed.contains("?") {
            issues.append("Keine Cliffhanger-/Spannungsfrage – der Text endet ohne Zug auf den Kauf")
        }

        // 4) KONFLIKTLos. Ein Blurb ohne Gegensatz (aber/doch/bis/plötzlich …) erzählt
        //    nur Setting. Ein einziger Kontrastmarker genügt als Beleg für Stakes.
        let konfliktMarker = [" aber ", " doch ", " bis ", " plötzlich", " jedoch",
                              " but ", " until ", " suddenly", " droht", " riskiert",
                              " muss sich entscheiden", " geheimnis", " lüge", " verrat"]
        if !konfliktMarker.contains(where: { lowered.contains($0) }) {
            issues.append("Kein erkennbarer Konflikt/Stake (kein „aber/doch/bis/droht/Geheimnis/Verrat“) – nur Setting, kein Sog")
        }

        return issues
    }

    /// Werbebegriffe, die Amazon in Titel/Produktbeschreibung untersagt
    /// (Preis-/Rang-/Werbeversprechen). Harte Regel, keine Geschmacksfrage.
    static let forbiddenPromoTerms = ["bestseller", "kostenlos", "gratis", "nr. 1", "nr.1",
                                      "#1", "best seller", "free book", "angebot", "reduziert"]

    /// Verstößt ein kundensichtbarer Text (Titel, Untertitel, Beschreibung) gegen
    /// Amazons Werbe-Verbot? Liefert die getroffenen Begriffe.
    static func promoViolations(in text: String) -> [String] {
        let lowered = " " + text.lowercased() + " "
        return forbiddenPromoTerms.filter { lowered.contains($0) }
    }

    private static func clean(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
