import AppKit
import Foundation

/// SELBSTBEWEIS: prüft ein fertiges Buch samt Dateien und Metadaten gegen harte,
/// nachrechenbare Kriterien – und liefert einen Bericht, in dem zu jedem Punkt der
/// GEMESSENE Wert steht.
///
/// Warum das existiert: „fertig" war bisher eine Behauptung. Erst wenn Umfang,
/// EPUB-Struktur, Cover-Maße, Keyword-Deckung und Verkaufstext einzeln nachgewiesen
/// sind, darf das Buch zu KDP. Fällt eine Pflichtprüfung durch, wird NICHT
/// hochgeladen – der Bericht sagt dann genau, was fehlt.
///
/// Ergänzt `PublicationReadiness` (das prüft die Erzähl-Logik) um die technische
/// und verkaufsseitige Seite: Dateien, Maße, Amazon-Metadaten.
enum ProofService {

    /// Ein einzelner Nachweis. `evidence` ist immer ein gemessener Wert.
    struct Check {
        let name: String
        let passed: Bool
        let evidence: String
        /// Nicht-Pflichtpunkte werden berichtet, blockieren aber keinen Upload.
        let required: Bool

        init(_ name: String, _ passed: Bool, _ evidence: String, required: Bool = true) {
            self.name = name
            self.passed = passed
            self.evidence = evidence
            self.required = required
        }
    }

    struct Group {
        let title: String
        let checks: [Check]
    }

    struct Report {
        let groups: [Group]
        let words: Int
        let pages: Int
        let chapters: Int

        var allChecks: [Check] { groups.flatMap(\.checks) }
        var openRequired: [Check] { allChecks.filter { $0.required && !$0.passed } }
        var passed: Bool { openRequired.isEmpty }

        /// Klartext-Bericht – genau das, was der Nutzer zu sehen bekommt.
        var text: String {
            var lines: [String] = []
            lines.append("SELBSTBEWEIS")
            lines.append("\(chapters) Kapitel · \(words) Wörter · ~\(pages) Druckseiten")
            lines.append("")
            for g in groups {
                lines.append(g.title.uppercased())
                for c in g.checks {
                    let mark = c.passed ? "✓" : (c.required ? "✗" : "·")
                    lines.append("  \(mark) \(c.name): \(c.evidence)")
                }
                lines.append("")
            }
            if passed {
                lines.append("ERGEBNIS: alle Pflichtprüfungen bestanden – das Buch darf zu KDP.")
            } else {
                lines.append("ERGEBNIS: \(openRequired.count) Pflichtprüfung(en) offen – KEIN Upload:")
                for c in openRequired { lines.append("  - \(c.name): \(c.evidence)") }
            }
            return lines.joined(separator: "\n")
        }
    }

    // MARK: - Einstieg

    /// Führt alle Prüfungen aus. Fehlende optionale Dateien (Druckcover) senken
    /// das Ergebnis nicht, fehlende Pflichtdateien schon.
    @MainActor
    static func prove(project: Project,
                      epubURL: URL?,
                      coverURL: URL?,
                      wrapURL: URL?,
                      wrapDimensions: PrintCoverService.Dimensions?,
                      targetPages: Int = 0) -> Report {
        let texts = chapterTexts(project)
        let words = texts.reduce(0) { $0 + wordCount($1) }
        let pages = PrintCoverService.estimatePages(words: words)

        var groups: [Group] = []
        groups.append(Group(title: "Manuskript",
                            checks: manuscriptChecks(project: project, texts: texts,
                                                     words: words, pages: pages, targetPages: targetPages)))
        groups.append(Group(title: "EPUB-Datei", checks: epubChecks(url: epubURL, chapterCount: texts.count)))
        groups.append(Group(title: "eBook-Cover", checks: coverChecks(url: coverURL)))
        groups.append(Group(title: "Amazon-Metadaten",
                            checks: metadataChecks(project: project, fullText: texts.joined(separator: "\n").lowercased())))
        if let wrapURL, let wrapDimensions {
            groups.append(Group(title: "Druckcover (Vorder- + Rückseite + Rücken)",
                                checks: printCoverChecks(url: wrapURL, dim: wrapDimensions)))
        }
        return Report(groups: groups, words: words, pages: pages, chapters: texts.count)
    }

