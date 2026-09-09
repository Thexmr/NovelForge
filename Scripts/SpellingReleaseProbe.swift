import Foundation
import SwiftData

@main
@MainActor
struct SpellingReleaseProbe {
    static func main() throws {
        let schema = Schema([
            Project.self, BookProfile.self, StoryBible.self, CharacterProfile.self,
            LocationProfile.self, Chapter.self, StoryScene.self, PipelineJob.self,
            QualityReport.self, ChatMessage.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]
        )
        let context = container.mainContext
        let project = Project(
            title: "Freigabetest", authorName: "Autor", language: "Deutsch",
            genre: "Roman", styleProfile: "modern", targetPageCount: 1,
            outputFormats: ["EPUB"]
        )
        let chapter = Chapter(
            chapterNumber: 1, title: "KAPITZEL 1", goal: "Entscheidung",
            targetWordCount: 80
        )
        chapter.finalText = Array(repeating: "Ein klarer Satz.", count: 24).joined(separator: " ")
            + " Der Standart war nähmlich falsch. Sie kam gestern abend zurück."
        chapter.status = .finalized
        chapter.actualWordCount = chapter.finalText?.wordCount ?? 0
        chapter.project = project
        project.chapters = [chapter]
        context.insert(project)
        context.insert(chapter)
        try context.save()

        let blocked = PublicationReadiness.exportBlockingIssues(project: project)
        precondition(
            blocked.contains { $0.contains("Eindeutige Rechtschreibfehler") },
            "Eine fehlerhafte Roman-Endfassung darf nicht exportiert werden"
        )

        chapter.title = SpellCheckService.korrigiereEindeutigeFehler(in: chapter.title)
        chapter.finalText = SpellCheckService.korrigiereEindeutigeFehler(
            in: chapter.finalText ?? ""
        )
        chapter.updatedAt = Date()
        let corrected = PublicationReadiness.exportBlockingIssues(project: project)
        precondition(
            !corrected.contains { $0.contains("Eindeutige Rechtschreibfehler") },
            "Nach der sicheren Korrektur darf kein Rechtschreibblocker verbleiben"
        )

        chapter.finalText = (chapter.finalText ?? "")
            + "\n\n„Was ist passiert?“?„, fragte Mara."
        let dialogueBlocked = PublicationReadiness.exportBlockingIssues(project: project)
        precondition(
            dialogueBlocked.contains { $0.contains("Beschädigte Dialogtypografie") },
            "Ein Manuskript mit zerstoerter Dialogtypografie darf nicht exportiert werden"
        )
        chapter.finalText = (chapter.finalText ?? "")
            .replacingOccurrences(of: "„Was ist passiert?“?„, fragte Mara.",
                                  with: "„Was ist passiert?“, fragte Mara.")
        let dialogueCorrected = PublicationReadiness.exportBlockingIssues(project: project)
        precondition(
            !dialogueCorrected.contains { $0.contains("Beschädigte Dialogtypografie") },
            "Korrekte deutsche Dialogtypografie muss exportierbar bleiben"
        )
        print("NovelForge spelling release probe: PASS")

        let openingReport = QualityReport(
            checkedArea: "Kapitel 1", checkType: LocalEditorialAssistant.openingReviewType,
            result: "Die Figur handelt gegen die festgelegte Vorgeschichte.",
            severity: .error, recommendation: "Motivation korrigieren und erneut pruefen.")
        openingReport.project = project
        context.insert(openingReport)
        project.qualityReports = [openingReport]
        precondition(PublicationReadiness.exportBlockingIssues(project: project).contains {
            $0.contains("Romananfang nicht freigabefaehig")
        }, "Offene semantische Fehler muessen auch den Export sperren")
        openingReport.autoFixed = true
        precondition(!PublicationReadiness.exportBlockingIssues(project: project).contains {
            $0.contains("Romananfang nicht freigabefaehig")
        }, "Nach erneuter Abnahme darf kein alter Befund weiter blockieren")
        print("NovelForge semantic opening release probe: PASS")
    }
}
