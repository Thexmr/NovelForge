import XCTest
import SwiftData
@testable import NovelForge

/// Verifikation der Exportformate – insbesondere der EPUB-Spezifikation
/// (mimetype muss der erste, unkomprimierte ZIP-Eintrag sein).
@MainActor
final class ExportEngineTests: XCTestCase {

    private func makeProjectWithChapter() throws -> (ModelContainer, Project) {
        let schema = Schema([
            Project.self, BookProfile.self, StoryBible.self, CharacterProfile.self,
            LocationProfile.self, Chapter.self, StoryScene.self,
            PipelineJob.self, QualityReport.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        let project = Project(
            title: "CI-Testbuch \(UUID().uuidString.prefix(8))",
            authorName: "Test Autor", language: "Deutsch", genre: "Krimi",
            styleProfile: "düster", targetPageCount: 60, outputFormats: ["EPUB"]
        )
        container.mainContext.insert(project)

        project.chapters = []
        let chapter = Chapter(chapterNumber: 1, title: "Erstes Kapitel",
                              goal: "Testziel", targetWordCount: 200)
        chapter.project = project
        chapter.finalText = "Erster Absatz des Kapitels.\n\n***\n\nZweiter Absatz nach dem Szenentrenner."
        project.chapters?.append(chapter)
        container.mainContext.insert(chapter)

        return (container, project)
    }

    private func cleanup(_ project: Project) {
        if let dir = try? ExportEngine.exportDirectory(for: project) {
            try? FileManager.default.removeItem(at: dir)
        }
    }

    /// EPUB-Spezifikation: Der erste ZIP-Eintrag muss „mimetype“ heißen und
    /// unkomprimiert (Methode 0 = stored) abgelegt sein – sonst lehnen
    /// Validatoren und manche Reader die Datei ab.
    func testEPUBHasStoredMimetypeAsFirstEntry() throws {
        let (container, project) = try makeProjectWithChapter()
        defer { _ = container; cleanup(project) }

        let url = try ExportEngine.exportToEPUB(project: project)
        let data = try Data(contentsOf: url)

        XCTAssertGreaterThan(data.count, 60)
        // ZIP Local File Header: Signatur PK\x03\x04
        XCTAssertEqual(data[0], 0x50)
        XCTAssertEqual(data[1], 0x4B)
        // Kompressionsmethode (Offset 8-9): 0 = stored
        let method = Int(data[8]) | (Int(data[9]) << 8)
        XCTAssertEqual(method, 0, "mimetype muss unkomprimiert gespeichert sein")
        // Dateiname des ersten Eintrags (Offset 30, 8 Bytes): "mimetype"
        let nameData = data.subdata(in: 30..<38)
        XCTAssertEqual(String(data: nameData, encoding: .utf8), "mimetype")
    }

    func testKDPReportContainsCoreFacts() throws {
        let (container, project) = try makeProjectWithChapter()
        defer { _ = container }

        let report = ExportEngine.generateKDPReport(project: project)
        XCTAssertTrue(report.contains(project.title))
        XCTAssertTrue(report.contains("Trim-Größe"))
        XCTAssertFalse(report.localizedCaseInsensitiveContains("KI-Offenlegung"))
        XCTAssertFalse(report.localizedCaseInsensitiveContains("KI-Unterstützung"))
    }

    func testKDPReportContainsImprintAndStoryMemorySignature() throws {
        let (container, project) = try makeProjectWithChapter()
        defer { _ = container }
        project.imprint = "Test Verlag\nMusterstraße 1\n12345 Berlin"
        project.memorySignature = "krimi testbuch sabotage hafenkante"

        let report = ExportEngine.generateKDPReport(project: project)

        XCTAssertTrue(report.contains("Test Verlag"))
        XCTAssertTrue(report.contains("Story-Memory-Signatur"))
        XCTAssertTrue(report.contains("hafenkante"))
    }

    func testBookCopyrightPageContainsImprintAndAuthorBioWithoutAIDisclosure() throws {
        let (container, project) = try makeProjectWithChapter()
        defer { _ = container }
        project.imprint = "Test Verlag\nMusterstraße 1\n12345 Berlin"
        project.authorBio = "Test Autor schreibt präzise Spannungsromane mit psychologischer Tiefe."

        let page = ExportEngine.bookCopyrightPageText(project: project)

        XCTAssertTrue(page.contains("Test Verlag"))
        XCTAssertTrue(page.contains("Über den Autor"))
        XCTAssertTrue(page.contains(project.authorBio))
        XCTAssertFalse(page.localizedCaseInsensitiveContains("KI"))
        XCTAssertFalse(page.localizedCaseInsensitiveContains("AI"))
        XCTAssertFalse(page.localizedCaseInsensitiveContains("künstliche intelligenz"))
        XCTAssertFalse(page.localizedCaseInsensitiveContains("generiert"))
    }

    func testKDPMetadataPromptForbidsAIDisclosureInCustomerFacingCopy() {
        let prompt = PromptFactory.kdpMetadata(
            title: "Nacht über dem Hafen",
            author: "Test Autor",
            authorBio: "Schreibt Thriller mit forensischer Genauigkeit.",
            genre: "Thriller",
            audience: "Thriller-Fans",
            synopsis: "Eine Ermittlerin jagt einen Saboteur.",
            language: "Deutsch"
        )

        XCTAssertTrue(prompt.contains("Schreibt Thriller"))
        XCTAssertTrue(prompt.contains("Keine Hinweise auf KI"))
    }

    /// rawBestText-Priorität: final > überarbeitet > Rohfassung > Szenen.
    func testRawBestTextPriority() throws {
        let (container, project) = try makeProjectWithChapter()
        defer { _ = container }
        let chapter = try XCTUnwrap(project.chapters?.first)

        chapter.finalText = "FINAL"
        chapter.revisedText = "REVIDIERT"
        chapter.draftText = "ROHFASSUNG"
        XCTAssertEqual(chapter.rawBestText, "FINAL")

        chapter.finalText = nil
        XCTAssertEqual(chapter.rawBestText, "REVIDIERT")

        chapter.revisedText = nil
        XCTAssertEqual(chapter.rawBestText, "ROHFASSUNG")

        chapter.draftText = nil
        chapter.scenes = []
        let scene = StoryScene(sceneNumber: 1, perspective: "Er", location: "Ort",
                               goal: "Ziel", targetWordCount: 100)
        scene.text = "SZENENTEXT"
        scene.chapter = chapter
        chapter.scenes?.append(scene)
        container.mainContext.insert(scene)
        XCTAssertEqual(chapter.rawBestText, "SZENENTEXT")
    }

    func testBestTextCleansPromptArtifactsForExportOnly() throws {
        let (container, project) = try makeProjectWithChapter()
        defer { _ = container }
        let chapter = try XCTUnwrap(project.chapters?.first)
        chapter.finalText = "Sie blieb stehen.\nZielumfang: ca. 600 Wörter\nKnüpfe nahtlos daran an.\nSie atmete aus."

        XCTAssertTrue(chapter.rawBestText?.contains("Zielumfang") == true)
        XCTAssertFalse(chapter.bestText?.contains("Zielumfang") == true)
        XCTAssertFalse(chapter.bestText?.lowercased().contains("knüpfe nahtlos") == true)
    }
}
