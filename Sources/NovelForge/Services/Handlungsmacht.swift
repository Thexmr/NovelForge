import Foundation

/// WER TREIBT DIE HANDLUNG – gemessen statt erbeten.
///
/// **Die Lücke.** Im Schreib-Prompt steht seit Langem „AKTIVE HAUPTFIGUR (Agency): Die
/// Hauptfigur TREIBT die Handlung durch eigene Entscheidungen". Das ist die richtige
/// Regel. Gemessen wurde sie nie – und eine Regel ohne Messung ist eine Bitte. Wie
/// zuverlässig Bitten in diesem Projekt befolgt werden, steht in den ausgelieferten
/// Büchern: „Liv" 263-mal trotz Namenssperre, 7,5 Bilder je 1000 Wörter statt der
/// geforderten 0,4.
///
/// **Warum das über den Leser entscheidet.** Eine Figur, der Dinge zustoßen, ist ein
/// Zuschauer. Der Leser fiebert nicht mit jemandem mit, der nur reagiert – er wartet
/// darauf, dass endlich jemand etwas tut. Auf 500 Seiten ist das der Unterschied zwischen
/// Sog und Geduldsprobe. Umgekehrt gilt aber auch: Eine Figur, die immer gewinnt, hat
/// keinen Gegner. Beide Extreme sind Fehler, deshalb misst diese Datei ein BAND, keine
/// Untergrenze.
///
/// **Warum am Plan und nicht an der Prosa.** Wer eine Wendung verursacht hat, steht nicht
/// zuverlässig im Satzbau – dafür bräuchte es eine syntaktische Analyse oder einen
/// Modellaufruf, und Letzterer wäre ein weiterer Rückkopplungspfad. Im Szenenplan lässt
/// sich der Antrieb direkt benennen, deterministisch auswerten und, was am wichtigsten
/// ist, VOR dem Schreiben korrigieren.
enum Handlungsmacht {

    /// Wer die Wendung der Szene verursacht.
    enum Antrieb: String, CaseIterable {
        /// Die Perspektivfigur selbst – durch eine Entscheidung oder Handlung.
        case figur
        /// Der Gegenspieler oder eine andere Figur mit eigenem Interesse.
        case gegenspieler
        /// Umstände: Unfall, Wetter, Behörde, ein Fund, eine Nachricht von außen.
        case zufall

        static func lesen(_ text: String) -> Antrieb? {
            let t = text.folding(options: [.caseInsensitive, .diacriticInsensitive],
                                 locale: .current).trimmingCharacters(in: .whitespaces)
            guard !t.isEmpty, t != "-" else { return nil }
            if t.hasPrefix("figur") || t.hasPrefix("sie") || t.hasPrefix("er ")
                || t.hasPrefix("selbst") || t.hasPrefix("hauptfigur") { return .figur }
            if t.hasPrefix("gegen") || t.hasPrefix("antagonist")
                || t.hasPrefix("andere") { return .gegenspieler }
            if t.hasPrefix("zufall") || t.hasPrefix("umstand") || t.hasPrefix("umstaende")
                || t.hasPrefix("aussen") || t.hasPrefix("schicksal") { return .zufall }
            return nil
        }
    }

    struct Kennzahl: Equatable {
        let figur: Int
        let gegenspieler: Int
        let zufall: Int

        var gesamt: Int { figur + gegenspieler + zufall }
        var anteilFigur: Double { gesamt == 0 ? 0 : Double(figur) / Double(gesamt) }
        var anteilZufall: Double { gesamt == 0 ? 0 : Double(zufall) / Double(gesamt) }

        /// Ab so vielen ausgewerteten Szenen ist der Anteil aussagekräftig.
        ///
        /// Ein Kapitel hat zwei bis sieben Szenen. Bei drei Szenen entscheidet eine
        /// einzige über 33 Prozentpunkte – solche Zahlen als Befund zu melden wäre
        /// Rauschen, das wie ein Ergebnis aussieht.
        var belastbar: Bool { gesamt >= 8 }
    }

