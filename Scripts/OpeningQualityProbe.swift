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
        require(prompt.contains("KAUSALE KLARHEIT") && prompt.contains("MOTIVATION")
                    && prompt.contains("PLAUSIBILITAET UND KONTINUITAET"),
                "der Lektorats-Prompt enthält die 10/10-Kriterien nicht")

        let targetedRepair = PromptFactory.openingTargetedRepair(
            language: "Deutsch",
            bookTitle: "Test",
            genre: "Psychologischer Thriller",
            chapterText: grounded,
            editorialContext: "Mara ist alleinige Erbin.",
            repairIssues: [
                "[MOTIVATION] FEHLER: Die Kuendigung ist unvorbereitet; vertage stattdessen das Gespraech."
            ],
            allowsCanonicalEventCorrections: true
        )
        require(targetedRepair.contains("CHIRURGISCHE KORREKTUR")
                    && targetedRepair.contains("Die Kuendigung ist unvorbereitet")
                    && targetedRepair.contains("hoehere Autoritaet"),
                "Folgerunden erhalten keine konkrete, kanonisch priorisierte Reparaturanweisung")
        require(!targetedRepair.contains("ohne Ereignisse oder Fakten zu veraendern"),
                "der Folgerunden-Prompt blockiert seine eigene Ereigniskorrektur")

        let auditPrompt = PromptFactory.openingEditorialAudit(
            language: "Deutsch", bookTitle: "Test", genre: "Psychologischer Thriller",
            editorialContext: "Mara ist alleinige Erbin.", chapterText: grounded)
        require(auditPrompt.contains("Ein glatter Stil ist KEIN Bestehensgrund")
                    && auditPrompt.contains("[PLAUSIBILITAET]"),
                "die semantische Endabnahme fehlt")
        require(AutonomousContentQuality.parseOpeningEditorialAudit("BESTANDEN").isEmpty,
                "BESTANDEN muss als fehlerfreie Abnahme gelten")
        require(!AutonomousContentQuality.parseOpeningEditorialAudit("""
        BESTANDEN
        [PLAUSIBILITAET] FEHLER: Anna ist zugleich am Bahnhof und zu Hause; den Ort korrigieren.
        """).isEmpty, "ein vorangestelltes BESTANDEN darf konkrete Fehler nicht verdecken")
        require(!AutonomousContentQuality.parseOpeningEditorialAudit(
            "BESTANDEN, aber die Motivation muss noch korrigiert werden.").isEmpty,
            "eine eingeschraenkte oder widerspruechliche Freigabe ist kein Bestehen")
        let parsed = AutonomousContentQuality.parseOpeningEditorialAudit("""
        1. [KLARHEIT] FEHLER: Die Frist hat keine erkennbare Ursache; nenne den Ausloeser.
        [EINSATZ] Der drohende Verlust trifft die Figur persönlich und konkret.
        Lob: schoene Atmosphaere.
        - [MOTIVATION] FEHLER: Die Kuendigung kommt ohne Vorgeschichte; zeige ein konkretes Erlebnis.
        """)
        require(parsed.count == 2 && parsed[0].hasPrefix("[KLARHEIT]")
                    && parsed[1].hasPrefix("[MOTIVATION]"),
                "Audit-Parser muss nur erlaubte konkrete Befunde uebernehmen")

        print("OpeningQualityProbe OK: natürlicher Einstieg, 10/10-Prompt und semantische Abnahme bestanden")
    }
}
