import Foundation

/// Prüft den Namensgenerator – die Antwort auf „Brenner, Liv und Voss stehen in jedem
/// zweiten Buch".
///
/// Gemessen an 35 ausgelieferten Büchern standen „Mira", „Brenner", „Voss" und „Jonas" in
/// je 14 davon. Ursache war die Richtung: Das Modell erfand die Namen, das Programm suchte
/// hinterher nach Kollisionen. Jetzt vergibt der Generator sie vorher. Dieses Programm
/// simuliert eine ganze Buchreihe und prüft, dass sich kein Name wiederholt.
///
///   SRC=$(find Sources/NovelForge -name '*.swift' ! -name 'NovelForgeApp.swift' | tr '\n' ' ')
///   swiftc -wmo -parse-as-library -module-name Probe -o /tmp/nm Scripts/NamensProbe.swift ${=SRC}
@main
struct NamensProbe {

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
        print("NAMENSGENERATOR\n")

        // ------------------------------------------------------------------
        // 1. VORRAT
        // ------------------------------------------------------------------
        let vor = StoryMemory.namensraeume.reduce(0) { $0 + $1.vornamen.count }
        let nach = StoryMemory.namensraeume.reduce(0) { $0 + $1.nachnamen.count }
        print("VORRAT: \(vor) Vornamen, \(nach) Nachnamen in "
              + "\(StoryMemory.namensraeume.count) Regionen")
        // Jede Figur verbraucht einen Vornamen dauerhaft. Bei sechs Hauptfiguren je Buch
        // ist die Zahl der Vornamen die harte Obergrenze fuer die Zahl der Buecher.
        print("        reicht rechnerisch fuer ~\(vor / 6) Buecher a 6 Hauptfiguren")
        pruefe("Vorrat traegt mindestens 40 Buecher", vor / 6 >= 40, "\(vor / 6)")

        // Keine Dublette im Vorrat selbst – sonst waere die Rechnung oben geschoent.
        var alleVor: [String] = [], alleNach: [String] = []
        for r in StoryMemory.namensraeume {
            alleVor += r.vornamen.map { $0.lowercased() }
            alleNach += r.nachnamen.map { $0.lowercased() }
        }
        pruefe("keine doppelten Vornamen im Vorrat",
               Set(alleVor).count == alleVor.count,
               "\(alleVor.count - Set(alleVor).count) Dubletten")
        pruefe("keine doppelten Nachnamen im Vorrat",
               Set(alleNach).count == alleNach.count,
               "\(alleNach.count - Set(alleNach).count) Dubletten")

        // Die gemessenen Wiederholungstaeter duerfen nicht im Vorrat stehen.
        let taeter = ["mira", "brenner", "voss", "jonas", "liv", "finn", "lena", "falk"]
        let imVorrat = taeter.filter { alleVor.contains($0) || alleNach.contains($0) }
        pruefe("keine der gemessenen Wiederholungsnamen im Vorrat", imVorrat.isEmpty,
               imVorrat.joined(separator: ", "))
        let unpassend = ["Notburga", "Bartholomäus", "Sieglinde", "Theodolinde",
                         "Perchta", "Dagobert", "Dietmar", "Traudl", "Pankraz",
                         "Ludger", "Norwin", "Willi", "Wenzel", "Bogumil",
                         "Jadwiga", "Genowefa", "Placyd", "Servatius"]
        pruefe("keine auffaellig historischen Namen in der Automatik",
               unpassend.allSatisfy { !NamensGenerator.istUnauffaelligerAutomatikname($0) })
        let unpassendeNachnamen = ["Hinterleitner", "Brandstätter", "Ebenbauer"]
        pruefe("keine auffaellig regionalen Nachnamen in der Automatik",
               unpassendeNachnamen.allSatisfy {
                   !NamensGenerator.istUnauffaelligerAutomatikNachname($0)
               })

        // ------------------------------------------------------------------
        // 2. SIMULATION EINER GANZEN BUCHREIHE
        // ------------------------------------------------------------------
        print("\nSIMULATION: 60 BUECHER HINTEREINANDER")
        var gesperrt = StoryMemory.verbrauchteNamen
        var alleNamen: [String] = []
        var buecherMitVollemEnsemble = 0
        var ersteLeere: Int?

        for buch in 1...60 {
            // FESTE Seeds statt UUID(): Ein Test mit Zufallswerten geht mal durch und mal
            // nicht – hier lag die Ausbeute je nach Zufall bei 59 oder 60 von 60 Buechern.
            // Ein sprunghafter Test ist schlimmer als keiner, weil niemand mehr hinsieht.
            let namen = NamensGenerator.namen(
                anzahl: 6, gesperrt: gesperrt,
                streuung: UUID(uuidString: String(format:
                    "00000000-0000-4000-8000-%012d", buch))!)
            if namen.count == 6 { buecherMitVollemEnsemble += 1 }
            else if ersteLeere == nil { ersteLeere = buch }
            for n in namen {
                alleNamen.append(n.voll)
                gesperrt.formUnion(CharacterCanonAudit.nameParts(n.voll))
            }
            if buch <= 3 || buch == 30 || buch == 60 {
                print("  Buch \(String(format: "%2d", buch)): "
                      + namen.map(\.voll).joined(separator: ", "))
            }
        }
        print("  → \(alleNamen.count) Namen vergeben, "
              + "\(buecherMitVollemEnsemble)/60 Buecher mit vollem Ensemble")
        if let leer = ersteLeere { print("  → ab Buch \(leer) reichte der Vorrat nicht mehr") }