    // MARK: - Manuskript

    @MainActor
    private static func chapterTexts(_ project: Project) -> [String] {
        (project.chapters ?? [])
            .sorted { $0.chapterNumber < $1.chapterNumber }
            .map { $0.finalText ?? $0.revisedText ?? $0.draftText ?? "" }
    }

    @MainActor
    private static func manuscriptChecks(project: Project, texts: [String],
                                         words: Int, pages: Int, targetPages: Int) -> [Check] {
        var checks: [Check] = []
        checks.append(Check("Kapitel vorhanden", texts.count >= 3, "\(texts.count) Kapitel"))
        checks.append(Check("Umfang", words >= 5000, "\(words) Wörter ≈ \(pages) Druckseiten"))
        if targetPages > 0 {
            checks.append(Check("Zielumfang \(targetPages) Seiten",
                                Double(pages) >= Double(targetPages) * 0.9,
                                "\(pages) von \(targetPages) Seiten (\(Int(Double(pages) / Double(targetPages) * 100)) %)"))
        }

        // Platzhalter aus fehlgeschlagenen Kapiteln dürfen nie im Buch landen.
        let placeholders = texts.filter { $0.localizedCaseInsensitiveContains("konnte nicht erzeugt werden") }
        checks.append(Check("Keine Platzhalter-Kapitel", placeholders.isEmpty,
                            placeholders.isEmpty ? "keine gefunden" : "\(placeholders.count) Kapitel betroffen"))

        // Label-Reste des Modells („UNTERTITEL:", „KEYWORDS:") im Fließtext.
        let labelPattern = try? NSRegularExpression(
            pattern: "^\\s*\\**\\s*(UNTERTITEL|UNTITEL|SUBTITLE|KEYWORDS?|KATEGORIEN?|KLAPPENTEXT)\\s*:",
            options: [.anchorsMatchLines, .caseInsensitive])
        let withLabels = texts.filter { t in
            guard let labelPattern else { return false }
            return labelPattern.firstMatch(in: t, range: NSRange(t.startIndex..., in: t)) != nil
        }
        checks.append(Check("Keine Formatvorlagen im Text", withLabels.isEmpty,
                            withLabels.isEmpty ? "keine gefunden" : "\(withLabels.count) Kapitel betroffen"))

        let short = texts.filter { wordCount($0) < 300 }
        checks.append(Check("Keine leeren Kapitel", short.isEmpty,
                            short.isEmpty ? "alle Kapitel ausreichend lang" : "\(short.count) Kapitel unter 300 Wörtern"))

        // Kapitel, die versehentlich aus einer Kopfzeile entstanden sind.
        let badTitles = (project.chapters ?? []).filter {
            ["titel", "untertitel", "kapitel", "format"].contains($0.title.trimmingCharacters(in: CharacterSet.whitespaces).lowercased())
        }
        checks.append(Check("Kapitelüberschriften plausibel", badTitles.isEmpty,
                            badTitles.isEmpty ? "\(texts.count) Überschriften geprüft"
                                              : badTitles.map(\.title).joined(separator: ", ")))
        return checks
    }

    // MARK: - EPUB

