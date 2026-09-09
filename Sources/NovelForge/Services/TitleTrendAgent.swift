import Foundation
import OSLog

/// Ergebnis der Titel-Trendrecherche für ein Genre.
struct TitleTrendReport: Codable, Sendable {
    /// Echte, aktuell im Genre erschienene Titel – Vorbild UND Kopiersperre zugleich.
    var beispiele: [String]
    /// Häufige inhaltstragende Wörter im Genre. Das sind die Begriffe, nach denen
    /// Leser bei Amazon tatsächlich suchen – die SEO-Grundlage des Titels.
    var seoBegriffe: [String]
    /// Gemessene Wortanzahl der aktuellen Titel (Median), gerundet.
    var typischeWortzahl: Int
    /// Wurde wirklich recherchiert, oder greift die hinterlegte Reserve?
    var istRecherchiert: Bool

    var isEmpty: Bool { beispiele.isEmpty && seoBegriffe.isEmpty }

    /// Briefing-Block für den Titel-Prompt.
    var briefing: String {
        guard !isEmpty else { return "" }
        var zeilen: [String] = []
        if !beispiele.isEmpty {
            let quelle = istRecherchiert
                ? "AKTUELL IM GENRE ERSCHIENEN (recherchiert, echte Titel)"
                : "TYPISCHE ERFOLGSMUSTER IM GENRE"
            zeilen.append("""
            \(quelle) – NUR als Muster für Klang, Länge und Bauart. \
            Diese Titel und ihre markanten Wörter sind TABU, sie dürfen weder kopiert \
            noch abgewandelt werden:
            \(beispiele.prefix(18).map { "• \($0)" }.joined(separator: "\n"))
            """)
        }
        if !seoBegriffe.isEmpty {
            zeilen.append("""
            SEO – danach suchen Leser in diesem Genre tatsächlich: \
            \(seoBegriffe.prefix(12).joined(separator: ", ")). \
            Mindestens EIN solcher Begriff (oder ein enges Synonym) gehört in den Titel, \
            damit das Buch in der Amazon-Suche überhaupt gefunden wird – aber nur, \
            wenn er natürlich klingt. Keyword-Stopfen ist verboten.
            """)
        }
        zeilen.append("GEMESSENE LÄNGE der aktuellen Genre-Titel: rund \(typischeWortzahl) Wörter. Bleib in dieser Größenordnung.")
        return zeilen.joined(separator: "\n\n")
    }
}

