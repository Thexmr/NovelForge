import Foundation

/// Prüft die Bucharchitektur-Sperre – die Stelle, an der eine echte Produktion neunmal
/// hintereinander abgebrochen ist.
///
/// Am 10.08.2026 lehnte `plotArchitekturMaengel` den Plot von „Die Nacht jagt dich"
/// zwischen 12:25 und 13:29 neunmal ab, jedes Mal mit derselben Meldung, jedes Mal mit
/// Abbruch in Phase 3 von 12. Der Grund war nicht der Plot, sondern seine Überschriften:
/// Die Prüfung suchte Zeichenketten im Fließtext. Dieses Programm hält fest, dass ein
/// guter Plot mit fremden Überschriften ab jetzt durchkommt – und ein leerer nicht.
///
///   SRC=$(find Sources/NovelForge -name '*.swift' ! -name 'NovelForgeApp.swift' | tr '\n' ' ')
///   swiftc -wmo -parse-as-library -module-name Probe -o /tmp/pg Scripts/PlotGateProbe.swift ${=SRC}
@main
struct PlotGateProbe {

    static var fehler = 0
    static var geprueft = 0

    static func pruefe(_ name: String, _ bedingung: Bool, _ detail: String = "") {
        geprueft += 1
        if bedingung { print("  OK   \(name)") }
        else {
            fehler += 1
            print("  FEHL \(name)\(detail.isEmpty ? "" : "  [\(detail)]")")
        }
    }

    /// Ein fachlich einwandfreier Thriller-Plot, der die Funktionen NICHT so nennt, wie die
    /// alte Stichwortsuche sie suchte. Genau dieser Fall hat die Produktion getoetet.
    static let plotMitEigenenUeberschriften = """
    DIE NACHT JAGT DICH — Bucharchitektur

    ERSTER ANSTOSS
    Kommissarin Ines Roth findet im Kofferraum ihres eigenen Wagens die Jacke einer seit
    zwei Jahren vermissten Studentin. Sie meldet es nicht.

    DER PUNKT OHNE RUECKFAHRKARTE
    Statt die Jacke abzugeben, sucht Ines auf eigene Faust weiter. Damit macht sie sich
    selbst zur Verdaechtigen und kann nicht mehr zurueck.

    ALLES KIPPT
    In der Buchmitte erkennt Ines, dass ihr eigener Mentor die Ermittlungsakte damals
    manipuliert hat. Aus der Suche nach einem Taeter wird die Frage, wem sie noch traut.

    WAS ES SIE KOSTET
    Um an die Akte zu kommen, verrät Ines ihre Partnerin und verliert die einzige
    Freundschaft, die sie noch hatte.

    DIE LETZTE NACHT
    Ines stellt den Mentor allein im leerstehenden Institut. Sie muss waehlen zwischen
    einem Gestaendnis, das ihn rettet, und einem Beweis, der sie selbst belastet.

    WIE ES AUSGEHT
    Der Mentor kommt vor Gericht, Ines verliert ihren Dienstgrad. Sie arbeitet danach in
    einer kleinen Dienststelle und schlaeft zum ersten Mal seit Jahren durch.

    WORUM ES WIRKLICH GEHT
    Kann Ines die Wahrheit ans Licht bringen, ohne selbst zu werden, was sie jagt?

    ZWEITER STRANG
    Ihre Partnerin Marit ermittelt parallel gegen Ines und liefert am Ende genau den
    Beweis, der den Mentor ueberfuehrt.

    BEAT|Ausloeser|Ines findet die Jacke der Vermissten im eigenen Kofferraum
    BEAT|Entscheidung|Sie meldet den Fund nicht und ermittelt heimlich weiter
    BEAT|Umkehr|Ihr Mentor hat die Akte damals selbst manipuliert
    BEAT|Preis|Sie verraet ihre Partnerin und verliert die letzte Freundschaft
    BEAT|Finale|Allein im Institut waehlt sie zwischen seinem Gestaendnis und dem Beweis
    BEAT|Aufloesung|Der Mentor kommt vor Gericht, Ines verliert ihren Dienstgrad
    BEAT|Frage|Kann Ines die Wahrheit ans Licht bringen, ohne zu werden was sie jagt
    BEAT|Nebenhandlung|Marit ermittelt gegen Ines und liefert am Ende den Beweis

    GEGENZUG|1|Der Mentor laesst die alte Akte aus dem Archiv entfernen|Ein Vorgang ist nicht auffindbar
    GEGENZUG|6|Er setzt Ines' Beurteilung herab|Ein Gespraech mit der Amtsleitung wird vorgezogen
    GEGENZUG|11|Er laesst Marit auf Ines ansetzen|Die Partnerin fragt zu genau nach
    GEGENZUG|16|Er bietet der Familie der Vermissten Geld|Die Mutter will nicht mehr reden
    GEGENZUG|21|Er meldet Ines wegen Beweismittelentzug|Eine Vorladung liegt im Fach
    """

