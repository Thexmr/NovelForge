import Foundation
import PDFKit
import CoreText

/// Unveränderliche, thread-sichere Exportansicht eines SwiftData-Projekts.
/// Sie wird einmal auf dem MainActor erzeugt; ZIP-, DOCX- und PDF-Arbeit kann
/// danach ohne Zugriff auf ModelContext/Relationships im Hintergrund laufen.
struct BookExportSnapshot: Sendable {
    struct Chapter: Sendable {
        let chapterNumber: Int
        let displayTitle: String
        let text: String
        let wordCount: Int
    }

    let title: String
    let authorName: String
    let languageCode: String
    let trimSizeRaw: String
    let targetPageCount: Int
    let imprint: String
    let authorBio: String
    let kdpDescription: String
    let isNonfiction: Bool
    let bibliography: String
    /// Pfad zum fertigen Cover – wird ins EPUB eingebettet, damit das Titelbild IM Buch
    /// steht und nicht nur als eigene Datei danebenliegt.
    let coverURL: URL?
    let chapters: [Chapter]

    var totalWordCount: Int {
        chapters.reduce(0) { $0 + $1.wordCount }
    }

    var trimSize: TrimSize {
        TrimSize(rawValue: trimSizeRaw) ?? .sixByNine
    }

    @MainActor
    init(project: Project) {
        title = project.title
        authorName = project.authorName
        languageCode = project.languageCode
        trimSizeRaw = project.trimSizeRaw
        targetPageCount = project.targetPageCount
        imprint = project.imprint
        authorBio = project.authorBio
        kdpDescription = project.bookProfile?.kdpDescription ?? ""
        isNonfiction = project.isNonfiction
        let bundle = NonfictionResearchService.decodeManifest(
            project.bookProfile?.sourceManifest ?? ""
        )
        bibliography = bundle?.bibliography ?? ""
        coverURL = CoverArtService.coverURL(for: project)
        var contentChapters: [BookExportSnapshot.Chapter] = (project.chapters ?? [])
            .sorted { $0.chapterNumber < $1.chapterNumber }
            .compactMap { chapter in
                guard let text = chapter.bestText,
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return nil
                }
                return Chapter(
                    chapterNumber: chapter.chapterNumber,
                    displayTitle: chapter.displayTitle,
                    text: text,
                    wordCount: text.wordCount
                )
            }
        if project.isNonfiction, !bibliography.isEmpty {
            let title = project.languageCode == "en" ? "Sources" : "Quellenverzeichnis"
            contentChapters.append(Chapter(
                chapterNumber: (contentChapters.last?.chapterNumber ?? 0) + 1,
                displayTitle: title,
                text: bibliography,
                wordCount: bibliography.wordCount
            ))
        }
        chapters = contentChapters
    }
}

struct ExportEngine {

    /// UserDefaults-Schlüssel für einen benutzerdefinierten Ausgabeordner
    /// (z.B. für die Dauerproduktion). Leer = Standard.
    static let exportRootDefaultsKey = "novelforge.exportRoot"

    /// Startet rechen- und dateiintensive Exporte ohne MainActor-Bindung und
    /// reicht einen Stop an den Worker weiter. Die Exportloops prüfen das
    /// Abbruchsignal zusätzlich an Kapitel- bzw. Seitengrenzen.
    private static func runInBackground<T: Sendable>(
        _ operation: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try Task.checkCancellation()
        let worker = Task.detached(priority: .userInitiated) {
            try operation()
        }
        return try await withTaskCancellationHandler {
            try await worker.value
        } onCancel: {
            worker.cancel()
        }
    }

