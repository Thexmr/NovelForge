import Foundation

struct ResearchSource: Codable, Equatable, Sendable, Identifiable {
    enum Kind: String, Codable, Sendable {
        case encyclopedia
        case scholarly
        case medical
        case official
    }

    let id: UUID
    let title: String
    let url: String
    let publisher: String
    let published: String
    let excerpt: String
    let kind: Kind

    init(title: String, url: String, publisher: String, published: String = "",
         excerpt: String, kind: Kind) {
        id = UUID()
        self.title = title
        self.url = url
        self.publisher = publisher
        self.published = published
        self.excerpt = excerpt
        self.kind = kind
    }
}

struct ResearchBundle: Codable, Equatable, Sendable {
    let query: String
    let researchedAt: Date
    let sources: [ResearchSource]

    var promptContext: String {
        guard !sources.isEmpty else { return "" }
        let entries = sources.enumerated().map { index, source in
            """
            [Q\(index + 1)] \(source.title)
            Herausgeber: \(source.publisher)\(source.published.isEmpty ? "" : " | Datum: \(source.published)")
            Typ: \(source.kind.rawValue)
            URL: \(source.url)
            Auszug: \(source.excerpt.truncated(to: 700))
            """
        }.joined(separator: "\n\n")
        return """
        RECHERCHIERTE QUELLENBASIS (nur diese Quellen verwenden; URL und [Q]-Nummer nie erfinden):
        \(entries)

        Quellen sind Ausgangsmaterial, kein automatischer Wahrheitsbeweis. Behauptungen nur so weit
        formulieren, wie der jeweilige Auszug sie trägt. Für weitergehende Aussagen [QUELLE PRÜFEN] setzen.
        """
    }

    var bibliography: String {
        sources.enumerated().map { index, source in
            let date = source.published.isEmpty ? "" : " (\(source.published))"
            return "[Q\(index + 1)] \(source.publisher)\(date): \(source.title). \(source.url)"
        }.joined(separator: "\n\n")
    }

    var hasScholarlySource: Bool {
        sources.contains { $0.kind == .scholarly || $0.kind == .medical || $0.kind == .official }
    }
}

