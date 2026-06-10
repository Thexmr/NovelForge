import Foundation
import PDFKit
import CoreText

struct ExportEngine {

    /// Exportverzeichnis: ~/Documents/NovelForge/<Projekttitel>/
    static func exportDirectory(for project: Project) throws -> URL {
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw AIError.systemError("Dokumente-Ordner nicht gefunden")
        }
        let dir = documents
            .appendingPathComponent("NovelForge", isDirectory: true)
            .appendingPathComponent(sanitizeFileName(project.title), isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - EPUB

    static func exportToEPUB(project: Project) throws -> URL {
        let epubURL = try exportDirectory(for: project)
            .appendingPathComponent("\(sanitizeFileName(project.title))_ebook.epub")

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

        let titlePage = generateTitlePageHTML(project: project)
        try titlePage.write(to: oebpsDir.appendingPathComponent("titlepage.xhtml"), atomically: true, encoding: .utf8)
        manifest += "    <item id=\"titlepage\" href=\"titlepage.xhtml\" media-type=\"application/xhtml+xml\" />\n"
        spine += "    <itemref idref=\"titlepage\" />\n"

        let copyrightPage = generateCopyrightPageHTML(project: project)
        try copyrightPage.write(to: oebpsDir.appendingPathComponent("copyright.xhtml"), atomically: true, encoding: .utf8)
        manifest += "    <item id=\"copyright\" href=\"copyright.xhtml\" media-type=\"application/xhtml+xml\" />\n"
        spine += "    <itemref idref=\"copyright\" />\n"

        let tocPage = generateNavHTML(project: project)
        try tocPage.write(to: oebpsDir.appendingPathComponent("toc.xhtml"), atomically: true, encoding: .utf8)
        manifest += "    <item id=\"toc\" href=\"toc.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\" />\n"
        spine += "    <itemref idref=\"toc\" />\n"

        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                let chapterId = "chapter\(chapter.chapterNumber)"
                let chapterFile = "chapter\(chapter.chapterNumber).xhtml"
                let chapterContent = generateChapterHTML(chapter: chapter)
                try chapterContent.write(to: oebpsDir.appendingPathComponent(chapterFile), atomically: true, encoding: .utf8)
                manifest += "    <item id=\"\(chapterId)\" href=\"\(chapterFile)\" media-type=\"application/xhtml+xml\" />\n"
                spine += "    <itemref idref=\"\(chapterId)\" />\n"
                chapterFiles.append((chapterId, chapterFile, chapter.title))
            }
        }

        // NCX (EPUB-2-Kompatibilität) – muss im Manifest deklariert sein.
        manifest += "    <item id=\"ncx\" href=\"toc.ncx\" media-type=\"application/x-dtbncx+xml\" />\n"

        let contentOPF = generateContentOPF(project: project, manifest: manifest, spine: spine)
        try contentOPF.write(to: oebpsDir.appendingPathComponent("content.opf"), atomically: true, encoding: .utf8)

        let tocNCX = generateTOCNCX(project: project, chapterFiles: chapterFiles)
        try tocNCX.write(to: oebpsDir.appendingPathComponent("toc.ncx"), atomically: true, encoding: .utf8)

