import Foundation

/// DER FAHRPLAN DES GEGENSPIELERS – das fehlende Rückgrat über 500 Seiten.
///
/// **Was gefehlt hat.** Die Figurenliste kennt den Antagonisten: Name, Ziel, Angst,
/// Schwäche. Der Draft-Prompt fordert „DER ANTAGONIST HANDELT". Aber nichts legte fest,
/// *was er tut, während die Hauptfigur woanders ist*. Die Folge ist in jedem langen Buch
/// dieselbe: Widerstand entsteht nur dann, wenn eine Szene ihn vorsieht. Der Gegner wartet
/// zwischen seinen Auftritten. Ein Roman spannt sich aber genau daran, dass der Gegner
/// weiterarbeitet, während man wegsieht – der Leser weiß mehr als die Figur, und daraus
/// entsteht der Druck, der 500 Seiten trägt.
///
/// **Warum eine Anweisung dafür nicht reicht.** Der Prompt bittet seit Langem um einen
/// aktiven Antagonisten. Gemessen an den ausgelieferten Büchern hat das nicht gereicht –
/// dieselbe Erfahrung wie bei der Namenssperre („Liv" stand 263-mal im Buch, obwohl die
/// Figurenliste andere Namen nannte) und beim Bilder-Limit (7,5 statt der geforderten
/// 0,4). Eine Anweisung ohne Struktur dahinter ist eine Bitte. Der Fahrplan ist die
/// Struktur: Er wird einmal geplant, gespeichert und dem Schreiber Kapitel für Kapitel
/// als Tatsache vorgelegt, nicht als Wunsch.
///
/// **Wo er liegt.** In `StoryBible.timeline` – einem Feld, das nirgends gelesen wurde
/// (geprüft: null Verwendungen). Dasselbe Vorgehen wie beim Erzähltakt in
/// `StoryScene.emotionalChange` und beim Preis in `newInformation`: ein vorhandenes,
/// ungenutztes Feld belegen statt das Schema zu migrieren. Die vorhandenen Bücher bleiben
/// unangetastet, alte Titel ohne Fahrplan laufen unverändert weiter.
struct Gegenspieler {

    /// Ein Zug des Gegenspielers – etwas, das er tut, ohne dass die Hauptfigur es auslöst.
    struct Zug: Equatable {
        /// Ab welchem Kapitel dieser Zug wirkt.
        let abKapitel: Int
        /// Was er tut. Eine Handlung, kein Zustand.
        let handlung: String
        /// Woran die Hauptfigur es merkt – oder was sie übersieht.
        let spur: String

        var klartext: String {
            spur.isEmpty ? handlung : "\(handlung) — spürbar an: \(spur)"
        }
    }

    private(set) var zuege: [Zug] = []

    init(zuege: [Zug] = []) {
        self.zuege = zuege.sorted { $0.abKapitel < $1.abKapitel }
    }

    // MARK: - Lesen und Schreiben

    /// Zeilenformat: `GEGENZUG|abKapitel|Handlung|Spur`
    ///
    /// Dasselbe Format wie `SZENE|` und `FIGUR|`, damit derselbe Parser-Stil gilt und der
    /// Plot-Agent nichts Neues lernen muss.
    static func parse(_ text: String) -> Gegenspieler {
        var gefunden: [Zug] = []
        for zeile in text.components(separatedBy: .newlines) {
            let z = zeile.trimmingCharacters(in: .whitespaces)
            guard z.uppercased().hasPrefix("GEGENZUG|") else { continue }
            let felder = z.dropFirst("GEGENZUG|".count)
                .components(separatedBy: "|")
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard felder.count >= 2 else { continue }
            let kapitelFeld = felder[0]
            let kapitel = Int(kapitelFeld) ?? {
                let folded = kapitelFeld.folding(
                    options: [.caseInsensitive, .diacriticInsensitive], locale: .current
                ).lowercased()
                guard folded.hasPrefix("abkapitel") else { return nil }
                return Int(kapitelFeld.filter(\.isNumber))
            }()
            guard let kapitel else { continue }
            let handlung = felder[1]
            guard handlung.wordCount >= 3 else { continue }
            gefunden.append(Zug(abKapitel: max(1, kapitel),
                                handlung: handlung,
                                spur: felder.count > 2 ? felder[2] : ""))
        }
        return Gegenspieler(zuege: gefunden)
    }

