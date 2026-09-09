import Foundation

/// Genre-abhängige Stil-Budgets.
///
/// **Warum das gebraucht wird.** Alle Stilprüfungen im Projekt waren bis hierher
/// genre-blind: Ein Liebesroman wurde an denselben Budgets gemessen wie ein Thriller.
/// Das ist der Grund, warum eine sauber geprüfte Romance sich kalt liest.
///
/// Körpersignale, Nähe und Sinneseindrücke sind im Thriller Ballast und in der Romance
/// das Genre selbst: Wenn die Heldin nicht spürt, dass er neben ihr steht, gibt es keine
/// Anziehung, und dann gibt es keinen Liebesroman. Dasselbe gilt für Bilder. Ein Krimi
/// lebt von nüchterner Beobachtung, ein Liebesroman von Sinnlichkeit.
///
/// Diese Datei dreht deshalb nicht an der Qualität, sondern an der ERWARTUNG. Die
/// Faktoren multiplizieren die Budgets der jeweiligen Prüfung.
enum GenreStilProfil {

    struct Profil {
        /// Faktor auf das Bilder-Budget (Vergleiche/Metaphern).
        let bilder: Double
        /// Faktor auf das Körpersignal-Budget (Puls, Wärme, Nähe, Berührung).
        let koerper: Double
        /// Faktor auf das Adverb-Budget.
        let adverbien: Double
        /// Klartext für den Draft-Prompt.
        let hinweis: String
    }

    /// Nüchtern, schnell, beobachtend. Bilder sind hier fast immer Ballast.
    static let spannung = Profil(
        bilder: 1.0, koerper: 1.0, adverbien: 1.0,
        hinweis: "Nüchtern und schnell erzählen. Bilder sind hier fast immer Ballast.")

    /// Sinnlichkeit IST das Genre. Ohne körperliche Wahrnehmung keine Anziehung.
    static let liebe = Profil(
        bilder: 2.0, koerper: 2.5, adverbien: 1.3,
        hinweis: "Körperliche Wahrnehmung ist hier PFLICHT, nicht Ballast: Wärme, Nähe, "
            + "Berührung, der Blick, der zu lange bleibt. Pro Begegnung mit dem Love "
            + "Interest mindestens ein Detail, das Begehren zeigt. Der Text darf warm "
            + "sein und Gefühle benennen; kühle Zurückhaltung ist hier ein Genre-Fehler.")

    /// Atmosphäre trägt mit. Bilder dürfen häufiger sein.
    static let stimmung = Profil(
        bilder: 1.8, koerper: 1.4, adverbien: 1.2,
        hinweis: "Atmosphäre trägt die Geschichte mit; Bilder dürfen häufiger stehen.")

    /// Einfach, direkt, konkret.
    static let jugend = Profil(
        bilder: 1.2, koerper: 1.2, adverbien: 1.0,
        hinweis: "Einfach, direkt, konkret. Kurze Sätze, klare Wörter.")

    /// Sachbuch: keine Bilder, keine Körpersignale.
    static let sachbuch = Profil(
        bilder: 0.5, koerper: 0.3, adverbien: 0.8,
        hinweis: "Sachlich. Bilder nur, wenn sie einen Sachverhalt erklären.")

    static func fuer(genre: String) -> Profil {
        let g = genre.folding(options: [.caseInsensitive, .diacriticInsensitive],
                              locale: .current)
        func hat(_ teile: [String]) -> Bool { teile.contains { g.contains($0) } }

        if BookContentType.infer(from: genre) == .nonfiction { return sachbuch }
        if hat(["romance", "liebe", "romantasy", "erotik", "new adult", "chick",
                "frauenroman", "lovers", "burn", "dating", "harem", "choose"]) { return liebe }
        if hat(["thriller", "krimi", "mystery", "noir", "spionage", "whodunit", "heist",
                "suspense", "agenten", "gerichts"]) { return spannung }
        if hat(["jugend", "kinder", "marchen", "coming-of-age"]) { return jugend }
        if hat(["horror", "gothic", "fantasy", "mythologie", "magischer realismus",
                "dark academia", "historisch", "saga", "literatur", "poesie"]) { return stimmung }
        return stimmung
    }

    /// Wendet einen Faktor auf ein Budget an; das Ergebnis bleibt mindestens 1.
    static func budget(_ basis: Int, faktor: Double) -> Int {
        max(1, Int((Double(basis) * faktor).rounded()))
    }
}
