import Foundation

struct ExportEngine {
    static func exportToEPUB(project: Project) throws -> URL {
        let fileName = "\(project.title)_ebook.epub"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        let lt = "\u{003C}"
        let gt = "\u{003E}"
        let slash = "\u{002F}"
        
        var content = ""
        content.append("\(lt)?xml version=\"1.0\" encoding=\"UTF-8\"?\(gt)\n")
        content.append("\(lt)html xmlns=\"http:\(slash)\(slash)www.w3.org\(slash)1999\(slash)xhtml\"\(gt)\n")
        content.append("\(lt)head\(gt)\n")
        content.append("\(lt)title\(gt)\(project.title)\(lt)\(slash)title\(gt)\n")
        content.append("\(lt)meta charset=\"UTF-8\" \(slash)\(gt)\n")
        content.append("\(lt)\(slash)head\(gt)\n")
        content.append("\(lt)body\(gt)\n")
        
        // Title page
        content.append("\(lt)h1\(gt)\(project.title)\(lt)\(slash)h1\(gt)\n")
        content.append("\(lt)p\(gt)\(project.authorName)\(lt)\(slash)p\(gt)\n")
        content.append("\(lt)hr \(slash)\(gt)\n")
        
        // Copyright
        let year = Calendar.current.component(.year, from: Date())
        content.append("\(lt)p\(gt)© \(year) \(project.authorName)\(lt)\(slash)p\(gt)\n")
        content.append("\(lt)hr \(slash)\(gt)\n")
        
        // Table of contents
        content.append("\(lt)h2\(gt)Inhaltsverzeichnis\(lt)\(slash)h2\(gt)\n")
        content.append("\(lt)ul\(gt)\n")
        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                content.append("\(lt)li\(gt)\(chapter.title)\(lt)\(slash)li\(gt)\n")
            }
        }
        content.append("\(lt)\(slash)ul\(gt)\n")
        content.append("\(lt)hr \(slash)\(gt)\n")
        
        // Chapters
        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                content.append("\(lt)h2\(gt)\(chapter.title)\(lt)\(slash)h2\(gt)\n")
                if let scenes = chapter.scenes?.sorted(by: { $0.sceneNumber < $1.sceneNumber }) {
                    for scene in scenes {
                        if let text = scene.text {
                            let paragraphs = text.components(separatedBy: .newlines)
                            for paragraph in paragraphs {
                                if !paragraph.isEmpty {
                                    content.append("\(lt)p\(gt)\(paragraph)\(lt)\(slash)p\(gt)\n")
                                }
                            }
                        }
                    }
                }
            }
        }
        
        content.append("\(lt)\(slash)body\(gt)\n")
        content.append("\(lt)\(slash)html\(gt)")
        
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    static func exportToPDF(project: Project) throws -> URL {
        let fileName = "\(project.title)_print.pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        var content = ""
        
        // Title page
        content.append("\(project.title)\n")
        content.append("\(project.authorName)\n\n")
        content.append("© \(Calendar.current.component(.year, from: Date())) \(project.authorName)\n\n")
        content.append("---\n\n")
        
        // Chapters
        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                content.append("\(chapter.title)\n\n")
                if let scenes = chapter.scenes?.sorted(by: { $0.sceneNumber < $1.sceneNumber }) {
                    for scene in scenes {
                        if let text = scene.text {
                            content.append("\(text)\n\n")
                        }
                    }
                }
                content.append("\n---\n\n")
            }
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    static func exportToDOCX(project: Project) throws -> URL {
        let fileName = "\(project.title).docx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        var content = ""
        content.append("Titel: \(project.title)\n")
        content.append("Autor: \(project.authorName)\n")
        content.append("Genre: \(project.genre)\n")
        content.append("Sprache: \(project.language)\n\n")
        
        if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
            for chapter in chapters {
                content.append("\(chapter.title)\n\n")
                if let finalText = chapter.finalText ?? chapter.revisedText ?? chapter.draftText {
                    content.append("\(finalText)\n\n")
                }
            }
        }
        
        try content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    static func generateKDPReport(project: Project) -> String {
        var report = "KDP FORMAT BERICHT\n"
        report.append("==================\n\n")
        report.append("Projekt: \(project.title)\n")
        report.append("Autor: \(project.authorName)\n")
        report.append("Sprache: \(project.language)\n")
        
        let formats = project.outputFormats.joined(separator: ", ")
        report.append("Format: \(formats)\n\n")
        
        let totalWords = project.chapters?.compactMap { $0.computedWordCount }.reduce(0, +) ?? 0
        let estimatedPages = totalWords / 250
        
        report.append("Gesamtwortzahl: \(totalWords)\n")
        report.append("Geschätzte Seiten: \(estimatedPages)\n")
        report.append("Zielseiten: \(project.targetPageCount)\n")
        report.append("Abweichung: \(abs(estimatedPages - project.targetPageCount)) Seiten\n\n")
        
        report.append("Kapitel: \(project.chapters?.count ?? 0)\n")
        report.append("Status: \(project.status.rawValue)\n\n")
        
        report.append("KI-Offenlegung:\n")
        report.append("Dieses Buch wurde mit KI-Unterstützung erstellt.\n")
        report.append("Verwendete Tools: NovelForge mit \(project.pipelineJobs?.count ?? 0) Pipeline-Schritten\n\n")
        
        report.append("Copyright-Hinweis:\n")
        report.append("Dies ist eine interne Prüfung ohne juristische Garantie.\n")
        
        return report
    }
    
    static func generateProductionLog(project: Project) -> String {
        var log = "PRODUKTIONSPROTOKOLL\n"
        log.append("====================\n\n")
        log.append("Projekt: \(project.title)\n")
        log.append("Erstellt: \(project.createdAt)\n")
        log.append("Abgeschlossen: \(project.updatedAt)\n\n")
        
        if let jobs = project.pipelineJobs?.sorted(by: { ($0.startTime ?? Date()) < ($1.startTime ?? Date()) }) {
            for job in jobs {
                log.append("[\(job.phase.rawValue)] \(job.agentName)\n")
                if let start = job.startTime {
                    log.append("  Start: \(start)\n")
                }
                if let end = job.endTime {
                    log.append("  Ende: \(end)\n")
                }
                log.append("  Status: \(job.status.rawValue)\n")
                if job.errorCount > 0 {
                    log.append("  Fehler: \(job.errorCount)\n")
                }
                log.append("\n")
            }
        }
        
        return log
    }
}