import Foundation

@main
enum RegressionProbe {
    static func main() {
        let duplicates = ChapterEventDuplicateParser.parse(
            "DUPLICATE|2|1|Das Versteck wird erneut entdeckt.|Zeige die unmittelbare Folge."
        )
        precondition(duplicates.count == 1)
        precondition(duplicates[0].laterSceneNumber == 2)
        precondition(duplicates[0].earlierSceneNumber == 1)
        precondition(ChapterEventDuplicateParser.isConclusive("KEINE DOPPLUNG"))

        let references = ChapterSceneReferenceParser.parse(
            "Kapitel 3, Szene 1 & Kapitel 3, Szene 2"
        )
        precondition(references == [
            ChapterSceneReference(chapterNumber: 3, sceneNumber: 1),
            ChapterSceneReference(chapterNumber: 3, sceneNumber: 2),
        ])

        precondition(ProductionCompletionPolicy.shouldRequireReview(
            chapterTexts: ["Kapitel eins.", "Kapitel zwei."],
            readinessShortfall: true,
            retriesExhausted: true
        ))
        precondition(!ProductionCompletionPolicy.shouldRequireReview(
            chapterTexts: ["Kapitel eins.", ""],
            readinessShortfall: true,
            retriesExhausted: true
        ))

        print("NovelForge regression probe: PASS")
    }
}
