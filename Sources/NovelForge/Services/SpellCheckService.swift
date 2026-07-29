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

    /// Korrigiert die Wörter, bei denen die Korrektur eindeutig ist – und NUR diese.
    ///
    /// Automatisch ersetzt wird nur, was sich in höchstens zwei Zeichen vom Vorschlag
    /// unterscheidet und dieselbe Groß-/Kleinschreibung am Wortanfang behält. Damit wird
    /// aus „KAPITZEL" wieder „KAPITEL", während ein Fachwort oder ein Name unangetastet
    /// bleibt: Bei denen liegt der beste Vorschlag weit entfernt, und ein beherzter
    /// Austausch würde den Text verschlimmbessern.
    ///
    /// Rückgabe: der korrigierte Text und die Liste der tatsächlich vorgenommenen
    /// Ersetzungen – damit im Bericht nachvollziehbar bleibt, was verändert wurde.
    @MainActor
    static func korrigiere(text: String, eigennamen: Set<String> = [])
        -> (text: String, ersetzungen: [(falsch: String, richtig: String, anzahl: Int)]) {
        let befunde = pruefe(text: text, eigennamen: eigennamen)
        var ergebnis = text
        var ersetzungen: [(String, String, Int)] = []

        for befund in befunde {
            guard let vorschlag = befund.vorschlaege.first else { continue }
            guard istEindeutig(falsch: befund.wort, richtig: vorschlag) else { continue }
            // Nur ganze Wörter ersetzen – „hüt" darf nicht in „behütet" hineinwirken.
            let muster = "(?<![\\p{L}])" + NSRegularExpression.escapedPattern(for: befund.wort) + "(?![\\p{L}])"
            guard let re = try? NSRegularExpression(pattern: muster) else { continue }
            let bereich = NSRange(ergebnis.startIndex..., in: ergebnis)
            let treffer = re.numberOfMatches(in: ergebnis, range: bereich)
            guard treffer > 0 else { continue }
            ergebnis = re.stringByReplacingMatches(
                in: ergebnis, range: bereich,
                withTemplate: NSRegularExpression.escapedTemplate(for: vorschlag))
            ersetzungen.append((befund.wort, vorschlag, treffer))
        }
        return (ergebnis, ersetzungen)
    }

    /// Ist die Korrektur eindeutig genug, um sie ohne Rückfrage anzuwenden?
    private static func istEindeutig(falsch: String, richtig: String) -> Bool {
        guard falsch.lowercased() != richtig.lowercased() else { return false }
        // Groß-/Kleinschreibung am Wortanfang muss übereinstimmen: Aus einem Substantiv
        // darf kein Verb werden und umgekehrt.
        guard falsch.first?.isUppercase == richtig.first?.isUppercase else { return false }
        // Höchstens zwei Zeichen Unterschied – ein Tippfehler, keine andere Vokabel.
        return abstand(falsch.lowercased(), richtig.lowercased()) <= 2
    }

    /// Levenshtein-Abstand, begrenzt auf kurze Wörter.
    private static func abstand(_ a: String, _ b: String) -> Int {
        let x = Array(a), y = Array(b)
        if abs(x.count - y.count) > 2 { return 99 }
        var vorige = Array(0...y.count)
        for i in 1...max(x.count, 1) where !x.isEmpty {
            var aktuelle = [i] + Array(repeating: 0, count: y.count)
            for j in 1...max(y.count, 1) where !y.isEmpty {
                aktuelle[j] = x[i-1] == y[j-1]
                    ? vorige[j-1]
                    : min(vorige[j-1], vorige[j], aktuelle[j-1]) + 1
            }
            vorige = aktuelle
        }
        return vorige[y.count]
    }

    /// Kurzfassung für Berichte und Prompts: „KAPITZEL (1×, besser: KAPITEL)".
    static func beschreibe(_ befunde: [Befund], hoechstens: Int = 25) -> String {
        befunde.prefix(hoechstens).map { b in
            let tipp = b.vorschlaege.first.map { ", besser: \($0)" } ?? ""
            return "\(b.wort) (\(b.anzahl)×\(tipp))"
        }.joined(separator: ", ")
    }
}
