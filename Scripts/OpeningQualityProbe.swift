import Foundation

@main
struct OpeningQualityProbe {
    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else {
            fputs("FEHLER: \(message)\n", stderr)
            exit(1)
        }
    }

    static func main() {
        let grounded = """
        Lea war zehn Minuten zu früh, was bei ihrer Schwester keine gute Idee war. Sie wartete im
        Café am Bahnhof, um mit Vera den Verkauf des Elternhauses zu unterschreiben. Auf dem Tisch
        lag die Mappe mit dem Vertrag. Als Vera nicht kam, fragte Lea sich, ob sie wieder weglief.
        """
        require(AutonomousContentQuality.openingMysteryStackIssues(in: grounded).isEmpty,
                "ein glaubwürdiger menschlicher Einstieg wird fälschlich blockiert")

        let stacked = """
        Ein anonymer Brief lag im Flur. Eine unbekannte Nachricht zeigte ein unbekanntes Foto.
        In der alten Akte stand eine Drohung ohne Absender. Mara nahm den Schlüsselbund und wusste,
        dass sie die verschlossene Tür nicht öffnen durfte.
        """
        let issues = AutonomousContentQuality.openingMysteryStackIssues(in: stacked)
        require(!issues.isEmpty, "ein künstlicher Rätselstapel wird nicht erkannt")
        require(AutonomousContentQuality.finalOpeningIssues(in: stacked, protagonistNames: ["Mara"])
                    .contains { $0.contains("Mystery-Requisiten") },
                "das Rätselstapel-Gate erreicht die Endabnahme nicht")

        let prompt = PromptFactory.openingHook(language: "Deutsch", bookTitle: "Test",
                                                genre: "Psychologischer Thriller", chapterText: grounded)
        require(prompt.contains("Alltagssituation") && prompt.contains("Rätsel-Stapel"),
                "der Lektorats-Prompt enthält den bestätigten Einstiegsstandard nicht")

        print("OpeningQualityProbe OK: natürlicher Einstieg bestanden, Rätselstapel blockiert")
    }
}
