import Foundation

/// Beweisprobe für die beiden neuen Lesbarkeits-Prüfungen und das Typografie-Netz.
///
/// Warum als Probe und nicht als XCTest: Auf diesem Rechner ist nur CommandLineTools
/// installiert, kein Xcode – `swift test` findet kein XCTest-Modul. Die Tests in
/// `Tests/NovelForgeTests/LogicTests.swift` existieren für die CI; hier läuft dieselbe
/// Prüfung ohne XCTest. Fällt eine Bedingung, bricht die Probe mit Meldung ab.
@main
enum DeepPOVProbe {
    static func main() {
        var bestanden = 0

        func pruefe(_ name: String, _ bedingung: Bool, _ detail: @autoclosure () -> String = "") {
            if bedingung {
                bestanden += 1
                print("  OK   \(name)")
            } else {
                print("  FEHL \(name) — \(detail())")
                exit(1)
            }
        }

        print("FILTERWOERTER (Deep POV)")
        let mitFilter = "Sie sah, dass er die Tür schloss. Er spürte, wie die Kälte kam. "
            + "Sie konnte hören, wie der Motor ansprang. Es schien ihr, als sei alles vorbei."
        let treffer = AutonomousContentQuality.filterwoerter(in: mitFilter)
        pruefe("vier Distanzformeln gefunden", treffer.count == 4,
               "gefunden: \(treffer.count) — \(treffer.map(\.stelle))")

        let ohneFilter = "Er schloss die Tür. Kälte kroch ihm in den Nacken. Der Motor sprang an, "
            + "zweimal, dann Stille. Sie wusste, dass es zu spät war."
        let leer = AutonomousContentQuality.filterwoerter(in: ohneFilter)
        pruefe("tiefe Perspektive nicht gemeldet", leer.isEmpty,
               "falsch positiv: \(leer.map(\.stelle))")

        print("VERGLEICHS-DICHTE")
        let bilderflut = """
        Der Summton brach ab, als würde ein Stecker gezogen. Drei Männer in zivilen \
        Windjacken, die wie Uniformen ausgesehen hätten, wäre der Stoff nicht so billig \
        gewesen. Der mittlere, kurz, mit einem Gesicht wie abgenutzte Möbelpolsterung, \
        zog einen Ausweis hervor. Der Mann neben ihr trat mit, synchron, wie bei einem \
        langsamen Tanz. Er lachte, ein Geräusch wie aus einem defekten Ventilator. \
        Schwarze Erde mit Glitzern, die im Regen wie Glassplitter aussahen.
        """
        let flut = AutonomousContentQuality.vergleichsDichte(in: bilderflut)
        print("       gefunden: \(flut.anzahl) Bilder, Budget \(flut.budget)")
        print("       Stellen:  \(flut.stellen.joined(separator: " | "))")
        pruefe("Bilderflut erkannt", flut.anzahl >= 5, "nur \(flut.anzahl)")
        pruefe("Budget überschritten gemeldet", flut.anzahl > flut.budget)
        pruefe("bestehende Prüfung ist hier blind (belegt die Lücke)",
               AutonomousContentQuality.gestapelteBilder(in: bilderflut).isEmpty)

        let nuechtern = "Sie zog die Tür zu. Der Schlüssel klemmte, wie immer. Zweimal drehen, "
            + "dann ruckeln, dann noch mal drehen. Sie hatte es Tom hundertmal erklärt, "
            + "und Tom hatte hundertmal genickt und nichts repariert. Draußen regnete es. "
            + "Sie wusste, wie das ausgeht."
        let sauber = AutonomousContentQuality.vergleichsDichte(in: nuechtern)
        pruefe("nüchterne Prosa nicht gemeldet", sauber.anzahl == 0,
               "falsch positiv: \(sauber.stellen)")

        let ueberlappung = AutonomousContentQuality.vergleichsDichte(in: "Der Raum wirkte wie eine Bühne.")
        pruefe("überlappende Muster zählen nur einmal", ueberlappung.anzahl == 1,
               "gezählt: \(ueberlappung.anzahl) — \(ueberlappung.stellen)")

        print("EINBINDUNG IN DEN DRAFT-LOOP")
        let satz = "Sie sah, dass er ging, und der Raum wirkte wie eine Bühne ohne Publikum. "
        let befunde = AutonomousContentQuality.styleTicViolations(in: String(repeating: satz, count: 20))
        pruefe("styleTicViolations meldet Filterwörter",
               befunde.contains { $0.contains("Filterwörter") }, "\(befunde)")
        pruefe("styleTicViolations meldet Bilderflut",
               befunde.contains { $0.contains("Vergleiche") }, "\(befunde)")

        print("BUDGET-LOGIK (nur Ueberzaehliges wird repariert)")
        // Sechs Bilder, Budget 2 → vier Saetze muessen in die Chirurgie, zwei bleiben.
        let ueber = AutonomousContentQuality.ueberzaehligeBilder(in: bilderflut)
        print("       ueberzaehlige Saetze: \(ueber.count) bei Budget \(flut.budget)")
        pruefe("erste Bilder bleiben stehen", ueber.count < flut.anzahl,
               "alle \(flut.anzahl) gemeldet – Budget wirkungslos")
        pruefe("Ueberzaehlige werden gemeldet", !ueber.isEmpty)

        let nuechternUeber = AutonomousContentQuality.ueberzaehligeBilder(in: nuechtern)
        pruefe("nuechterne Passage liefert nichts zu reparieren", nuechternUeber.isEmpty,
               "\(nuechternUeber.map(\.satz))")

        let gebuendelt = AutonomousContentQuality.reparierbareStilSaetze(in: bilderflut)
        pruefe("gebuendelte Liste enthaelt die Bilder", !gebuendelt.isEmpty)
        let kappe = AutonomousContentQuality.reparierbareStilSaetze(
            in: String(repeating: "Er lachte wie ein Ventilator. ", count: 60), hoechstens: 12)
        pruefe("Obergrenze haelt den Reparatur-Prompt endlich", kappe.count <= 12,
               "\(kappe.count) Saetze")

        print("BUCHWEITE KENNZAHLEN (Freigabe-Gate)")
        let kennzahlen = AutonomousContentQuality.stilKennzahlen(inChapters: [bilderflut])
        print("       Bilder je 1000 Woerter: \(String(format: "%.1f", kennzahlen.bilder))")
        pruefe("Kennzahl wird berechnet", kennzahlen.bilder > 0 && kennzahlen.woerter > 0)

        print("TYPOGRAFIE")
        let roh = "\u{201E}Sie ist drin.\u{22} Ein Mann: \u{22}Lass sie.\u{22}"
        let norm = AutonomousContentQuality.vereinheitlicheAnfuehrungszeichen(roh)
        print("       vorher:  \(roh)")
        print("       nachher: \(norm)")
        pruefe("keine geraden Zoll-Zeichen mehr", !norm.contains("\u{22}"))
        pruefe("öffnendes deutsches Zeichen gesetzt", norm.contains("\u{201E}"))
        pruefe("schließendes deutsches Zeichen gesetzt", norm.contains("\u{201C}"))

        print("LOOP-BREMSE (harte Schranke pro Szene)")
        var budget = SzenenBudget(kapitel: 7, szene: 3)
        pruefe("startet mit vollem Budget",
               budget.darfWeiter && budget.verbleibend == SzenenBudget.maximaleVersuche)
        // Echte Fehlversuche muessen das Budget aufbrauchen - danach ist Schluss, egal was
        // das Modell liefert. Jede Fassung ist bewusst deutlich anders, damit hier NICHT
        // die Stagnationserkennung greift, sondern die Zaehlgrenze.
        //
        // Der Test zaehlt gegen `maximaleVersuche` statt gegen eine feste Zahl: Die Grenze
        // ist eine Stellschraube (aktuell 25), die Schranke selbst darf nie verschwinden.
        let echtVerschieden = [
            "Der Zug fuhr ein, und niemand stieg aus.",
            "Sie legte das Messer neben den Teller und stand auf.",
            "Im Hof bellte ein Hund, dreimal, dann war Ruhe.",
            "Er zaehlte das Geld nach, obwohl er wusste, dass es stimmte.",
            "Die Ampel sprang auf Gruen, aber keiner fuhr los.",
            "Auf dem Dachboden roch es nach nassem Karton und Lavendel.",
            "Ihr Vater hatte den Brief nie geoeffnet, das sah man am Rand.",
            "Zwei Kinder stritten sich um ein Fahrrad ohne Sattel.",
        ]
        // Jede Fassung bekommt eine eigene Nummer, damit auch bei mehr Runden als
        // Beispielsaetzen keine Wiederholung entsteht, die faelschlich als Stillstand gilt.
        for i in 0..<SzenenBudget.maximaleVersuche {
            budget.verbuche(fassung: "\(echtVerschieden[i % echtVerschieden.count]) (\(i))")
        }
        pruefe("Budget nach der letzten Runde erschoepft", !budget.darfWeiter,
               "verbraucht: \(budget.verbraucht), stagniert: \(budget.stagniert)")
        pruefe("Abbruchgrund wird genannt", budget.abbruchGrund?.contains("Versuchsbudget") == true,
               budget.abbruchGrund ?? "kein Grund")

        // Der teure Fall: Das Modell wiederholt sich. Dann darf nicht bis zum Ende
        // durchgezaehlt werden - der zweite gleiche Versuch beendet die Szene sofort.
        var stagnation = SzenenBudget(kapitel: 1, szene: 1)
        let fassung = "Sie stand am Herd und ruehrte die Suppe um, waehrend draussen der "
            + "Regen gegen die Scheibe schlug und niemand ein Wort sagte."
        stagnation.verbuche(fassung: fassung)
        stagnation.verbuche(fassung: fassung + " ")
        pruefe("Stagnation stoppt sofort", !stagnation.darfWeiter && stagnation.verbraucht == 2,
               "verbraucht: \(stagnation.verbraucht)")
        pruefe("Stagnationsgrund wird genannt",
               stagnation.abbruchGrund?.contains("identisch") == true, stagnation.abbruchGrund ?? "-")

        // Eine echte Neufassung darf NICHT als Stagnation gelten.
        var fortschritt = SzenenBudget(kapitel: 2, szene: 2)
        fortschritt.verbuche(fassung: "Sie stand am Herd und ruehrte die Suppe um.")
        fortschritt.verbuche(fassung: "Er warf den Schluessel auf den Tisch und ging wortlos "
            + "an ihr vorbei in den Garten hinaus.")
        pruefe("echte Neufassung laeuft weiter", fortschritt.darfWeiter)

        // Auch ein Fehlversuch ohne Text kostet Budget - sonst haette ein dauerhaft
        // fehlschlagender Provider wieder keine Schranke.
        var leeresBudget = SzenenBudget(kapitel: 3, szene: 1)
        for _ in 1...SzenenBudget.maximaleVersuche { leeresBudget.verbuche(fassung: nil) }
        pruefe("leere Antworten kosten ebenfalls Budget", !leeresBudget.darfWeiter)

        print("SCENE & SEQUEL (Erzaehltakt)")
        let plan = StructureParser.parseScenes("""
        SZENE|1|Mira|Imkerei|Morgen|Sie will die Stoecke oeffnen|Polizei sperrt ab|Sie wird abgewiesen|Szene
        SZENE|2|Mira|Auto|Mittag|-|-|Sie entscheidet sich fuer den Anwalt|Nachklang
        SZENE|3|Mira|Kanzlei|Nachmittag|Sie will Akteneinsicht|Anwalt blockt|Sie erfaehrt vom Testament|Szene
        """)
        pruefe("drei Szenen geplant", plan.count == 3, "\(plan.count)")
        pruefe("Takt wird gelesen", plan[1].takt == "Nachklang", "\(plan[1].takt)")
        pruefe("Nachklang wird erkannt", plan[1].istNachklang)
        pruefe("normale Szene ist kein Nachklang", !plan[0].istNachklang && !plan[2].istNachklang)

        let altPlan = StructureParser.parseScenes(
            "SZENE|1|Tom|Kueche|Abend|Er will reden|Sie schweigt|Er geht")
        pruefe("Altplan ohne Takt bleibt lesbar",
               altPlan.count == 1 && !altPlan[0].istNachklang, "\(altPlan.first?.takt ?? "?")")

        print("WANT vs NEED (Figurenbogen)")
        let neu = StructureParser.parseCharacters(
            "FIGUR|Mira|Protagonistin|34|Imkerin|Sie will beweisen, dass die Schwester nicht "
            + "freiwillig ging|Verlassenwerden|Misstrauen|knapp|-|Schwester von Zofia|Zofia "
            + "verschwand 2019|Sie muss aufhoeren, sich schuldig zu fuehlen")
        pruefe("Figur wird gelesen", neu.count == 1, "\(neu.count) Figuren")
        pruefe("Ziel (Want) gefuellt", neu.first?.goal.contains("beweisen") == true)
        pruefe("Inneres Brauchen (Need) gefuellt",
               neu.first?.innerNeed.contains("schuldig") == true, "\(neu.first?.innerNeed ?? "-")")
        pruefe("Want und Need sind verschieden", neu.first?.goal != neu.first?.innerNeed)

        // Altbestand ohne das neue Feld darf nicht brechen.
        let alt = StructureParser.parseCharacters(
            "FIGUR|Tom|Nebenfigur|40|Lehrer|Ruhe|Streit|traege|breit|-|Nachbar|keine")
        pruefe("Altformat ohne Need bleibt lesbar", alt.count == 1 && alt.first?.innerNeed == "",
               "\(alt.first?.innerNeed ?? "?")")

        print("RECHTSCHREIBUNG (Stand nach der Reform 1996)")
        let altschreibung = "Er wußte, daß sie es muß. Ein bißchen Streß, ein Kuß, "
            + "das Schloß am Fluß. Sie läßt es."
        let befund = SpellCheckService.veralteteRechtschreibung(in: altschreibung)
        print("       gefunden: \(befund.map { "\($0.alt)→\($0.neu)" }.joined(separator: ", "))")
        pruefe("Vor-1996-Formen werden gefunden", befund.count >= 8, "\(befund.count)")
        let korrigiert = SpellCheckService.korrigiereVeralteteRechtschreibung(altschreibung)
        print("       korrigiert: \(korrigiert)")
        pruefe("kein scharfes S mehr aus der Altschreibung",
               !korrigiert.contains("daß") && !korrigiert.contains("muß")
                   && !korrigiert.contains("wußte") && !korrigiert.contains("läßt"), korrigiert)

        // ENTSCHEIDEND: korrekte ß-Woerter duerfen NIE angefasst werden.
        let korrektesSZ = "Auf der Straße war es heiß. Sie saß am Fuß der großen Eiche, "
            + "vergaß den Gruß und aß ein süßes Stück. Er ließ sie in Maßen weiß werden."
        let unveraendert = SpellCheckService.korrigiereVeralteteRechtschreibung(korrektesSZ)
        pruefe("korrektes scharfes S bleibt unangetastet", unveraendert == korrektesSZ,
               "veraendert zu: \(unveraendert)")
        pruefe("korrektes scharfes S wird nicht gemeldet",
               SpellCheckService.veralteteRechtschreibung(in: korrektesSZ).isEmpty)

        // Und der Weg durch humanizeProse muss es ebenfalls korrigieren.
        let durchPipeline = AutonomousContentQuality.humanizeProse("Er wußte, daß sie kommt.")
        pruefe("humanizeProse korrigiert die Altschreibung",
               !durchPipeline.contains("wußte") && !durchPipeline.contains("daß"), durchPipeline)

        print("TELEMETRIE")
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("nf_telemetrie_probe", isDirectory: true)
        try? FileManager.default.removeItem(at: tmp)
        try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
        for (i, pruefung) in ["Bilderflut", "Bilderflut", "Satzreparatur"].enumerated() {
            ProductionTelemetry.anhaengen(.init(
                zeit: "2026-08-09T12:0\(i):00Z", lauf: "probe", projekt: "Testbuch",
                phase: "Rohfassung", bereich: "K1/S\(i + 1)", pruefung: pruefung,
                schwere: "Warnung", ergebnis: "Beispielbefund"), in: tmp)
        }
        let datei = tmp.appendingPathComponent("probe.jsonl")
        let zeilen = (try? String(contentsOf: datei, encoding: .utf8))?
            .split(separator: "\n").count ?? 0
        pruefe("drei Befunde angehaengt (JSONL)", zeilen == 3, "Zeilen: \(zeilen)")
        let haeufig = ProductionTelemetry.haeufigkeiten(inDatei: datei)
        print("       Auswertung: \(haeufig.map { "\($0.pruefung) \($0.anzahl)x" }.joined(separator: ", "))")
        pruefe("Haeufigkeit je Pruefung wird ausgewertet",
               haeufig.first?.pruefung == "Bilderflut" && haeufig.first?.anzahl == 2, "\(haeufig)")
        pruefe("kein Manuskripttext im Eintrag",
               !(try! String(contentsOf: datei, encoding: .utf8)).contains("Summton"))
        try? FileManager.default.removeItem(at: tmp)

        print("")
        print("ALLE \(bestanden) PRUEFUNGEN BESTANDEN")
    }
}