/// Recherchiert, welche Titel in einem Genre gerade erscheinen, und leitet daraus
/// SEO-Begriffe und Bauart-Muster ab.
///
/// Warum überhaupt recherchieren: Ohne echte Marktdaten erfindet das Modell Titel
/// nach eigenem Geschmack – so entstand „Unser Sommer in der blauen Küche". Mit einer
/// Liste dessen, was im Genre wirklich verkauft wird, trifft es Ton und Länge, und
/// die Kopiersperre verhindert zugleich, dass es einfach abschreibt.
///
/// Quelle ist die öffentliche Google-Books-API (kein Schlüssel nötig). Fällt sie aus,
/// greift eine im Code hinterlegte Reserve – die Produktion steht deswegen nie still.
actor TitleTrendAgent {
    static let shared = TitleTrendAgent()

    private let session: URLSession
    private let logger = Logger(subsystem: "com.novelforge.app", category: "titeltrend")
    /// Recherche je Genre nur einmal pro Sitzung – die Trends ändern sich nicht stündlich.
    private var cache: [String: TitleTrendReport] = [:]

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 25
        configuration.httpAdditionalHeaders = [
            "User-Agent": "NovelForge/2.1 titletrends (contact: local-app)"
        ]
        session = URLSession(configuration: configuration)
    }

    /// Recherchiert die Titellage im Genre.
    ///
    /// - Parameter modellRecherche: Liefert auf einen Prompt hin Modelltext. Das
    ///   Sprachmodell ist hier die belastbarste Quelle: Es kennt die Bestsellerlisten
    ///   des Genres, während es für aktuelle deutsche Genre-Titel keine frei
    ///   zugängliche API gibt (Google Books riegelt ohne Schlüssel mit HTTP 429 ab,
    ///   OpenLibrary liefert veraltete und sprachlich falsche Treffer). Fehlt die
    ///   Closure, bleibt es beim Web-Versuch und der hinterlegten Reserve.
    func report(genre rawGenre: String, language: String,
                modellRecherche: (@Sendable (String) async throws -> String)? = nil) async -> TitleTrendReport {
        let genre = rawGenre.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = "\(genre.lowercased())|\(language.lowercased())"
        if let zwischengespeichert = cache[key] { return zwischengespeichert }

        var bericht = Self.reserve(for: genre)

        // 1. Das Modell als Rechercheur – die verlässlichste verfügbare Quelle.
        if let modellRecherche,
           let text = try? await modellRecherche(Self.recherchePrompt(genre: genre, language: language)) {
            let titel = Self.parseTitel(text)
            if titel.count >= 6 {
                bericht = TitleTrendReport(
                    beispiele: Array(titel.prefix(20)),
                    seoBegriffe: Self.haeufigeBegriffe(in: titel) + Self.reserve(for: genre).seoBegriffe,
                    typischeWortzahl: Self.medianWortzahl(titel),
                    istRecherchiert: true
                )
            }
        }

        // 2. Web-Abruf als Ergänzung, solange er antwortet.
        if let recherchiert = try? await recherchiere(genre: genre, language: language),
           recherchiert.beispiele.count >= 6 {
            var zusammen = bericht
            zusammen.beispiele = Array((bericht.beispiele + recherchiert.beispiele).prefix(24))
            zusammen.seoBegriffe = Array(Set(bericht.seoBegriffe + recherchiert.seoBegriffe)).sorted()
            zusammen.istRecherchiert = true
            bericht = zusammen
        }

        if !bericht.istRecherchiert {
            logger.notice("Titel-Trendrecherche nicht verfügbar – hinterlegte Muster für \(genre, privacy: .public) verwendet.")
        }
        cache[key] = bericht
        return bericht
    }

    /// Rechercheauftrag ans Modell. Bewusst als reine Faktenabfrage formuliert:
    /// Es soll aufzählen, was es kennt, nicht erfinden.
    static func recherchePrompt(genre: String, language: String) -> String {
        """
        Rechercheauftrag – KEINE eigenen Erfindungen.

        Nenne 15 Buchtitel, die im Genre „\(genre)" auf \(language) in den letzten \
        Jahren nachweislich erfolgreich waren: Bestsellerlisten (SPIEGEL, Amazon), \
        Amazon-Kindle-Charts oder starke BookTok-Titel. Nur real existierende, \
        veröffentlichte Bücher.

        Nenne anschließend die Wörter, die Leser in diesem Genre tatsächlich in die \
        Amazon-Suche eintippen (Suchbegriffe, nicht Werbefloskeln).

        Format, exakt einzuhalten:
        TITEL|<Buchtitel>
        (15 Zeilen)
        SUCHBEGRIFFE|<begriff>, <begriff>, <begriff>, …

        Keine Erklärungen, keine Autorennamen, keine Nummerierung.
        """
    }

    static func parseTitel(_ text: String) -> [String] {
        var titel: [String] = []
        var gesehen = Set<String>()
        for zeile in text.split(separator: "\n") {
            let z = zeile.trimmingCharacters(in: .whitespaces)
            guard z.uppercased().hasPrefix("TITEL|") else { continue }
            let wert = String(z.dropFirst(6))
                .trimmingCharacters(in: CharacterSet(charactersIn: " \"'„“”»«*-–—.").union(.whitespaces))
            let wörter = wert.split(separator: " ").count
            guard !wert.isEmpty, (1...8).contains(wörter),
                  gesehen.insert(wert.lowercased()).inserted else { continue }
            titel.append(wert)
        }
        return titel
    }

    // MARK: - Recherche

    private func recherchiere(genre: String, language: String) async throws -> TitleTrendReport {
        let suchbegriffe = Self.suchbegriffe(for: genre)
        var titel: [String] = []
        for begriff in suchbegriffe {
            let treffer = (try? await hole(subject: begriff, language: language)) ?? []
            titel.append(contentsOf: treffer)
            if titel.count >= 40 { break }
        }

        var gesehen = Set<String>()
        let eindeutig = titel.filter { t in
            let k = t.lowercased()
            guard !gesehen.contains(k) else { return false }
            gesehen.insert(k)
            return true
        }
        guard eindeutig.count >= 6 else { throw TitleTrendError.zuWenigeTreffer }

        return TitleTrendReport(
            beispiele: Array(eindeutig.prefix(24)),
            seoBegriffe: Self.haeufigeBegriffe(in: eindeutig),
            typischeWortzahl: Self.medianWortzahl(eindeutig),
            istRecherchiert: true
        )
    }

    private func hole(subject: String, language: String) async throws -> [String] {
        var components = URLComponents(string: "https://www.googleapis.com/books/v1/volumes")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "subject:\(subject)"),
            URLQueryItem(name: "langRestrict", value: Self.sprachcode(language)),
            URLQueryItem(name: "orderBy", value: "newest"),
            URLQueryItem(name: "printType", value: "books"),
            URLQueryItem(name: "maxResults", value: "40")
        ]
        guard let url = components.url else { throw TitleTrendError.ungueltigeAnfrage }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TitleTrendError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let antwort = try JSONDecoder().decode(GoogleBooksAntwort.self, from: data)
        return antwort.items?.compactMap { eintrag -> String? in
            guard let titel = eintrag.volumeInfo?.title?
                .trimmingCharacters(in: .whitespacesAndNewlines), !titel.isEmpty else { return nil }
            // Reihenbände („Band 3"), Sammelausgaben und Fachbuch-Bandwürmer taugen
            // nicht als Muster für einen eigenständigen Romantitel.
            let wörter = titel.split(separator: " ").count
            guard (1...7).contains(wörter), !titel.contains(":"), !titel.contains("(") else { return nil }
            let lower = titel.lowercased()
            let ausschluss = ["band ", "teil ", "sammelband", "gesamtausgabe", "boxset",
                              "collection", "omnibus", "bände", "staffel"]
            guard !ausschluss.contains(where: { lower.contains($0) }) else { return nil }
            return titel
        } ?? []
    }

    // MARK: - Auswertung

    /// Inhaltstragende Wörter, die in mehreren aktuellen Titeln vorkommen.
    /// Genau diese Begriffe tippen Leser in die Amazon-Suche.
    private static func haeufigeBegriffe(in titel: [String]) -> [String] {
        var zaehler: [String: Int] = [:]
        for t in titel {
            let wörter = Set(t.lowercased()
                .components(separatedBy: CharacterSet.letters.inverted)
                .filter { $0.count >= 4 && !fuellwoerter.contains($0) })
            for wort in wörter { zaehler[wort, default: 0] += 1 }
        }
        return zaehler.filter { $0.value >= 2 }
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .prefix(14)
            .map(\.key)
    }

    private static func medianWortzahl(_ titel: [String]) -> Int {
        let zahlen = titel.map { $0.split(separator: " ").count }.sorted()
        guard !zahlen.isEmpty else { return 4 }
        return max(2, min(6, zahlen[zahlen.count / 2]))
    }

    private static let fuellwoerter: Set<String> = [
        "eine", "einer", "eines", "einem", "einen", "über", "unter", "durch", "gegen",
        "ohne", "beim", "vom", "zum", "zur", "roman", "band", "buch", "story",
        "sind", "wird", "werden", "haben", "hatte", "dass", "sich", "auch", "nach",
        "aber", "oder", "wenn", "dann", "noch", "sehr", "mehr", "alle", "alles"
    ]

    private static func sprachcode(_ language: String) -> String {
        let l = language.lowercased()
        if l.hasPrefix("de") || l.contains("deutsch") { return "de" }
        if l.hasPrefix("en") || l.contains("engl") { return "en" }
        if l.hasPrefix("fr") || l.contains("franz") { return "fr" }
        if l.hasPrefix("es") || l.contains("span") { return "es" }
        return "de"
    }

    /// Google-Books-Kategorien, die dem Genre am nächsten kommen.
    private static func suchbegriffe(for genre: String) -> [String] {
        let g = genre.lowercased()
        if g.contains("thriller") || g.contains("krimi") || g.contains("spannung") {
            return ["Thriller", "Krimi", "Fiction+Thrillers"]
        }
        if g.contains("liebe") || g.contains("roman") && g.contains("liebes") || g.contains("romance") {
            return ["Liebesroman", "Romance", "Fiction+Romance"]
        }
        if g.contains("erotik") { return ["Erotik", "Fiction+Erotica"] }
        if g.contains("fantasy") { return ["Fantasy", "Fiction+Fantasy"] }
        if g.contains("science") || g.contains("sci-fi") || g.contains("scifi") {
            return ["Science+Fiction", "Fiction+Science+Fiction"]
        }
        if g.contains("histor") { return ["Historischer+Roman", "Fiction+Historical"] }
        if g.contains("horror") { return ["Horror", "Fiction+Horror"] }
        if g.contains("jugend") || g.contains("young") { return ["Jugendbuch", "Young+Adult"] }
        if g.contains("ratgeber") || g.contains("sachbuch") { return ["Ratgeber", "Self-Help"] }
        return ["Roman", "Fiction", genre.replacingOccurrences(of: " ", with: "+")]
    }

    /// Reserve, falls die Recherche ausfällt: bewusst KEINE echten Buchtitel, sondern
    /// beschriebene Bauarten. So kann nichts versehentlich abgeschrieben werden, und
    /// der Prompt bekommt trotzdem eine klare Richtung.
    private static func reserve(for genre: String) -> TitleTrendReport {
        let g = genre.lowercased()
        let seo: [String]
        if g.contains("thriller") || g.contains("krimi") {
            seo = ["schweigen", "lüge", "spur", "opfer", "schuld", "nacht", "jagd", "vermisst"]
        } else if g.contains("liebe") || g.contains("romance") || g.contains("erotik") {
            seo = ["herz", "sehnsucht", "verboten", "berühren", "sommer", "nähe", "versprechen", "kuss"]
        } else if g.contains("fantasy") {
            seo = ["schatten", "krone", "blut", "fluch", "reich", "magie", "sturm", "thron"]
        } else if g.contains("histor") {
            seo = ["erbe", "haus", "tochter", "sturm", "jahre", "hoffnung", "krieg", "schwur"]
        } else {
            seo = ["geheimnis", "wahrheit", "abschied", "wiedersehen", "schweigen", "anfang"]
        }
        return TitleTrendReport(beispiele: [], seoBegriffe: seo,
                                typischeWortzahl: 4, istRecherchiert: false)
    }
}

enum TitleTrendError: LocalizedError {
    case ungueltigeAnfrage
    case httpStatus(Int)
    case zuWenigeTreffer

    var errorDescription: String? {
        switch self {
        case .ungueltigeAnfrage: return "Titel-Trendabfrage konnte nicht gebildet werden."
        case .httpStatus(let code): return "Titel-Trendrecherche antwortete mit Status \(code)."
        case .zuWenigeTreffer: return "Zu wenige aktuelle Titel für eine belastbare Auswertung."
        }
    }
}

private struct GoogleBooksAntwort: Decodable {
    struct Eintrag: Decodable {
        struct Info: Decodable { let title: String? }
        let volumeInfo: Info?
    }
    let items: [Eintrag]?
}