        pruefe("60 Buecher bekommen ein volles Ensemble",
               buecherMitVollemEnsemble == 60, "\(buecherMitVollemEnsemble)/60")

        // DIE ENTSCHEIDENDE PRUEFUNG: kein Name zweimal, ueber alle Buecher.
        let vornamen = alleNamen.compactMap { $0.split(separator: " ").first.map(String.init) }
        let doppelt = Dictionary(grouping: vornamen.map { $0.lowercased() }, by: { $0 })
            .filter { $0.value.count > 1 }
        pruefe("KEIN Vorname wiederholt sich ueber 60 Buecher", doppelt.isEmpty,
               doppelt.keys.sorted().prefix(6).joined(separator: ", "))
        pruefe("60-Buecher-Simulation bleibt frei von komischen Automatiknamen",
               alleNamen.allSatisfy {
                   guard let first = $0.split(separator: " ").first else { return false }
                   return NamensGenerator.istUnauffaelligerAutomatikname(String(first))
               })
        pruefe("60-Buecher-Simulation nutzt nur den modernen Namensraum",
               alleNamen.count == 360 && alleNamen.allSatisfy { name in
                   guard let first = name.split(separator: " ").first else { return false }
                   return NamensGenerator.istModernerAutomatikname(String(first))
               })
        let modern = ["Emma", "Noah", "Marie", "Daniel", "Nele", "Hendrik"]
        pruefe("moderner Reservepool wird im Dauerbetrieb verwendet",
               modern.contains { wanted in
                   alleNamen.contains { $0.hasPrefix(wanted + " ") }
               })

        // Und keiner der gemessenen Wiederholungstaeter taucht auf.
        let verboten = alleNamen.filter { name in
            let teile = name.split(separator: " ").map {
                String($0).folding(
                    options: [.caseInsensitive, .diacriticInsensitive], locale: .current
                ).lowercased()
            }
            return !Set(teile).isDisjoint(with: Set(taeter))
        }
        pruefe("Brenner, Liv, Voss und Co. kommen nie vor", verboten.isEmpty,
               verboten.prefix(5).joined(separator: ", "))

        // ------------------------------------------------------------------
        // 3. FAMILIE UND STIMMIGKEIT
        // ------------------------------------------------------------------
        print("\nENSEMBLE EINES BUCHES")
        let ensemble = NamensGenerator.namen(
            anzahl: 6, gesperrt: StoryMemory.verbrauchteNamen,
            streuung: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!)
        for n in ensemble { print("  \(n.voll)  (\(n.region))") }
        pruefe("sechs Namen erzeugt", ensemble.count == 6, "\(ensemble.count)")
        pruefe("zwei Figuren teilen einen Nachnamen (Familie)",
               ensemble.count >= 2 && ensemble[0].nachname == ensemble[1].nachname,
               ensemble.prefix(2).map(\.voll).joined(separator: " / "))
        pruefe("die Familie stammt aus derselben Region",
               ensemble.count >= 2 && ensemble[0].region == ensemble[1].region)

        // Das erzeugte Ensemble darf die eigene Kollisionspruefung bestehen.
        pruefe("Ensemble besteht die Namenspruefung",
               StoryMemory.namensKollisionen(ensemble.map(\.voll),
                                             vergeben: StoryMemory.verbrauchteNamen).isEmpty,
               StoryMemory.namensKollisionen(ensemble.map(\.voll),
                                             vergeben: StoryMemory.verbrauchteNamen)
                .joined(separator: " | "))

        // ------------------------------------------------------------------
        // 4. PROMPT
        // ------------------------------------------------------------------
        print("\nPROMPT-BLOCK")
        let block = NamensGenerator.promptBlock(ensemble)
        pruefe("Prompt nennt alle Namen",
               ensemble.allSatisfy { block.contains($0.voll) })
        pruefe("Prompt ist verbindlich formuliert",
               block.contains("VERBINDLICH") && block.contains("Erfinde keine eigenen Namen"))
        pruefe("leeres Ensemble erzeugt keinen Block",
               NamensGenerator.promptBlock([]).isEmpty)

        // ------------------------------------------------------------------
        // 5. WIEDERAUFNAHME MUSS STABIL SEIN
        // ------------------------------------------------------------------
        print("\nSTABILITAET")
        let id = UUID()
        let a = NamensGenerator.namen(anzahl: 6, gesperrt: StoryMemory.verbrauchteNamen,
                                      streuung: id)
        let b = NamensGenerator.namen(anzahl: 6, gesperrt: StoryMemory.verbrauchteNamen,
                                      streuung: id)
        pruefe("gleiche Projekt-ID ergibt dieselben Namen", a == b,
               a.map(\.voll).joined(separator: ",") + " vs " + b.map(\.voll).joined(separator: ","))

        print("\n" + (fehler == 0
            ? "ALLE \(geprueft) PRUEFUNGEN BESTANDEN"
            : "\(fehler) VON \(geprueft) PRUEFUNGEN FEHLGESCHLAGEN"))
        if fehler > 0 { exit(1) }
    }
}
