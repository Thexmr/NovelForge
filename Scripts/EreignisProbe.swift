import Foundation

/// Kalibrierung und Prüfung des Ereignis-Registers.
///
/// Die Schwelle in `EreignisRegister.dopplungsSchwelle` ist eine Behauptung, solange sie
/// nicht an echten Szenenplänen gemessen ist. Dieses Programm misst sie: Es druckt für
/// jedes Paar den tatsächlichen Wert und prüft danach, dass die Trennung hält.
///
/// Aufruf:
///   SRC=$(find Sources/NovelForge -name '*.swift' ! -name 'NovelForgeApp.swift' | tr '\n' ' ')
///   swiftc -wmo -parse-as-library -module-name Probe -o /tmp/ep Scripts/EreignisProbe.swift ${=SRC}
@main
struct EreignisProbe {

    static var fehler = 0
    static var geprueft = 0

    static func pruefe(_ name: String, _ bedingung: Bool, _ detail: String = "") {
        geprueft += 1
        if bedingung {
            print("  OK   \(name)")
        } else {
            fehler += 1
            print("  FEHL \(name)\(detail.isEmpty ? "" : "  [\(detail)]")")
        }
    }

    static func szene(_ nr: Int, _ pov: String, _ ort: String, _ ziel: String,
                      _ hindernis: String, _ wendung: String, _ takt: String = "Szene")
        -> PlannedScene {
        var s = PlannedScene(number: nr, perspective: pov, location: ort, time: "Morgen",
                             goal: ziel, obstacle: hindernis, turn: wendung)
        s.takt = takt
        return s
    }