        try createEPUBArchive(sourceDirectory: workDir, destination: epubURL)
        return epubURL
    }

    // MARK: - PDF (mit echter Seitenumbruch-Logik)

    static func exportToPDF(project: Project) throws -> URL {
        let url = try exportDirectory(for: project)
            .appendingPathComponent("\(sanitizeFileName(project.title))_print.pdf")

        let pdfDocument = PDFDocument()

        appendPaginatedText("\(project.title)\n\n\(project.authorName)", to: pdfDocument, fontSize: 24, centeredVertically: true)

        let year = Calendar.current.component(.year, from: Date())
        appendPaginatedText("© \(year) \(project.authorName)\n\nAlle Rechte vorbehalten.", to: pdfDocument, fontSize: 11, centeredVertically: true)

        var toc = "Inhaltsverzeichnis\n\n"
        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                toc += "\(chapter.chapterNumber). \(chapter.title)\n"
            }
        }
        appendPaginatedText(toc, to: pdfDocument, fontSize: 12, centeredVertically: false)

        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                guard let text = chapter.bestText else { continue }
                appendPaginatedText("\(chapter.title)\n\n\(text)", to: pdfDocument, fontSize: 12, centeredVertically: false)
            }
        }

        guard pdfDocument.write(to: url) else {
            throw AIError.systemError("PDF konnte nicht geschrieben werden")
        }
        return url
    }

    // MARK: - DOCX

    static func exportToDOCX(project: Project) throws -> URL {
        let docxURL = try exportDirectory(for: project)
            .appendingPathComponent("\(sanitizeFileName(project.title)).docx")

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
        let documentXML = generateDOCXDocument(project: project)
        try documentXML.write(to: wordDir.appendingPathComponent("document.xml"), atomically: true, encoding: .utf8)

        try createZIPArchive(sourceDirectory: workDir, destination: docxURL)
        return docxURL
    }

    // MARK: - HTML-Erzeugung

    private static func xhtmlHeader(title: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head><title>\(escapeXML(title))</title></head>
        <body>
        """
    }

    private static func generateTitlePageHTML(project: Project) -> String {
        xhtmlHeader(title: project.title) + """

            <div style="text-align: center; margin-top: 30%;">
                <h1>\(escapeXML(project.title))</h1>
                <p style="font-size: 1.2em;">\(escapeXML(project.authorName))</p>
            </div>
        </body>
        </html>
        """
    }

    private static func generateCopyrightPageHTML(project: Project) -> String {
        let year = Calendar.current.component(.year, from: Date())
        return xhtmlHeader(title: "Copyright") + """

            <div style="text-align: center; margin-top: 30%;">
                <p>\(escapeXML("© \(year) \(project.authorName)"))</p>
                <p>Alle Rechte vorbehalten.</p>
            </div>
        </body>
        </html>
        """
    }

    /// EPUB-3-Navigationsdokument (nav epub:type="toc").
    private static func generateNavHTML(project: Project) -> String {
        var items = ""
        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                items += "            <li><a href=\"chapter\(chapter.chapterNumber).xhtml\">\(escapeXML(chapter.title))</a></li>\n"
            }
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

    private static func generateChapterHTML(chapter: Chapter) -> String {
        var content = xhtmlHeader(title: chapter.title)
        content += "\n    <h1>\(escapeXML(chapter.title))</h1>"

        if let text = chapter.bestText {
            for paragraph in text.components(separatedBy: .newlines) {
                let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty {
                    content += "\n    <p>\(escapeXML(trimmed))</p>"
                }
            }
        }

        content += "\n</body>\n</html>"
        return content
    }

    // MARK: - OPF / NCX

    private static func generateContentOPF(project: Project, manifest: String, spine: String) -> String {
        let uuid = UUID().uuidString
        let date = ISO8601DateFormatter().string(from: Date())

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>\(escapeXML(project.title))</dc:title>
                <dc:creator>\(escapeXML(project.authorName))</dc:creator>
                <dc:language>\(project.languageCode)</dc:language>
                <dc:identifier id="bookid">urn:uuid:\(uuid)</dc:identifier>
                <meta property="dcterms:modified">\(date)</meta>
            </metadata>
            <manifest>
        \(manifest)    </manifest>
            <spine toc="ncx">
        \(spine)    </spine>
        </package>
        """
    }

    private static func generateTOCNCX(project: Project, chapterFiles: [(id: String, file: String, title: String)]) -> String {
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
            <docTitle><text>\(escapeXML(project.title))</text></docTitle>
            <navMap>
        \(navPoints)    </navMap>
        </ncx>
        """
    }

    // MARK: - DOCX-Erzeugung (WordprocessingML, Standard-Präfix w:)

    private static func generateDOCXDocument(project: Project) -> String {
        var body = ""

        body += paragraph(text: project.title, style: "Title")
        body += paragraph(text: project.authorName, style: "Subtitle")

        let year = Calendar.current.component(.year, from: Date())
        body += paragraph(text: "© \(year) \(project.authorName)", style: nil)
        body += paragraph(text: "Alle Rechte vorbehalten.", style: nil)
        body += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"

        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                body += paragraph(text: chapter.title, style: "Heading1")
                if let text = chapter.bestText {
                    for para in text.components(separatedBy: .newlines) {
                        let trimmed = para.trimmingCharacters(in: .whitespaces)
                        if !trimmed.isEmpty {
                            body += paragraph(text: trimmed, style: nil)
                        }
                    }
                }
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

    // MARK: - PDF-Hilfen

    /// Rendert Text über beliebig viele Seiten (Letter, 1-Zoll-Rand).
    private static func appendPaginatedText(_ text: String, to document: PDFDocument,
                                            fontSize: CGFloat, centeredVertically: Bool) {
        let pageWidth: CGFloat = 612.0
        let pageHeight: CGFloat = 792.0
        let margin: CGFloat = 72.0

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = centeredVertically ? .center : .left
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineHeightMultiple = 1.25

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont(name: "Georgia", size: fontSize) ?? NSFont.systemFont(ofSize: fontSize),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.black
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)

        let textHeight = pageHeight - 2 * margin
        let yOffset: CGFloat = centeredVertically ? (pageHeight / 2 - 100) : margin
        let textRect = CGRect(x: margin, y: yOffset,
                              width: pageWidth - 2 * margin,
                              height: centeredVertically ? 200 : textHeight)
        let path = CGPath(rect: textRect, transform: nil)

        var location = 0
        let length = attributed.length

        while location < length {
            let pageData = NSMutableData()
            guard let consumer = CGDataConsumer(data: pageData as CFMutableData) else { return }
            var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
            guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

            context.beginPDFPage(nil)
            // PDF-Kontext hat den Ursprung unten links – genau das Koordinatensystem,
            // das CoreText erwartet. Kein Flip nötig.
            let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(location, 0), path, nil)
            CTFrameDraw(frame, context)
            context.endPDFPage()
            context.closePDF()

            let visibleRange = CTFrameGetVisibleStringRange(frame)
            if visibleRange.length <= 0 { break }
            location += visibleRange.length

            if let pageDoc = PDFDocument(data: pageData as Data), let page = pageDoc.page(at: 0) {
                document.insert(page, at: document.pageCount)
            }

            if centeredVertically { break } // Deckblatt & Co. sind einseitig
        }
    }

    // MARK: - ZIP

    private static func runZip(arguments: [String], workingDirectory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw AIError.systemError("ZIP-Erstellung fehlgeschlagen (Status \(process.terminationStatus))")
        }
    }

    /// EPUB-konformes ZIP: mimetype zuerst und unkomprimiert.
    private static func createEPUBArchive(sourceDirectory: URL, destination: URL) throws {
        try? FileManager.default.removeItem(at: destination)
        try runZip(arguments: ["-X", "-0", "-q", destination.path, "mimetype"],
                   workingDirectory: sourceDirectory)
        try runZip(arguments: ["-X", "-9", "-q", "-r", destination.path, "META-INF", "OEBPS"],
                   workingDirectory: sourceDirectory)
    }

    private static func createZIPArchive(sourceDirectory: URL, destination: URL) throws {
        try? FileManager.default.removeItem(at: destination)
        try runZip(arguments: ["-X", "-9", "-q", "-r", destination.path, "."],
                   workingDirectory: sourceDirectory)
    }

    // MARK: - Utility

    private static func escapeXML(_ text: String) -> String {
        var result = text
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
        report += "Formate: \(project.outputFormats.joined(separator: ", "))\n\n"

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
        report += String(format: "- Figuren: %.0f%%\n", scores.characters * 100)
        report += String(format: "- Stil: %.0f%%\n", scores.style * 100)
        report += String(format: "- Konsistenz: %.0f%%\n", scores.consistency * 100)
        report += String(format: "- KDP-Format: %.0f%%\n\n", scores.kdp * 100)

        report += "KI-Offenlegung:\n"
        report += "Dieses Buch wurde mit KI-Unterstützung erstellt (NovelForge, \(project.pipelineJobs?.count ?? 0) Pipeline-Schritte).\n\n"
        report += "Copyright-Hinweis:\n"
        report += "Dies ist eine interne Prüfung ohne juristische Garantie.\n"
        return report
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
