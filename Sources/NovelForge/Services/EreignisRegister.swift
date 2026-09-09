import Foundation

/// BUCHWEITES GEDÄCHTNIS DAFÜR, WAS SCHON ERZÄHLT WURDE.
///
/// **Das Problem.** Der Schreib-Loop kannte bisher nur zwei Gedächtnisse: die letzten
/// Sätze der Vorszene (für den Anschluss) und `repeatedSentenceCollisions` (für wörtliche
/// Dopplungen). Beides arbeitet auf Satzebene. Auf Ereignisebene war das Buch blind:
/// Kapitel 9 konnte „Mira öffnet die Bienenstöcke und wird von der Polizei abgewiesen"
/// erzählen, obwohl genau das in Kapitel 3 schon stand — mit anderen Worten, also für jede
/// Satzprüfung unsichtbar. Für den Leser ist es dieselbe Szene ein zweites Mal.
///
/// **Die Forschung.** FACTTRACK (arXiv 2407.16347) beschreibt für lange generierte Texte
/// genau dieses Verfahren: atomare Fakten mit Gültigkeitsintervall statt eines
/// Volltext-Kontexts. Ein Ereignis wird einmal erzählt und ist danach *Vergangenheit*.
/// Darauf darf später verwiesen werden (Erinnerung, Gespräch, Konsequenz) — es darf nur
/// nicht ein zweites Mal als neu passieren.
///
/// **Warum auf dem Plan und nicht auf der Prosa.** Die Prosa müsste erst interpretiert
/// werden, das ginge nur mit einem Modellaufruf — teuer, unzuverlässig und wieder eine
/// Schleife. Der Szenenplan ist bereits strukturiert (`PlannedScene`: Perspektive, Ort,
/// Ziel, Hindernis, Wendung). Dort ist die Dopplung deterministisch messbar, und zwar
/// BEVOR ein einziges Wort geschrieben wurde. Das folgt der Projektregel: Prävention im
/// Prompt schlägt Reparatur danach.
///
/// **Zwei Wirkungen:**
/// 1. `dopplungen(...)` meldet doppelte Szenenpläne als Befund, bevor produziert wird.
/// 2. `bereitsErzaehltHinweis(...)` gibt dem Draft Writer eine kurze Liste dessen, was
///    schon passiert ist — damit er darauf verweisen kann, statt es neu zu erzählen.
struct EreignisRegister {

    /// Ein erzähltes Ereignis, reduziert auf das, was es identifizierbar macht.
    struct Ereignis: Equatable {
        let kapitel: Int
        let szene: Int
        /// Wessen Perspektive – dasselbe Ereignis aus zwei Perspektiven ist zulässig
        /// und in Mehrperspektiv-Romanen sogar ein Stilmittel.
        let figur: String
        let ort: String
        /// Klartext für Bericht und Prompt („Mira will die Stöcke öffnen → sie wird abgewiesen").
        let beschreibung: String
        /// Normalisierte Inhaltswörter aus Ziel + Hindernis + Wendung.
        let kern: Set<String>

        var kurz: String { "K\(kapitel)/S\(szene): \(beschreibung)" }
    }

    /// Ab dieser Übereinstimmung der Inhaltswörter gilt ein Ereignis als schon erzählt.
    ///
    /// **Gemessen, nicht geschätzt.** `Scripts/EreignisProbe.swift` rechnet den Wert bei
    /// jedem Lauf neu über sechs Szenenpaare – drei inhaltlich identische, anders
    /// formulierte, und drei verwandte, aber verschiedene. Ergebnis:
    ///
    /// | Gruppe | gemessen |
    /// |---|---|
    /// | Dopplung, andere Wörter | 0,50 |
    /// | Dopplung, Reihenfolge getauscht | 0,75 |
    /// | Dopplung, Synonyme | 0,71 |
    /// | verschieden: suchen vs. finden | 0,22 |
    /// | verschieden: gleicher Ort, andere Handlung | 0,00 |
    /// | verschieden: gleiche Figur, späterer Konflikt | 0,15 |
    ///
    /// 0,40 liegt mit 0,18 Abstand über der höchsten echten Verschiedenheit und mit 0,10
    /// unter der schwächsten echten Dopplung. Der erste Kalibrierungslauf ergab noch 0,33
    /// für die erste Zeile – zu wenig; die Ursache lag im Vergleich, nicht in der Schwelle
    /// (siehe `passen`).
    ///
    /// **Grenze der Kalibrierung:** sechs Paare sind eine Trennschärfe-Prüfung, kein
    /// Referenzband. Ein Treffer ist deshalb ein Bericht und ein Prompt-Hinweis, keine
    /// harte Sperre – nach Projektregel 3.
    static let dopplungsSchwelle = 0.40