actor NonfictionResearchService {
    static let shared = NonfictionResearchService()

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 45
        configuration.httpAdditionalHeaders = [
            "User-Agent": "NovelForge/2.1 research (contact: local-app)"
        ]
        session = URLSession(configuration: configuration)
    }

    func research(query rawQuery: String, genre: String, language: String) async throws -> ResearchBundle {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.wordCount >= 2 else { throw ResearchError.queryTooShort }

        let riskDomain = NonfictionSafety.riskDomain(genre: genre, premise: query)
        async let wikipedia = try? wikipediaSources(query: query, language: language)
        async let crossref = try? crossrefSources(query: query)
        async let pubmed: [ResearchSource]? = riskDomain == .health
            ? (try? await pubMedSources(query: Self.pubMedQuery(query)))
            : []
        async let official: [ResearchSource]? = (riskDomain == .finance || riskDomain == .legal)
            ? officialSources(query: query, domain: riskDomain)
            : []

        // In Teil-Ausdrücke zerlegt: die verkettete ??/+-Form überforderte den Type-Checker.
        let wikiSources = await wikipedia ?? []
        let crossrefSrc = await crossref ?? []
        let pubmedSrc = await pubmed ?? []
        let officialSrc = await official ?? []
        let combined = wikiSources + crossrefSrc + pubmedSrc + officialSrc
        var seen = Set<String>()
        let unique = combined.filter { source in
            let key = source.url.lowercased()
            guard !key.isEmpty, !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
        guard !unique.isEmpty else { throw ResearchError.noSources }
        return ResearchBundle(query: query, researchedAt: Date(), sources: Array(unique.prefix(12)))
    }

    static func decodeManifest(_ data: String) -> ResearchBundle? {
        guard let encoded = data.data(using: .utf8), !encoded.isEmpty else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(ResearchBundle.self, from: encoded)
    }

    static func encodeManifest(_ bundle: ResearchBundle) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(bundle)
        return String(decoding: data, as: UTF8.self)
    }

    private func wikipediaSources(query: String, language: String) async throws -> [ResearchSource] {
        let code: String
        switch language.lowercased() {
        case let value where value.contains("engl"): code = "en"
        case let value where value.contains("franz"): code = "fr"
        case let value where value.contains("span"): code = "es"
        default: code = "de"
        }
        var components = URLComponents(string: "https://\(code).wikipedia.org/w/api.php")!
        components.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: query),
            URLQueryItem(name: "gsrlimit", value: "4"),
            URLQueryItem(name: "prop", value: "extracts|info"),
            URLQueryItem(name: "exintro", value: "1"),
            URLQueryItem(name: "explaintext", value: "1"),
            URLQueryItem(name: "inprop", value: "url"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "formatversion", value: "2")
        ]
        let data = try await fetch(components.url!)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let queryObject = root?["query"] as? [String: Any]
        let pages = queryObject?["pages"] as? [[String: Any]] ?? []
        return pages.compactMap { page in
            guard let title = page["title"] as? String,
                  let url = page["fullurl"] as? String,
                  let extract = page["extract"] as? String,
                  extract.wordCount >= 20 else { return nil }
            return ResearchSource(title: title, url: url, publisher: "Wikipedia",
                                  excerpt: extract, kind: .encyclopedia)
        }
    }

    private func crossrefSources(query: String) async throws -> [ResearchSource] {
        var components = URLComponents(string: "https://api.crossref.org/works")!
        components.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "rows", value: "6"),
            URLQueryItem(name: "select", value: "DOI,title,URL,publisher,published,abstract,type")
        ]
        let data = try await fetch(components.url!)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let message = root?["message"] as? [String: Any]
        let items = message?["items"] as? [[String: Any]] ?? []
        return items.compactMap { item in
            guard let title = (item["title"] as? [String])?.first,
                  let url = item["URL"] as? String else { return nil }
            let publisher = item["publisher"] as? String ?? "Crossref"
            let abstract = Self.cleanMarkup(item["abstract"] as? String ?? "")
            let type = item["type"] as? String ?? "Fachpublikation"
            let excerpt = abstract.wordCount >= 12
                ? abstract
                : "Bibliografischer Nachweis einer \(type)-Publikation zum Recherchethema. Volltext vor Verwendung prüfen."
            return ResearchSource(title: title, url: url, publisher: publisher,
                                  excerpt: excerpt, kind: .scholarly)
        }
    }

    private func pubMedSources(query: String) async throws -> [ResearchSource] {
        var search = URLComponents(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi")!
        search.queryItems = [URLQueryItem(name: "db", value: "pubmed"),
                             URLQueryItem(name: "term", value: query),
                             URLQueryItem(name: "retmax", value: "5"),
                             URLQueryItem(name: "retmode", value: "json")]
        let searchData = try await fetch(search.url!)
        let root = try JSONSerialization.jsonObject(with: searchData) as? [String: Any]
        let result = root?["esearchresult"] as? [String: Any]
        let ids = result?["idlist"] as? [String] ?? []
        guard !ids.isEmpty else { return [] }

        var summary = URLComponents(string: "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi")!
        summary.queryItems = [URLQueryItem(name: "db", value: "pubmed"),
                              URLQueryItem(name: "id", value: ids.joined(separator: ",")),
                              URLQueryItem(name: "retmode", value: "json")]
        let data = try await fetch(summary.url!)
        let summaryRoot = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let summaryResult = summaryRoot?["result"] as? [String: Any]
        return ids.compactMap { id in
            guard let item = summaryResult?[id] as? [String: Any],
                  let title = item["title"] as? String else { return nil }
            let journal = item["fulljournalname"] as? String ?? "PubMed"
            let date = item["pubdate"] as? String ?? ""
            return ResearchSource(title: title,
                                  url: "https://pubmed.ncbi.nlm.nih.gov/\(id)/",
                                  publisher: journal, published: date,
                                  excerpt: "PubMed-Nachweis. Abstract oder Volltext vor jeder konkreten medizinischen Aussage prüfen.",
                                  kind: .medical)
        }
    }

    private func officialSources(query: String,
                                 domain: NonfictionSafety.RiskDomain) -> [ResearchSource] {
        let portals: [(String, String, String)]
        switch domain {
        case .finance:
            portals = [
                ("BaFin-Verbraucherschutz", "https://www.bafin.de/DE/Verbraucher/verbraucher_node.html", "Bundesanstalt für Finanzdienstleistungsaufsicht"),
                ("Deutsche Bundesbank – Themen", "https://www.bundesbank.de/de/aufgaben/themen", "Deutsche Bundesbank"),
                ("Bundesfinanzministerium – Themen", "https://www.bundesfinanzministerium.de/Web/DE/Themen/themen.html", "Bundesministerium der Finanzen")
            ]
        case .legal:
            portals = [
                ("Gesetze im Internet", "https://www.gesetze-im-internet.de/", "Bundesministerium der Justiz / Bundesamt für Justiz"),
                ("Bundesministerium der Justiz – Themen", "https://www.bmj.de/DE/themen/themen_node.html", "Bundesministerium der Justiz"),
                ("Bundesamt für Justiz", "https://www.bundesjustizamt.de/", "Bundesamt für Justiz")
            ]
        default:
            return []
        }
        return portals.map { title, url, publisher in
            ResearchSource(
                title: title, url: url, publisher: publisher,
                excerpt: "Offizielles Fachportal für die Prüfung zum Thema \"(query)\". Vor einer konkreten Rechts- oder Finanzbehauptung die einschlägige aktuelle Unterseite, Vorschrift oder Veröffentlichung öffnen und belegen.",
                kind: .official
            )
        }
    }

    private func fetch(_ url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ResearchError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }

    private static func cleanMarkup(_ input: String) -> String {
        input.replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&amp;", with: "&")
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func pubMedQuery(_ input: String) -> String {
        let normalized = input.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
        let translations: [(String, String)] = [
            ("bewegung", "exercise"), ("sport", "exercise"),
            ("stressbewaltigung", "stress management"), ("stress", "stress"),
            ("angst", "anxiety"), ("depression", "depression"),
            ("schlaf", "sleep"), ("ernahrung", "nutrition"),
            ("gewicht", "weight"), ("achtsamkeit", "mindfulness"),
            ("ruckenschmerz", "back pain"), ("blutdruck", "blood pressure")
        ]
        let matched = translations.compactMap { marker, english in
            normalized.contains(marker) ? english : nil
        }
        return matched.isEmpty ? input : Array(Set(matched)).sorted().joined(separator: " ")
    }
}

enum ResearchError: LocalizedError {
    case queryTooShort
    case noSources
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .queryTooShort: return "Das Recherchethema ist zu kurz."
        case .noSources: return "Keine verwertbaren Quellen gefunden."
        case .httpStatus(let code): return "Recherche-Dienst antwortete mit HTTP \(code)."
        }
    }
}
