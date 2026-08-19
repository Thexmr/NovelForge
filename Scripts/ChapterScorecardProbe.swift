import Foundation

@main
struct ChapterScorecardProbe {
    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("FEHLER: \(message)\n", stderr)
            exit(1)
        }
    }

    private static func scene(text: String) -> StoryScene {
        let scene = StoryScene(
            sceneNumber: 1, perspective: "Mara", location: "Bahnhof",
            goal: "Den Koffer vor dem Zug sichern", targetWordCount: text.wordCount
        )
        scene.text = text
        scene.obstacle = "Ein Fremder versperrt Mara den Bahnsteig."
        scene.emotionalChange = "Mara entscheidet sich gegen die Flucht."
        scene.status = .written
        return scene
    }

    static func main() {
        let concrete = String(repeating:
            "Mara sprang über die Stufen. Der Koffer klemmte zwischen zwei Bänken. "
                + "Der Schaffner pfiff. Sie riss den Griff hoch und rannte zum letzten Waggon. ", count: 5)
        let clean = ChapterEditorialScorecard.evaluate(
            chapterNumber: 1, text: concrete,
            goal: "Mara sichert den Koffer vor dem Zug.",
            conflict: "Ein Fremder versperrt ihr den Weg.",
            targetWordCount: concrete.wordCount, scenes: [scene(text: concrete)]
        )
        require(clean.verdict == .ready, "konkretes Kapitel erhält keine Freigabe")
        require(clean.overall >= ChapterEditorialScorecard.passThreshold,
                "konkretes Kapitel unterschreitet den Lektoratsgrenzwert")
        require(clean.momentum >= 0.75,
                "konkretes Kapitel unterschreitet den Sog-Grenzwert")

        let staticScene = StoryScene(
            sceneNumber: 1, perspective: "Mara", location: "Bahnhof",
            goal: "Den Fremden am Bahnsteig beobachten", targetWordCount: concrete.wordCount
        )
        staticScene.text = concrete
        staticScene.obstacle = "Der Fremde bleibt außer Reichweite."
        staticScene.status = .written
        let staticChapter = ChapterEditorialScorecard.evaluate(
            chapterNumber: 2, text: concrete,
            goal: "Mara beobachtet den Fremden am Bahnsteig.",
            conflict: "Der Fremde bleibt für Mara unerreichbar.",
            targetWordCount: concrete.wordCount, scenes: [staticScene]
        )
        require(staticChapter.verdict == .revise && staticChapter.momentum < 0.75,
                "eine Szene ohne Wendung oder Folge passiert den Sog-Grenzwert")

        let formulaic = String(repeating:
            "Mara drehte sich um. Sie schüttelte den Kopf. Mara schloss die Augen. "
                + "Mara spürte, wie sich etwas in ihr verschob. ", count: 7)
        let weak = ChapterEditorialScorecard.evaluate(
            chapterNumber: 2, text: formulaic,
            goal: "Mara stellt den Fremden zur Rede.",
            conflict: "Der Fremde verweigert jede Antwort.",
            targetWordCount: formulaic.wordCount, scenes: [scene(text: formulaic)]
        )
        require(weak.verdict == .revise, "Formelcluster passiert den Lektoratsmodus")
        require(weak.prose < 0.75, "Formelcluster senkt den Prosa-Score nicht")

        let explained = String(repeating:
            "Mara schob den Koffer unter die Bank. Das zeigte, dass sie niemanden mehr an sich heranlassen wollte. ",
            count: 8)
        let explainedFindings = AutonomousContentQuality.antiGlaetteFindings(in: explained)
        require(explainedFindings.count >= 2,
                "wiederholte Deutungssätze werden nicht als Anti-Glätte-Befund erkannt")
        let explainedCard = ChapterEditorialScorecard.evaluate(
            chapterNumber: 3, text: explained,
            goal: "Mara sichert den Koffer vor dem Zug.",
            conflict: "Ein Fremder versperrt ihr den Weg.",
            targetWordCount: explained.wordCount, scenes: [scene(text: explained)]
        )
        require(explainedCard.verdict == .revise,
                "übererklärende Prosa passiert den Lektoratsmodus")

        let roundEnding = String(repeating:
            "Mara maß den Abstand zum Gleis und zog den Koffer dichter an sich. ", count: 10)
            + "Was geschah mit dem Koffer, wenn der Zug längst fort war?"
        require(!AutonomousContentQuality.kuenstlichRundeSchlusssaetze(in: roundEnding).isEmpty,
                "künstlicher Erkenntnis-Haken am Szenenende wird nicht erkannt")
        let roundCard = ChapterEditorialScorecard.evaluate(
            chapterNumber: 4, text: roundEnding,
            goal: "Mara sichert den Koffer vor dem Zug.",
            conflict: "Ein Fremder versperrt ihr den Weg.",
            targetWordCount: roundEnding.wordCount, scenes: [scene(text: roundEnding)]
        )
        require(roundCard.verdict == .revise,
                "künstlicher Erkenntnis-Haken passiert den Lektoratsmodus")

        print("ChapterScorecardProbe OK: klar=\(Int((clean.overall * 100).rounded())) %, "
                + "statisch=\(Int((staticChapter.momentum * 100).rounded())) %, "
                + "formelhaft=\(Int((weak.overall * 100).rounded())) %, "
                + "anti-glätte blockiert")
    }
}
