import Foundation
import SwiftData

@main
@MainActor
enum FirstPagesPreview {
    private struct Preview: Codable {
        let title: String
        let author: String
        let chapterTitle: String
        let text: String
    }

    static func main() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let storePath = environment["NF_PREVIEW_STORE"], !storePath.isEmpty,
              let outputPath = environment["NF_PREVIEW_OUTPUT"], !outputPath.isEmpty else {
            print("PREVIEW_FAIL: NF_PREVIEW_STORE und NF_PREVIEW_OUTPUT sind erforderlich")
            exit(2)
        }

        let schema = Schema([
            Project.self, BookProfile.self, StoryBible.self, CharacterProfile.self,
            LocationProfile.self, Chapter.self, StoryScene.self, PipelineJob.self,
            QualityReport.self, ChatMessage.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration(
                    schema: schema,
                    url: URL(fileURLWithPath: storePath)
                )
            ]
        )
        let projects = try container.mainContext.fetch(FetchDescriptor<Project>())
        guard let project = projects.first(where: {
            $0.chapters?.contains(where: { $0.bestText?.isEmpty == false }) == true
        }),
              let chapter = (project.chapters ?? [])
                .sorted(by: { $0.chapterNumber < $1.chapterNumber })
                .first,
              let text = chapter.bestText,
              !text.isEmpty else {
            print("PREVIEW_FAIL: Kein gespeicherter Buchanfang gefunden")
            exit(1)
        }

        let preview = Preview(
            title: project.title,
            author: project.authorName,
            chapterTitle: chapter.displayTitle,
            text: AutonomousContentQuality.vereinheitlicheAnfuehrungszeichen(
                SpellCheckService.korrigiereVeralteteRechtschreibung(text)
            )
        )
        let data = try JSONEncoder().encode(preview)
        try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        print("PREVIEW_OK: \(preview.title) | \(preview.text.wordCount) Wörter im ersten Kapitel")
    }
}
