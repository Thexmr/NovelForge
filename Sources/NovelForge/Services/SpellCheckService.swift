import AppKit
import Foundation

/// Rechtschreibprüfung für das fertige Manuskript – offline, ohne Modellaufruf.
///
/// Warum es das gibt: KDP meldete nach dem Upload „121 mögliche Rechtschreibfehler".
/// Die Pipeline hatte bis dahin überhaupt keine Rechtschreibprüfung – der
/// Proofreading-Agent formulierte um, aber niemand schlug je in einem Wörterbuch nach.
///
/// Der eingebaute Prüfer allein reicht dafür nicht: Am selben Manuskript gemessen
/// meldete er 123 Beanstandungen, von denen **87 völlig korrekte zusammengesetzte
/// Wörter** waren – „Reibefläche" (18×), „Ziffernblatt", „Todesurkunde",
/// „Brandschutzgutachten". Deutsche Prüfwörterbücher führen Komposita nicht auf.
/// Ungefiltert wäre die Prüfung wertlos: Sie würde bei jedem Buch Alarm schlagen.
///
/// Diese Klasse filtert deshalb heraus, was sich in zwei bekannte Wörter zerlegen
/// lässt, und meldet nur den Rest. Am Testmanuskript blieben davon 36 Kandidaten übrig
/// – darunter der echte Fehler „KAPITZEL" statt „KAPITEL", und zwar in einer
/// Kapitelüberschrift.
enum SpellCheckService {

    struct Befund {
        let wort: String
        let anzahl: Int
        /// Vorschläge des Systemprüfers, bester zuerst.
        let vorschlaege: [String]
    }

    /// Lautmalerei und erzählerische Wortschöpfungen. In einem Roman sind sie Absicht,
    /// kein Fehler – „Plink", „Klong" beschreiben Geräusche.
    private static let erlaubteWortschoepfungen: Set<String> = [
        "plink", "klong", "pling", "klack", "klong", "wumm", "zisch", "knack",
        "plopp", "ratsch", "schlurf", "tock", "tack", "surr", "brumm",
    ]

    /// Prüft das Manuskript und liefert nur die Wörter, die wirklich verdächtig sind.
    ///
    /// - Parameter eigennamen: Figuren- und Ortsnamen aus der Story Bible. Sie stehen
    ///   in keinem Wörterbuch und dürfen nicht als Fehler gelten. OHNE diese Liste
    ///   meldet die Prüfung jeden Romannamen – am Testmanuskript etwa „Kelms".
    @MainActor
    static func pruefe(text: String, eigennamen: Set<String> = []) -> [Befund] {
        let pruefer = NSSpellChecker.shared
        pruefer.setLanguage("de_DE")

        var treffer: [String: Int] = [:]
        var offset = 0
        let ns = text as NSString
        while offset < ns.length {
            let r = pruefer.checkSpelling(of: text, startingAt: offset, language: "de_DE",
                                          wrap: false, inSpellDocumentWithTag: 0, wordCount: nil)
            if r.location == NSNotFound || r.length == 0 { break }
            treffer[ns.substring(with: r), default: 0] += 1
            offset = r.location + max(r.length, 1)
        }

        let namenKlein = Set(eigennamen.map { $0.lowercased() })
        var befunde: [Befund] = []
        for (wort, anzahl) in treffer {
            let klein = wort.lowercased()
            if erlaubteWortschoepfungen.contains(klein) { continue }
            // Eigenname oder eine gebeugte Form davon („Mira" → „Miras").
            if namenKlein.contains(klein) { continue }
            if namenKlein.contains(where: { klein.hasPrefix($0) && klein.count - $0.count <= 2 }) { continue }
            if istKompositum(wort, pruefer: pruefer) { continue }

            let vorschlaege = pruefer.guesses(forWordRange: NSRange(location: 0, length: (wort as NSString).length),
                                              in: wort, language: "de_DE",
                                              inSpellDocumentWithTag: 0) ?? []
            befunde.append(Befund(wort: wort, anzahl: anzahl, vorschlaege: Array(vorschlaege.prefix(3))))
        }
        return befunde.sorted { $0.anzahl > $1.anzahl }
    }

    /// Steht ein Wort nicht im Wörterbuch, lässt sich aber in zwei Wörter zerlegen,
    /// die BEIDE darin stehen, ist es ein zusammengesetztes Wort und korrekt.
    /// Das Fugen-s („Brandschutz·s·gutachten") wird dabei berücksichtigt.
    @MainActor
    private static func istKompositum(_ wort: String, pruefer: NSSpellChecker) -> Bool {
        func bekannt(_ w: String) -> Bool {
            guard w.count >= 4 else { return false }
            return pruefer.checkSpelling(of: w, startingAt: 0, language: "de_DE",
                                         wrap: false, inSpellDocumentWithTag: 0,
                                         wordCount: nil).location == NSNotFound
        }
        func bekanntInBeidenSchreibweisen(_ w: String) -> Bool {
            bekannt(w.lowercased()) || bekannt(w.lowercased().capitalized)
        }

        let z = Array(wort)
        guard z.count >= 8 else { return false }
        for i in 4...(z.count - 4) {
            let vorne = String(z[0..<i])
            guard bekanntInBeidenSchreibweisen(vorne) else { continue }
            let hinten = String(z[i...])
            if bekanntInBeidenSchreibweisen(hinten) { return true }
            if hinten.hasPrefix("s"), hinten.count >= 5,
               bekanntInBeidenSchreibweisen(String(hinten.dropFirst())) { return true }
        }
        return false
    }

    /// Sammelt zu jedem Verdachtswort den Satz, in dem es steht.
    ///
    /// WARUM NICHT AUTOMATISCH ERSETZEN: Ein erster Versuch ersetzte alles, was dem
    /// Wörterbuchvorschlag um höchstens zwei Zeichen nahekam. Am echten Manuskript
    /// gemessen war davon genau EINE von zwanzig Ersetzungen richtig:
    ///
    ///     KAPITZEL   → KAPITEL      ✓ der einzige echte Treffer
    ///     Rußspuren  → Fußspuren    ✗ das Buch handelt von einem Brand
    ///     Keratin    → Kerstin      ✗ Fachwort wird zum Vornamen
    ///     angekokelt → angekoppelt  ✗ Sinn zerstört
    ///     Kelms      → Helms        ✗ Eigenname verändert
    ///     Plink      → Pink         ✗ Lautmalerei zerstört
    ///
    /// Der Zeichenabstand sagt nichts darüber, ob ein Wort an DIESER Stelle gemeint ist.
    /// Das kann nur entscheiden, wer den Satz versteht. Diese Funktion bereitet deshalb
    /// nur auf; die Entscheidung trifft das Sprachmodell mit dem Satz vor Augen.
    static func mitKontext(_ befunde: [Befund], text: String, hoechstens: Int = 30) -> [(Befund, String)] {
        let saetze = text.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return befunde.prefix(hoechstens).map { befund in
            let satz = saetze.first {
                $0.range(of: befund.wort, options: [.literal]) != nil
            } ?? ""
            return (befund, String(satz.prefix(220)))
        }
    }

    /// Kurzfassung für Berichte und Prompts: „KAPITZEL (1×, besser: KAPITEL)".
    static func beschreibe(_ befunde: [Befund], hoechstens: Int = 25) -> String {
        befunde.prefix(hoechstens).map { b in
            let tipp = b.vorschlaege.first.map { ", besser: \($0)" } ?? ""
            return "\(b.wort) (\(b.anzahl)×\(tipp))"
        }.joined(separator: ", ")
    }
}