    /// Serialisiert für die Ablage in `StoryBible.timeline`.
    var gespeichert: String {
        zuege.map { "GEGENZUG|\($0.abKapitel)|\($0.handlung)|\($0.spur)" }
            .joined(separator: "\n")
    }

    // MARK: - Abfragen

    var istLeer: Bool { zuege.isEmpty }

    /// Der Zug, der in diesem Kapitel wirkt – der letzte, der bereits begonnen hat.
    func zug(fuerKapitel kapitel: Int) -> Zug? {
        zuege.last { $0.abKapitel <= kapitel }
    }

    /// Was der Gegenspieler bis hierher getan hat – für die Kapitelplanung.
    ///
    /// Ohne diese Rückschau plant das Modell den nächsten Zug unabhängig vom letzten, und
    /// der Gegner tut dreimal dasselbe mit anderen Worten.
    func bisherigeZuege(vorKapitel kapitel: Int) -> [Zug] {
        zuege.filter { $0.abKapitel < kapitel }
    }

    /// Der Block für den Schreib-Prompt.
    ///
    /// Bewusst als Tatsache formuliert und mit der ausdrücklichen Erlaubnis, dass die
    /// Hauptfigur nichts davon mitbekommt. Ohne diesen Zusatz baut das Modell den Gegenzug
    /// in jede Szene als sichtbares Ereignis ein – dann ist der Gegner wieder nur da, wenn
    /// die Szene ihn zeigt, und der Druck im Hintergrund entsteht erneut nicht.
    func promptBlock(fuerKapitel kapitel: Int) -> String {
        guard let zug = zug(fuerKapitel: kapitel) else { return "" }
        var text = """

        WÄHREND SIE DAS TUT (Gegenspieler, läuft unabhängig weiter):
        \(zug.handlung)
        """
        if !zug.spur.isEmpty {
            text += "\nSpur davon in dieser Szene: \(zug.spur)"
        }
        text += """

        Das geschieht, ob die Hauptfigur davon weiß oder nicht. Erkläre es nicht und zeige \
        es nicht als eigene Szene. Es darf durchscheinen — eine Nachricht, die niemand \
        geschrieben haben will, ein Termin, der plötzlich vorgezogen ist, jemand, der \
        gestern noch anders geantwortet hätte. Höchstens ein Detail; oft ist gar keines \
        besser als ein deutliches.
        """
        return text
    }

    // MARK: - Prüfen

