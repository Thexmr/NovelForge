import Foundation

/// Deterministischer Pseudozufall (SplitMix64) – reproduzierbar und damit testbar.
/// Wird mit einem stabilen, pro Buch eindeutigen Seed gestartet, sodass jedes Buch
/// eine andere – aber über den gesamten Produktionslauf KONSTANTE – Stil-DNA erhält.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Die „Stil-DNA" eines Buches: pro Buch zufällig aus großen Optionspools gezogen,
/// damit JEDES Buch eine andere Erzählstruktur, Perspektive und Stimme bekommt.
///
/// Zweck: Amazon KDP erkennt „Programmatic Content" daran, dass viele Bücher dieselbe
/// Schablone teilen (gleiche Struktur, gleicher Schreibstil, nur Namen getauscht). Diese
/// Signatur bricht genau diese Gleichförmigkeit – der kombinatorische Raum ist riesig
/// (Millionen Kombinationen), sodass aufeinanderfolgende Bücher keine erkennbare
/// Template-Verwandtschaft mehr haben.
struct NarrativeSignature: Equatable {
    let pov: String
    let tense: String
    let structureModel: String
    let openingType: String
    let sentenceRhythm: String
    let descriptionDensity: String
    let dialogueBalance: String
    let chapterRhythm: String
    let narrativeDistance: String
    let motifTechnique: String

    static let povOptions = [
        "Ich-Perspektive (Präsenz und Unmittelbarkeit, subjektiv gefärbt)",
        "Personale 3. Person, eng an einer Figur (tiefe Innensicht)",
        "Personale 3. Person mit wechselnder Fokusfigur je Kapitel",
        "Auktoriale Erzählstimme mit eigener Haltung (sparsam, modern eingesetzt)",
    ]
    static let tenseOptions = [
        "Präteritum (klassisch, ruhiger Erzählabstand)",
        "Präsens (unmittelbar, drängend)",
    ]
    static let structureOptions = [
        "Klassische Drei-Akt-Dramaturgie mit klaren Wendepunkten",
        "In medias res – Einstieg mitten in der Krise, Vorgeschichte tröpfelt nach",
        "Rahmenerzählung – eine äußere Situation rahmt die eigentliche Geschichte",
        "Nichtlinear – bewusste Zeitsprünge, deren Reihenfolge selbst Bedeutung trägt",
        "Zwei parallele Handlungsstränge, die sich erst spät verknüpfen",
        "Countdown-Struktur – ein tickendes Limit treibt jedes Kapitel",
        "Mosaik aus eng verzahnten Episoden mit durchlaufendem rotem Faden",
        "Über Kontrast statt offenen Dauerkonflikt erzählt (ruhige Wucht)",
    ]
    static let openingOptions = [
        "Eröffnung mit einer konkreten Handlung unter Druck",
        "Eröffnung mitten in einem aufgeladenen Dialog",
        "Eröffnung mit einem rätselhaften Detail, das sofort Fragen stellt",
        "Eröffnung mit einer starken, eigenwilligen Erzählstimme",
        "Eröffnung mit einem feinen Riss im scheinbar normalen Alltag",
        "Eröffnung mit einer beiläufig gesetzten Vorausdeutung",
    ]
    static let rhythmOptions = [
        "Kurze, treibende Sätze; harte Schnitte",
        "Lange, fließende Perioden mit eingeschobenen kurzen Akzenten",
        "Stark wechselnder Rhythmus, oft stakkatohaft in Spannungsmomenten",
        "Ruhiger, beobachtender Rhythmus mit präzisen Details",
    ]
    static let densityOptions = [
        "Sparsam und cinematisch – wenige, gezielte Bilder",
        "Sinnlich-dicht, mit körperlich spürbaren Details",
        "Funktional und klar – Beschreibung dient nur der Handlung",
    ]
    static let dialogueOptions = [
        "Dialoglastig – der Konflikt entsteht vor allem im Gespräch",
        "Ausgewogen zwischen Dialog, Handlung und Innensicht",
        "Beschreibungs- und handlungslastig, Dialog sparsam und zugespitzt",
    ]
    static let chapterRhythmOptions = [
        "Kurze Kapitel mit hartem Cliffhanger-Schnitt",
        "Längere, atmende Kapitel mit innerer Steigerung",
        "Bewusst ungleiche Kapitellängen als Spannungsmittel",
    ]
    static let distanceOptions = [
        "Nüchtern und beobachtend, die Wertung dem Leser überlassen",
        "Emotional nah, fast unter der Haut der Figur",
        "Leicht ironisch-distanziert, mit trockenem Unterton",
        "Poetisch verdichtet, aber nie überladen",
    ]
    static let motifOptions = [
        "Ein wiederkehrendes konkretes Objekt als stiller Bedeutungsträger",
        "Ein Farb- oder Lichtmotiv, das die Stimmung trägt",
        "Wetter und Jahreszeit als gebrochener Kontrapunkt (nicht spiegelnd)",
        "Ein Sinnesmotiv (Geruch oder Klang), das Szenen verknüpft",
        "Kein aufgesetztes Leitmotiv – Bedeutung entsteht nur aus der Handlung",
    ]