    private(set) var ereignisse: [Ereignis] = []

    init() {}

    // MARK: - Erfassen

    /// Eine geplante Szene ins Register aufnehmen.
    ///
    /// Nachklang-Takte werden bewusst NICHT erfasst: Ein Nachklang verarbeitet das
    /// Ereignis der Vorszene, er ist selbst keines. Würde man ihn aufnehmen, meldete das
    /// Register die korrekte Scene-&-Sequel-Struktur als Dopplung — der klassische Fall,
    /// in dem eine Prüfung genau das bestraft, was sie fördern soll.
    mutating func erfasse(_ szene: PlannedScene, kapitel: Int) {
        guard !szene.istNachklang else { return }
        let kern = Self.inhaltswoerter(szene.goal + " " + szene.obstacle + " " + szene.turn)
        guard kern.count >= 3 else { return }   // zu dünn für eine belastbare Aussage
        ereignisse.append(Ereignis(
            kapitel: kapitel,
            szene: szene.number,
            figur: Self.normalisiert(szene.perspective),
            ort: Self.normalisiert(szene.location),
            beschreibung: Self.beschreibung(szene),
            kern: kern
        ))
    }

    // MARK: - Prüfen

    /// Gibt es zu dieser geplanten Szene schon ein erzähltes Ereignis?
    ///
    /// - Returns: das frühere Ereignis samt Übereinstimmung, sonst `nil`.
    func bereitsErzaehlt(_ szene: PlannedScene, kapitel: Int)
        -> (frueher: Ereignis, uebereinstimmung: Double)? {
        guard !szene.istNachklang else { return nil }
        let kern = Self.inhaltswoerter(szene.goal + " " + szene.obstacle + " " + szene.turn)
        guard kern.count >= 3 else { return nil }
        let figur = Self.normalisiert(szene.perspective)

        var bester: (Ereignis, Double)?
        for e in ereignisse {
            // Sich selbst nicht mit sich vergleichen.
            if e.kapitel == kapitel && e.szene == szene.number { continue }
            // Dasselbe Geschehen aus zwei Perspektiven ist erlaubt und gewollt.
            guard e.figur == figur else { continue }
            let wert = Self.uebereinstimmung(e.kern, kern)
            guard wert >= Self.dopplungsSchwelle else { continue }
            if bester == nil || wert > bester!.1 { bester = (e, wert) }
        }
        guard let treffer = bester else { return nil }
        return (treffer.0, treffer.1)
    }

    /// Alle Dopplungen im Plan eines ganzen Buches – in Planreihenfolge geprüft.
    ///
    /// Läuft VOR der Produktion. Was hier gemeldet wird, kostet noch keinen Modellaufruf.
    static func dopplungen(imBuchplan plan: [(kapitel: Int, szenen: [PlannedScene])])
        -> [(kapitel: Int, szene: Int, meldung: String)] {
        var register = EreignisRegister()
        var befunde: [(Int, Int, String)] = []
        for (kapitel, szenen) in plan {
            for szene in szenen {
                if let (frueher, wert) = register.bereitsErzaehlt(szene, kapitel: kapitel) {
                    let prozent = Int((wert * 100).rounded())
                    befunde.append((kapitel, szene.number,
                        "Dieses Ereignis steht schon in \(frueher.kurz) "
                        + "(\(prozent) % Übereinstimmung). Entweder die Szene bekommt ein "
                        + "eigenes Ziel, oder sie wird zum Nachklang, der auf das frühere "
                        + "Ereignis zurückblickt."))
                } else {
                    register.erfasse(szene, kapitel: kapitel)
                }
            }
        }
        return befunde
    }