    static func main() {
        print("PLOT-SPERRE (Bucharchitektur)\n")

        // ------------------------------------------------------------------
        // 1. DER FALL, DER DIE PRODUKTION GETOETET HAT
        // ------------------------------------------------------------------
        print("GUTER PLOT MIT EIGENEN UEBERSCHRIFTEN")
        let maengel = AutonomousContentQuality.plotArchitekturMaengel(
            plotMitEigenenUeberschriften, istSachbuch: false)
        for m in maengel { print("       \(m)") }
        pruefe("wird NICHT mehr abgelehnt", maengel.isEmpty,
               maengel.joined(separator: " | "))

        let beats = AutonomousContentQuality.plotBeats(plotMitEigenenUeberschriften)
        pruefe("acht Beats gelesen", beats.count == 8, "\(beats.count)")
        pruefe("Umkehr wird erkannt",
               beats["umkehr"]?.contains("Mentor") == true, beats["umkehr"] ?? "-")
        pruefe("Preis wird erkannt",
               beats["preis"]?.contains("Partnerin") == true, beats["preis"] ?? "-")

        // Der Fahrplan des Gegenspielers muss aus derselben Antwort lesbar sein.
        let fahrplan = Gegenspieler.parse(plotMitEigenenUeberschriften)
        pruefe("Gegenspieler-Fahrplan wird mitgelesen", fahrplan.zuege.count == 5,
               "\(fahrplan.zuege.count)")
        let placeholderVariant = Gegenspieler.parse(
            "GEGENZUG|abKapitel2|Sie zieht den Vereinstermin vor|Die Einladung fehlt"
        )
        pruefe("Wörtlich übernommener abKapitel-Platzhalter bleibt lesbar",
               placeholderVariant.zuege.first?.abKapitel == 2,
               "\(placeholderVariant.zuege.count)")
        pruefe("Fahrplan hat keine Maengel",
               fahrplan.maengel(kapitelAnzahl: 25).isEmpty,
               fahrplan.maengel(kapitelAnzahl: 25).joined(separator: " | "))

        // Und die dramatische Frage muss ankommen.
        let frage = DramatischeFrage.finde(in: plotMitEigenenUeberschriften)
        pruefe("dramatische Frage wird gefunden",
               frage?.contains("ohne selbst zu werden") == true
                || frage?.contains("ohne zu werden") == true, frage ?? "-")

        // ------------------------------------------------------------------
        // 2. SCHREIBVARIANTEN DER SCHLUESSELWOERTER
        // ------------------------------------------------------------------
        print("\nSCHREIBVARIANTEN")
        let varianten = """
        BEAT|AUSLÖSER|Sie findet die Jacke im eigenen Kofferraum
        BEAT|Irreversible Entscheidung|Sie meldet den Fund nicht und ermittelt weiter
        BEAT|Midpoint|Ihr Mentor hat die Akte damals selbst manipuliert
        BEAT|Opfer|Sie verraet ihre Partnerin und verliert die Freundschaft
        BEAT|Höhepunkt|Allein im Institut waehlt sie zwischen Gestaendnis und Beweis
        BEAT|Auflösung|Der Mentor kommt vor Gericht, Ines verliert den Dienstgrad
        BEAT|Dramatische Frage|Kann sie die Wahrheit finden ohne selbst zu fallen
        BEAT|Subplot|Marit ermittelt gegen Ines und liefert den entscheidenden Beweis
        """ + String(repeating: " Fliesstext", count: 180)   // Mindestlaenge: 180 Woerter
        let variantenBeats = AutonomousContentQuality.plotBeats(varianten)
        pruefe("Umlaute und Synonyme werden zugeordnet", variantenBeats.count == 8,
               "\(variantenBeats.count): \(variantenBeats.keys.sorted().joined(separator: ", "))")
        pruefe("Varianten-Plot besteht die Pruefung",
               AutonomousContentQuality.plotArchitekturMaengel(varianten, istSachbuch: false).isEmpty,
               AutonomousContentQuality.plotArchitekturMaengel(varianten, istSachbuch: false)
                .joined(separator: " | "))

        // ------------------------------------------------------------------
        // 3. WAS WEITERHIN AUFFALLEN MUSS
        // ------------------------------------------------------------------
        print("\nECHTE MAENGEL FALLEN WEITER AUF")

        let ohneUmkehr = varianten.components(separatedBy: .newlines)
            .filter { !$0.contains("Midpoint") }.joined(separator: "\n")
        pruefe("fehlender Beat wird gemeldet",
               AutonomousContentQuality.plotArchitekturMaengel(ohneUmkehr, istSachbuch: false)
                .contains { $0.contains("zentrale Umkehr") })

        let leereBeats = """
        BEAT|Ausloeser|Etwas passiert
        BEAT|Entscheidung|Sie entscheidet
        BEAT|Umkehr|Es kippt
        BEAT|Preis|Sie verliert
        BEAT|Finale|Das Finale
        BEAT|Aufloesung|Es endet
        BEAT|Frage|Die Frage
        BEAT|Nebenhandlung|Ein Strang
        """
        let leerMaengel = AutonomousContentQuality.plotArchitekturMaengel(
            leereBeats, istSachbuch: false)
        pruefe("Schablonen-Beats werden gemeldet", !leerMaengel.isEmpty,
               "\(leerMaengel.count) Maengel")
        pruefe("Meldung nennt die Unbestimmtheit",
               leerMaengel.contains { $0.contains("zu unbestimmt") },
               leerMaengel.first ?? "-")

        // Altbestand ohne Beat-Liste: Die Stichwortsuche greift weiterhin.
        let alterPlot = """
        AUSLÖSENDES EREIGNIS: Ines findet die Jacke.
        IRREVERSIBLE ENTSCHEIDUNG: Sie meldet es nicht.
        ZENTRALE UMKEHR: Der Mentor war es.
        UNVERMEIDBARER PREIS: Sie verliert die Freundschaft.
        FINALE KONFRONTATION: Im Institut.
        AUFLÖSUNG und Nachklang: Er kommt vor Gericht.
        ZENTRALE FRAGE: Kann sie die Wahrheit finden?
        NEBENHANDLUNG: Marit ermittelt gegen sie.
        """ + String(repeating: " Wort", count: 200)
        pruefe("alter Plot ohne Beat-Liste besteht weiterhin",
               AutonomousContentQuality.plotArchitekturMaengel(alterPlot, istSachbuch: false).isEmpty,
               AutonomousContentQuality.plotArchitekturMaengel(alterPlot, istSachbuch: false)
                .joined(separator: " | "))

        pruefe("Plot ohne alles faellt durch",
               !AutonomousContentQuality.plotArchitekturMaengel(
                   "Ein kurzer Text ohne Struktur.", istSachbuch: false).isEmpty)

        // ------------------------------------------------------------------
        // 4. NAMENSSPERRE – Familien muessen moeglich sein
        // ------------------------------------------------------------------
        //
        // Am 10.08.2026 brach die Produktion direkt NACH der bestandenen Plotplanung ab:
        // „Fuer die kollidierenden Figurennamen konnte kein sicherer katalogweit neuer
        // Ersatz gebildet werden." Der Plot hatte „Alva Voss" und „Henning Voss" – Tochter
        // und Vater. Der geteilte Nachname galt als Verwechslung, die Reparatur benannte
        // beide um (Namensteile werden im ganzen Kanon ersetzt), und dieselbe Pruefung
        // schlug erneut an. Zwei Figuren mit gemeinsamem Nachnamen waren unmoeglich.
        print("\nNAMENSSPERRE")

        let familie = ["Liv", "Alva Voss", "Elias", "Henning Voss", "Wald"]
        pruefe("Familie mit gemeinsamem Nachnamen ist erlaubt",
               StoryMemory.namensKollisionen(familie, vergeben: []).isEmpty,
               StoryMemory.namensKollisionen(familie, vergeben: []).joined(separator: " | "))
        pruefe("Familie erzeugt keine Ersetzung",
               StoryMemory.sichereNamensErsetzungen(familie, vergeben: [])?.isEmpty == true)

        // Dieselbe Figur mit und ohne Vornamen ist keine zweite Figur.
        pruefe("Figur mit und ohne Vornamen kollidiert nicht",
               StoryMemory.namensKollisionen(["Ines", "Ines Roth"], vergeben: []).isEmpty,
               StoryMemory.namensKollisionen(["Ines", "Ines Roth"], vergeben: [])
                .joined(separator: " | "))

        // Die eigentliche Regel muss weiter greifen: verwechselbare, ABER verschiedene Namen.
        let verwechselbar = StoryMemory.namensKollisionen(["Lena Berg", "Leni Kraus"],
                                                          vergeben: [])
        pruefe("Lena neben Leni bleibt ein Befund", !verwechselbar.isEmpty,
               verwechselbar.joined(separator: " | "))

        // Und die katalogweite Sperre gegen FRUEHERE Buecher bleibt unberuehrt.
        pruefe("Name aus einem frueheren Buch bleibt gesperrt",
               !StoryMemory.namensKollisionen(["Mira Brenner"],
                                              vergeben: ["brenner"]).isEmpty)

        // ------------------------------------------------------------------
        // 5. KAPITEL-KAUSALITAET – Substanz statt Formel
        // ------------------------------------------------------------------
        //
        // Die Pruefung verlangte woertlich „FOLGE AUS KAPITEL N:" im Ausloeser-Feld. Der
        // Prompt fordert diese Form zwar, aber ein Kapitel, das die Kausalitaet in eigenen
        // Worten benennt, fiel durch – und die Pruefung steht in der finalen Freigabe der
        // Kapitelplanung. Am 10.08.2026 kam kein Belletristik-Plan durch.
        print("\nKAPITEL-KAUSALITAET")

        func kap(_ nr: Int, _ titel: String, _ cause: String, _ decision: String,
                 _ outcome: String, _ schritt: String) -> PlannedChapter {
            PlannedChapter(number: nr, title: titel,
                           goal: "\(cause) \(decision) \(outcome)",
                           conflict: "Ein Gegner steht dagegen",
                           cause: cause, decision: decision, outcome: outcome,
                           emotionalStep: schritt)
        }

        // Kausal sauber, aber OHNE die Formel: jeder Ausloeser greift das Vorkapitel auf.
        let eigeneWorte = [
            kap(1, "Der erste Abend", "AUSLÖSER: Maren findet den gekündigten Mietvertrag",
                "Maren beschliesst den Laden trotzdem zu halten",
                "Der Laden bleibt offen, das Geld reicht bis Maerz",
                "Aus Schreck wird Trotz"),
            kap(2, "Was das Geld nicht deckt", "Weil das Geld nur bis Maerz reicht, sucht Maren einen Buergen",
                "Maren fragt ihren Bruder um die Buergschaft",
                "Der Bruder sagt zu, verlangt aber Mitsprache im Laden",
                "Erleichterung mit einem Rest Misstrauen"),
            kap(3, "Mitsprache", "Die Mitsprache des Bruders zwingt Maren zu einer Abstimmung",
                "Maren stimmt gegen den Vorschlag ihres Bruders",
                "Der Bruder zieht die Buergschaft zurueck",
                "Trotz kippt in Angst"),
            kap(4, "Ohne Netz", "Die zurueckgezogene Buergschaft laesst Maren ohne Sicherheit",
                "Maren verkauft die Wohnung ihrer Mutter",
                "Der Laden ist gerettet, das Elternhaus verloren",
                "Angst weicht einer harten Klarheit"),
        ]
        let eigenMaengel = AutonomousContentQuality.kapitelKausalitaetsMaengel(eigeneWorte)
        for m in eigenMaengel { print("       \(m)") }
        pruefe("Kausalitaet in eigenen Worten wird anerkannt",
               !eigenMaengel.contains { $0.contains("knüpft nicht erkennbar an") },
               eigenMaengel.joined(separator: " | "))

        // Die alte Formel muss weiterhin gelten (Altbestand).
        let mitFormel = [
            eigeneWorte[0],
            kap(2, "Zweites", "FOLGE AUS KAPITEL 1: Der Laden braucht eine Buergschaft",
                "Maren fragt ihren Bruder um Hilfe",
                "Der Bruder sagt zu und verlangt Mitsprache",
                "Erleichterung mit Misstrauen"),
            eigeneWorte[2], eigeneWorte[3],
        ]
        pruefe("alte Formel bleibt gueltig",
               !AutonomousContentQuality.kapitelKausalitaetsMaengel(mitFormel)
                .contains { $0.contains("knüpft nicht erkennbar an") })

        // Ein echter Bruch muss weiterhin auffallen.
        let bruch = [
            eigeneWorte[0],
            kap(2, "Ganz woanders", "In Lissabon beginnt eine Hitzewelle",
                "Ein Fremder kauft eine Fahrkarte nach Porto",
                "Der Zug faellt aus, er bleibt am Bahnhof",
                "Langeweile wird zu Neugier"),
            eigeneWorte[2], eigeneWorte[3],
        ]
        pruefe("echter Handlungsbruch faellt weiterhin auf",
               AutonomousContentQuality.kapitelKausalitaetsMaengel(bruch)
                .contains { $0.contains("knüpft nicht erkennbar an") },
               AutonomousContentQuality.kapitelKausalitaetsMaengel(bruch).joined(separator: " | "))

        print("\n" + (fehler == 0
            ? "ALLE \(geprueft) PRUEFUNGEN BESTANDEN"
            : "\(fehler) VON \(geprueft) PRUEFUNGEN FEHLGESCHLAGEN"))
        if fehler > 0 { exit(1) }
    }
}