    private static func pick<T, R: RandomNumberGenerator>(_ options: [T], _ rng: inout R) -> T {
        options[Int.random(in: 0..<options.count, using: &rng)]
    }

    static func make<R: RandomNumberGenerator>(using rng: inout R) -> NarrativeSignature {
        NarrativeSignature(
            pov: pick(povOptions, &rng),
            tense: pick(tenseOptions, &rng),
            structureModel: pick(structureOptions, &rng),
            openingType: pick(openingOptions, &rng),
            sentenceRhythm: pick(rhythmOptions, &rng),
            descriptionDensity: pick(densityOptions, &rng),
            dialogueBalance: pick(dialogueOptions, &rng),
            chapterRhythm: pick(chapterRhythmOptions, &rng),
            narrativeDistance: pick(distanceOptions, &rng),
            motifTechnique: pick(motifOptions, &rng)
        )
    }

    /// Erzeugt eine Signatur aus einem stabilen Seed (reproduzierbar).
    static func make(seed: UInt64) -> NarrativeSignature {
        var rng = SeededGenerator(seed: seed)
        return make(using: &rng)
    }

    /// Stabiler 64-Bit-Hash (FNV-1a) – im Gegensatz zu `hashValue` über App-Starts hinweg
    /// konstant, sodass derselbe Seed-String reproduzierbar dieselbe DNA ergibt.
    static func stableSeed(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }

    /// Verbindlicher Prompt-Block (deutsch), der die Einzigartigkeit dieses Buches erzwingt.
    /// Perspektive/Zeitform lassen sich überschreiben, wenn der Autor sie im Wizard selbst
    /// gewählt hat – die übrigen acht Dimensionen sorgen weiterhin für Varianz pro Buch.
    func directiveText(povOverride: String? = nil, tenseOverride: String? = nil) -> String {
        let usedPov = (povOverride?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? pov
        let usedTense = (tenseOverride?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? tense
        return """
        STIL-DNA DIESES BUCHES (VERBINDLICH – macht das Buch unverwechselbar; NICHT im Text erwähnen):
        - Erzählperspektive: \(usedPov)
        - Zeitform: \(usedTense)
        - Erzählstruktur: \(structureModel)
        - Eröffnung des Buches: \(openingType)
        - Satzrhythmus: \(sentenceRhythm)
        - Beschreibungsdichte: \(descriptionDensity)
        - Verhältnis Dialog/Beschreibung: \(dialogueBalance)
        - Kapitelrhythmus: \(chapterRhythm)
        - Erzähldistanz und Ton: \(narrativeDistance)
        - Leitmotiv-Technik: \(motifTechnique)
        EINZIGARTIGKEIT (Amazon-KDP-Schutz gegen „Programmatic Content"): Diese Geschichte folgt KEINER Standardvorlage und teilt mit keinem anderen Buch dieselbe Schablone. Halte diese Stil-DNA konsequent durch und vermeide jede Formulierung, Struktur oder Kapitel-Architektur, die nach austauschbarem Massentext klingt. Eigene, in sich stimmige Stimme.
        """
    }

    /// Voller Direktiv-Block ohne Überschreibungen.
    var directive: String { directiveText() }
}