    /// Findet laengere Plansequenzen, die trotz anderer Formulierungen dieselbe
    /// dramatische Funktion am selben Schauplatz wiederholen.
    ///
    /// Ein gleicher Ort allein ist kein Fehler: Ein Familienroman kann drei Kapitel
    /// lang im selben Haus spielen. Problematisch wird erst die Kombination aus
    /// demselben Ortskern und derselben Funktion in mindestens drei fortlaufenden
    /// Kapiteln, etwa dreimal Tunnel + Flucht/Verfolgung. Genau dieses Muster blieb
    /// fuer die normale Ereignis-Aehnlichkeit unsichtbar, weil Handy, Abzweig und Name
    /// die einzelnen Szenen oberflaechlich verschieden machten.
    static func stagnierendeSequenzen(
        imBuchplan plan: [(kapitel: Int, szenen: [PlannedScene])]
    ) -> [String] {
        struct KapitelSignatur {
            let nummer: Int
            let orte: Set<String>
            let funktionen: Set<String>
        }

        let ortStop: Set<String> = [
            "derselbe", "dieselbe", "dasselbe", "gleich", "gleiche", "gleichen",
            "nahe", "naeher", "innenraum", "eingang", "bereich", "abschnitt",
            "abgeschaltet", "abgeschalteter", "verlassen", "verlassener",
        ]
        func ortskern(_ text: String) -> Set<String> {
            Set(inhaltswoerter(text).filter { !ortStop.contains($0) && $0.count >= 4 })
        }
        func funktionen(_ text: String) -> Set<String> {
            let t = normalisiert(text)
            let familien: [(String, [String])] = [
                ("Flucht/Verfolgung", ["flieh", "flucht", "entkomm", "verfolg", "versteck"]),
                ("Suche/Fund", ["such", "find", "entdeck", "spur"]),
                ("Beobachtung", ["beobacht", "ueberwach", "beschatt"]),
                ("Verhoer/Konfrontation", ["konfront", "befrag", "verhoer", "zur rede", "gesteh"]),
                ("Einbruch/Zugang", ["einbr", "bricht ein", "oeffnet", "zugang", "schluessel"]),
                ("Rettung/Schutz", ["rett", "schuetz", "beschuetz"]),
            ]
            return Set(familien.compactMap { name, marker in
                marker.contains(where: t.contains) ? name : nil
            })
        }

        let signaturen = plan.sorted { $0.kapitel < $1.kapitel }.compactMap { eintrag -> KapitelSignatur? in
            let szenen = eintrag.szenen.filter { !$0.istNachklang }
            let orte = szenen.reduce(into: Set<String>()) { result, szene in
                result.formUnion(ortskern(szene.location))
            }
            let funktionen = funktionen(
                szenen.map { $0.goal + " " + $0.obstacle + " " + $0.turn }
                    .joined(separator: " ")
            )
            guard !orte.isEmpty, !funktionen.isEmpty else { return nil }
            return KapitelSignatur(nummer: eintrag.kapitel, orte: orte,
                                   funktionen: funktionen)
        }
        guard signaturen.count >= 3 else { return [] }

        var befunde: [String] = []
        for index in 0...(signaturen.count - 3) {
            let fenster = Array(signaturen[index...(index + 2)])
            guard fenster[1].nummer == fenster[0].nummer + 1,
                  fenster[2].nummer == fenster[1].nummer + 1 else { continue }
            let gemeinsameOrte = fenster.dropFirst().reduce(fenster[0].orte) {
                $0.intersection($1.orte)
            }
            let gemeinsameFunktionen = fenster.dropFirst().reduce(fenster[0].funktionen) {
                $0.intersection($1.funktionen)
            }
            guard !gemeinsameOrte.isEmpty, !gemeinsameFunktionen.isEmpty else { continue }
            let meldung = "Kapitel \(fenster[0].nummer)-\(fenster[2].nummer) wiederholen "
                + gemeinsameFunktionen.sorted().joined(separator: ", ")
                + " am selben Schauplatzkern ("
                + gemeinsameOrte.sorted().prefix(3).joined(separator: ", ") + ")."
            if !befunde.contains(meldung) { befunde.append(meldung) }
        }
        return befunde
    }

