import XCTest
import SwiftData
@testable import NovelForge

/// Tests der automatischen Qualitätsbewertung mit einer In-Memory-Datenbank.
@MainActor
final class QualityScoreTests: XCTestCase {

    private func makeProject() throws -> (ModelContainer, Project) {
        let schema = Schema([
            Project.self, BookProfile.self, StoryBible.self, CharacterProfile.self,
            LocationProfile.self, Chapter.self, StoryScene.self,
            PipelineJob.self, QualityReport.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])

        let project = Project(
            title: "Testbuch", authorName: "Test Autor", language: "Deutsch",
            genre: "Krimi", styleProfile: "düster",
            targetPageCount: 100, outputFormats: ["EPUB"]
        )
        container.mainContext.insert(project)
        return (container, project)
    }

    func testScoresOnEmptyProjectAreZero() throws {
        let (container, project) = try makeProject()
        defer { _ = container } // Container am Leben halten

        let scores = QualityScores.compute(for: project)
        XCTAssertEqual(scores.structure, 0)
        XCTAssertEqual(scores.characters, 0)
        XCTAssertEqual(scores.style, 0)
        XCTAssertEqual(scores.kdp, 0)
    }

    func testScoresWithWellFormedChapter() throws {
        let (container, project) = try makeProject()
        defer { _ = container }

        project.chapters = []
        let chapter = Chapter(chapterNumber: 1, title: "Eins", goal: "Klares Ziel", targetWordCount: 1000)
        chapter.project = project
        project.chapters?.append(chapter)
        container.mainContext.insert(chapter)

        chapter.scenes = []
        let scene = StoryScene(sceneNumber: 1, perspective: "Er", location: "Hafen",
                               goal: "Fliehen", targetWordCount: 1000)
        scene.text = Array(repeating: "Wort", count: 1000).joined(separator: " ")
        scene.status = .written
        scene.chapter = chapter
        chapter.scenes?.append(scene)
        container.mainContext.insert(scene)
        chapter.finalText = scene.text

        let scores = QualityScores.compute(for: project)
        // Kapitel hat Ziel + Szenen → volle Struktur.
        XCTAssertEqual(scores.structure, 1.0)
        // Szene exakt auf Zielwortzahl → voller Stil-Score.
        XCTAssertEqual(scores.style, 1.0)
        // Keine Konsistenzprobleme gemeldet → voller Score.
        XCTAssertEqual(scores.consistency, 1.0)
        // 1.000 von 25.000 Zielwörtern → KDP-Score niedrig, aber > 0.
        XCTAssertGreaterThan(scores.kdp, 0)
        XCTAssertLessThan(scores.kdp, 0.2)
    }

    func testProjectTotalWordCountUsesFastChapterCounts() throws {
        let (container, project) = try makeProject()
        defer { _ = container }

        project.chapters = []
        let first = Chapter(chapterNumber: 1, title: "Eins", goal: "Ziel", targetWordCount: 5000)
        let second = Chapter(chapterNumber: 2, title: "Zwei", goal: "Ziel", targetWordCount: 5000)
        first.actualWordCount = 4_000
        second.actualWordCount = 5_000
        first.finalText = Array(repeating: "Wort", count: 20_000).joined(separator: " ")
        second.finalText = Array(repeating: "Wort", count: 20_000).joined(separator: " ")
        first.project = project
        second.project = project
        project.chapters?.append(first)
        project.chapters?.append(second)
        container.mainContext.insert(first)
        container.mainContext.insert(second)

        XCTAssertEqual(project.totalWordCount, 9_000)
    }

    func testConsistencyScoreDropsWithSevereIssues() throws {
        let (container, project) = try makeProject()
        defer { _ = container }

        project.qualityReports = []
        for index in 0..<3 {
            let report = QualityReport(checkedArea: "Zeitlinie", checkType: "Konsistenz",
                                       result: "Widerspruch \(index)", severity: .error,
                                       recommendation: "")
            report.project = project
            project.qualityReports?.append(report)
            container.mainContext.insert(report)
        }

        let scores = QualityScores.compute(for: project)
        // 3 schwere Befunde à 10% Abzug.
        XCTAssertEqual(scores.consistency, 0.7, accuracy: 0.0001)
    }

    func testCachedScoresInvalidateAfterSceneUpdate() throws {
        let (container, project) = try makeProject()
        defer { _ = container }

        let chapter = Chapter(chapterNumber: 1, title: "Eins",
                              goal: "Klares Ziel", targetWordCount: 100)
        let scene = StoryScene(sceneNumber: 1, perspective: "Er", location: "Hafen",
                               goal: "Fliehen", targetWordCount: 100)
        scene.text = Array(repeating: "Wort", count: 100).joined(separator: " ")
        scene.status = .written
        scene.chapter = chapter
        chapter.scenes = [scene]
        chapter.actualWordCount = 100
        chapter.finalText = scene.text
        chapter.project = project
        project.chapters = [chapter]
        container.mainContext.insert(chapter)
        container.mainContext.insert(scene)

        XCTAssertEqual(QualityScores.cached(for: project).style, 1.0)

        scene.text = Array(repeating: "Wort", count: 20).joined(separator: " ")
        scene.updatedAt = scene.updatedAt.addingTimeInterval(1)

        XCTAssertLessThan(QualityScores.cached(for: project).style, 1.0)
    }
}
