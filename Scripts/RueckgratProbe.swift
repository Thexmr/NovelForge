import Foundation

/// Prüft das Roman-Rückgrat: Gegenspieler-Fahrplan, Handlungsmacht, dramatische Frage.
///
/// Die drei Strukturen, die über das ganze Buch reichen statt über die einzelne Szene.
///
///   SRC=$(find Sources/NovelForge -name '*.swift' ! -name 'NovelForgeApp.swift' | tr '\n' ' ')
///   swiftc -wmo -parse-as-library -module-name Probe -o /tmp/rp Scripts/RueckgratProbe.swift ${=SRC}
@main
struct RueckgratProbe {

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

    static func main() {
        print("ROMAN-RUECKGRAT\n")

        // ------------------------------------------------------------------
        // 1. GEGENSPIELER-FAHRPLAN
        // ------------------------------------------------------------------
        print("GEGENSPIELER-FAHRPLAN")

        let plotText = """
        Der Roman folgt Mira, die nach dem Tod ihres Vaters die Imkerei uebernimmt.
        Zentrale dramatische Frage: Kann Mira den Hof halten, ohne zu werden wie ihr Vater?

        GEGENZUG|1|Brenner kauft still die Schulden des Hofes auf|Ein Brief der Bank kommt frueher als sonst
        GEGENZUG|6|Brenner setzt den Gemeinderat unter Druck|Der Nachbar gruesst nicht mehr
        GEGENZUG|11|Brenner laesst den Wegzugang sperren|Ein neues Schloss am Tor
        GEGENZUG|16|Brenner bietet Miras Schwester Geld fuer ihren Anteil|Die Schwester weicht Fragen aus
        GEGENZUG|21|Brenner meldet den Betrieb bei der Aufsicht|Eine Pruefung wird angekuendigt
        """
        let fahrplan = Gegenspieler.parse(plotText)
        pruefe("fuenf Zuege gelesen", fahrplan.zuege.count == 5, "\(fahrplan.zuege.count)")
        pruefe("Zuege sind nach Kapitel sortiert",
               fahrplan.zuege.map(\.abKapitel) == [1, 6, 11, 16, 21])
        pruefe("Spur wird gelesen",
               fahrplan.zuege.first?.spur.contains("Bank") == true)

        pruefe("Kapitel 1 findet den ersten Zug",
               fahrplan.zug(fuerKapitel: 1)?.abKapitel == 1)
        pruefe("Kapitel 10 findet den Zug ab 6",
               fahrplan.zug(fuerKapitel: 10)?.abKapitel == 6)
        pruefe("Kapitel 30 findet den letzten Zug",
               fahrplan.zug(fuerKapitel: 30)?.abKapitel == 21)

        let block = fahrplan.promptBlock(fuerKapitel: 10)
        pruefe("Prompt nennt die Handlung", block.contains("Gemeinderat"))
        pruefe("Prompt nennt die Spur", block.contains("gruesst nicht mehr"))
        pruefe("Prompt verbietet die eigene Szene",
               block.contains("nicht als eigene Szene"))
        pruefe("Prompt erlaubt, dass die Figur nichts merkt",
               block.contains("ob die Hauptfigur davon weiß oder nicht"))

        // Speichern und wieder lesen muss dasselbe ergeben.
        pruefe("Fahrplan uebersteht Speichern und Laden",
               Gegenspieler.parse(fahrplan.gespeichert).zuege == fahrplan.zuege)

        print("\nFAHRPLAN-MAENGEL")
        pruefe("guter Fahrplan hat keine Maengel",
               fahrplan.maengel(kapitelAnzahl: 25).isEmpty,
               fahrplan.maengel(kapitelAnzahl: 25).joined(separator: " | "))

        // Zu wenige Zuege fuer ein langes Buch.
        let duenn = Gegenspieler.parse("""
        GEGENZUG|1|Brenner kauft die Schulden des Hofes auf|Ein Brief der Bank
        GEGENZUG|3|Brenner setzt den Gemeinderat unter Druck|Der Nachbar gruesst nicht
        """)
        let duennMaengel = duenn.maengel(kapitelAnzahl: 50)
        for m in duennMaengel { print("       \(m)") }
        pruefe("zu wenige Zuege werden gemeldet",
               duennMaengel.contains { $0.contains("nur 2 Zuege") || $0.contains("nur 2 Züge") },
               duennMaengel.joined(separator: " | "))
        pruefe("Stillstand im letzten Buchteil wird gemeldet",
               duennMaengel.contains { $0.contains("letzten Buchteil") })

        // Wiederholter Zug: derselbe Schritt zweimal.
        let doppelt = Gegenspieler.parse("""
        GEGENZUG|1|Brenner kauft still die Schulden des Hofes auf|Ein Brief
        GEGENZUG|9|Brenner kauft die Schulden des Hofes still auf|Noch ein Brief
        GEGENZUG|18|Brenner laesst den Wegzugang sperren|Ein neues Schloss
        """)
        let doppeltMaengel = doppelt.maengel(kapitelAnzahl: 20)
        pruefe("wiederholter Zug wird erkannt",
               doppeltMaengel.contains { $0.contains("wiederholt") },
               doppeltMaengel.joined(separator: " | "))

        // Grosse Luecke: Der Gegner steht zu lange still.
        let luecke = Gegenspieler.parse("""
        GEGENZUG|1|Brenner kauft die Schulden auf|Ein Brief
        GEGENZUG|3|Brenner setzt den Rat unter Druck|Kein Gruss
        GEGENZUG|30|Brenner bietet der Schwester Geld|Sie weicht aus
        """)
        pruefe("lange Untaetigkeit wird gemeldet",
               luecke.maengel(kapitelAnzahl: 32).contains { $0.contains("lang nichts") },
               luecke.maengel(kapitelAnzahl: 32).joined(separator: " | "))

        pruefe("leerer Plot ergibt leeren Fahrplan",
               Gegenspieler.parse("Ein Plot ganz ohne Gegenzuege.").istLeer)
        pruefe("leerer Fahrplan erzeugt keinen Prompt-Block",
               Gegenspieler(zuege: []).promptBlock(fuerKapitel: 5).isEmpty)

        // ------------------------------------------------------------------
        // 2. HANDLUNGSMACHT
        // ------------------------------------------------------------------
        print("\nHANDLUNGSMACHT")

        typealias A = Handlungsmacht.Antrieb
        pruefe("Figur wird gelesen", A.lesen("Figur") == .figur)
        pruefe("Gegenspieler wird gelesen", A.lesen("Gegenspieler") == .gegenspieler)
        pruefe("Zufall wird gelesen", A.lesen("Zufall") == .zufall)
        pruefe("Umlaut-Schreibweise wird gelesen", A.lesen("zufällig") == .zufall)
        pruefe("leeres Feld ergibt nichts", A.lesen("") == nil)
        pruefe("Strich ergibt nichts", A.lesen("-") == nil)
        pruefe("Unbekanntes ergibt nichts", A.lesen("irgendwas") == nil)

        // Ausgewogen: Figur treibt gut ein Drittel, Zufall bleibt selten.
        let gut = Handlungsmacht.messe([.figur, .gegenspieler, .figur, .gegenspieler,
                                        .zufall, .figur, .gegenspieler, .gegenspieler,
                                        .figur, .gegenspieler])
        print(String(format: "       ausgewogen: Figur %.0f %%, Zufall %.0f %%",
                     gut.anteilFigur * 100, gut.anteilZufall * 100))
        pruefe("ausgewogenes Buch bekommt keinen Befund",
               Handlungsmacht.befund(gut) == nil, Handlungsmacht.befund(gut) ?? "-")

        // Zuschauerin: Der Figur stoesst alles zu.
        let passiv = Handlungsmacht.messe([.gegenspieler, .gegenspieler, .zufall, .gegenspieler,
                                           .figur, .gegenspieler, .zufall, .gegenspieler,
                                           .gegenspieler, .figur])
        print(String(format: "       passiv:     Figur %.0f %%", passiv.anteilFigur * 100))
        pruefe("passive Hauptfigur wird erkannt",
               Handlungsmacht.befund(passiv)?.contains("Zuschauerin") == true,
               Handlungsmacht.befund(passiv) ?? "-")

        // Kein Gegendruck: Die Figur loest fast alles selbst aus.
        let allmaechtig = Handlungsmacht.messe(Array(repeating: A.figur, count: 9)
                                               + [.gegenspieler])
        pruefe("fehlender Gegendruck wird erkannt",
               Handlungsmacht.befund(allmaechtig)?.contains("entgegen") == true,
               Handlungsmacht.befund(allmaechtig) ?? "-")

        // Beliebigkeit: zu viel Zufall.
        let beliebig = Handlungsmacht.messe([.zufall, .zufall, .zufall, .zufall,
                                             .figur, .figur, .figur, .figur,
                                             .gegenspieler, .gegenspieler])
        pruefe("Zufall als Erzaehlprinzip wird erkannt",
               Handlungsmacht.befund(beliebig)?.contains("beliebig") == true,
               Handlungsmacht.befund(beliebig) ?? "-")

        // Keine Aussage ohne Datengrundlage.
        let wenig = Handlungsmacht.messe([.gegenspieler, .gegenspieler, .zufall])
        pruefe("drei Szenen sind nicht belastbar", !wenig.belastbar)
        pruefe("zu wenig Daten erzeugt keinen Befund", Handlungsmacht.befund(wenig) == nil)

        // Aus dem Szenenplan gelesen, Nachklaenge ausgenommen.
        let plan = StructureParser.parseScenes("""
        SZENE|1|Mira|Hof|Morgen|Sie will den Hof halten|Die Bank mahnt|Sie unterschreibt|Szene|Sie verliert die Ruecklage|Figur
        SZENE|2|Mira|Auto|Mittag|-|-|Sie entscheidet sich|Nachklang|-|Figur
        SZENE|3|Mira|Rathaus|Abend|Sie will den Antrag stellen|Brenner war schneller|Sie wird vertroestet|Szene|Sie verliert die Frist|Gegenspieler
        """)
        let ausPlan = Handlungsmacht.messe(szenen: plan)
        pruefe("Nachklang wird nicht mitgezaehlt", ausPlan.gesamt == 2, "\(ausPlan.gesamt)")
        pruefe("Antriebe aus dem Plan stimmen",
               ausPlan.figur == 1 && ausPlan.gegenspieler == 1)
        pruefe("Preis steht neben dem Antrieb",
               plan.first?.preis == "Sie verliert die Ruecklage", plan.first?.preis ?? "-")

        // ------------------------------------------------------------------
        // 3. DRAMATISCHE FRAGE
        // ------------------------------------------------------------------
        print("\nDRAMATISCHE FRAGE")

        let frage = DramatischeFrage.finde(in: plotText)
        print("       gefunden: \(frage ?? "-")")
        pruefe("markierte Frage wird gefunden",
               frage == "Kann Mira den Hof halten, ohne zu werden wie ihr Vater?",
               frage ?? "-")

        // Ohne Etikett: der erste echte Fragesatz rettet den Plan.
        let ohneEtikett = """
        Mira uebernimmt die Imkerei ihres Vaters. Wird sie den Hof halten koennen, ohne
        dieselben Fehler zu machen wie er? Der Gegenspieler heisst Brenner.
        """
        let frage2 = DramatischeFrage.finde(in: ohneEtikett)
        print("       ohne Etikett: \(frage2 ?? "-")")
        pruefe("Frage ohne Etikett wird gefunden",
               frage2?.hasPrefix("Wird sie den Hof halten") == true, frage2 ?? "-")

        pruefe("kurze Einwuerfe gelten nicht als Buchfrage",
               DramatischeFrage.finde(in: "Was nun? Der Plot geht weiter.") == nil,
               DramatischeFrage.finde(in: "Was nun? Der Plot geht weiter.") ?? "-")
        pruefe("Plot ganz ohne Frage ergibt nichts",
               DramatischeFrage.finde(in: "Ein Plot in Aussagesaetzen. Nichts weiter.") == nil)

        let fragenBlock = DramatischeFrage.promptBlock(frage: frage)
        pruefe("Prompt nennt die Frage", fragenBlock.contains("ohne zu werden wie ihr Vater"))
        pruefe("Prompt verlangt Bezug", fragenBlock.contains("Beiwerk"))
        pruefe("ohne Frage kein Prompt-Block",
               DramatischeFrage.promptBlock(frage: nil).isEmpty)

        print("\n" + (fehler == 0
            ? "ALLE \(geprueft) PRUEFUNGEN BESTANDEN"
            : "\(fehler) VON \(geprueft) PRUEFUNGEN FEHLGESCHLAGEN"))
        if fehler > 0 { exit(1) }
    }
}
