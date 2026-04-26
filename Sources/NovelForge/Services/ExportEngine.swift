import Foundation
import PDFKit

struct ExportEngine {
    static func exportToEPUB(project: Project) throws -> URL {
        let fileName = "\(sanitizeFileName(project.title))_ebook.epub"
        let tempDir = FileManager.default.temporaryDirectory
        let epubURL = tempDir.appendingPathComponent(fileName)
        
        let workDir = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        
        // mimetype
        let mimetypeURL = workDir.appendingPathComponent("mimetype")
        try "application/epub+zip".write(to: mimetypeURL, atomically: true, encoding: String.Encoding.utf8)
        
        // META-INF
        let metaInfDir = workDir.appendingPathComponent("META-INF")
        try FileManager.default.createDirectory(at: metaInfDir, withIntermediateDirectories: true)
        
        let containerXML = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\">\n" +
            "    <rootfiles>\n" +
            "        <rootfile full-path=\"OEBPS/content.opf\" media-type=\"application/oebps-package+xml\" />\n" +
            "    </rootfiles>\n" +
            "</container>"
        try containerXML.write(to: metaInfDir.appendingPathComponent("container.xml"), atomically: true, encoding: String.Encoding.utf8)
        
        // OEBPS
        let oebpsDir = workDir.appendingPathComponent("OEBPS")
        try FileManager.default.createDirectory(at: oebpsDir, withIntermediateDirectories: true)
        
        var manifest = ""
        var spine = ""
        var chapterFiles: [(id: String, file: String)] = []
        
        // Title page
        let titlePageContent = generateTitlePageHTML(project: project)
        try titlePageContent.write(to: oebpsDir.appendingPathComponent("titlepage.xhtml"), atomically: true, encoding: String.Encoding.utf8)
        manifest += "    <item id=\"titlepage\" href=\"titlepage.xhtml\" media-type=\"application/xhtml+xml\" />\n"
        spine += "    <itemref idref=\"titlepage\" />\n"
        
        // Copyright page
        let copyrightContent = generateCopyrightPageHTML(project: project)
        try copyrightContent.write(to: oebpsDir.appendingPathComponent("copyright.xhtml"), atomically: true, encoding: String.Encoding.utf8)
        manifest += "    <item id=\"copyright\" href=\"copyright.xhtml\" media-type=\"application/xhtml+xml\" />\n"
        spine += "    <itemref idref=\"copyright\" />\n"
        
        // TOC page
        let tocContent = generateTOCPageHTML(project: project)
        try tocContent.write(to: oebpsDir.appendingPathComponent("toc.xhtml"), atomically: true, encoding: String.Encoding.utf8)
        manifest += "    <item id=\"toc\" href=\"toc.xhtml\" media-type=\"application/xhtml+xml\" />\n"
        spine += "    <itemref idref=\"toc\" />\n"
        
        // Chapters
        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                let chapterId = "chapter\(chapter.chapterNumber)"
                let chapterFile = "chapter\(chapter.chapterNumber).xhtml"
                let chapterContent = generateChapterHTML(chapter: chapter)
                try chapterContent.write(to: oebpsDir.appendingPathComponent(chapterFile), atomically: true, encoding: String.Encoding.utf8)
                manifest += "    <item id=\"\(chapterId)\" href=\"\(chapterFile)\" media-type=\"application/xhtml+xml\" />\n"
                spine += "    <itemref idref=\"\(chapterId)\" />\n"
                chapterFiles.append((chapterId, chapterFile))
            }
        }
        
        // content.opf
        let contentOPF = generateContentOPF(project: project, manifest: manifest, spine: spine)
        try contentOPF.write(to: oebpsDir.appendingPathComponent("content.opf"), atomically: true, encoding: String.Encoding.utf8)
        
        // toc.ncx
        let tocNCX = generateTOCNCX(project: project, chapterFiles: chapterFiles)
        try tocNCX.write(to: oebpsDir.appendingPathComponent("toc.ncx"), atomically: true, encoding: String.Encoding.utf8)
        
        // Create ZIP
        try createZIPArchive(sourceDirectory: workDir, destination: epubURL)
        
        // Cleanup
        try? FileManager.default.removeItem(at: workDir)
        
        return epubURL
    }
    
    static func exportToPDF(project: Project) throws -> URL {
        let fileName = "\(sanitizeFileName(project.title))_print.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        let pdfDocument = PDFDocument()
        
        // Title page
        addTextPage(to: pdfDocument, text: "\(project.title)\n\n\(project.authorName)")
        
        // Copyright page
        let year = Calendar.current.component(.year, from: Date())
        addTextPage(to: pdfDocument, text: "© \(year) \(project.authorName)\n\nAlle Rechte vorbehalten.")
        
        // Table of contents
        var tocText = "Inhaltsverzeichnis\n\n"
        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                tocText += "\(chapter.title)\n"
            }
        }
        addTextPage(to: pdfDocument, text: tocText)
        
        // Chapters
        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                let text = chapter.finalText ?? chapter.revisedText ?? chapter.draftText ?? ""
                if !text.isEmpty {
                    addTextPage(to: pdfDocument, text: "\(chapter.title)\n\n\(text)")
                }
            }
        }
        
        pdfDocument.write(to: url)
        return url
    }
    
    static func exportToDOCX(project: Project) throws -> URL {
        let fileName = "\(sanitizeFileName(project.title)).docx"
        let tempDir = FileManager.default.temporaryDirectory
        let docxURL = tempDir.appendingPathComponent(fileName)
        
        let workDir = tempDir.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: workDir, withIntermediateDirectories: true)
        
        // [Content_Types].xml
        let contentTypes = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" +
            "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\">\n" +
            "    <Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\" />\n" +
            "    <Default Extension=\"xml\" ContentType=\"application/xml\" />\n" +
            "    <Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\" />\n" +
            "</Types>"
        try contentTypes.write(to: workDir.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: String.Encoding.utf8)
        
        // _rels/.rels
        let relsDir = workDir.appendingPathComponent("_rels")
        try FileManager.default.createDirectory(at: relsDir, withIntermediateDirectories: true)
        let rels = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" +
            "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\">\n" +
            "    <Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\" />\n" +
            "</Relationships>"
        try rels.write(to: relsDir.appendingPathComponent(".rels"), atomically: true, encoding: String.Encoding.utf8)
        
        // word/document.xml
        let wordDir = workDir.appendingPathComponent("word")
        try FileManager.default.createDirectory(at: wordDir, withIntermediateDirectories: true)
        
        let documentXML = generateDOCXDocument(project: project)
        try documentXML.write(to: wordDir.appendingPathComponent("document.xml"), atomically: true, encoding: String.Encoding.utf8)
        
        // Create ZIP
        try createZIPArchive(sourceDirectory: workDir, destination: docxURL)
        
        // Cleanup
        try? FileManager.default.removeItem(at: workDir)
        
        return docxURL
    }
    
    // MARK: - HTML Generation
    
    private static func generateTitlePageHTML(project: Project) -> String {
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<!DOCTYPE html>\n" +
            "<html xmlns=\"http://www.w3.org/1999/xhtml\">\n" +
            "<head><title>" + escapeXML(project.title) + "</title></head>\n" +
            "<body>\n" +
            "    <div style=\"text-align: center; margin-top: 200px;\">\n" +
            "        <h1>" + escapeXML(project.title) + "</h1>\n" +
            "        <p style=\"font-size: 1.2em;\">" + escapeXML(project.authorName) + "</p>\n" +
            "    </div>\n" +
            "</body>\n" +
            "</html>"
    }
    
    private static func generateCopyrightPageHTML(project: Project) -> String {
        let year = Calendar.current.component(.year, from: Date())
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<!DOCTYPE html>\n" +
            "<html xmlns=\"http://www.w3.org/1999/xhtml\">\n" +
            "<head><title>Copyright</title></head>\n" +
            "<body>\n" +
            "    <div style=\"text-align: center; margin-top: 100px;\">\n" +
            "        <p>" + escapeXML("© \(year) \(project.authorName)") + "</p>\n" +
            "        <p>Alle Rechte vorbehalten.</p>\n" +
            "    </div>\n" +
            "</body>\n" +
            "</html>"
    }
    
    private static func generateTOCPageHTML(project: Project) -> String {
        var toc = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<!DOCTYPE html>\n" +
            "<html xmlns=\"http://www.w3.org/1999/xhtml\">\n" +
            "<head><title>Inhaltsverzeichnis</title></head>\n" +
            "<body>\n" +
            "    <h1>Inhaltsverzeichnis</h1>\n" +
            "    <ul>"
        
        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                toc += "\n        <li><a href=\"chapter\(chapter.chapterNumber).xhtml\">" + escapeXML(chapter.title) + "</a></li>"
            }
        }
        
        toc += "\n    </ul>\n</body>\n</html>"
        return toc
    }
    
    private static func generateChapterHTML(chapter: Chapter) -> String {
        var content = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<!DOCTYPE html>\n" +
            "<html xmlns=\"http://www.w3.org/1999/xhtml\">\n" +
            "<head><title>" + escapeXML(chapter.title) + "</title></head>\n" +
            "<body>\n" +
            "    <h1>" + escapeXML(chapter.title) + "</h1>"
        
        if let scenes = chapter.scenes?.sorted(by: { $0.sceneNumber < $1.sceneNumber }) {
            for scene in scenes {
                if let text = scene.text {
                    let paragraphs = text.components(separatedBy: .newlines)
                    for paragraph in paragraphs {
                        if !paragraph.trimmingCharacters(in: .whitespaces).isEmpty {
                            content += "\n    <p>" + escapeXML(paragraph) + "</p>"
                        }
                    }
                }
            }
        }
        
        content += "\n</body>\n</html>"
        return content
    }
    
    // MARK: - OPF Generation
    
    private static func generateContentOPF(project: Project, manifest: String, spine: String) -> String {
        let uuid = UUID().uuidString
        let date = ISO8601DateFormatter().string(from: Date())
        
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<package version=\"3.0\" xmlns=\"http://www.idpf.org/2007/opf\" unique-identifier=\"bookid\">\n" +
            "    <metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\">\n" +
            "        <dc:title>" + escapeXML(project.title) + "</dc:title>\n" +
            "        <dc:creator>" + escapeXML(project.authorName) + "</dc:creator>\n" +
            "        <dc:language>" + escapeXML(project.language) + "</dc:language>\n" +
            "        <dc:identifier id=\"bookid\">urn:uuid:\(uuid)</dc:identifier>\n" +
            "        <dc:date>\(date)</dc:date>\n" +
            "    </metadata>\n" +
            "    <manifest>\n" +
            manifest +
            "    </manifest>\n" +
            "    <spine toc=\"ncx\">\n" +
            spine +
            "    </spine>\n" +
            "</package>"
    }
    
    private static func generateTOCNCX(project: Project, chapterFiles: [(id: String, file: String)]) -> String {
        let uuid = UUID().uuidString
        var navPoints = ""
        
        for (index, chapterFile) in chapterFiles.enumerated() {
            navPoints += "        <navPoint id=\"\(chapterFile.id)\" playOrder=\"\(index + 1)\">\n" +
                "            <navLabel><text>Kapitel \(index + 1)</text></navLabel>\n" +
                "            <content src=\"\(chapterFile.file)\" />\n" +
                "        </navPoint>\n"
        }
        
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<ncx version=\"2005-1\" xmlns=\"http://www.daisy.org/z3986/2005/ncx/\">\n" +
            "    <head>\n" +
            "        <meta name=\"dtb:uid\" content=\"urn:uuid:\(uuid)\" />\n" +
            "        <meta name=\"dtb:depth\" content=\"1\" />\n" +
            "        <meta name=\"dtb:totalPageCount\" content=\"0\" />\n" +
            "        <meta name=\"dtb:maxPageNumber\" content=\"0\" />\n" +
            "    </head>\n" +
            "    <docTitle><text>" + escapeXML(project.title) + "</text></docTitle>\n" +
            "    <navMap>\n" +
            navPoints +
            "    </navMap>\n" +
            "</ncx>"
    }
    
    // MARK: - DOCX Generation
    
    private static func generateDOCXDocument(project: Project) -> String {
        var body = ""
        
        // Title
        body += "<wp:p><wp:pPr><wp:pStyle wp:val=\"Title\" /></wp:pPr><wp:r><wp:t>" + escapeXML(project.title) + "</wp:t></wp:r></wp:p>"
        
        // Author
        body += "<wp:p><wp:pPr><wp:pStyle wp:val=\"Subtitle\" /></wp:pPr><wp:r><wp:t>" + escapeXML(project.authorName) + "</wp:t></wp:r></wp:p>"
        
        // Copyright
        let year = Calendar.current.component(.year, from: Date())
        body += "<wp:p><wp:r><wp:t>© \(year) " + escapeXML(project.authorName) + "</wp:t></wp:r></wp:p>"
        body += "<wp:p><wp:r><wp:t>Alle Rechte vorbehalten.</wp:t></wp:r></wp:p>"
        
        // Page break
        body += "<wp:p><wp:r><wp:br wp:type=\"page\" /></wp:r></wp:p>"
        
        // Chapters
        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                body += "<wp:p><wp:pPr><wp:pStyle wp:val=\"Heading1\" /></wp:pPr><wp:r><wp:t>" + escapeXML(chapter.title) + "</wp:t></wp:r></wp:p>"
                
                if let text = chapter.finalText ?? chapter.revisedText ?? chapter.draftText {
                    let paragraphs = text.components(separatedBy: .newlines)
                    for paragraph in paragraphs {
                        if !paragraph.trimmingCharacters(in: .whitespaces).isEmpty {
                            body += "<wp:p><wp:r><wp:t>" + escapeXML(paragraph) + "</wp:t></wp:r></wp:p>"
                        }
                    }
                }
            }
        }
        
        return "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n" +
            "<wp:document xmlns:wp=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">\n" +
            "    <wp:body>\n" +
            body +
            "    </wp:body>\n" +
            "</wp:document>"
    }
    
    // MARK: - PDF Helper
    
    private static func addTextPage(to document: PDFDocument, text: String) {
        let pageWidth: CGFloat = 612.0
        let pageHeight: CGFloat = 792.0
        let margin: CGFloat = 72.0
        
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        let mutableData = NSMutableData()
        
        guard let consumer = CGDataConsumer(data: mutableData as CFMutableData) else { return }
        var mediaBox = pageRect
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
        
        context.beginPDFPage(nil)
        context.translateBy(x: 0, y: pageHeight)
        context.scaleBy(x: 1.0, y: -1.0)
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        paragraphStyle.lineBreakMode = .byWordWrapping
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .paragraphStyle: paragraphStyle,
            .foregroundColor: NSColor.black
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString as CFAttributedString)
        let textRect = CGRect(x: margin, y: margin, width: pageWidth - 2 * margin, height: pageHeight - 2 * margin)
        let path = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, attributedString.length), path, nil)
        
        CTFrameDraw(frame, context)
        
        context.endPDFPage()
        context.closePDF()
        
        let pdfData = Data(referencing: mutableData)
        if let pdfDoc = PDFDocument(data: pdfData),
           let page = pdfDoc.page(at: 0) {
            document.insert(page, at: document.pageCount)
        }
    }
    
    // MARK: - ZIP Archive
    
    private static func createZIPArchive(sourceDirectory: URL, destination: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", "-q", destination.path, "."]
        process.currentDirectoryURL = sourceDirectory
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw AIError.systemError("ZIP-Erstellung fehlgeschlagen")
        }
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
    
    private static func sanitizeFileName(_ name: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
    
    // MARK: - Reports
    
    static func generateKDPReport(project: Project) -> String {
        var report = "KDP FORMAT BERICHT\n"
        report += String(repeating: "=", count: 20) + "\n\n"
        report += "Projekt: \(project.title)\n"
        report += "Autor: \(project.authorName)\n"
        report += "Sprache: \(project.language)\n"
        
        let formats = project.outputFormats.joined(separator: ", ")
        report += "Format: \(formats)\n\n"
        
        let totalWords = project.chapters?.compactMap { $0.computedWordCount }.reduce(0, +) ?? 0
        let estimatedPages = totalWords / 250
        
        report += "Gesamtwortzahl: \(totalWords)\n"
        report += "Geschätzte Seiten: \(estimatedPages)\n"
        report += "Zielseiten: \(project.targetPageCount)\n"
        report += "Abweichung: \(abs(estimatedPages - project.targetPageCount)) Seiten\n\n"
        
        report += "Kapitel: \(project.chapters?.count ?? 0)\n"
        report += "Status: \(project.status.rawValue)\n\n"
        
        report += "KI-Offenlegung:\n"
        report += "Dieses Buch wurde mit KI-Unterstützung erstellt.\n"
        report += "Verwendete Tools: NovelForge mit \(project.pipelineJobs?.count ?? 0) Pipeline-Schritten\n\n"
        
        report += "Copyright-Hinweis:\n"
        report += "Dies ist eine interne Prüfung ohne juristische Garantie.\n"
        
        return report
    }
    
    static func generateProductionLog(project: Project) -> String {
        var log = "PRODUKTIONSPROTOKOLL\n"
        log += String(repeating: "=", count: 20) + "\n\n"
        log += "Projekt: \(project.title)\n"
        log += "Erstellt: \(project.createdAt)\n"
        log += "Abgeschlossen: \(project.updatedAt)\n\n"
        
        if let jobs = project.pipelineJobs?.sorted(by: { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }) {
            for job in jobs {
                log += "[\(job.phase.rawValue)] \(job.agentName)\n"
                if let start = job.startTime {
                    log += "  Start: \(start)\n"
                }
                if let end = job.endTime {
                    log += "  Ende: \(end)\n"
                }
                log += "  Status: \(job.status.rawValue)\n"
                if job.errorCount > 0 {
                    log += "  Fehler: \(job.errorCount)\n"
                }
                log += "\n"
            }
        }
        
        return log
    }
}