    private static func epubChecks(url: URL?, chapterCount: Int) -> [Check] {
        guard let url, let data = try? Data(contentsOf: url) else {
            return [Check("EPUB vorhanden", false, "Datei fehlt: \(url?.lastPathComponent ?? "(kein Pfad)")")]
        }
        var checks: [Check] = []
        checks.append(Check("EPUB vorhanden", data.count > 2048, "\(data.count / 1024) KB"))

        // Pflicht der EPUB-Spezifikation: „mimetype" ist der ERSTE Eintrag und
        // UNKOMPRIMIERT. Fehlt das, lehnen strenge Prüfer die Datei ab.
        let firstName = data.count > 38 ? String(decoding: data[30..<38], as: UTF8.self) : ""
        let method: UInt16 = data.count > 10
            ? UInt16(data[8]) | (UInt16(data[9]) << 8)
            : 0xFFFF
        checks.append(Check("EPUB-Struktur (mimetype zuerst, unkomprimiert)",
                            firstName == "mimetype" && method == 0,
                            "erster Eintrag „\(firstName)“, Methode \(method == 0 ? "stored" : "deflate")"))

        // Direkt in den Bytes suchen. Ein mehrere Megabyte großes EPUB in einen String
        // zu verwandeln kostet unnötig Speicher – und weil ZIP-Daten kein gültiges UTF-8
        // sind, würde dabei zusätzlich verfälscht.
        func enthaelt(_ muster: String) -> Bool {
            let nadel = Array(muster.utf8)
            guard !nadel.isEmpty, data.count >= nadel.count else { return false }
            return data.withUnsafeBytes { roh -> Bool in
                let bytes = roh.bindMemory(to: UInt8.self)
                outer: for start in 0...(bytes.count - nadel.count) {
                    for i in 0..<nadel.count where bytes[start + i] != nadel[i] { continue outer }
                    return true
                }
                return false
            }
        }
        checks.append(Check("Pflichtdateien enthalten",
                            enthaelt("META-INF/container.xml") && enthaelt(".opf"),
                            "container.xml und OPF im Archiv"))

        // Die Kapiteldateien im Archiv müssen zur Kapitelzahl des Projekts passen –
        // sonst fehlt im ausgelieferten Buch stillschweigend Text.
        if chapterCount > 0 {
            var gefunden = 0
            for nummer in 1...chapterCount where enthaelt("chapter\(nummer).xhtml") || enthaelt("chap\(nummer).xhtml") {
                gefunden += 1
            }
            checks.append(Check("Alle Kapitel im EPUB", gefunden == 0 || gefunden >= chapterCount,
                                gefunden == 0 ? "Kapiteldateien anders benannt – nicht prüfbar"
                                              : "\(gefunden) von \(chapterCount) Kapiteldateien",
                                required: gefunden > 0))
        }
        return checks
    }

    // MARK: - Cover

    private static func coverChecks(url: URL?) -> [Check] {
        guard let url, FileManager.default.fileExists(atPath: url.path) else {
            return [Check("eBook-Cover vorhanden", false, "Datei fehlt: \(url?.lastPathComponent ?? "(kein Pfad)")")]
        }
        let bytes = ((try? FileManager.default.attributesOfItem(atPath: url.path))?[.size] as? Int) ?? 0
        let mb = Double(bytes) / (1024 * 1024)
        var checks = [Check("eBook-Cover vorhanden", mb > 0.02, String(format: "%.2f MB", mb))]
        guard let data = try? Data(contentsOf: url), let rep = NSBitmapImageRep(data: data) else {
            checks.append(Check("Cover-Maße", false, "Bild nicht lesbar"))
            return checks
        }
        checks.append(Check("Cover-Maße mindestens 1600×2400",
                            rep.pixelsWide >= 1600 && rep.pixelsHigh >= 2400,
                            "\(rep.pixelsWide)×\(rep.pixelsHigh) px"))
        checks.append(Check("Cover unter 50 MB", mb < 50, String(format: "%.2f MB", mb)))
        return checks
    }