    // MARK: - Prompt

    /// Kurze Liste dessen, was bereits passiert ist – für den Draft-Prompt.
    ///
    /// Bewusst knapp gehalten (Standard: die letzten acht Ereignisse derselben Figur).
    /// Eine vollständige Liste aller 250 Szenen wäre Kontext-Ballast; entscheidend ist,
    /// dass das Modell die zuletzt erzählten Ereignisse als *erledigt* sieht.
    func bereitsErzaehltHinweis(fuer figur: String, hoechstens: Int = 8) -> String {
        let gesucht = Self.normalisiert(figur)
        let passend = ereignisse.filter { $0.figur == gesucht }.suffix(hoechstens)
        guard !passend.isEmpty else { return "" }
        let zeilen = passend.map { "- \($0.beschreibung)" }.joined(separator: "\n")
        return """
        BEREITS ERZÄHLT (nicht noch einmal erzählen):
        \(zeilen)

        Diese Ereignisse sind vorbei. Die Figur darf sich daran erinnern, darüber sprechen
        oder mit den Folgen leben. Sie dürfen nicht erneut als Geschehen der Gegenwart
        stattfinden. Diese Szene bringt etwas Neues.
        """
    }

    // MARK: - Rechnen

    /// Dice-Koeffizient über Inhaltswörter: 2·Treffer / (|A|+|B|).
    ///
    /// Für kurze Phrasen deutlich stabiler als Jaccard: Bei fünf gemeinsamen von je acht
    /// Wörtern ergibt Dice 0,63, Jaccard nur 0,45 – Jaccard bestraft die Länge doppelt und
    /// bräuchte eine so niedrige Schwelle, dass Zufallstreffer durchkommen.
    ///
    /// Gezählt wird nicht die Mengenschnittmenge, sondern eine Paarung nach `passen`:
    /// Jedes Wort aus A darf höchstens einen Partner in B binden. Ohne diese Einschränkung
    /// würde ein Kompositum wie „Polizeiabsperrung" gleichzeitig „Polizei" und „Absperrung"
    /// bedienen und die Übereinstimmung künstlich heben.
    static func uebereinstimmung(_ a: Set<String>, _ b: Set<String>) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        // Lange Wörter zuerst paaren: Sie sind die spezifischeren und sollen nicht von
        // einem kurzen, unspezifischen Wort weggeschnappt werden.
        var frei = b
        var treffer = 0
        for wort in a.sorted(by: { $0.count > $1.count }) {
            guard let partner = frei.first(where: { passen(wort, $0) }) else { continue }
            frei.remove(partner)
            treffer += 1
        }
        return 2.0 * Double(treffer) / Double(a.count + b.count)
    }

    /// Bezeichnen zwei Wörter dieselbe Sache?
    ///
    /// Der naive Vergleich (Gleichheit oder feste Stammkürzung) scheitert am Deutschen,
    /// und zwar messbar: Beim ersten Kalibrierungslauf kam die inhaltlich identische Szene
    /// „Sie will die Bienenstöcke öffnen / Polizei hat abgesperrt / sie wird abgewiesen"
    /// gegen ihre Umformulierung nur auf 0,33 – unter jeder brauchbaren Schwelle. Grund
    /// waren zwei Eigenheiten der Sprache:
    ///
    /// - **Komposita.** „Bienenstöcke" und „Stöcke" sind verschiedene Zeichenketten, meinen
    ///   aber dasselbe Ding. Deshalb: Steckt das kürzere Wort (ab vier Zeichen) im längeren,
    ///   gilt es als Treffer.
    /// - **Flexion.** „öffnen/öffnet", „verschlossen/verschlossene", „Polizei/
    ///   Polizeiabsperrung" unterscheiden sich nur am Ende. Deshalb: vier gemeinsame
    ///   Anfangszeichen genügen.
    ///
    /// Vier Zeichen sind die Untergrenze, an der das noch trennt: Bei drei fielen „Schuppen",
    /// „Schlüssel" und „Schwester" über das gemeinsame „sch" zusammen.
    static func passen(_ x: String, _ y: String) -> Bool {
        if x == y { return true }
        let kurz = x.count <= y.count ? x : y
        let lang = x.count <= y.count ? y : x
        guard kurz.count >= 4 else { return false }
        if gemeinsamerAnfang(kurz, lang) >= 4 { return true }
        // Kompositum: ohne die Flexionsendung des kurzen Worts suchen.
        return lang.contains(kurz.dropLast())
    }

    private static func gemeinsamerAnfang(_ a: String, _ b: String) -> Int {
        var n = 0
        for (x, y) in zip(a, b) {
            if x != y { break }
            n += 1
        }
        return n
    }

    /// Inhaltswörter: klein, ohne Diakritika, ohne Funktionswörter.
    ///
    /// Bewusst NICHT auf eine feste Länge gekürzt. Eine Kürzung auf sechs Zeichen wirkt wie
    /// ein Stemmer, zerstört aber genau die Information, die `passen` für Komposita
    /// braucht: Aus „Bienenstöcke" würde „bienen", und die Verwandtschaft zu „Stöcke" wäre
    /// nicht mehr sichtbar.
    static func inhaltswoerter(_ text: String) -> Set<String> {
        let roh = text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { $0.count >= 3 }
        var ergebnis = Set<String>()
        for wort in roh {
            let klein = wort.lowercased()
            guard !funktionswoerter.contains(klein) else { continue }
            ergebnis.insert(klein)
        }
        return ergebnis
    }

    /// Wörter ohne Aussagekraft für die Frage „ist das dasselbe Ereignis?".
    ///
    /// Ohne diese Liste bestünde die Schnittmenge zweier beliebiger Szenenziele zur Hälfte
    /// aus „sie", „wird", „einen" – jedes Ereignispaar läge dann über der Schwelle.
    private static let funktionswoerter: Set<String> = [
        "der", "die", "das", "den", "dem", "des", "ein", "eine", "einen", "einem", "einer",
        "eines", "und", "oder", "aber", "doch", "denn", "sondern", "als", "wie", "dass",
        "weil", "damit", "wenn", "obwohl", "sich", "ihr", "ihre", "ihren", "ihrem", "ihres",
        "sein", "seine", "seinen", "seinem", "seines", "mit", "ohne", "aus", "auf", "vom",
        "von", "zum", "zur", "bei", "nach", "vor", "ueber", "unter", "durch", "gegen",
        "fuer", "ist", "sind", "war", "waren", "hat", "habe", "haben", "hatte", "hatten",
        "wird", "werden", "wurde", "wurden", "will", "wollen", "wollte", "kann", "koennen",
        "konnte", "muss", "muessen", "musste", "soll", "sollen", "sollte", "darf", "duerfen",
        "nicht", "kein", "keine", "keinen", "noch", "schon", "nur", "auch", "sehr", "mehr",
        "dann", "dort", "hier", "wieder", "immer", "etwas", "alles", "nichts", "man", "ihm",
        "ihn", "sie", "sich", "wir", "uns", "euch", "ihnen", "dieser", "diese", "dieses",
        "dabei", "dazu", "damit", "davon", "daran", "darauf",
    ]

    private static func normalisiert(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    private static func beschreibung(_ szene: PlannedScene) -> String {
        let ziel = szene.goal.trimmingCharacters(in: .whitespaces)
        let wendung = szene.turn.trimmingCharacters(in: .whitespaces)
        if ziel.isEmpty && wendung.isEmpty { return szene.location }
        if wendung.isEmpty || wendung == "-" { return ziel }
        if ziel.isEmpty || ziel == "-" { return wendung }
        return "\(ziel) → \(wendung)"
    }
}