    /// Untergrenze für den Anteil selbst verursachter Wendungen.
    ///
    /// Ein Drittel ist die Schwelle, unter der eine Figur als Zuschauerin gelesen wird:
    /// Zwei von drei Wendungen stoßen ihr dann zu. Das entspricht der gängigen
    /// Lektoratsregel, dass die Hauptfigur den dritten Akt selbst herbeiführen muss und
    /// bis dahin mindestens gleichauf mit den Kräften gegen sie liegt.
    static let untergrenzeFigur = 0.33

    /// Obergrenze – eine Figur, die fast alles selbst auslöst, hat keinen Gegner.
    ///
    /// Bewusst mitgeprüft: Eine Prüfung, die nur „zu passiv" kennt, treibt das Modell ins
    /// andere Extrem. Dann trifft die Heldin lauter Entscheidungen, gegen die niemand
    /// steht – und das liest sich nicht stark, sondern folgenlos.
    static let obergrenzeFigur = 0.75

    /// Obergrenze für Wendungen aus reinem Zufall.
    ///
    /// Zufall ist als Auslöser erlaubt (der auslösende Vorfall ist fast immer einer) und
    /// als Verschärfung. Er darf nur nicht das Erzählprinzip sein: Ein Buch, in dem jede
    /// dritte Wendung ein Fund, ein Anruf oder ein Unfall ist, wirkt beliebig, weil nichts
    /// aus dem Vorherigen folgt.
    static let obergrenzeZufall = 0.30

    // MARK: - Messen

    static func messe(_ antriebe: [Antrieb?]) -> Kennzahl {
        let vorhanden = antriebe.compactMap { $0 }
        return Kennzahl(
            figur: vorhanden.filter { $0 == .figur }.count,
            gegenspieler: vorhanden.filter { $0 == .gegenspieler }.count,
            zufall: vorhanden.filter { $0 == .zufall }.count)
    }

    static func messe(szenen: [PlannedScene]) -> Kennzahl {
        // Nachklänge zählen nicht: Ihr Takt ist Reaktion → Dilemma → Entscheidung, sie
        // haben per Definition keine äußere Wendung. Sie mitzuzählen würde entweder die
        // Figur künstlich stärken oder – wenn das Feld leer bleibt – die Datenbasis
        // verwässern.
        messe(szenen.filter { !$0.istNachklang }.map { Antrieb.lesen($0.antrieb) })
    }

    /// Klartext-Befund oder `nil`, wenn das Verhältnis stimmt.
    static func befund(_ kennzahl: Kennzahl) -> String? {
        guard kennzahl.belastbar else { return nil }
        let figurProzent = Int((kennzahl.anteilFigur * 100).rounded())
        let zufallProzent = Int((kennzahl.anteilZufall * 100).rounded())

        if kennzahl.anteilFigur < untergrenzeFigur {
            return "Die Hauptfigur verursacht nur \(figurProzent) % der Wendungen "
                + "(\(kennzahl.figur) von \(kennzahl.gesamt)). Ihr stößt zu, was geschieht – "
                + "sie ist Zuschauerin ihrer eigenen Geschichte. Mindestens jede dritte "
                + "Wendung muss aus ihrer Entscheidung folgen."
        }
        if kennzahl.anteilFigur > obergrenzeFigur {
            return "Die Hauptfigur verursacht \(figurProzent) % der Wendungen "
                + "(\(kennzahl.figur) von \(kennzahl.gesamt)). Es steht ihr fast nichts "
                + "entgegen – ohne Gegendruck bleiben ihre Entscheidungen folgenlos."
        }
        if kennzahl.anteilZufall > obergrenzeZufall {
            return "\(zufallProzent) % der Wendungen entstehen aus Zufall oder äußeren "
                + "Umständen (\(kennzahl.zufall) von \(kennzahl.gesamt)). Das liest sich "
                + "beliebig: Was passiert, folgt nicht aus dem, was vorher geschah."
        }
        return nil
    }
}