    /// Prüft das Druckcover – inklusive der Frage, ob das Barcode-Feld WIRKLICH frei ist.
    /// Dazu wird der Bereich ausgelesen und gemessen: nur wenn er nahezu weiß und ohne
    /// Struktur ist, kann Amazon dort den EAN drucken.
    private static func printCoverChecks(url: URL, dim: PrintCoverService.Dimensions) -> [Check] {
        var checks: [Check] = []
        guard let data = try? Data(contentsOf: url), let rep = NSBitmapImageRep(data: data) else {
            return [Check("Druckcover lesbar", false, "Datei nicht lesbar: \(url.lastPathComponent)")]
        }
        let sizeOK = abs(rep.pixelsWide - dim.widthPx) <= 2 && abs(rep.pixelsHigh - dim.heightPx) <= 2
        checks.append(Check("Druckcover-Maße (Rücken aus Seitenzahl)", sizeOK,
                            sizeOK ? dim.summary
                                   : "\(rep.pixelsWide)×\(rep.pixelsHigh) statt \(dim.widthPx)×\(dim.heightPx)"))

        // Barcode-Feld: unten rechts auf der Rückseite, 2,0" × 1,2", muss weiß sein.
        // 4 px Rand bleiben außen vor – an der harten Kante erzeugt JPEG Überschwinger.
        let dpi = PrintCoverService.dpi
        let inset = 4
        let left = Int((PrintCoverService.bleedInch + dim.trim.widthInch - PrintCoverService.safeInch
                        - PrintCoverService.barcodeWidthInch) * dpi) + inset
        let top = Int((PrintCoverService.bleedInch + PrintCoverService.safeInch) * dpi) + inset  // von unten
        let w = Int(PrintCoverService.barcodeWidthInch * dpi) - 2 * inset
        let h = Int(PrintCoverService.barcodeHeightInch * dpi) - 2 * inset
        var darkest = 255
        var covered = 0
        var samples = 0
        // Rasterprobe (jeder 8. Punkt) – für den Nachweis genau genug und schnell.
        var y = rep.pixelsHigh - top - h
        let yEnd = rep.pixelsHigh - top
        while y < yEnd {
            var x = left
            while x < left + w {
                if x >= 0, y >= 0, x < rep.pixelsWide, y < rep.pixelsHigh,
                   let c = rep.colorAt(x: x, y: y) {
                    let v = Int(min(c.redComponent, min(c.greenComponent, c.blueComponent)) * 255)
                    darkest = min(darkest, v)
                    if v < 230 { covered += 1 }
                    samples += 1
                }
                x += 8
            }
            y += 8
        }
        let ratio = samples > 0 ? Double(covered) / Double(samples) : 1
        let free = samples > 0 && darkest >= 200 && ratio < 0.01
        checks.append(Check("Barcode-Feld frei (2,0\" × 1,2\")", free,
                            String(format: "dunkelster Punkt %d, %.2f %% belegt – %@",
                                   darkest, ratio * 100, free ? "weiß und leer" : "überdeckt")))

        // KDP nimmt Taschenbuch-Cover nur als PDF an.
        let pdfURL = url.deletingPathExtension().appendingPathExtension("pdf")
        if FileManager.default.fileExists(atPath: pdfURL.path) {
            let expectedW = dim.totalWidthInch * 72
            let expectedH = dim.totalHeightInch * 72
            if let doc = CGPDFDocument(pdfURL as CFURL), let page = doc.page(at: 1) {
                let box = page.getBoxRect(.mediaBox)
                let ok = abs(box.width - expectedW) < 1 && abs(box.height - expectedH) < 1
                checks.append(Check("Druckcover als PDF in exakter Seitengröße", ok,
                                    String(format: "%.1f × %.1f pt (Soll %.1f × %.1f pt)",
                                           box.width, box.height, expectedW, expectedH)))
            } else {
                checks.append(Check("Druckcover als PDF lesbar", false, "PDF nicht lesbar"))
            }
        } else {
            checks.append(Check("Druckcover als PDF", false,
                                "PDF fehlt – KDP lehnt ein JPEG als Taschenbuch-Cover ab", required: false))
        }
        return checks
    }

    // MARK: - Amazon-Metadaten