    /// Mängel des Fahrplans – gemeldet, bevor das Buch geschrieben wird.
    ///
    /// - Parameter kapitelAnzahl: Länge des Buches; bestimmt, wie viele Züge nötig sind.
    func maengel(kapitelAnzahl: Int) -> [String] {
        guard kapitelAnzahl > 0 else { return [] }
        var befunde: [String] = []

        // Wie viele Züge braucht ein Buch? Einer je fünf Kapitel, mindestens drei.
        //
        // Fünf ist kein runder Zufallswert: Bei der Standardplanung (2500 Wörter je
        // Kapitel) sind fünf Kapitel rund 50 Druckseiten. Länger als 50 Seiten darf der
        // Gegner nicht stillstehen, sonst zerfällt das Buch in Episoden. Drei ist die
        // Untergrenze, unter der es keine Steigerung gibt, sondern nur Anfang und Ende.
        let noetig = max(3, kapitelAnzahl / 5)
        if zuege.count < noetig {
            befunde.append("Der Gegenspieler hat nur \(zuege.count) Züge für \(kapitelAnzahl) "
                + "Kapitel geplant (nötig: \(noetig)). Zwischen seinen Zügen steht die "
                + "Handlung still.")
        }

        // WIEDERKEHRENDE WÖRTER ZÄHLEN NICHT MIT.
        //
        // Ein Fehlalarm aus der Prüfdatei: „Er setzt Ines' Beurteilung herab" und „Er lässt
        // Marit auf Ines ansetzen" galten als Wiederholung. Zwei verschiedene Handlungen –
        // die Ähnlichkeit kam aus „Ines", dem Namen der Hauptfigur, der naturgemäß in JEDEM
        // Zug des Gegenspielers steht. Ein Wort, das überall vorkommt, unterscheidet nichts.
        //
        // Deshalb fliegt raus, was in mehr als der Hälfte aller Züge auftaucht: Figuren-
        // und Ortsnamen, der Gegenspieler selbst, wiederkehrende Requisiten. Das braucht
        // keine Namensliste von außen und wirkt auch bei Namen, die niemand vorhersehen
        // konnte – dasselbe Prinzip wie bei `verliebteWoerter`.
        let haeufigkeit = zuege
            .flatMap { EreignisRegister.inhaltswoerter($0.handlung) }
            .reduce(into: [String: Int]()) { $0[$1, default: 0] += 1 }
        //
        // Die zusätzliche Bedingung „mindestens drei Vorkommen" ist nicht kosmetisch: Ohne
        // sie verdeckt sich eine echte Wiederholung selbst. Bei drei Zügen sind zwei
        // Vorkommen bereits „mehr als die Hälfte" – ein doppelter Zug erklärt damit seine
        // eigenen Wörter für allgegenwärtig, beide Kerne werden leer, und die Dopplung
        // fällt durch. Genau das hat die Prüfdatei gefunden.
        let allgegenwaertig = Set(haeufigkeit
            .filter { $0.value >= 3 && $0.value * 2 > zuege.count }
            .keys)

        // Kein Zug darf einen anderen wiederholen: Zweimal dasselbe heißt, der Gegner ist
        // nicht vorangekommen – und dann war das Kapitel dazwischen folgenlos.
        func handlungsKern(_ text: String) -> Set<String> {
            EreignisRegister.inhaltswoerter(text).subtracting(allgegenwaertig)
        }
        for (i, zug) in zuege.enumerated() {
            let kern = handlungsKern(zug.handlung)
            guard kern.count >= 2 else { continue }
            for frueher in zuege.prefix(i) {
                let wert = EreignisRegister.uebereinstimmung(
                    handlungsKern(frueher.handlung), kern)
                if wert >= EreignisRegister.dopplungsSchwelle {
                    befunde.append("Zug ab Kapitel \(zug.abKapitel) wiederholt den Zug ab "
                        + "Kapitel \(frueher.abKapitel) („\(frueher.handlung)“).")
                    break
                }
            }
        }

        // Der letzte Zug muss in die zweite Buchhälfte fallen. Ein Gegner, der nach zwei
        // Dritteln fertig ist, überlässt das Finale dem Zufall.
        if let letzter = zuege.last, letzter.abKapitel < kapitelAnzahl / 2 {
            befunde.append("Der letzte Zug liegt in Kapitel \(letzter.abKapitel) von "
                + "\(kapitelAnzahl). Im ganzen letzten Buchteil unternimmt der Gegenspieler "
                + "nichts mehr.")
        }

        // Die größte Lücke: Wo steht der Gegner am längsten still?
        if zuege.count >= 2 {
            var groessteLuecke = 0
            var luekenStart = 0
            for (a, b) in zip(zuege, zuege.dropFirst()) {
                let luecke = b.abKapitel - a.abKapitel
                if luecke > groessteLuecke { groessteLuecke = luecke; luekenStart = a.abKapitel }
            }
            if groessteLuecke > max(6, kapitelAnzahl / 4) {
                befunde.append("Zwischen Kapitel \(luekenStart) und "
                    + "\(luekenStart + groessteLuecke) tut der Gegenspieler \(groessteLuecke) "
                    + "Kapitel lang nichts.")
            }
        }

        return befunde
    }
}
