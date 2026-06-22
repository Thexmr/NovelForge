import Foundation

/// Harte Inhaltssperre für die Buchgenerierung.
///
/// Zero-Tolerance-Regel: Sexuelle oder erotische Inhalte im Zusammenhang mit
/// Kindern oder Minderjährigen werden NIEMALS akzeptiert oder gespeichert –
/// unabhängig von Genre oder Sinnlichkeitsgrad. Reine lokale Heuristik
/// (kein Netzwerkaufruf, deterministisch).
///
/// Funktionsweise: Es liegt eine Verletzung vor, wenn ein *expliziter* sexueller
/// Marker UND ein Minderjährigkeits-Hinweis (Kind-Wort oder Altersangabe < 18)
/// nah beieinander stehen. Damit bleiben unbedenkliche Fälle unberührt – ein Kind
/// kommt in einer nicht-sexuellen Szene vor ODER eine rein erwachsene erotische
/// Szene. Häufige harmlose Wendungen (Kinderwunsch, „wie ein Baby“, spielende
/// Kinder, „junge Frau“) sind über eine Ausnahmeliste vom Block ausgenommen.
///
/// Grenzen (bewusst): Eine Schlagwort-Heuristik kann nicht jede Umschreibung
/// erkennen; sie ist eine harte Sperre ZUSÄTZLICH zu den Schutzmechanismen des
/// Sprachmodells, kein vollständiger Ersatz. Im Zweifel wird zugunsten der
/// Sicherheit blockiert (und als Bericht markiert) statt gespeichert.
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

        // Bereiche, in denen ein Kind-Wort harmlos ist (Kinderwunsch, Vergleiche …).
        let benign = regexRanges(benignPattern, in: lower)
        func inBenign(_ pos: Int) -> Bool { benign.contains { $0.lower <= pos && pos <= $0.upper } }

        // a) Minderjährigkeits-Wort (ohne harmlosen Kontext) nahe einem sexuellen Marker.
        let minor = regexOffsets(minorPattern, in: lower).filter { !inBenign($0) }
        if minor.contains(where: { m in sexual.contains { abs($0 - m) <= proximity } }) {
            return "sexueller Kontext nahe Minderjährigkeits-Hinweis"
        }

        // b) Altersangabe < 18 nahe einem sexuellen Marker.
        for (offset, age) in underageAges(in: lower)
        where !inBenign(offset) && sexual.contains(where: { abs($0 - offset) <= proximity }) {
            return "Altersangabe \(age) Jahre (<18) im sexuellen Kontext"
        }

        return nil
    }

    /// true = Text darf gespeichert werden.
    static func isSafe(_ text: String) -> Bool { violation(in: text) == nil }

    // MARK: - Konfiguration

    /// Zeichen-Fenster, in dem sexueller Marker und Minderjährigkeits-Hinweis als
    /// „im selben Kontext“ gelten (~15–20 Wörter). Bewusst eng, um harmlose
    /// Erwachsenen-Szenen, in denen weiter entfernt ein Kind erwähnt wird, nicht
    /// fälschlich zu blockieren.
    private static let proximity = 110

    /// Ausgeschriebene Kind-Altersangaben (< 18) als Regex-Baustein.
    private static let writtenChildNumber =
        "(?:zwei|drei|vier|fünf|sechs|sieben|acht|neun|zehn|elf|zwölf|dreizehn|vierzehn|fünfzehn|sechzehn|siebzehn)"

    /// Explizite sexuelle Marker (Wortstämme, DE + EN). Bewusst auf eindeutig
    /// sexuelle Handlungen beschränkt – NICHT „nackt“/„küssen“ und auch nicht
    /// kontextarme Begriffe wie „Erektion“/„aroused“/„nipple“ (zu fehleranfällig).
    private static let sexualPattern: String = "(?i)(?:" + [
        "geschlechtsverkehr", "geschlechtsteil", "geschlechtsorgan",
        "hatte sex", "sex mit", "beim sex", "\\bsex\\b",
        "penis", "vagina", "schamlippen", "klitoris", "ejakul\\w*", "samenerguss",
        "orgasmus", "masturb\\w*", "penetr\\w*", "drang in (?:sie|ihn)",
        "stieß in (?:sie|ihn)", "leckte (?:ihre|seinen|ihren)", "ihre nässe",
        "stöhnte vor lust", "ritt ihn", "blies ihm", "nahm ihn in den mund",
        // EN
        "had sex", "sexual intercourse", "clitoris", "ejaculat\\w*", "orgasm",
        "masturbat\\w*", "penetrat\\w*", "blowjob", "thrust into", "fuck\\w*"
    ].joined(separator: "|") + ")"

    /// Minderjährigkeits-Hinweise (Wortgrenzen → keine Treffer in „Kindheit“ etc.).
    /// Enthält die häufigen Kind-Substantive; „junge“ nur als Substantiv (negativer
    /// Lookahead schließt „junge Frau/Mann …“ aus). „baby“/„jugendlich“ sind bewusst
    /// NICHT enthalten (in Erotik fast immer Kosename bzw. Adjektiv → zu viele
    /// Fehlalarme); echte Säuglinge deckt „säugling/kleinkind/neugeboren“ ab.
    private static let minorPattern: String = "(?i)\\b(?:" + [
        "minderjährig\\w*", "kind", "kinder", "kindes", "kindlich\\w*", "kindeskörper",
        "kleinkind\\w*", "säugling\\w*", "neugeboren\\w*", "vorschulkind\\w*",
        "grundschul\\w*", "schulkind\\w*", "kindergarten\\w*", "vorpubertär\\w*",
        "pubertierend\\w*", "halbwüchsig\\w*", "teenager", "teenie\\w*",
        // gängige Kind-Substantive
        "mädchen", "töchterchen", "söhnchen", "stieftochter", "stiefsohn",
        "tochter", "sohn", "knabe\\w*", "bub\\w*", "bübchen", "enkelin", "enkelkind",
        "nichte", "neffe", "zögling\\w*", "pflegekind\\w*", "ziehkind\\w*",
        // „der Junge“ (Substantiv), aber nicht „junge Frau/Mann/…“
        "junge(?!\\s+(?:frau|mann|männer|dame|damen|leute|menschen|paar|liebe|katze|hund|welt|garde|stars?))",
        // ausgeschriebene Altersangaben < 18
        writtenChildNumber + "jährig\\w*",
        writtenChildNumber + "\\s+jahre\\s+alt",
        // EN
        "underage", "minor", "juvenile", "pubescent", "preteen", "prepubescent",
        "schoolgirl", "schoolboy", "schoolchild", "toddler", "infant",
        "child", "children", "kids?", "young girl", "young boy", "little (?:girl|boy)"
    ].joined(separator: "|") + ")\\b"

    /// Harmlose Kontexte, in denen ein Kind-Wort NICHT als Minderjährigkeits-Hinweis
    /// zählt (Kinderwunsch, Vergleiche, spielende Kinder …).
    private static let benignPattern: String = "(?i)(?:" + [
        "gemeinsame[sn]? kind(?:er)?", "eigene[sn]? kind(?:er)?", "unser(?:e|en)? kind(?:er)?",
        "kinderwunsch", "wie ein kind", "wie ein baby", "wie ein kleines kind",
        "kind(?:er)? (?:zu )?(?:bekommen|erwarten|zeugen|wollen|kriegen|großzu|haben wollt\\w*)",
        "spielten die kinder", "kinder spiel\\w*", "spielende kinder",
        "kinder im garten", "kinder im nebenzimmer", "kinder im nebenraum",
        // EN
        "like a (?:kid|baby|child)", "wanted (?:a )?(?:child|children|kids?|baby)",
        "children playing", "kids? play\\w*", "raising (?:a )?(?:child|children|kids?)"
    ].joined(separator: "|") + ")"

    // MARK: - Heuristik-Bausteine

    /// Findet Altersangaben in Ziffern 1–17 (z.B. „14 Jahre alt“, „16-jährig“,
    /// „im Alter von 12“). Liefert (Zeichen-Offset, Alter).
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
        regexRanges(pattern, in: text).map { $0.lower }
    }

    private static func regexRanges(_ pattern: String, in text: String) -> [(lower: Int, upper: Int)] {
        guard let re = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { (lower: $0.range.location, upper: $0.range.location + $0.range.length) }
    }
}
