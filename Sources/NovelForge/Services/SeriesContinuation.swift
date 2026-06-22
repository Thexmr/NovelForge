import Foundation

/// Baut den Fortsetzungs-Kontext für einen Folgeband aus einem abgeschlossenen Band.
/// Damit erbt der nächste Band Figuren, Welt, Ausgang und offene Fäden und erzählt
/// die Reihe konsistent weiter (Harry-Potter-Prinzip: Band 1 → 2 → 3 …).
enum SeriesContinuation {

    /// Verdichteter Kontext des bisherigen Verlaufs (Figuren, Welt, Ende, offene Fäden).
    static func brief(from previous: Project) -> String {
        var parts: [String] = []
        let seriesLabel = previous.seriesName.isEmpty ? previous.title : previous.seriesName
        let bandNo = max(1, previous.seriesNumber)
        parts.append("REIHE: \(seriesLabel)")
        parts.append("VORHERIGER BAND: „\(previous.title)“ (Band \(bandNo))")

        if let premise = previous.bookProfile?.premise.trimmingCharacters(in: .whitespacesAndNewlines),
           !premise.isEmpty {
            parts.append("WORUM ES GING: \(premise.truncated(to: 400))")
        }

        // Wiederkehrende Figuren – Namen/Eigenschaften müssen erhalten bleiben.
        let characters = (previous.storyBible?.characters ?? [])
            .sorted { $0.createdAt < $1.createdAt }
        if !characters.isEmpty {
            let lines = characters.prefix(8).map { c -> String in
                var s = "- \(c.name)"
                if !c.role.isEmpty { s += " (\(c.role))" }
                if !c.age.isEmpty { s += ", \(c.age)" }
                if !c.goal.isEmpty { s += " – Ziel: \(c.goal.truncated(to: 90))" }
                return s
            }
            parts.append("WIEDERKEHRENDE FIGUREN (Namen, Eigenschaften und Beziehungen BEIBEHALTEN, weiterentwickeln):\n"
                         + lines.joined(separator: "\n"))
        }

        // Welt / Schauplätze.
        let locations = previous.storyBible?.locations ?? []
        if !locations.isEmpty {
            let names = locations.prefix(6).map { loc -> String in
                loc.type.isEmpty ? loc.name : "\(loc.name) (\(loc.type))"
            }
            parts.append("WELT / SCHAUPLÄTZE (BEIBEHALTEN): " + names.joined(separator: ", "))
        }

        // Wie der vorherige Band endete – aus den letzten Kapiteln verdichtet.
        let chapters = (previous.chapters ?? []).sorted { $0.chapterNumber < $1.chapterNumber }
        let endings = chapters.suffix(3).compactMap { chapter -> String? in
            let scenes = (chapter.scenes ?? []).sorted { $0.sceneNumber < $1.sceneNumber }
            let summary = scenes.compactMap { $0.summary }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            guard !summary.isEmpty else { return nil }
            return "Kap. \(chapter.chapterNumber): \(summary.truncated(to: 320))"
        }
        if !endings.isEmpty {
            parts.append("WIE BAND \(bandNo) ENDETE:\n" + endings.joined(separator: "\n"))
        }

        // Offene Fäden, die der Folgeband aufgreifen soll.
        if let open = previous.storyBible?.openQuestions.trimmingCharacters(in: .whitespacesAndNewlines),
           !open.isEmpty {
            parts.append("OFFENE FÄDEN (im Folgeband aufgreifen und teils auflösen): \(open.truncated(to: 400))")
        }

        return parts.joined(separator: "\n\n")
    }

    /// Standardtitel für den nächsten Band (kann später inhaltlich geschärft werden).
    static func nextVolumeTitle(from previous: Project) -> String {
        let seriesLabel = previous.seriesName.isEmpty ? previous.title : previous.seriesName
        let nextNumber = (previous.seriesNumber > 0 ? previous.seriesNumber : 1) + 1
        return "\(seriesLabel) – Band \(nextNumber)"
    }
}