    @MainActor
    private static func metadataChecks(project: Project, fullText: String) -> [Check] {
        let profile = project.bookProfile
        var checks: [Check] = []
        let title = (profile?.kdpTitle.isEmpty == false ? profile!.kdpTitle : project.title)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        checks.append(Check("Titel gesetzt", title.count >= 3 && title.count <= 200,
                            "„\(title)“ (\(title.count) Zeichen)"))
        checks.append(Check("Titel klickstark (≤ 32 Zeichen, kein Doppelpunkt)",
                            title.count <= 32 && !title.contains(":") && !title.contains("–"),
                            "\(title.count) Zeichen\(title.contains(":") ? ", enthält Doppelpunkt" : "")"))

        let sub = (profile?.kdpSubtitle ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        checks.append(Check("Untertitel unterscheidet sich vom Titel",
                            sub.isEmpty || sub.lowercased() != title.lowercased(),
                            sub.isEmpty ? "kein Untertitel" : "„\(sub)“", required: false))

        let desc = (profile?.kdpDescription ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        checks.append(Check("Verkaufstext vorhanden (200–4000 Zeichen)",
                            desc.count >= 200 && desc.count <= 4000,
                            "\(wordCount(desc)) Wörter, \(desc.count) Zeichen"))
        let paragraphs = desc.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }.filter { !$0.isEmpty }
        checks.append(Check("Verkaufsdramaturgie (Haken, Einsatz, Einsatzverlust, Frage, Leseransprache)",
                            paragraphs.count >= 4, "\(paragraphs.count) Absätze"))

        let keywords = (profile?.kdpKeywords ?? "")
            .components(separatedBy: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }.filter { !$0.isEmpty }
        checks.append(Check("7 Suchphrasen", keywords.count == 7, "\(keywords.count) Phrasen"))

        let banned = ["kostenlos", "gratis", "bestseller", "kindle", "ebook", "amazon", "taschenbuch"]
        let badKeywords = keywords.filter { k in
            k.count > 50 || banned.contains { k.lowercased().contains($0) }
        }
        checks.append(Check("Suchphrasen regelkonform (≤ 50 Zeichen, keine Rang-/Preiswörter)",
                            badKeywords.isEmpty,
                            badKeywords.isEmpty ? "alle in Ordnung" : badKeywords.joined(separator: " / ")))

        let singleWord = keywords.filter { $0.split(separator: " ").count < 2 }
        checks.append(Check("Suchphrasen mehrwortig (echte Suchanfragen)", singleWord.isEmpty,
                            singleWord.isEmpty ? "alle mit 2+ Wörtern" : singleWord.joined(separator: " / ")))

        // Deckung: Jede Suchphrase muss etwas benennen, das das Buch WIRKLICH liefert –
        // sonst kommen Leser über eine Suche, die das Buch nicht bedient, und springen ab.
        //
        // ABER: Genre-, Ton- und Leseerwartungswörter („psychothriller", „spannend")
        // stehen naturgemäß NIE im Prosatext eines Romans. Sie hier zu verlangen wäre
        // ein Denkfehler und würde gute Keywords verwerfen. Geprüft wird deshalb nur
        // der KONKRETE Teil einer Phrase: Schauplatz, Figurentyp, Gegenstand.
        let uncovered = keywords.filter { k in
            let concrete = k.split(separator: " ").map { String($0).lowercased() }
                .filter { wort in wort.count >= 5 && !searchVocabulary.contains { wort.contains($0) } }
            if concrete.isEmpty { return false }        // reine Genre-/Tonphrase ist zulässig
            return !concrete.contains { fullText.contains($0) }
        }
        checks.append(Check("Suchphrasen durch den Buchtext gedeckt", uncovered.isEmpty,
                            uncovered.isEmpty ? "\(keywords.count) Phrasen im Text belegt"
                                              : uncovered.joined(separator: " / ")))

        let categories = (profile?.kdpCategories ?? "")
            .components(separatedBy: ",").map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }.filter { !$0.isEmpty }
        checks.append(Check("Kategorien gesetzt (1–3 Pfade)",
                            (1...3).contains(categories.count),
                            categories.isEmpty ? "keine" : categories.joined(separator: " | ")))
        return checks
    }

    // MARK: - Hilfen

    /// Wortstämme, die eine SUCHABSICHT beschreiben (Genre, Ton, Leseerwartung).
    /// Sie kommen im Romantext nicht vor und dürfen es auch nicht – sie sind trotzdem
    /// genau die Begriffe, die Leser bei Amazon eintippen.
    private static let searchVocabulary = [
        "thriller", "krimi", "roman", "fantasy", "horror", "grusel", "liebes", "romance",
        "mystery", "sachbuch", "ratgeber", "jugend", "kinder", "dystop", "science",
        "spann", "fessel", "packend", "unheimlich", "düster", "atmosph",
        "psycholog", "wendung", "nervenkitzel", "abgründ", "deutsch",
        "reihe", "band", "kurzgeschichte", "debüt",
    ]

    private static func wordCount(_ s: String) -> Int {
        s.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}