    static func main() {
        print("EREIGNIS-REGISTER – Kalibrierung an Szenenplänen\n")

        // ------------------------------------------------------------------
        // 1. MESSUNG: Wie weit liegen echte Dopplungen und echte Unterschiede
        //    auseinander? Ohne diesen Abstand ist jede Schwelle geraten.
        // ------------------------------------------------------------------
        print("GEMESSENE UEBEREINSTIMMUNG")

        func wert(_ a: PlannedScene, _ b: PlannedScene) -> Double {
            EreignisRegister.uebereinstimmung(
                EreignisRegister.inhaltswoerter(a.goal + " " + a.obstacle + " " + a.turn),
                EreignisRegister.inhaltswoerter(b.goal + " " + b.obstacle + " " + b.turn))
        }

        // Echte Dopplungen: dasselbe Ereignis, anders formuliert.
        let dopplungen: [(String, PlannedScene, PlannedScene)] = [
            ("gleiche Szene, andere Woerter",
             szene(1, "Mira", "Imkerei", "Sie will die Bienenstoecke oeffnen",
                   "Die Polizei hat abgesperrt", "Sie wird abgewiesen"),
             szene(9, "Mira", "Bienenhaus", "Sie moechte die Stoecke oeffnen",
                   "Polizeiabsperrung versperrt den Weg", "Man weist sie ab")),
            ("gleiche Szene, Reihenfolge getauscht",
             szene(2, "Jonas", "Werkstatt", "Er sucht den Brief seines Vaters",
                   "Die Schublade ist verschlossen", "Er findet nur eine Quittung"),
             szene(14, "Jonas", "Werkstatt", "Die verschlossene Schublade haelt ihn auf",
                   "Er sucht den Brief des Vaters", "Uebrig bleibt eine Quittung")),
            ("gleiche Szene, Synonyme",
             szene(3, "Mira", "Hafen", "Sie will das Boot verkaufen",
                   "Der Kaeufer springt ab", "Der Verkauf scheitert"),
             szene(21, "Mira", "Hafen", "Sie moechte das Boot verkaufen",
                   "Der Kaeufer zieht zurueck", "Der Verkauf scheitert")),
        ]

        // Verwandt, aber ein anderes Ereignis – das ist der schwierige Fall.
        let verschieden: [(String, PlannedScene, PlannedScene)] = [
            ("suchen vs. finden",
             szene(4, "Jonas", "Werkstatt", "Er sucht den Schluessel zum Schuppen",
                   "Niemand weiss, wo er liegt", "Die Suche bleibt erfolglos"),
             szene(11, "Jonas", "Schuppen", "Er oeffnet den Schuppen mit dem Schluessel",
                   "Drinnen steht ein fremdes Auto", "Er ruft seine Schwester an")),
            ("gleicher Ort, andere Handlung",
             szene(5, "Mira", "Imkerei", "Sie will die Bienenstoecke oeffnen",
                   "Die Polizei hat abgesperrt", "Sie wird abgewiesen"),
             szene(17, "Mira", "Imkerei", "Sie bringt dem Nachbarn den Honig zurueck",
                   "Er will das Geld nicht annehmen", "Sie bleibt zum Essen")),
            ("gleiche Figur, spaeterer Konflikt",
             szene(6, "Mira", "Kanzlei", "Sie will den Vertrag unterschreiben",
                   "Der Anwalt zoegert", "Sie unterschreibt trotzdem"),
             szene(23, "Mira", "Kanzlei", "Sie will den Vertrag rueckgaengig machen",
                   "Die Frist ist abgelaufen", "Sie verliert das Haus")),
        ]

        var maxVerschieden = 0.0
        var minDopplung = 1.0
        for (name, a, b) in dopplungen {
            let w = wert(a, b)
            minDopplung = min(minDopplung, w)
            print(String(format: "       DOPPLUNG    %.2f  %@", w, name))
        }
        for (name, a, b) in verschieden {
            let w = wert(a, b)
            maxVerschieden = max(maxVerschieden, w)
            print(String(format: "       VERSCHIEDEN %.2f  %@", w, name))
        }
        print(String(format: "       → Dopplungen ab %.2f, Verschiedene bis %.2f, Schwelle %.2f",
                     minDopplung, maxVerschieden, EreignisRegister.dopplungsSchwelle))

        // Beide Abstaende werden geprueft, nicht nur die Lage: Eine Schwelle, die zwar
        // dazwischen liegt, aber an einer Gruppe klebt, kippt beim naechsten Satzbau.
        let luftNachUnten = EreignisRegister.dopplungsSchwelle - maxVerschieden
        let luftNachOben = minDopplung - EreignisRegister.dopplungsSchwelle
        pruefe("Schwelle liegt zwischen beiden Gruppen",
               luftNachUnten > 0 && luftNachOben > 0,
               String(format: "verschieden bis %.2f, Dopplung ab %.2f", maxVerschieden, minDopplung))
        pruefe("Abstand zu den Verschiedenen >= 0,10",
               luftNachUnten >= 0.10, String(format: "%.2f", luftNachUnten))
        pruefe("Abstand zu den Dopplungen >= 0,05",
               luftNachOben >= 0.05, String(format: "%.2f", luftNachOben))

        // ------------------------------------------------------------------
        // 2. VERHALTEN DES REGISTERS
        // ------------------------------------------------------------------
        print("\nREGISTER")

        var register = EreignisRegister()
        let ersteSzene = szene(1, "Mira", "Imkerei", "Sie will die Bienenstoecke oeffnen",
                               "Die Polizei hat abgesperrt", "Sie wird abgewiesen")
        register.erfasse(ersteSzene, kapitel: 3)
        pruefe("Ereignis wird aufgenommen", register.ereignisse.count == 1)

        let wiederholung = szene(2, "Mira", "Bienenhaus", "Sie moechte die Stoecke oeffnen",
                                 "Polizeiabsperrung versperrt den Weg", "Man weist sie ab")
        pruefe("Wiederholung wird erkannt",
               register.bereitsErzaehlt(wiederholung, kapitel: 9) != nil)

        let neu = szene(3, "Mira", "Imkerei", "Sie bringt dem Nachbarn den Honig zurueck",
                        "Er will das Geld nicht annehmen", "Sie bleibt zum Essen")
        pruefe("neues Ereignis laeuft durch",
               register.bereitsErzaehlt(neu, kapitel: 9) == nil)
        register.erfasse(neu, kapitel: 9)   // ab hier kennt das Register zwei Ereignisse

        // Perspektivwechsel: dasselbe Geschehen aus anderen Augen ist ein Stilmittel.
        let ausJonasSicht = szene(4, "Jonas", "Imkerei", "Sie will die Bienenstoecke oeffnen",
                                  "Die Polizei hat abgesperrt", "Sie wird abgewiesen")
        pruefe("anderer POV gilt nicht als Dopplung",
               register.bereitsErzaehlt(ausJonasSicht, kapitel: 9) == nil)

        // Nachklang: verarbeitet die Vorszene, ist selbst kein Ereignis.
        let nachklang = szene(5, "Mira", "Auto", "Sie denkt an die Absperrung",
                              "Die Bienenstoecke bleiben zu", "Sie entscheidet sich fuer den Anwalt",
                              "Nachklang")
        pruefe("Nachklang wird nicht als Dopplung gemeldet",
               register.bereitsErzaehlt(nachklang, kapitel: 9) == nil)
        var registerMitNachklang = EreignisRegister()
        registerMitNachklang.erfasse(nachklang, kapitel: 9)
        pruefe("Nachklang kommt nicht ins Register",
               registerMitNachklang.ereignisse.isEmpty)

        // Zu duenne Angaben duerfen keine Aussage erzwingen.
        let leer = szene(6, "Mira", "Kueche", "-", "-", "-")
        var duenn = EreignisRegister()
        duenn.erfasse(leer, kapitel: 1)
        pruefe("leerer Plan erzeugt kein Ereignis", duenn.ereignisse.isEmpty)
        pruefe("leerer Plan meldet keine Dopplung",
               register.bereitsErzaehlt(leer, kapitel: 1) == nil)

        // ------------------------------------------------------------------
        // 3. GANZER BUCHPLAN
        // ------------------------------------------------------------------
        print("\nBUCHPLAN (Pruefung vor der Produktion)")

        let plan: [(kapitel: Int, szenen: [PlannedScene])] = [
            (3, [ersteSzene, neu]),
            (9, [wiederholung, ausJonasSicht]),
            (12, [szene(1, "Mira", "Hafen", "Sie will das Boot verkaufen",
                        "Der Kaeufer springt ab", "Der Verkauf scheitert")]),
        ]
        let befunde = EreignisRegister.dopplungen(imBuchplan: plan)
        for b in befunde { print("       K\(b.kapitel)/S\(b.szene): \(b.meldung)") }
        pruefe("genau eine Dopplung im Plan gefunden", befunde.count == 1,
               "gefunden: \(befunde.count)")
        pruefe("Dopplung zeigt auf die richtige Szene",
               befunde.first?.kapitel == 9 && befunde.first?.szene == 2)
        pruefe("Meldung nennt die fruehere Fundstelle",
               befunde.first?.meldung.contains("K3/S1") == true,
               befunde.first?.meldung ?? "-")

        // ------------------------------------------------------------------
        // 4. PROMPT-HINWEIS
        // ------------------------------------------------------------------
        print("\nPROMPT-HINWEIS")
        let hinweis = register.bereitsErzaehltHinweis(fuer: "Mira")
        print(hinweis.split(separator: "\n").map { "       \($0)" }.joined(separator: "\n"))
        pruefe("Hinweis nennt die erzaehlten Ereignisse",
               hinweis.contains("Bienenstoecke") && hinweis.contains("Honig"))
        pruefe("Hinweis erlaubt Erinnerung, verbietet Wiederholung",
               hinweis.contains("erinnern") && hinweis.contains("nicht erneut"))
        pruefe("Hinweis fuer unbekannte Figur ist leer",
               register.bereitsErzaehltHinweis(fuer: "Aksel").isEmpty)

        // ------------------------------------------------------------------
        // 5. PREIS (steigender Einsatz)
        // ------------------------------------------------------------------
        print("\nPREIS")

        let mitPreis = StructureParser.parseScenes("""
        SZENE|1|Mira|Imkerei|Morgen|Sie will die Stoecke oeffnen|Polizei sperrt ab|Sie wird abgewiesen|Szene|Sie verliert den Zugang zum Betrieb
        SZENE|2|Mira|Auto|Mittag|-|-|Sie entscheidet sich fuer den Anwalt|Nachklang|Sie gibt die Aussicht auf eine gueetliche Einigung auf
        """)
        pruefe("zwei Szenen gelesen", mitPreis.count == 2, "\(mitPreis.count)")
        pruefe("Preis wird gelesen",
               mitPreis.first?.preis == "Sie verliert den Zugang zum Betrieb",
               mitPreis.first?.preis ?? "-")
        pruefe("Preis der zweiten Szene wird gelesen",
               mitPreis.last?.preis.contains("Einigung") == true)
        pruefe("Takt bleibt neben dem Preis erhalten",
               mitPreis.first?.istNachklang == false && mitPreis.last?.istNachklang == true)

        // Altbestand: Plaene ohne Preisfeld muessen weiter lesbar bleiben.
        let ohnePreis = StructureParser.parseScenes("""
        SZENE|1|Mira|Imkerei|Morgen|Sie will die Stoecke oeffnen|Polizei sperrt ab|Sie wird abgewiesen|Szene
        """)
        pruefe("Altplan ohne Preis bleibt lesbar", ohnePreis.count == 1)
        pruefe("Altplan hat leeren Preis", ohnePreis.first?.preis.isEmpty == true)

        // Wiederholter Preis: derselbe Einsatz zweimal, anders formuliert.
        let preisA = "Sie verliert den Zugang zum Betrieb"
        let preisB = "Der Zugang zu ihrem Betrieb ist fuer sie verloren"
        let preisC = "Sie gibt das Sorgerecht fuer ihre Tochter auf"
        func gleich(_ a: String, _ b: String) -> Double {
            EreignisRegister.uebereinstimmung(EreignisRegister.inhaltswoerter(a),
                                              EreignisRegister.inhaltswoerter(b))
        }
        print(String(format: "       gleicher Preis, andere Worte  %.2f", gleich(preisA, preisB)))
        print(String(format: "       anderer Preis                 %.2f", gleich(preisA, preisC)))
        pruefe("wiederholter Preis wird erkannt",
               gleich(preisA, preisB) >= EreignisRegister.dopplungsSchwelle,
               String(format: "%.2f", gleich(preisA, preisB)))
        pruefe("anderer Preis gilt nicht als Wiederholung",
               gleich(preisA, preisC) < EreignisRegister.dopplungsSchwelle,
               String(format: "%.2f", gleich(preisA, preisC)))

        print("\n" + (fehler == 0
            ? "ALLE \(geprueft) PRUEFUNGEN BESTANDEN"
            : "\(fehler) VON \(geprueft) PRUEFUNGEN FEHLGESCHLAGEN"))
        if fehler > 0 { exit(1) }
    }
}
