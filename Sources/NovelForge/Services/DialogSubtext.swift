import Foundation

/// MESSUNG DES SUBTEXTS IM DIALOG.
///
/// **Warum das der wichtigste Dialogbefund ist.** Alle bisherigen Dialogprüfungen im
/// Projekt messen *Menge* und *Form*: `dialoganteil` zählt, wie viel gesprochen wird,
/// `dialogOhneAnfuehrungszeichen` prüft die Auszeichnung, `parseDialogueVoiceVerdicts`
/// lässt ein Modell über eigene Stimmen urteilen. Keine davon misst, ob überhaupt Subtext
/// da ist – und genau daran erkennt man KI-Dialog auf den ersten Blick:
///
/// > „Wo warst du gestern Abend?"
/// > „Ich war bei Thomas."
///
/// Jede Frage bekommt ihre Antwort, sofort, vollständig, in den Worten der Frage. Das ist
/// kein Gespräch, das ist ein Verhörprotokoll. Menschen antworten anders: Sie weichen aus,
/// stellen eine Gegenfrage, überhören, wechseln das Thema, antworten auf etwas, das gar
/// nicht gefragt war. Der Abstand zwischen dem, was gefragt, und dem, was geantwortet
/// wird, IST der Subtext – und damit die Spannung.
///
/// **Was gemessen wird.** Der Anteil der Fragen, die direkt beantwortet werden. Über 70 %
/// liest sich wie ein Protokoll. Unter 20 % wird es beliebig: Wenn niemand je auf etwas
/// eingeht, verliert der Leser den Faden.
///
/// **Warum deterministisch und nicht per Modell.** Ein Modellaufruf pro Szene wäre ein
/// weiterer Rückkopplungspfad – und die Projektgeschichte kennt genug davon. Diese Messung
/// kostet nichts, läuft überall, und ihr Ergebnis ist zwischen zwei Läufen identisch.
enum DialogSubtext {

    /// Ab diesem Anteil direkter Antworten liest sich der Dialog wie ein Verhör.
    ///
    /// Der Wert stammt nicht aus dem Nichts: Er steht als Handwerksregel in der
    /// Projekt-CLAUDE.md („über 70 % direkte Antworten auf die Vorfrage =
    /// Verhörprotokoll") und deckt sich mit der gängigen Lektoratsfaustregel, dass etwa
    /// jede dritte Frage im Roman unbeantwortet oder schräg beantwortet bleiben soll.
    static let verhoerSchwelle = 0.70

    /// Unter diesem Anteil redet niemand mehr miteinander.
    ///
    /// Die Gegenrichtung wird bewusst mitgemessen. Eine Prüfung, die nur „zu direkt"
    /// kennt, treibt das Modell ins andere Extrem: Wenn keine Frage je beantwortet wird,
    /// entsteht kein Subtext, sondern Beliebigkeit.
    static let beliebigkeitsSchwelle = 0.20

    /// Ab so vielen Fragen ist der Anteil überhaupt aussagekräftig.
    ///
    /// Bei zwei Fragen entscheidet eine einzige Antwort über 50 Prozentpunkte. Solche
    /// Zahlen als Befund zu melden wäre Rauschen, das wie ein Ergebnis aussieht.
    static let mindestFragen = 4

    struct Kennzahl: Equatable {
        let fragen: Int
        let direkt: Int
        var ausweichend: Int { fragen - direkt }
        var anteilDirekt: Double { fragen == 0 ? 0 : Double(direkt) / Double(fragen) }
        /// Aussagekräftig genug für einen Befund?
        var belastbar: Bool { fragen >= DialogSubtext.mindestFragen }
        var istVerhoerprotokoll: Bool { belastbar && anteilDirekt >= DialogSubtext.verhoerSchwelle }
        var istBeliebig: Bool { belastbar && anteilDirekt < DialogSubtext.beliebigkeitsSchwelle }
    }

    // MARK: - Messen

    static func messe(in text: String) -> Kennzahl {
        let paare = fragePaare(in: text)
        let direkt = paare.filter { istDirekteAntwort(auf: $0.frage, antwort: $0.antwort) }.count
        return Kennzahl(fragen: paare.count, direkt: direkt)
    }

    static func messe(inChapters kapitel: [String]) -> Kennzahl {
        var fragen = 0, direkt = 0
        for text in kapitel {
            let k = messe(in: text)
            fragen += k.fragen
            direkt += k.direkt
        }
        return Kennzahl(fragen: fragen, direkt: direkt)
    }

    /// Klartext-Befund oder `nil`, wenn der Dialog in Ordnung ist.
    static func befund(in text: String) -> String? { befund(fuer: messe(in: text)) }

    static func befund(fuer kennzahl: Kennzahl) -> String? {
        guard kennzahl.belastbar else { return nil }
        let prozent = Int((kennzahl.anteilDirekt * 100).rounded())
        if kennzahl.istVerhoerprotokoll {
            return "\(prozent) % der Fragen werden direkt beantwortet (\(kennzahl.direkt) von "
                + "\(kennzahl.fragen)). Das liest sich wie ein Verhör. Figuren weichen aus, "
                + "stellen Gegenfragen, überhören oder antworten auf etwas anderes – der "
                + "Abstand zwischen Frage und Antwort ist der Subtext."
        }
        if kennzahl.istBeliebig {
            return "Nur \(prozent) % der Fragen werden beantwortet (\(kennzahl.direkt) von "
                + "\(kennzahl.fragen)). So viel Ausweichen wirkt nicht vielschichtig, sondern "
                + "beliebig – der Leser verliert den Faden des Gesprächs."
        }
        return nil
    }

