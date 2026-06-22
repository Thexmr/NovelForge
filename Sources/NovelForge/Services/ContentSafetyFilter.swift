import Foundation

/// Harte Inhaltssperre für die Buchgenerierung.
///
/// Zero-Tolerance-Regel: Sexuelle oder erotische Inhalte im Zusammenhang mit
/// Kindern oder Minderjährigen werden NIEMALS akzeptiert oder gespeichert –
/// unabhängig von Genre oder Sinnlichkeitsgrad. Reine lokale Heuristik
/// (kein Netzwerkaufruf, deterministisch), bewusst streng: im Zweifel blockieren.
///
/// Die Heuristik schlägt nur an, wenn ein *expliziter* sexueller Marker UND ein
/// Minderjährigkeits-Hinweis (Wort oder Altersangabe < 18) nah beieinander
/// stehen. Dadurch bleiben unbedenkliche Szenen (ein Kind kommt vor; ODER eine
/// erwachsene erotische Szene) unberührt – nur die gefährliche Kombination wird
/// gesperrt. Mögliche Fehlalarme (z.B. „Teenager“ nahe einer expliziten Szene)
/// werden bewusst zugunsten der Sicherheit in Kauf genommen und als Bericht
/// markiert, statt den Text zu speichern.
enum ContentSafetyFilter {

    /// Immer aktiver, nicht verhandelbarer Sicherheitsblock für Generierungs-Prompts.
    static let promptDirective = """
    SICHERHEIT (ABSOLUT, NICHT VERHANDELBAR): Jede Figur, die an romantischen, \
    intimen oder sexuellen Handlungen beteiligt ist, ist eindeutig erwachsen \
    (mindestens 18 Jahre). Die Sexualisierung von Kindern oder Minderjährigen ist \
    unter allen Umständen verboten - auch angedeutet, in Rückblenden, Träumen, \
    Vergleichen oder Nebensätzen. Kommen minderjährige Figuren vor, bleiben sie von \
    jeder sexuellen oder erotischen Darstellung vollständig ausgenommen.
    """

    /// nil = unbedenklich. Sonst eine kurze Begründung der Sperre.
    static func violation(in text: String) -> String? {
        let lower = text.lowercased()

        // Schnell-Ausstieg: ohne expliziten sexuellen Marker gibt es nichts zu sperren.
        let sexual = regexOffsets(sexualPattern, in: lower)
        guard !sexual.isEmpty else { return nil }

        // a) Minderjährigkeits-Wort in Nähe eines sexuellen Markers.
        let minor = regexOffsets(minorPattern, in: lower)
        if minPairDistance(sexual, minor) <= proximity {
            return "sexueller Kontext nahe Minderjährigkeits-Hinweis"
        }

        // b) Altersangabe < 18 in Nähe eines sexuellen Markers.
        for (offset, age) in underageAges(in: lower)
        where sexual.contains(where: { abs($0 - offset) <= proximity }) {
            return "Altersangabe \(age) Jahre (<18) im sexuellen Kontext"
        }

        return nil
    }

    /// true = Text darf gespeichert werden.
    static func isSafe(_ text: String) -> Bool { violation(in: text) == nil }

    // MARK: - Konfiguration

    /// Zeichen-Fenster, in dem sexueller Marker und Minderjährigkeits-Hinweis als
    /// „im selben Kontext“ gelten (~30–40 Wörter).
    private static let proximity = 220

    /// Explizite sexuelle Marker (Wortstämme, DE + EN). Bewusst auf eindeutig
    /// sexuelle Handlungen/Erregung beschränkt – NICHT „nackt“/„küssen“ allein,
    /// um harmlose Familienszenen (Baden, Gute-Nacht-Kuss) nicht zu treffen.
    private static let sexualPattern: String = "(?i)(?:" + [
        "geschlechtsverkehr", "geschlechtsteil", "geschlechtsorgan",
        "hatte sex", "sex mit", "beim sex", "\\bsex\\b",
        "penis", "vagina", "schamlippen", "klitoris", "erektion", "erigiert",
        "ejakul\\w*", "samenerguss", "orgasmus", "masturb\\w*", "penetr\\w*",
        "drang in (?:sie|ihn)", "stieß in (?:sie|ihn)", "stieß zu",
        "leckte (?:ihre|seinen|ihren)", "ihre nässe", "stöhnte vor lust",
        "lustvoll stöhn\\w*", "ritt ihn", "blies ihm", "nahm ihn in den mund",
        // EN
        "had sex", "sexual intercourse", "clitoris", "erection", "ejaculat\\w*",
        "orgasm", "masturbat\\w*", "penetrat\\w*", "aroused (?:her|him)",
        "blowjob", "thrust into", "fuck\\w*", "nipple"
    ].joined(separator: "|") + ")"

    /// Minderjährigkeits-Hinweise (Wortgrenzen → keine Treffer in „Kindheit“,
    /// „Kinderspiel“ etc.). „Teenager/jugendlich“ bewusst enthalten: nahe einer
    /// expliziten Szene gehören sie zur menschlichen Prüfung.
    private static let minorPattern: String = "(?i)\\b(?:" + [
        "minderjährig\\w*", "kind", "kinder", "kindes", "kindlich\\w*", "kindeskörper",
        "kleinkind\\w*", "säugling\\w*", "baby", "babys", "vorschulkind\\w*",
        "grundschul\\w*", "schulkind\\w*", "kindergarten\\w*", "vorpubertär\\w*",
        "pubertierend\\w*", "halbwüchsig\\w*", "teenager", "teenie\\w*",
        "jugendlich\\w*",
        // ausgeschriebene Kind-Altersangaben (<18), die die Ziffern-Regex nicht fängt
        "(?:zwei|drei|vier|fünf|sechs|sieben|acht|neun|zehn|elf|zwölf|dreizehn|vierzehn|fünfzehn|sechzehn|siebzehn)jährig\\w*",
        // EN
        "underage", "preteen", "pre-teen", "prepubescent", "schoolgirl",
        "schoolboy", "toddler", "infant", "child", "children", "kids?",
        "little (?:girl|boy)"
    ].joined(separator: "|") + ")\\b"

    // MARK: - Heuristik-Bausteine

    /// Findet Altersangaben 1–17 (z.B. „14 Jahre alt“, „16-jährig“, „im Alter von 12“).
    /// Liefert (Zeichen-Offset, Alter).
    private static func underageAges(in text: String) -> [(Int, Int)] {
        let pattern = "(?i)(?:\\bim alter von\\s+)?(\\d{1,2})\\s*[-‑ ]?\\s*(?:jährig\\w*|jahre alt|jahre|jahren|j\\.)"
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        var result: [(Int, Int)] = []
        for match in re.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            guard match.numberOfRanges > 1 else { continue }
            let numRange = match.range(at: 1)
            guard numRange.location != NSNotFound,
                  let age = Int(ns.substring(with: numRange)), age < 18 else { continue }
            result.append((match.range.location, age))
        }
        return result
    }

    private static func regexOffsets(_ pattern: String, in text: String) -> [Int] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { $0.range.location }
    }

    /// Kleinster Abstand zwischen einem Offset aus `a` und einem aus `b`
    /// (Int.max, wenn eine Liste leer ist).
    private static func minPairDistance(_ a: [Int], _ b: [Int]) -> Int {
        guard !a.isEmpty, !b.isEmpty else { return Int.max }
        var best = Int.max
        for x in a {
            for y in b {
                best = min(best, abs(x - y))
                if best == 0 { return 0 }
            }
        }
        return best
    }
}
