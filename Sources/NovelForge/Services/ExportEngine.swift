import Foundation
import PDFKit
import CoreText

struct ExportEngine {

    /// UserDefaults-Schlüssel für einen benutzerdefinierten Ausgabeordner
    /// (z.B. für die Dauerproduktion). Leer = Standard.
    static let exportRootDefaultsKey = "novelforge.exportRoot"

    /// Wurzel des Exportordners: benutzerdefiniert oder ~/Documents/NovelForge.
    static func exportRootDirectory() throws -> URL {
        if let custom = UserDefaults.standard.string(forKey: exportRootDefaultsKey),
           !custom.isEmpty {
            let url = URL(fileURLWithPath: custom, isDirectory: true)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url
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
        let dir = try exportRootDirectory()
            .appendingPathComponent(sanitizeFileName(project.title), isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - EPUB

    /// Exportiert das Buch als EPUB 3. Mit `sampleChapterCount` entsteht eine
    /// Leseprobe (erste N Kapitel + Abschlussseite) für Marketing und Testleser.
    static func exportToEPUB(project: Project, sampleChapterCount: Int? = nil) throws -> URL {
        let isSample = sampleChapterCount != nil
        let suffix = isSample ? "_Leseprobe" : "_ebook"
        let epubURL = try exportDirectory(for: project)
            .appendingPathComponent("\(sanitizeFileName(project.title))\(suffix).epub")

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

        let titlePage = generateTitlePageHTML(project: project)
        try titlePage.write(to: oebpsDir.appendingPathComponent("titlepage.xhtml"), atomically: true, encoding: .utf8)
        manifest += "    <item id=\"titlepage\" href=\"titlepage.xhtml\" media-type=\"application/xhtml+xml\" />\n"
        spine += "    <itemref idref=\"titlepage\" />\n"

        let copyrightPage = generateCopyrightPageHTML(project: project)
        try copyrightPage.write(to: oebpsDir.appendingPathComponent("copyright.xhtml"), atomically: true, encoding: .utf8)
        manifest += "    <item id=\"copyright\" href=\"copyright.xhtml\" media-type=\"application/xhtml+xml\" />\n"
        spine += "    <itemref idref=\"copyright\" />\n"

        let allChapters = (project.chapters ?? []).sorted { $0.chapterNumber < $1.chapterNumber }
        let chapters = sampleChapterCount.map { Array(allChapters.prefix($0)) } ?? allChapters

        let tocPage = generateNavHTML(chapters: chapters)
        try tocPage.write(to: oebpsDir.appendingPathComponent("toc.xhtml"), atomically: true, encoding: .utf8)
        manifest += "    <item id=\"toc\" href=\"toc.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\" />\n"
        spine += "    <itemref idref=\"toc\" />\n"

        for chapter in chapters {
            let chapterId = "chapter\(chapter.chapterNumber)"
            let chapterFile = "chapter\(chapter.chapterNumber).xhtml"
            let chapterContent = generateChapterHTML(chapter: chapter)
            try chapterContent.write(to: oebpsDir.appendingPathComponent(chapterFile), atomically: true, encoding: .utf8)
            manifest += "    <item id=\"\(chapterId)\" href=\"\(chapterFile)\" media-type=\"application/xhtml+xml\" />\n"
            spine += "    <itemref idref=\"\(chapterId)\" />\n"
            chapterFiles.append((chapterId, chapterFile, chapter.title))
        }

        if isSample {
            let endPage = generateSampleEndHTML(project: project)
            try endPage.write(to: oebpsDir.appendingPathComponent("sample_end.xhtml"), atomically: true, encoding: .utf8)
            manifest += "    <item id=\"sampleend\" href=\"sample_end.xhtml\" media-type=\"application/xhtml+xml\" />\n"
            spine += "    <itemref idref=\"sampleend\" />\n"
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

    static func exportToPDF(project: Project) throws -> URL {
        let url = try exportDirectory(for: project)
            .appendingPathComponent("\(sanitizeFileName(project.title))_print.pdf")

        let trim = project.trimSize
        let estimatedPages = max(24, project.totalWordCount / AppConstants.wordsPerPage)
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

        appendCenteredPage(makeTitleAttributed(project: project), to: pdfDocument, layout: layout, state: &state)
        appendCenteredPage(makeCopyrightAttributed(project: project), to: pdfDocument, layout: layout, state: &state)
        appendFlowedText(makeTOCAttributed(project: project), to: pdfDocument, layout: layout, state: &state, numbered: false)

        state.numbering = true
        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                guard let text = chapter.bestText else { continue }
                let attributed = makeChapterAttributed(title: chapter.title, text: text)
                appendFlowedText(attributed, to: pdfDocument, layout: layout, state: &state, numbered: true)
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

        let documentXML = generateDOCXDocument(project: project)
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
    p.scenebreak { text-indent: 0; text-align: center; margin: 1em 0; }
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

    private static func generateTitlePageHTML(project: Project) -> String {
        xhtmlHeader(title: project.title) + """

            <div class="titlepage">
                <h1>\(escapeXML(project.title))</h1>
                <p class="first" style="text-align: center; font-size: 1.2em;">\(escapeXML(project.authorName))</p>
            </div>
        </body>
        </html>
        """
    }

    private static func generateCopyrightPageHTML(project: Project) -> String {
        let lines = copyrightPageText(project: project)
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

    private static func generateSampleEndHTML(project: Project) -> String {
        var teaser = ""
        if let description = project.bookProfile?.kdpDescription, !description.isEmpty {
            teaser = "\n        <p class=\"first\" style=\"text-align: center; margin-top: 2em;\">\(escapeXML(description.truncated(to: 400)))</p>"
        }
        return xhtmlHeader(title: "Ende der Leseprobe") + """

            <div class="copyrightpage">
                <p class="first" style="text-align: center;">— Ende der Leseprobe —</p>
                <p class="first" style="text-align: center; margin-top: 1em;">„\(escapeXML(project.title))“ von \(escapeXML(project.authorName))</p>\(teaser)
            </div>
        </body>
        </html>
        """
    }

    /// EPUB-3-Navigationsdokument (nav epub:type="toc").
    private static func generateNavHTML(chapters: [Chapter]) -> String {
        var items = ""
        for chapter in chapters {
            items += "            <li><a href=\"chapter\(chapter.chapterNumber).xhtml\">\(escapeXML(chapter.title))</a></li>\n"
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

        var afterBreak = true // erster Absatz ohne Einzug (Verlagskonvention)
        if let text = chapter.bestText {
            for paragraph in text.components(separatedBy: .newlines) {
                let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty { continue }

                if isSceneBreakLine(trimmed) {
                    content += "\n    <p class=\"scenebreak\">* * *</p>"
                    afterBreak = true
                    continue
                }

                let cssClass = afterBreak ? " class=\"first\"" : ""
                content += "\n    <p\(cssClass)>\(escapeXML(trimmed))</p>"
                afterBreak = false
            }
        }

        content += "\n</body>\n</html>"
        return content
    }

    // MARK: - OPF / NCX

    private static func generateContentOPF(project: Project, manifest: String, spine: String) -> String {
        let uuid = UUID().uuidString
        let date = ISO8601DateFormatter().string(from: Date())

        var descriptionXML = ""
        if let description = project.bookProfile?.kdpDescription, !description.isEmpty {
            descriptionXML = "\n        <dc:description>\(escapeXML(description))</dc:description>"
        }

        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
            <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                <dc:title>\(escapeXML(project.title))</dc:title>
                <dc:creator>\(escapeXML(project.authorName))</dc:creator>
                <dc:language>\(project.languageCode)</dc:language>
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

    private static func generateDOCXDocument(project: Project) -> String {
        var body = ""

        body += paragraph(text: project.title, style: "Title")
        body += paragraph(text: project.authorName, style: "Subtitle")

        for line in copyrightPageText(project: project).components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                body += paragraph(text: trimmed, style: nil)
            }
        }
        body += "<w:p><w:r><w:br w:type=\"page\"/></w:r></w:p>"

        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                body += paragraph(text: chapter.title, style: "Heading1")
                var afterBreak = true
                if let text = chapter.bestText {
                    for para in text.components(separatedBy: .newlines) {
                        let trimmed = para.trimmingCharacters(in: .whitespaces)
                        if trimmed.isEmpty { continue }
                        if isSceneBreakLine(trimmed) {
                            body += paragraph(text: "* * *", style: "SceneBreak")
                            afterBreak = true
                            continue
                        }
                        body += bodyParagraph(text: trimmed, indentFirstLine: !afterBreak)
                        afterBreak = false
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

    private static func makeTitleAttributed(project: Project) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacing = 18

        let result = NSMutableAttributedString()
        result.append(NSAttributedString(string: project.title + "\n", attributes: [
            .font: bookFont(size: 24, bold: true),
            .paragraphStyle: style,
            .foregroundColor: NSColor.black
        ]))
        result.append(NSAttributedString(string: project.authorName, attributes: [
            .font: bookFont(size: 13),
            .paragraphStyle: style,
            .foregroundColor: NSColor.black
        ]))
        return result
    }

    private static func makeCopyrightAttributed(project: Project) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineHeightMultiple = 1.4

        return NSAttributedString(string: copyrightPageText(project: project), attributes: [
            .font: bookFont(size: 9),
            .paragraphStyle: style,
            .foregroundColor: NSColor.black
        ])
    }

    private static func copyrightPageText(project: Project) -> String {
        let year = Calendar.current.component(.year, from: Date())
        var lines = [
            "© \(year) \(project.authorName)",
            "Alle Rechte vorbehalten."
        ]
        let imprint = project.imprint.trimmingCharacters(in: .whitespacesAndNewlines)
        if !imprint.isEmpty {
            lines.append("")
            lines.append(contentsOf: imprint.components(separatedBy: .newlines))
        }
        lines.append("")
        lines.append("Dieses Werk wurde mit KI-Unterstützung erstellt.")
        return lines.joined(separator: "\n")
    }

    private static func makeTOCAttributed(project: Project) -> NSAttributedString {
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

        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                result.append(NSAttributedString(string: "\(chapter.chapterNumber)  ·  \(chapter.title)\n", attributes: [
                    .font: bookFont(size: 10.5),
                    .paragraphStyle: entryStyle,
                    .foregroundColor: NSColor.black
                ]))
            }
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
                result.append(NSAttributedString(string: "* * *\n", attributes: [
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
                                           layout: PrintLayout, state: inout PrintState) {
        let pageData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pageData as CFMutableData) else { return }
        var mediaBox = CGRect(x: 0, y: 0, width: layout.pageWidth, height: layout.pageHeight)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

        context.beginPDFPage(nil)
        let inset: CGFloat = 44
        let rect = CGRect(x: inset, y: layout.pageHeight * 0.32,
                          width: layout.pageWidth - 2 * inset,
                          height: layout.pageHeight * 0.42)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0),
                                             CGPath(rect: rect, transform: nil), nil)
        CTFrameDraw(frame, context)
        context.endPDFPage()
        context.closePDF()

        state.pageIndex += 1
        if let pageDoc = PDFDocument(data: pageData as Data), let page = pageDoc.page(at: 0) {
            document.insert(page, at: document.pageCount)
        }
    }

    /// Fließtext über beliebig viele Seiten mit Spiegelrändern (Bundsteg)
    /// und optionaler Seitennummerierung.
    private static func appendFlowedText(_ attributed: NSAttributedString, to document: PDFDocument,
                                         layout: PrintLayout, state: inout PrintState, numbered: Bool) {
        let framesetter = CTFramesetterCreateWithAttributedString(attributed as CFAttributedString)
        var location = 0
        let length = attributed.length

        while location < length {
            // Seite 0 (erste PDF-Seite) ist eine rechte Buchseite: Bund links.
            let isRecto = state.pageIndex % 2 == 0
            let leftMargin = isRecto ? layout.insideMargin : layout.outsideMargin
            let rightMargin = isRecto ? layout.outsideMargin : layout.insideMargin
            let textRect = CGRect(x: leftMargin, y: layout.bottomMargin,
                                  width: layout.pageWidth - leftMargin - rightMargin,
                                  height: layout.pageHeight - layout.topMargin - layout.bottomMargin)
            let path = CGPath(rect: textRect, transform: nil)

            let pageData = NSMutableData()
            guard let consumer = CGDataConsumer(data: pageData as CFMutableData) else { return }
            var mediaBox = CGRect(x: 0, y: 0, width: layout.pageWidth, height: layout.pageHeight)
            guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }

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
            if visibleRange.length <= 0 { break }
            location += visibleRange.length
            state.pageIndex += 1

            if let pageDoc = PDFDocument(data: pageData as Data), let page = pageDoc.page(at: 0) {
                document.insert(page, at: document.pageCount)
            }
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
        report += "Formate: \(project.outputFormats.joined(separator: ", "))\n"
        report += "Trim-Größe (Print): \(project.trimSize.displayName)\n\n"
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

    static func generateKDPMetadataReport(project: Project) -> String {
        var report = "KDP-METADATEN FÜR DIE VERÖFFENTLICHUNG\n"
        report += String(repeating: "=", count: 38) + "\n\n"
        report += "Titel: \(project.title)\n"
        report += "Autor: \(project.authorName)\n"
        report += "Sprache: \(project.language)\n"
        report += "Trim-Größe (Print): \(project.trimSize.displayName)\n\n"

        guard let profile = project.bookProfile else { return report }

        if !profile.kdpDescription.isEmpty {
            report += "PRODUKTBESCHREIBUNG (für die KDP-Detailseite):\n"
            report += profile.kdpDescription + "\n\n"
        }
        if !profile.kdpKeywords.isEmpty {
            report += "KEYWORDS (7 Suchbegriffe):\n"
            report += profile.kdpKeywords + "\n\n"
        }
        if !profile.kdpCategories.isEmpty {
            report += "KATEGORIE-VORSCHLÄGE:\n"
            report += profile.kdpCategories + "\n\n"
        }
        if profile.kdpDescription.isEmpty {
            report += "Hinweis: Die Metadaten werden in der Pipeline-Phase „KDP-Formatierung\u{201C} automatisch generiert.\n"
        }

        report += "Hinweis: Bei der Veröffentlichung muss die KI-Unterstützung gemäß KDP-Richtlinien angegeben werden.\n"
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
