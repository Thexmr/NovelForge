import Foundation

enum BookContentType: String, CaseIterable, Identifiable {
    case fiction = "Roman & Erzählung"
    case nonfiction = "Sachbuch & Ratgeber"

    var id: String { rawValue }

    static let nonfictionGenres = [
        "Sachbuch", "Ratgeber", "Praxisbuch", "How-to", "Arbeitsbuch",
        "Persönlichkeitsentwicklung", "Produktivität & Zeitmanagement",
        "Kommunikation & Beziehungen", "Karriere & Beruf", "Gründung & Selbstständigkeit",
        "Business & Management", "Finanzratgeber", "Gesundheitsratgeber",
        "Ernährung", "Fitness & Bewegung", "Achtsamkeit & Stressbewältigung",
        "Elternratgeber", "Erziehungsratgeber", "Lernratgeber", "Kreativratgeber",
        "Technikratgeber", "Computer & Internet", "Wissenschaft populär",
        "Geschichte", "Politik & Gesellschaft", "Natur & Umwelt", "Reise-Sachbuch",
        "Biografie", "Autobiografie", "Memoir", "Essay", "True Crime Sachbuch"
    ]

    static func infer(from genre: String) -> BookContentType {
        let normalized = genre.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let direct = Set(nonfictionGenres.map {
            $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        })
        if direct.contains(normalized) { return .nonfiction }
        let markers = ["ratgeber", "sachbuch", "how-to", "arbeitsbuch", "biografie",
                       "autobiografie", "memoir", "management", "personlichkeitsentwicklung"]
        return markers.contains(where: normalized.contains) ? .nonfiction : .fiction
    }
}

enum NonfictionSafety {
    enum RiskDomain {
        case general, health, finance, legal
    }
    static func isHighRisk(genre: String, premise: String = "") -> Bool {
        riskDomain(genre: genre, premise: premise) != .general
    }

    static func riskDomain(genre: String, premise: String = "") -> RiskDomain {
        let text = "\(genre) \(premise)"
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if ["gesund", "medizin", "heil", "therap", "depression", "angststor", "trauma"]
            .contains(where: text.contains) { return .health }
        if ["finanz", "geldanlage", "investment", "steuer"]
            .contains(where: text.contains) { return .finance }
        if ["recht", "juristisch", "vertrag"]
            .contains(where: text.contains) { return .legal }
        return .general
    }

    static func directive(genre: String, premise: String = "") -> String {
        let highRisk = isHighRisk(genre: genre, premise: premise)
        return """
        FAKTEN- UND QUELLENINTEGRITÄT (verbindlich):
        - Erfinde niemals Fakten, Studien, Statistiken, Quellen, Zitate, Institutionen, Fachleute oder Fallbeispiele.
        - Behaupte nichts als wissenschaftlich belegt, wenn keine prüfbare Quelle vorliegt. Formuliere Unsicherheit transparent oder lasse die Behauptung weg.
        - Beispiele ohne dokumentierte Quelle sind eindeutig als fiktive, illustrative Beispiele zu kennzeichnen.
        - Keine Erfolgsgarantien, Heilungsversprechen, Einkommensversprechen oder absoluten Wirkversprechen.
        - Trenne Fakten, Erfahrung, Meinung und praktische Empfehlung sprachlich sauber.
        \(highRisk ? "- HOCHRISIKOTHEMA: Nur allgemeine Bildung, keine individuelle medizinische, psychologische, rechtliche, steuerliche oder finanzielle Beratung. Nenne Grenzen, Risiken und wann qualifizierte Fachhilfe notwendig ist. Quellenpflicht für jede entscheidungsrelevante Behauptung." : "")
        """
    }

    static func requiresSourceReview(_ text: String) -> Bool {
        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return ["[quelle prufen]", "[beleg prufen]", "[faktencheck]", "[citation needed]"]
            .contains(where: normalized.contains)
    }

    static func citationNumbers(in text: String) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: #"\[Q(\d+)\]"#,
                                                   options: [.caseInsensitive]) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let swiftRange = Range(match.range(at: 1), in: text) else { return nil }
            return Int(text[swiftRange])
        }
    }

    static func invalidCitationNumbers(in text: String, sourceCount: Int) -> [Int] {
        Array(Set(citationNumbers(in: text).filter { $0 < 1 || $0 > sourceCount })).sorted()
    }
}

extension Project {
    var contentType: BookContentType { BookContentType.infer(from: genre) }
    var isNonfiction: Bool { contentType == .nonfiction }
}
