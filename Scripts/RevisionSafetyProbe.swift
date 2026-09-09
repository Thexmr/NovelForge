import Foundation

@main
enum RevisionSafetyProbe {
    static func main() {
        func issues(_ source: String, _ candidate: String) -> [String] {
            RevisionSafety.issues(source: source, candidate: candidate)
        }

        precondition(issues(
            "Mara wartete drei Stunden und ging dann nach Hause.",
            "Nach drei Stunden gab Mara das Warten auf und ging nach Hause."
        ).isEmpty, "Eine inhaltstreue Umformulierung muss erlaubt bleiben")

        precondition(issues(
            "Um 3 Uhr klopfte Mara zweimal.",
            "Am Nachmittag klopfte Mara."
        ).contains(where: { $0.contains("Zahl") }),
        "Verlorene Zahlen muessen eine Revision blockieren")

        precondition(issues("Mara kam nicht.", "Mara kam.")
            .contains(where: { $0.contains("Verneinung") }),
        "Eine verschwundene Verneinung muss blockieren")

        precondition(issues(
            "„Bleib hier“, sagte Mara. Jonas schwieg.",
            "Bleib hier, sagte Mara. Jonas schwieg."
        ).contains(where: { $0.contains("Anführungszeichen") }),
        "Dialogzeichen muessen erhalten bleiben")

        precondition(issues(
            "Mara ging zum Fenster und sah hinaus.",
            "Mara geht zum Fenster und sieht hinaus."
        ).contains(where: { $0.contains("Erzählzeit") }),
        "Die Erzaehlzeit darf nicht wechseln")

        precondition(issues(
            "Ich ging zum Fenster und wartete dort.",
            "Sie ging zum Fenster und wartete dort."
        ).contains(where: { $0.contains("Perspektive") }),
        "Die Perspektive darf nicht wechseln")

        precondition(issues(
            "Sein Bruder, der abgerissene Knopf, die Drohung, die Brandstiftung und die Feuerwehrschläuche blieben als Spuren.",
            "Sein Bruder und die Drohung blieben als Spuren."
        ).contains(where: { $0.contains("Inhaltselemente") }),
        "Zusammengestrichene Indizien muessen erkannt werden")

        precondition(RevisionSafety.parseBlindWinner("A") == .first)
        precondition(RevisionSafety.parseBlindWinner("BESSER: B") == .second)
        precondition(RevisionSafety.parseBlindWinner("GLEICH") == .equal)
        precondition(RevisionSafety.parseBlindWinner("Vielleicht A") == .invalid)
        precondition(RevisionSafety.candidateClearlyWins(
            originalFirst: .second, candidateFirst: .first
        ), "Der Kandidat muss in beiden Positionen gewinnen")
        precondition(!RevisionSafety.candidateClearlyWins(
            originalFirst: .second, candidateFirst: .equal
        ), "Ein Gleichstand ist keine nachgewiesene Verbesserung")
        precondition(!RevisionSafety.candidateClearlyWins(
            originalFirst: .first, candidateFirst: .first
        ), "Positionsbevorzugung muss die Uebernahme verhindern")

        let blindPrompt = PromptFactory.revisionVerdict(
            language: "Deutsch", chapterTitle: "Probe",
            draft: "Originalsatz.", revision: "Neuer Satz."
        )
        precondition(!blindPrompt.localizedCaseInsensitiveContains("Rohfassung")
                     && !blindPrompt.localizedCaseInsensitiveContains("überarbeitete Fassung"),
                     "Der Lektor darf nicht erfahren, welche Fassung bearbeitet wurde")

        print("NovelForge revision safety probe: PASS")
    }
}
