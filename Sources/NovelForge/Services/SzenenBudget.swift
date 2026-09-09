import Foundation

/// HARTE SCHRANKE gegen Endlosschleifen beim Schreiben einer Szene.
///
/// **Warum das existiert.** Die Produktion hatte Läufe, in denen dieselbe Szene über
/// Stunden neu geschrieben wurde: Entwurf → Gate lehnt ab → Neufassung → Gate lehnt ab →
/// Reparatur → Gate lehnt ab. Jeder einzelne Pfad hatte eine eigene kleine Obergrenze
/// (`for attempt in 1...3`), aber die PFADE ZUSAMMEN hatten keine.
///
/// Die Forschung zu „Infinite Agentic Loops“ (arXiv 2607.01641) benennt genau dieses
/// Muster als häufigste Ursache: *Retry feedback without bounds* – ein Validator schickt
/// die Ausführung zurück in einen Modellaufruf, ohne dass eine Schranke den gesamten
/// Rückkopplungspfad abdeckt. Der entscheidende Satz dort:
///
/// > Sichtbare Ausstiege, die von Modellausgaben gesteuert werden, sind keine wirksamen
/// > Schranken, weil die Fortsetzung semantisch fragil bleibt.
///
/// Übersetzt auf NovelForge: „Die Schleife endet, sobald das Modell guten Text liefert“
/// ist KEINE Schranke. Wenn das Modell den Fehler nicht beheben kann, endet sie nie.
///
/// **Die Lösung.** Ein Budget, das der Steuerung gehört, nicht dem Modell: Jede Szene hat
/// eine feste Gesamtzahl an Generierungsversuchen über ALLE Pfade hinweg. Ist sie
/// aufgebraucht, wird die beste vorhandene Fassung übernommen und der Befund als Bericht
/// gespeichert – das Buch läuft weiter. Ein fertig geschriebenes Buch mit einem
/// Stilbefund ist besser als ein Buch, das nie fertig wird.
///
/// **Zusätzlich: Fortschrittserkennung.** Liefern zwei Versuche praktisch denselben Text,
/// bringt ein dritter nichts. Das Budget wird dann sofort beendet, nicht erst nach der
/// letzten Runde. Das spart die teuersten Fälle: das Modell wiederholt sich, weil es den
/// beanstandeten Punkt nicht versteht.
struct SzenenBudget {

    /// Gesamtzahl der Modellaufrufe für EINE Szene, über Entwurf, Qualitätsneufassung,
    /// Stilreparatur, Verdichtung und Satz-Chirurgie hinweg.
    ///
    /// **Dieser Wert ist bewusst KEIN Sparmechanismus.** Vorgabe des Autors: Tokens
    /// spielen keine Rolle, die Bücher müssen gut werden. Eine Szene darf also so oft
    /// überarbeitet werden, wie sie tatsächlich besser wird.
    ///
    /// 25 ist deshalb reichlich bemessen: Der normale Fall braucht 1–2, eine schwierige
    /// Szene mit Umfangs-, Stil- und Wiederholungsreparatur etwa 6–8. Die Grenze greift
    /// erst bei einem Lauf, der sich nachweislich festgefahren hat.
    ///
    /// Die eigentliche Arbeit macht ohnehin die Stagnationserkennung darunter: Sie stoppt
    /// sofort, wenn zwei Fassungen praktisch gleich sind – also genau dann, wenn weitere
    /// Versuche nichts bringen. Das kostet nichts an Qualität, spart aber die
    /// stundenlangen Wiederholungen. Diese Zahl hier ist nur das letzte Netz, falls das
    /// Modell zwar immer neuen, aber immer wieder unbrauchbaren Text liefert.
    static let maximaleVersuche = 25

    /// Ab dieser Ähnlichkeit gelten zwei Fassungen als „kein Fortschritt“.
    ///
    /// Bewusst hoch angesetzt (0,92): Nur eine fast wortgleiche Wiederholung gilt als
    /// Stillstand. Eine echte Neufassung derselben Handlung teilt deutlich weniger
    /// Trigramme und darf weiterlaufen – auch das dient der Qualität, nicht der Ersparnis.
    static let stagnationsSchwelle = 0.92

    private(set) var verbraucht = 0
    private var letzteFassung: String?
    private(set) var stagniert = false

    /// Schlüssel nur für Diagnose/Telemetrie.
    let kapitel: Int
    let szene: Int

    init(kapitel: Int, szene: Int) {
        self.kapitel = kapitel
        self.szene = szene
    }

    var verbleibend: Int { max(0, Self.maximaleVersuche - verbraucht) }

    /// Darf noch ein Modellaufruf für diese Szene erfolgen?
    ///
    /// Diese Prüfung liegt bewusst VOR dem Aufruf und wird von der Steuerung ausgewertet –
    /// nicht vom Modell. Das ist der Unterschied zwischen einer Schranke und einer Bitte.
    var darfWeiter: Bool { verbleibend > 0 && !stagniert }

    /// Einen Versuch verbuchen und auf Stagnation prüfen.
    ///
    /// - Parameter fassung: der gerade erzeugte Text; `nil` bei einem Fehlversuch
    ///   (Netzwerk, leere Antwort). Auch ein Fehlversuch kostet Budget, sonst hätte ein
    ///   dauerhaft fehlschlagender Provider wieder keine Schranke.
    mutating func verbuche(fassung: String?) {
        verbraucht += 1
        guard let neu = fassung, !neu.isEmpty else { return }
        if let alt = letzteFassung, Self.aehnlichkeit(alt, neu) >= Self.stagnationsSchwelle {
            stagniert = true
        }
        letzteFassung = neu
    }

    /// Klartext für Bericht und Telemetrie.
    var abbruchGrund: String? {
        if stagniert {
            return "Zwei Fassungen waren praktisch identisch – weitere Versuche bringen nichts. "
                + "Beste vorhandene Fassung übernommen (K\(kapitel)/S\(szene), \(verbraucht) Versuche)."
        }
        if verbleibend == 0 {
            return "Versuchsbudget der Szene aufgebraucht (\(Self.maximaleVersuche) Versuche, "
                + "K\(kapitel)/S\(szene)). Beste vorhandene Fassung übernommen, Befund bleibt offen."
        }
        return nil
    }

    /// Ähnlichkeit zweier Fassungen über gemeinsame Wort-Trigramme (Jaccard).
    ///
    /// Bewusst nicht zeichengenau: Eine Neufassung, die nur Kommas verschiebt, soll als
    /// „kein Fortschritt“ gelten. Eine echte Neufassung teilt dagegen deutlich weniger
    /// Trigramme, selbst wenn sie dieselbe Handlung erzählt.
    static func aehnlichkeit(_ a: String, _ b: String) -> Double {
        let ta = trigramme(a), tb = trigramme(b)
        guard !ta.isEmpty, !tb.isEmpty else { return 0 }
        let schnitt = ta.intersection(tb).count
        let vereinigung = ta.union(tb).count
        return vereinigung == 0 ? 0 : Double(schnitt) / Double(vereinigung)
    }

    private static func trigramme(_ text: String) -> Set<String> {
        let woerter = text.lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        guard woerter.count >= 3 else { return [] }
        var ergebnis = Set<String>()
        for i in 0...(woerter.count - 3) {
            ergebnis.insert(woerter[i...(i + 2)].joined(separator: " "))
        }
        return ergebnis
    }
}