    /// Wurzel des Exportordners: benutzerdefiniert oder ~/Documents/NovelForge.
    static func exportRootDirectory() throws -> URL {
        let defaults = UserDefaults.standard
        if let custom = defaults.string(forKey: exportRootDefaultsKey) {
            let normalizedPath = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            if !normalizedPath.isEmpty {
                let fileManager = FileManager.default
                let originalURL = URL(fileURLWithPath: custom, isDirectory: true)
                let normalizedURL = URL(fileURLWithPath: normalizedPath, isDirectory: true)

                // Ein unsichtbares Leerzeichen am Ende erzeugt auf macOS einen
                // anderen Ordner. Bestehende Exporte sicher an den sichtbaren Pfad
                // verschieben, solange dort noch nichts kollidiert.
                if originalURL.path != normalizedURL.path,
                   fileManager.fileExists(atPath: originalURL.path),
                   !fileManager.fileExists(atPath: normalizedURL.path) {
                    do {
                        try fileManager.moveItem(at: originalURL, to: normalizedURL)
                    } catch {
                        // Parallele Exportworker können dieselbe Migration sehen.
                        // Hat ein anderer Worker sie bereits erledigt, ist alles gut.
                        guard fileManager.fileExists(atPath: normalizedURL.path) else {
                            throw AIError.systemError(
                                "Exportordner konnte nicht bereinigt werden: \(error.localizedDescription)"
                            )
                        }
                    }
                }

                if custom != normalizedPath {
                    defaults.set(normalizedPath, forKey: exportRootDefaultsKey)
                }
                try fileManager.createDirectory(at: normalizedURL, withIntermediateDirectories: true)
                return normalizedURL
            }
            defaults.removeObject(forKey: exportRootDefaultsKey)
        }
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw AIError.systemError("Dokumente-Ordner nicht gefunden")
        }
        let dir = documents.appendingPathComponent("NovelForge", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Exportverzeichnis eines Projekts: <Wurzel>/<Projekttitel>/
    static func exportDirectory(for project: Project) throws -> URL {
        try exportDirectory(forTitle: project.title)
    }

    private static func exportDirectory(forTitle title: String) throws -> URL {
        let dir = try exportRootDirectory()
            .appendingPathComponent(sanitizeFileName(title), isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - EPUB

    /// Exportiert das Buch als EPUB 3. Mit `sampleChapterCount` entsteht eine
    /// Leseprobe (erste N Kapitel + Abschlussseite) für Marketing und Testleser.
    /// Stoppt den Export, wenn (noch) kein Manuskripttext vorhanden ist – verhindert leere Bücher.
    private static func ensureExportable(_ project: Project) throws {
        try PublicationReadiness.validateForExport(project: project)
    }

    @MainActor
    static func prepareSnapshot(for project: Project) throws -> BookExportSnapshot {
        try ensureExportable(project)
        return BookExportSnapshot(project: project)
    }

    @MainActor
    static func exportToEPUB(project: Project, sampleChapterCount: Int? = nil) throws -> URL {
        try exportPreparedToEPUB(prepareSnapshot(for: project), sampleChapterCount: sampleChapterCount)
    }

    @MainActor
    static func exportToEPUBInBackground(project: Project,
                                         sampleChapterCount: Int? = nil) async throws -> URL {
        let snapshot = try prepareSnapshot(for: project)
        return try await exportPreparedToEPUBInBackground(
            snapshot,
            sampleChapterCount: sampleChapterCount
        )
    }

    static func exportPreparedToEPUBInBackground(_ book: BookExportSnapshot,
                                                 sampleChapterCount: Int? = nil) async throws -> URL {
        try await runInBackground {
            try exportPreparedToEPUB(book, sampleChapterCount: sampleChapterCount)
        }
    }

    private static func exportPreparedToEPUB(_ book: BookExportSnapshot,
                                             sampleChapterCount: Int? = nil) throws -> URL {
        try Task.checkCancellation()
        let isSample = sampleChapterCount != nil
        let suffix = isSample ? "_Leseprobe" : "_ebook"
        let epubURL = try exportDirectory(forTitle: book.title)
            .appendingPathComponent("\(sanitizeFileName(book.title))\(suffix).epub")

        let tempDir = FileManager.default.temporaryDirectory
        let workDir = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        // mimetype (muss als erster, unkomprimierter Eintrag ins ZIP)
        let mimetypeURL = workDir.appendingPathComponent("mimetype")
        try "application/epub+zip".write(to: mimetypeURL, atomically: true, encoding: .utf8)

        // META-INF
        let metaInfDir = workDir.appendingPathComponent("META-INF")
        try FileManager.default.createDirectory(at: metaInfDir, withIntermediateDirectories: true)
        let containerXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml" />
            </rootfiles>
        </container>
        """
        try containerXML.write(to: metaInfDir.appendingPathComponent("container.xml"), atomically: true, encoding: .utf8)

        // OEBPS
        let oebpsDir = workDir.appendingPathComponent("OEBPS")
        try FileManager.default.createDirectory(at: oebpsDir, withIntermediateDirectories: true)

        var manifest = ""
        var spine = ""
        var chapterFiles: [(id: String, file: String, title: String)] = []

        // Professionelles eBook-Stylesheet (Verlagskonventionen).
        try epubStylesheet.write(to: oebpsDir.appendingPathComponent("stylesheet.css"), atomically: true, encoding: .utf8)
        manifest += "    <item id=\"css\" href=\"stylesheet.css\" media-type=\"text/css\" />\n"

        // TITELBILD einbetten. Ohne das enthält das EPUB kein Cover – Lese-Apps und die
        // KDP-Vorschau zeigen dann nur die Textseite, obwohl das Cover als eigene Datei
        // längst existiert. properties="cover-image" ist die Auszeichnung, an der
        // Lese-Apps und Shops das Titelbild erkennen.
        if let coverURL = book.coverURL,
           let coverDaten = try? Data(contentsOf: coverURL), coverDaten.count > 1024 {
            let istJPEG = coverDaten.count > 2 && coverDaten[0] == 0xFF && coverDaten[1] == 0xD8
            let name = istJPEG ? "cover.jpg" : "cover.png"
            try coverDaten.write(to: oebpsDir.appendingPathComponent(name))
            manifest += "    <item id=\"coverimg\" href=\"\(name)\" media-type=\""
                + (istJPEG ? "image/jpeg" : "image/png") + "\" properties=\"cover-image\" />\n"

            let coverSeite = """
            <?xml version="1.0" encoding="UTF-8"?>
            <html xmlns="http://www.w3.org/1999/xhtml">
            <head><title>Cover</title>
            <style>html,body{margin:0;padding:0;height:100%;text-align:center}img{max-width:100%;max-height:100%}</style>
            </head>
            <body><img src="\(name)" alt="Cover" /></body>
            </html>
            """
            try coverSeite.write(to: oebpsDir.appendingPathComponent("cover.xhtml"), atomically: true, encoding: .utf8)
            manifest += "    <item id=\"coverpage\" href=\"cover.xhtml\" media-type=\"application/xhtml+xml\" />\n"
            spine += "    <itemref idref=\"coverpage\" />\n"
        }

        let titlePage = generateTitlePageHTML(book: book)
        try titlePage.write(to: oebpsDir.appendingPathComponent("titlepage.xhtml"), atomically: true, encoding: .utf8)
        manifest += "    <item id=\"titlepage\" href=\"titlepage.xhtml\" media-type=\"application/xhtml+xml\" />\n"
        spine += "    <itemref idref=\"titlepage\" />\n"

        let copyrightPage = generateCopyrightPageHTML(book: book)
        try copyrightPage.write(to: oebpsDir.appendingPathComponent("copyright.xhtml"), atomically: true, encoding: .utf8)
        manifest += "    <item id=\"copyright\" href=\"copyright.xhtml\" media-type=\"application/xhtml+xml\" />\n"
        // Impressum/Copyright kommt ans ENDE des Buches (Spine-Eintrag unten), nicht an den Anfang.

        let chapters = sampleChapterCount.map { Array(book.chapters.prefix($0)) } ?? book.chapters

        let tocPage = generateNavHTML(chapters: chapters)
        try tocPage.write(to: oebpsDir.appendingPathComponent("toc.xhtml"), atomically: true, encoding: .utf8)
        manifest += "    <item id=\"toc\" href=\"toc.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\" />\n"
        spine += "    <itemref idref=\"toc\" />\n"

        // WICHTIG: ID/Dateiname aus der Position (index) ableiten, NICHT aus chapterNumber.
        // chapterNumber ist nicht garantiert eindeutig (Plan-Reparaturen/„Buch erweitern")
        // – doppelte Nummern würden sonst die XHTML-Datei des ersten Kapitels überschreiben
        // und doppelte Manifest-/Spine-/NCX-IDs erzeugen (ungültiges, von KDP abgelehntes EPUB).
        for (index, chapter) in chapters.enumerated() {
            try Task.checkCancellation()
            let chapterId = "chapter\(index + 1)"
            let chapterFile = "chapter\(index + 1).xhtml"
            let chapterContent = generateChapterHTML(chapter: chapter)
            try chapterContent.write(to: oebpsDir.appendingPathComponent(chapterFile), atomically: true, encoding: .utf8)
            manifest += "    <item id=\"\(chapterId)\" href=\"\(chapterFile)\" media-type=\"application/xhtml+xml\" />\n"
            spine += "    <itemref idref=\"\(chapterId)\" />\n"
            chapterFiles.append((chapterId, chapterFile, chapter.displayTitle))
        }

        if isSample {
            let endPage = generateSampleEndHTML(book: book)
            try endPage.write(to: oebpsDir.appendingPathComponent("sample_end.xhtml"), atomically: true, encoding: .utf8)
            manifest += "    <item id=\"sampleend\" href=\"sample_end.xhtml\" media-type=\"application/xhtml+xml\" />\n"
            spine += "    <itemref idref=\"sampleend\" />\n"
        }

        // Impressum/Copyright als LETZTE Seite (eBook-Konvention; nicht am Anfang).
        spine += "    <itemref idref=\"copyright\" />\n"

        // NCX (EPUB-2-Kompatibilität) – muss im Manifest deklariert sein.
        manifest += "    <item id=\"ncx\" href=\"toc.ncx\" media-type=\"application/x-dtbncx+xml\" />\n"

        let contentOPF = generateContentOPF(book: book, manifest: manifest, spine: spine)
        try contentOPF.write(to: oebpsDir.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

        let tocNCX = generateTOCNCX(book: book, chapterFiles: chapterFiles)
        try tocNCX.write(to: oebpsDir.appendingPathComponent("toc.ncx"), atomically: true, encoding: .utf8)

        try Task.checkCancellation()
        try createEPUBArchive(sourceDirectory: workDir, destination: epubURL)
        return epubURL
    }

    // MARK: - PDF (KDP-konformer Buchsatz)

    private struct PrintLayout {
        let pageWidth: CGFloat
        let pageHeight: CGFloat
        let topMargin: CGFloat
        let bottomMargin: CGFloat
        let outsideMargin: CGFloat
        let insideMargin: CGFloat
    }

    private struct PrintState {
        var pageIndex = 0      // 0-basiert; Seite 0 ist eine rechte Seite (recto)
        var bodyPage = 0       // sichtbare Seitennummer im Buchblock
        var numbering = false
    }

    @MainActor
    static func exportToPDF(project: Project) throws -> URL {
        try exportPreparedToPDF(prepareSnapshot(for: project))
    }

    @MainActor
    static func exportToPDFInBackground(project: Project) async throws -> URL {
        try await exportPreparedToPDFInBackground(prepareSnapshot(for: project))
    }

    static func exportPreparedToPDFInBackground(_ book: BookExportSnapshot) async throws -> URL {
        try await runInBackground {
            try exportPreparedToPDF(book)
        }
    }

    private static func exportPreparedToPDF(_ book: BookExportSnapshot) throws -> URL {
        try Task.checkCancellation()
        let url = try exportDirectory(forTitle: book.title)
            .appendingPathComponent("\(sanitizeFileName(book.title))_print.pdf")

        let trim = book.trimSize
        let estimatedPages = max(24, book.totalWordCount / AppConstants.wordsPerPage)
        let layout = PrintLayout(
            pageWidth: trim.pageWidth,
            pageHeight: trim.pageHeight,
            topMargin: 54,                                                   // 0,75"
            bottomMargin: 54,                                                // 0,75" inkl. Seitenzahl
            outsideMargin: 36,                                               // 0,5" (KDP-Minimum: 0,25")
            insideMargin: max(36, TrimSize.gutterPoints(forPageCount: estimatedPages))
        )

        let pdfDocument = PDFDocument()
        var state = PrintState()

        try appendCenteredPage(makeTitleAttributed(book: book), to: pdfDocument, layout: layout, state: &state)
        try appendFlowedText(makeTOCAttributed(book: book), to: pdfDocument, layout: layout, state: &state, numbered: false)

        state.numbering = true
        for chapter in book.chapters {
            try Task.checkCancellation()
            let attributed = makeChapterAttributed(title: chapter.displayTitle, text: chapter.text)
            try appendFlowedText(attributed, to: pdfDocument, layout: layout, state: &state, numbered: true)
        }

        // Impressum/Copyright als letzte Seite (nicht am Anfang).
        try appendCenteredPage(makeCopyrightAttributed(book: book), to: pdfDocument, layout: layout, state: &state)

        let stagedURL = stagingURL(for: url)
        defer { try? FileManager.default.removeItem(at: stagedURL) }
        guard pdfDocument.write(to: stagedURL) else {
            throw AIError.systemError("PDF konnte nicht geschrieben werden")
        }
        try installStagedFile(stagedURL, at: url)
        return url
    }

    // MARK: - DOCX

    @MainActor
    static func exportToDOCX(project: Project) throws -> URL {
        try exportPreparedToDOCX(prepareSnapshot(for: project))
    }

    @MainActor
    static func exportToDOCXInBackground(project: Project) async throws -> URL {
        try await exportPreparedToDOCXInBackground(prepareSnapshot(for: project))
    }

    static func exportPreparedToDOCXInBackground(_ book: BookExportSnapshot) async throws -> URL {
        try await runInBackground {
            try exportPreparedToDOCX(book)
        }
    }

    private static func exportPreparedToDOCX(_ book: BookExportSnapshot) throws -> URL {
        try Task.checkCancellation()
        let docxURL = try exportDirectory(forTitle: book.title)
            .appendingPathComponent("\(sanitizeFileName(book.title)).docx")

        let tempDir = FileManager.default.temporaryDirectory
        let workDir = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workDir) }

        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" />
            <Default Extension="xml" ContentType="application/xml" />
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml" />
            <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml" />
        </Types>
        """
        try contentTypes.write(to: workDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)

        let relsDir = workDir.appendingPathComponent("_rels")
        try FileManager.default.createDirectory(at: relsDir, withIntermediateDirectories: true)
        let rels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml" />
        </Relationships>
        """
        try rels.write(to: relsDir.appendingPathComponent(".rels"), atomically: true, encoding: .utf8)

        let wordDir = workDir.appendingPathComponent("word")
        try FileManager.default.createDirectory(at: wordDir, withIntermediateDirectories: true)

        let wordRelsDir = wordDir.appendingPathComponent("_rels")
        try FileManager.default.createDirectory(at: wordRelsDir, withIntermediateDirectories: true)
        let documentRels = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml" />
        </Relationships>
        """
        try documentRels.write(to: wordRelsDir.appendingPathComponent("document.xml.rels"), atomically: true, encoding: .utf8)

        try docxStyles.write(to: wordDir.appendingPathComponent("styles.xml"), atomically: true, encoding: .utf8)

        let documentXML = try generateDOCXDocument(book: book)
        try documentXML.write(to: wordDir.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)

        try createZIPArchive(sourceDirectory: workDir, destination: docxURL)
        return docxURL
    }

    // MARK: - HTML-Erzeugung

    private static let epubStylesheet = """
    body { font-family: Georgia, "Times New Roman", serif; line-height: 1.5; margin: 0 4%; }
    h1 { text-align: center; font-weight: normal; font-size: 1.4em; margin: 3em 0 2em 0; page-break-before: always; }
    p { margin: 0; text-indent: 1.2em; text-align: justify; }
    p.first { text-indent: 0; }
    p.scenebreak { text-indent: 0; text-align: center; margin: 2.2em 0; }
    .titlepage, .copyrightpage { text-align: center; margin-top: 30%; }
    .titlepage h1 { page-break-before: avoid; margin: 0 0 1em 0; font-size: 1.8em; }
    nav ol { list-style: none; padding: 0; }
    nav li { margin: 0.4em 0; text-align: center; }
    """

    private static func xhtmlHeader(title: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head>
            <title>\(escapeXML(title))</title>
            <link rel="stylesheet" type="text/css" href="stylesheet.css" />
        </head>
        <body>
        """
    }

    private static func generateTitlePageHTML(book: BookExportSnapshot) -> String {
        xhtmlHeader(title: book.title) + """

            <div class="titlepage">
                <h1>\(escapeXML(book.title))</h1>
                <p class="first" style="text-align: center; font-size: 1.2em;">\(escapeXML(book.authorName))</p>
            </div>
        </body>
        </html>
        """
    }

    private static func generateCopyrightPageHTML(book: BookExportSnapshot) -> String {
        let lines = bookCopyrightPageText(
            authorName: book.authorName,
            imprint: book.imprint,
            authorBio: book.authorBio
        )
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { "            <p class=\"first\" style=\"text-align: center;\">\(escapeXML($0))</p>" }
            .joined(separator: "\n")
        return xhtmlHeader(title: "Copyright") + """

            <div class="copyrightpage">
        \(lines)
            </div>
        </body>
        </html>
        """
    }

    private static func generateSampleEndHTML(book: BookExportSnapshot) -> String {
        var teaser = ""
        if !book.kdpDescription.isEmpty {
            teaser = "\n        <p class=\"first\" style=\"text-align: center; margin-top: 2em;\">\(escapeXML(book.kdpDescription.truncated(to: 400)))</p>"
        }
        return xhtmlHeader(title: "Ende der Leseprobe") + """

            <div class="copyrightpage">
                <p class="first" style="text-align: center;">— Ende der Leseprobe —</p>
                <p class="first" style="text-align: center; margin-top: 1em;">„\(escapeXML(book.title))“ von \(escapeXML(book.authorName))</p>\(teaser)
            </div>
        </body>
        </html>
        """
    }

    /// EPUB-3-Navigationsdokument (nav epub:type="toc").
    private static func generateNavHTML(chapters: [BookExportSnapshot.Chapter]) -> String {
        var items = ""
        // Index-basierte Dateinamen – muss exakt zur Vergabe in exportToEPUB passen (siehe dort).
        for (index, chapter) in chapters.enumerated() {
            items += "            <li><a href=\"chapter\(index + 1).xhtml\">\(escapeXML(chapter.displayTitle))</a></li>\n"
        }
        return xhtmlHeader(title: "Inhaltsverzeichnis") + """

            <nav epub:type="toc" id="toc">
                <h1>Inhaltsverzeichnis</h1>
                <ol>
        \(items)        </ol>
            </nav>
        </body>
        </html>
        """
    }

    private static func generateChapterHTML(chapter: BookExportSnapshot.Chapter) -> String {
        var content = xhtmlHeader(title: chapter.displayTitle)
        content += "\n    <h1>\(escapeXML(chapter.displayTitle))</h1>"

        var afterBreak = true // erster Absatz ohne Einzug (Verlagskonvention)
        for paragraph in chapter.text.components(separatedBy: .newlines) {
            let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if isSceneBreakLine(trimmed) {
                // Szenenwechsel als ruhiger, leerer Abstand statt sichtbarer „* * *"
                // (die Sternchen wirken im eBook wie ein Fehler). Das geschützte
                // Leerzeichen hält den Absatz offen, sodass eine klare Lücke bleibt.
                content += "\n    <p class=\"scenebreak\">\u{00A0}</p>"
                afterBreak = true
                continue
            }

            let cssClass = afterBreak ? " class=\"first\"" : ""
            content += "\n    <p\(cssClass)>\(escapeXML(trimmed))</p>"
            afterBreak = false
        }

        content += "\n</body>\n</html>"
        return content
    }

    // MARK: - OPF / NCX

    private static func generateContentOPF(book: BookExportSnapshot, manifest: String, spine: String) -> String {
        let uuid = UUID().uuidString
        let date = ISO8601DateFormatter().string(from: Date())

        var descriptionXML = ""
        if !book.kdpDescription.isEmpty {
            descriptionXML = "\n        <dc:description>\(escapeXML(book.kdpDescription))</dc:description>"
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/">
                <dc:title>\(escapeXML(book.title))</dc:title>
                <dc:creator>\(escapeXML(book.authorName))</dc:creator>
                <dc:language>\(book.languageCode)</dc:language>
                <dc:identifier id="bookid">urn:uuid:\(uuid)</dc:identifier>
                <meta property="dcterms:modified">\(date)</meta>\(descriptionXML)
            </metadata>
            <manifest>
        \(manifest)    </manifest>
            <spine toc="ncx">
        \(spine)    </spine>
        </package>
        """
    }

    private static func generateTOCNCX(book: BookExportSnapshot, chapterFiles: [(id: String, file: String, title: String)]) -> String {
        let uuid = UUID().uuidString
        var navPoints = ""
        for (index, entry) in chapterFiles.enumerated() {
            navPoints += """
                    <navPoint id="\(entry.id)" playOrder="\(index + 1)">
                        <navLabel><text>\(escapeXML(entry.title))</text></navLabel>
                        <content src="\(entry.file)" />
                    </navPoint>

            """
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <ncx version="2005-1" xmlns="http://www.daisy.org/z3986/2005/ncx/">
            <head>
                <meta name="dtb:uid" content="urn:uuid:\(uuid)" />
                <meta name="dtb:depth" content="1" />
                <meta name="dtb:totalPageCount" content="0" />
                <meta name="dtb:maxPageNumber" content="0" />
            </head>
            <docTitle><text>\(escapeXML(book.title))</text></docTitle>
            <navMap>
        \(navPoints)    </navMap>
        </ncx>
        """
    }

    // MARK: - DOCX-Erzeugung (WordprocessingML, Standard-Präfix w:)

    private static let docxStyles = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        <w:docDefaults>
            <w:rPrDefault><w:rPr><w:rFonts w:ascii="Georgia" w:hAnsi="Georgia"/><w:sz w:val="22"/></w:rPr></w:rPrDefault>
            <w:pPrDefault><w:pPr><w:spacing w:line="312" w:lineRule="auto"/></w:pPr></w:pPrDefault>
        </w:docDefaults>
        <w:style w:type="paragraph" w:default="1" w:styleId="Normal">
            <w:name w:val="Normal"/>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Title">
            <w:name w:val="Title"/><w:basedOn w:val="Normal"/>
            <w:pPr><w:jc w:val="center"/><w:spacing w:before="2400" w:after="240"/></w:pPr>
            <w:rPr><w:b/><w:sz w:val="56"/></w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Subtitle">
            <w:name w:val="Subtitle"/><w:basedOn w:val="Normal"/>
            <w:pPr><w:jc w:val="center"/><w:spacing w:after="480"/></w:pPr>
            <w:rPr><w:sz w:val="28"/></w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="Heading1">
            <w:name w:val="heading 1"/><w:basedOn w:val="Normal"/>
            <w:pPr><w:pageBreakBefore/><w:jc w:val="center"/><w:spacing w:before="1440" w:after="480"/><w:outlineLvl w:val="0"/></w:pPr>
            <w:rPr><w:b/><w:sz w:val="32"/></w:rPr>
        </w:style>
        <w:style w:type="paragraph" w:styleId="SceneBreak">
            <w:name w:val="Scene Break"/><w:basedOn w:val="Normal"/>
            <w:pPr><w:jc w:val="center"/><w:spacing w:before="240" w:after="240"/></w:pPr>
        </w:style>
    </w:styles>
    """

    private static func generateDOCXDocument(book: BookExportSnapshot) throws -> String {
        var body = ""

        body += paragraph(text: book.title, style: "Title")
        body += paragraph(text: book.authorName, style: "Subtitle")
        body += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"

        for chapter in book.chapters {
            try Task.checkCancellation()
            body += paragraph(text: chapter.displayTitle, style: "Heading1")
            var afterBreak = true
            for para in chapter.text.components(separatedBy: .newlines) {
                let trimmed = para.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }
                if isSceneBreakLine(trimmed) {
                    // Szenenwechsel als ruhiger Abstand statt sichtbarer „* * *".
                    body += paragraph(text: "\u{00A0}", style: "SceneBreak")
                    afterBreak = true
                    continue
                }
                body += bodyParagraph(text: trimmed, indentFirstLine: !afterBreak)
                afterBreak = false
            }
        }

        // Impressum/Copyright als letzte Seite (nicht am Anfang).
        body += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"
        let copyright = bookCopyrightPageText(
            authorName: book.authorName,
            imprint: book.imprint,
            authorBio: book.authorBio
        )
        for line in copyright.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                body += paragraph(text: trimmed, style: nil)
            }
        }

        return """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
        \(body)
            </w:body>
        </w:document>
        """
    }

    private static func paragraph(text: String, style: String?) -> String {
        let styleXML = style.map { "<w:pPr><w:pStyle w:val=\"\($0)\"/></w:pPr>" } ?? ""
        return "<w:p>\(styleXML)<w:r><w:t xml:space=\"preserve\">\(escapeXML(text))</w:t></w:r></w:p>"
    }

    /// Fließtextabsatz: Blocksatz, optional mit Erstzeileneinzug (Romankonvention).
    private static func bodyParagraph(text: String, indentFirstLine: Bool) -> String {
        let indent = indentFirstLine ? "<w:ind w:firstLine=\"284\"/>" : ""
        return "<w:p><w:pPr>\(indent)<w:jc w:val=\"both\"/></w:pPr><w:r><w:t xml:space=\"preserve\">\(escapeXML(text))</w:t></w:r></w:p>"
    }

    // MARK: - PDF-Hilfen (CoreText-Buchsatz)

    private static func bookFont(size: CGFloat, bold: Bool = false) -> NSFont {
        let name = bold ? "Georgia-Bold" : "Georgia"
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size, weight: bold ? .bold : .regular)
    }

    private static func isSceneBreakLine(_ line: String) -> Bool {
        line.replacingOccurrences(of: " ", with: "") == "***"
    }

    private static func makeTitleAttributed(book: BookExportSnapshot) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacing = 18

        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: book.title + "\n", attributes: [
            .font: bookFont(size: 24, bold: true),
            .paragraphStyle: style,
            .foregroundColor: NSColor.black
        ]))
        result.append(NSAttributedString(string: book.authorName, attributes: [
            .font: bookFont(size: 13),
            .paragraphStyle: style,
            .foregroundColor: NSColor.black
        ]))
        return result
    }

    private static func makeCopyrightAttributed(book: BookExportSnapshot) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineHeightMultiple = 1.4

        let copyright = bookCopyrightPageText(
            authorName: book.authorName,
            imprint: book.imprint,
            authorBio: book.authorBio
        )
        return NSAttributedString(string: copyright, attributes: [
            .font: bookFont(size: 9),
            .paragraphStyle: style,
            .foregroundColor: NSColor.black
        ])
    }

    static func bookCopyrightPageText(project: Project) -> String {
        bookCopyrightPageText(
            authorName: project.authorName,
            imprint: project.imprint,
            authorBio: project.authorBio
        )
    }

    private static func bookCopyrightPageText(authorName: String,
                                              imprint: String,
                                              authorBio: String) -> String {
        let year = Calendar.current.component(.year, from: Date())
        var lines = [
            "© \(year) \(authorName)",
            "Alle Rechte vorbehalten."
        ]
        // KI-Kennzeichnung IM BUCH. Die Meldung bei KDP (aiDisclosure = „ai-generated")
        // ist das Eine; die wahrheitsgemäße Angabe gehört auch ins Frontmatter – Amazon
        // verlangt Transparenz über KI-erzeugte Inhalte, und ein Buch, das sie intern
        // verschweigt, während das Konto sie deklariert, ist der klassische Widerspruch,
        // der bei Prüfung auffliegt. Diese Zeile entsteht erst hier beim Export und
        // steht in keinem Projektfeld – der PublicContentGuard (Produktionshinweise in
        // Nutzertexten) wird davon nicht berührt.
        lines.append("")
        lines.append("Dieses Buch wurde mit KI-Unterstützung erstellt.")
        let cleanImprint = imprint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanImprint.isEmpty {
            lines.append("")
            lines.append(contentsOf: cleanImprint.components(separatedBy: .newlines))
        }
        let cleanAuthorBio = authorBio.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanAuthorBio.isEmpty {
            lines.append("")
            lines.append("Über den Autor")
            lines.append(cleanAuthorBio)
        }
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private static func makeTOCAttributed(book: BookExportSnapshot) -> NSAttributedString {
        let headingStyle = NSMutableParagraphStyle()
        headingStyle.alignment = .center
        headingStyle.paragraphSpacingBefore = 48
        headingStyle.paragraphSpacing = 24

        let entryStyle = NSMutableParagraphStyle()
        entryStyle.alignment = .left
        entryStyle.lineHeightMultiple = 1.45

        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: "Inhalt\n", attributes: [
            .font: bookFont(size: 17, bold: true),
            .paragraphStyle: headingStyle,
            .foregroundColor: NSColor.black
        ]))

        for chapter in book.chapters {
            result.append(NSAttributedString(string: "\(chapter.chapterNumber)  ·  \(chapter.displayTitle)\n", attributes: [
                .font: bookFont(size: 10.5),
                .paragraphStyle: entryStyle,
                .foregroundColor: NSColor.black
            ]))
        }
        return result
    }

    /// Buchsatz für ein Kapitel: zentrierte Überschrift, Blocksatz mit
    /// Erstzeileneinzug, zentrierte Szenentrenner.
    private static func makeChapterAttributed(title: String, text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let titleStyle = NSMutableParagraphStyle()
        titleStyle.alignment = .center
        titleStyle.paragraphSpacingBefore = 72
        titleStyle.paragraphSpacing = 36
        result.append(NSAttributedString(string: title + "\n", attributes: [
            .font: bookFont(size: 17, bold: true),
            .paragraphStyle: titleStyle,
            .foregroundColor: NSColor.black
        ]))

        let bodyStyle = NSMutableParagraphStyle()
        bodyStyle.alignment = .justified
        bodyStyle.lineHeightMultiple = 1.3
        bodyStyle.firstLineHeadIndent = 16
        bodyStyle.lineBreakMode = .byWordWrapping

        let firstParagraphStyle = NSMutableParagraphStyle()
        firstParagraphStyle.alignment = .justified
        firstParagraphStyle.lineHeightMultiple = 1.3
        firstParagraphStyle.firstLineHeadIndent = 0
        firstParagraphStyle.lineBreakMode = .byWordWrapping

        let breakStyle = NSMutableParagraphStyle()
        breakStyle.alignment = .center
        breakStyle.paragraphSpacingBefore = 12
        breakStyle.paragraphSpacing = 12

        var afterBreak = true // erster Absatz nach Überschrift ohne Einzug
        for rawParagraph in text.components(separatedBy: .newlines) {
            let paragraph = rawParagraph.trimmingCharacters(in: .whitespaces)
            if paragraph.isEmpty { continue }

            if isSceneBreakLine(paragraph) {
                // Szenenwechsel als ruhiger Abstand statt sichtbarer „* * *".
                result.append(NSAttributedString(string: "\u{00A0}\n", attributes: [
                    .font: bookFont(size: 11),
                    .paragraphStyle: breakStyle,
                    .foregroundColor: NSColor.black
                ]))
                afterBreak = true
                continue
            }

            result.append(NSAttributedString(string: paragraph + "\n", attributes: [
                .font: bookFont(size: 10.5),
                .paragraphStyle: afterBreak ? firstParagraphStyle : bodyStyle,
                .foregroundColor: NSColor.black
            ]))
            afterBreak = false
        }
        return result
    }

    /// Einseitige, vertikal zentrierte Seite (Titel, Copyright).
    private static func appendCenteredPage(_ attributed: NSAttributedString, to document: PDFDocument,
                                           layout: PrintLayout, state: inout PrintState) throws {
        try Task.checkCancellation()
        let inset: CGFloat = 44
        let rect = CGRect(x: inset, y: layout.pageHeight * 0.32,
                          width: layout.pageWidth - 2 * inset,
                          height: layout.pageHeight * 0.42)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)

        // Passt der Text nicht in den zentrierten Bereich (z.B. langer Impressum-/
        // Copyright-Text), fließend und paginiert setzen, statt ihn stillschweigend
        // abzuschneiden.
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter, CFRangeMake(0, 0), nil,
            CGSize(width: rect.width, height: .greatestFiniteMagnitude), nil)
        if suggested.height > rect.height {
            try appendFlowedText(attributed, to: document, layout: layout, state: &state, numbered: false)
            return
        }

        let pageData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pageData as CFMutableData) else {
            throw AIError.systemError("PDF-Seite konnte nicht vorbereitet werden")
        }
        var mediaBox = CGRect(x: 0, y: 0, width: layout.pageWidth, height: layout.pageHeight)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw AIError.systemError("PDF-Zeichenkontext konnte nicht erstellt werden")
        }

        context.beginPDFPage(nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0),
                                             CGPath(rect: rect, transform: nil), nil)
        CTFrameDraw(frame, context)
        context.endPDFPage()
        context.closePDF()

        state.pageIndex += 1
        guard let pageDoc = PDFDocument(data: pageData as Data), let page = pageDoc.page(at: 0) else {
            throw AIError.systemError("PDF-Seite konnte nicht übernommen werden")
        }
        document.insert(page, at: document.pageCount)
    }

    /// Fließtext über beliebig viele Seiten mit Spiegelrändern (Bundsteg)
    /// und optionaler Seitennummerierung.
    private static func appendFlowedText(_ attributed: NSAttributedString, to document: PDFDocument,
                                         layout: PrintLayout, state: inout PrintState,
                                         numbered: Bool) throws {
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        var location = 0
        let length = attributed.length

        while location < length {
            try Task.checkCancellation()
            // Seite 0 (erste PDF-Seite) ist eine rechte Buchseite: Bund links.
            let isRecto = state.pageIndex % 2 == 0
            let leftMargin = isRecto ? layout.insideMargin : layout.outsideMargin
            let rightMargin = isRecto ? layout.outsideMargin : layout.insideMargin
            let textRect = CGRect(x: leftMargin, y: layout.bottomMargin,
                                  width: layout.pageWidth - leftMargin - rightMargin,
                                  height: layout.pageHeight - layout.topMargin - layout.bottomMargin)
            let path = CGPath(rect: textRect, transform: nil)

            let pageData = NSMutableData()
            guard let consumer = CGDataConsumer(data: pageData as CFMutableData) else {
                throw AIError.systemError("PDF-Seite konnte nicht vorbereitet werden")
            }
            var mediaBox = CGRect(x: 0, y: 0, width: layout.pageWidth, height: layout.pageHeight)
            guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
                throw AIError.systemError("PDF-Zeichenkontext konnte nicht erstellt werden")
            }

            context.beginPDFPage(nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(location, 0), path, nil)
            CTFrameDraw(frame, context)

            if numbered && state.numbering {
                state.bodyPage += 1
                drawPageNumber(state.bodyPage, in: context, layout: layout)
            }

            context.endPDFPage()
            context.closePDF()

            let visibleRange = CTFrameGetVisibleStringRange(frame)
            guard visibleRange.length > 0 else {
                throw AIError.systemError("PDF-Buchsatz konnte einen Textabschnitt nicht umbrechen")
            }
            location += visibleRange.length
            state.pageIndex += 1

            guard let pageDoc = PDFDocument(data: pageData as Data), let page = pageDoc.page(at: 0) else {
                throw AIError.systemError("PDF-Seite konnte nicht übernommen werden")
            }
            document.insert(page, at: document.pageCount)
        }
    }

    private static func drawPageNumber(_ number: Int, in context: CGContext, layout: PrintLayout) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: bookFont(size: 9),
            .foregroundColor: NSColor.black
        ]
        let attributed = NSAttributedString(string: "\(number)", attributes: attributes)
        let line = CTLineCreateWithAttributedString(attributed as CFAttributedString)
        let lineWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        context.textPosition = CGPoint(x: (layout.pageWidth - lineWidth) / 2,
                                       y: layout.bottomMargin * 0.4)
        CTLineDraw(line, context)
    }

    // MARK: - ZIP

    private static func runZip(arguments: [String], workingDirectory: URL) throws {
        // Absichern gegen fehlendes/sandbox-blockiertes System-Binary: klare Fehlermeldung
        // statt eines undurchsichtigen Absturzes beim Prozessstart.
        let zipPath = "/usr/bin/zip"
        guard FileManager.default.isExecutableFile(atPath: zipPath) else {
            throw AIError.systemError("ZIP-Werkzeug nicht verfügbar (\(zipPath) fehlt oder ist nicht ausführbar). Export als EPUB/ZIP nicht möglich.")
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: zipPath)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        do {
            try process.run()
        } catch {
            throw AIError.systemError("ZIP-Prozess konnte nicht gestartet werden: \(error.localizedDescription)")
        }
        while process.isRunning {
            if Task.isCancelled {
                process.terminate()
                process.waitUntilExit()
                throw CancellationError()
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        if process.terminationStatus != 0 {
            throw AIError.systemError("ZIP-Erstellung fehlgeschlagen (Status \(process.terminationStatus))")
        }
    }

    /// EPUB-konformes ZIP: mimetype zuerst und unkomprimiert.
    private static func createEPUBArchive(sourceDirectory: URL, destination: URL) throws {
        let stagedURL = stagingURL(for: destination)
        defer { try? FileManager.default.removeItem(at: stagedURL) }
        try runZip(arguments: ["-X", "-0", "-q", stagedURL.path, "mimetype"],
                   workingDirectory: sourceDirectory)
        try runZip(arguments: ["-X", "-9", "-q", "-r", stagedURL.path, "META-INF", "OEBPS"],
                   workingDirectory: sourceDirectory)
        try installStagedFile(stagedURL, at: destination)
    }

    private static func createZIPArchive(sourceDirectory: URL, destination: URL) throws {
        let stagedURL = stagingURL(for: destination)
        defer { try? FileManager.default.removeItem(at: stagedURL) }
        try runZip(arguments: ["-X", "-9", "-q", "-r", stagedURL.path, "."],
                   workingDirectory: sourceDirectory)
        try installStagedFile(stagedURL, at: destination)
    }

    private static func stagingURL(for destination: URL) -> URL {
        destination.deletingLastPathComponent()
            .appendingPathComponent(".\(destination.lastPathComponent).\(UUID().uuidString).partial")
    }

    /// Erst nach vollständig erfolgreicher Erzeugung wird die bisherige Datei
    /// ersetzt. Bei Fehler oder Stop bleibt damit entweder der letzte gültige
    /// Export erhalten oder es existiert gar keine öffentliche Ausgabedatei.
    private static func installStagedFile(_ stagedURL: URL, at destination: URL) throws {
        try Task.checkCancellation()
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(
                destination,
                withItemAt: stagedURL,
                backupItemName: nil,
                options: [.usingNewMetadataOnly]
            )
        } else {
            try fileManager.moveItem(at: stagedURL, to: destination)
        }
    }

    // MARK: - Utility

    private static func escapeXML(_ text: String) -> String {
        // XML 1.0 verbietet Steuerzeichen außer Tab/LF/CR. Liefert ein LLM (z. B. via
        // JSON-Escape U+0000 oder U+000C) ein solches Zeichen, entstünde sonst eine
        // ungültige, nicht öffenbare EPUB/OPF/NCX. Daher XML-1.0-illegale Scalars entfernen.
        var result = String(String.UnicodeScalarView(text.unicodeScalars.filter { scalar in
            let v = scalar.value
            return v == 0x09 || v == 0x0A || v == 0x0D
                || (v >= 0x20 && v <= 0xD7FF)
                || (v >= 0xE000 && v <= 0xFFFD)
                || (v >= 0x10000 && v <= 0x10FFFF)
        }))
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&apos;")
        return result
    }

    static func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        let cleaned = name.components(separatedBy: invalidCharacters).joined(separator: "_")
        return cleaned.isEmpty ? "Unbenannt" : cleaned
    }

    // MARK: - Berichte

    static func generateKDPReport(project: Project) -> String {
        var report = "KDP FORMAT-BERICHT\n"
        report += String(repeating: "=", count: 20) + "\n\n"
        report += "Projekt: \(project.title)\n"
        report += "Autor: \(project.authorName)\n"
        report += "Sprache: \(project.language)\n"
        report += "Formate: \(project.outputFormats.joined(separator: ", "))\n"
        report += "Trim-Größe (Print): \(project.trimSize.displayName)\n\n"
        if !project.authorBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            report += "Autorprofil:\n\(project.authorBio)\n\n"
        }
        if !project.imprint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            report += "Impressum:\n\(project.imprint)\n\n"
        }
        if !project.memorySignature.isEmpty {
            report += "Story-Memory-Signatur: \(project.memorySignature.truncated(to: 220))\n\n"
        }

        let totalWords = project.totalWordCount
        let estimatedPages = totalWords / AppConstants.wordsPerPage

        report += "Gesamtwortzahl: \(FormattingHelpers.formatWordCount(totalWords))\n"
        report += "Geschätzte Seiten: \(estimatedPages)\n"
        report += "Zielseiten: \(project.targetPageCount)\n"
        report += "Abweichung: \(abs(estimatedPages - project.targetPageCount)) Seiten\n\n"

        report += "Kapitel: \(project.chapters?.count ?? 0)\n"
        report += "Status: \(project.status.displayName)\n\n"

        let scores = QualityScores.compute(for: project)
        report += "Qualitätsbewertung (intern):\n"
        report += String(format: "- Struktur: %.0f%%\n", scores.structure * 100)
        report += String(format: "- %@: %.0f%%\n",
                         project.isNonfiction ? "Lesernutzen" : "Figuren", scores.characters * 100)
        report += String(format: "- Stil: %.0f%%\n", scores.style * 100)
        report += String(format: "- Konsistenz: %.0f%%\n", scores.consistency * 100)
        report += String(format: "- KDP-Format: %.0f%%\n\n", scores.kdp * 100)

        report += "Copyright-Hinweis:\n"
        report += "Dies ist eine interne Prüfung ohne juristische Garantie.\n"
        return report
    }

    static func generateKDPMetadataReport(project: Project) -> String {
        KDPSalesSheet.make(for: project).exportText
    }

    static func generateProductionLog(project: Project) -> String {
        var log = "PRODUKTIONSPROTOKOLL\n"
        log += String(repeating: "=", count: 20) + "\n\n"
        log += "Projekt: \(project.title)\n"
        log += "Erstellt: \(project.createdAt.formattedString())\n"
        log += "Zuletzt aktualisiert: \(project.updatedAt.formattedString())\n\n"

        if let jobs = project.pipelineJobs?.sorted(by: { ($0.startTime ?? $0.createdAt) < ($1.startTime ?? $1.createdAt) }) {
            for job in jobs {
                log += "[\(job.phase.rawValue)] \(job.agentName)"
                if let chapter = job.chapterNumber { log += " – Kapitel \(chapter)" }
                if let scene = job.sceneNumber { log += ", Szene \(scene)" }
                log += "\n"
                if let start = job.startTime { log += "  Start: \(start.formattedString())\n" }
                if let end = job.endTime { log += "  Ende: \(end.formattedString())\n" }
                log += "  Status: \(job.status.rawValue)\n"
                if job.tokenUsage > 0 { log += "  Tokens: \(job.tokenUsage)\n" }
                if job.errorCount > 0 { log += "  Fehler: \(job.errorCount)\n" }
                log += "\n"
            }
        }
        return log
    }
}