    // MARK: - Paare finden

    struct FragePaar: Equatable {
        let frage: String
        let antwort: String
    }

    /// Aufeinanderfolgende Repliken, bei denen die erste eine Frage ist.
    ///
    /// Es wird nur das unmittelbar folgende Redestück betrachtet. Ein Sprecher, der zwei
    /// Absätze später auf die Frage zurückkommt, ist erzählerisch etwas anderes – und für
    /// diese Messung ohnehin ein Ausweichen.
    static func fragePaare(in text: String) -> [FragePaar] {
        let reden = repliken(in: text)
        var paare: [FragePaar] = []
        for i in 0..<max(0, reden.count - 1) {
            let frage = reden[i].trimmingCharacters(in: .whitespacesAndNewlines)
            guard frage.hasSuffix("?") else { continue }
            // Rhetorische Einwürfe („Was?", „Wie bitte?") sind keine Fragen im Sinne
            // dieser Messung: Sie tragen keinen Inhalt, auf den man ausweichen könnte.
            guard frage.split(separator: " ").count >= 3 else { continue }
            paare.append(FragePaar(frage: frage, antwort: reden[i + 1]))
        }
        return paare
    }

    /// Die wörtliche Rede eines Textes, in Reihenfolge.
    ///
    /// Deckt die im Deutschen üblichen Anführungszeichen ab. Nach
    /// `vereinheitlicheAnfuehrungszeichen` steht im Manuskript nur noch „…", die
    /// Toleranz hier gilt Zwischenständen und importierten Texten.
    static func repliken(in text: String) -> [String] {
        let muster = "[\u{201E}\u{201C}\"\u{00BB}]([^\u{201E}\u{201C}\u{201D}\"\u{00AB}\u{00BB}]{2,})[\u{201C}\u{201D}\"\u{00AB}]"
        guard let re = try? NSRegularExpression(pattern: muster) else { return [] }
        let ns = text as NSString
        return re.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .compactMap { treffer -> String? in
                guard treffer.numberOfRanges > 1 else { return nil }
                let inhalt = ns.substring(with: treffer.range(at: 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return inhalt.isEmpty ? nil : inhalt
            }
    }

    // MARK: - Direkt oder ausweichend?

    /// Beantwortet diese Replik die Frage direkt?
    ///
    /// Drei Kriterien, in dieser Reihenfolge geprüft:
    ///
    /// 1. **Gegenfrage** → nie direkt. Das ist die klassischste Ausweichbewegung überhaupt
    ///    und wird zuerst geprüft, weil eine Gegenfrage die Wörter der Frage aufgreifen
    ///    kann und sonst über Kriterium 3 fälschlich als direkt gälte.
    /// 2. **Bestätigungspartikel am Anfang** („Ja", „Nein", „Doch", „Klar") → direkt.
    ///    Kürzer und eindeutiger geht eine Antwort nicht.
    /// 3. **Inhaltliche Überlappung** → direkt, wenn die Antwort in den Wörtern der Frage
    ///    formuliert ist. „Wo warst du gestern Abend?" / „Ich war gestern Abend bei
    ///    Thomas." Genau dieses Aufgreifen der Frageworte ist das Muster, an dem
    ///    KI-Dialog erkennbar wird.
    static func istDirekteAntwort(auf frage: String, antwort: String) -> Bool {
        let a = antwort.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !a.isEmpty else { return false }
        if a.hasSuffix("?") { return false }
        if beginntMitPartikel(a) { return true }
        return EreignisRegister.uebereinstimmung(
            EreignisRegister.inhaltswoerter(frage),
            EreignisRegister.inhaltswoerter(a)
        ) >= ueberlappungsSchwelle
    }

    /// Ab dieser Wortüberlappung gilt eine Antwort als in den Worten der Frage formuliert.
    ///
    /// **Gemessen** in `Scripts/DialogProbe.swift` an Frage-Antwort-Paaren beider Sorten;
    /// der Lauf druckt die Werte und prüft, dass die Schwelle mit Abstand dazwischen liegt.
    ///
    /// Die Rechenfunktion wird bewusst aus `EreignisRegister` mitbenutzt statt kopiert:
    /// Sie löst dasselbe Problem (deutsche Komposita und Flexion) und ist dort an echten
    /// Beispielen kalibriert. Zwei Kopien derselben Heuristik driften auseinander, und
    /// eine doppelte Prüfung ist schlimmer als keine.
    static let ueberlappungsSchwelle = 0.34

    /// Antworten, die mit einem dieser Wörter beginnen, sind eindeutig direkt.
    ///
    /// Bewusst nur echte Bestätigungs- und Verneinungspartikel. „Vielleicht", „Möglich"
    /// oder „Kann sein" stehen absichtlich NICHT darin: Das sind Ausweichbewegungen, auch
    /// wenn sie grammatisch wie Antworten aussehen.
    private static let partikel: Set<String> = [
        "ja", "nein", "doch", "klar", "sicher", "natuerlich", "genau", "stimmt",
        "richtig", "korrekt", "nie", "niemals", "immer", "nichts", "niemand", "keiner",
    ]

    private static func beginntMitPartikel(_ antwort: String) -> Bool {
        let erstes = antwort
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.letters.inverted)
            .first(where: { !$0.isEmpty })?
            .lowercased()
        guard let wort = erstes else { return false }
        return partikel.contains(wort)
    }
}
