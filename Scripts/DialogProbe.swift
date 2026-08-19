import Foundation

/// Kalibrierung und Prüfung der Subtext-Messung.
///
/// Druckt für jedes Frage-Antwort-Paar die gemessene Überlappung und prüft danach, dass
/// `DialogSubtext.ueberlappungsSchwelle` mit Abstand zwischen beiden Gruppen liegt.
///
///   SRC=$(find Sources/NovelForge -name '*.swift' ! -name 'NovelForgeApp.swift' | tr '\n' ' ')
///   swiftc -wmo -parse-as-library -module-name Probe -o /tmp/dp Scripts/DialogProbe.swift ${=SRC}
@main
struct DialogProbe {

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

    /// Baut einen Prosaabsatz mit deutscher Rede-Auszeichnung.
    static func gespraech(_ zeilen: [String]) -> String {
        zeilen.enumerated().map { i, z in
            "\u{201E}\(z)\u{201C} \(i % 2 == 0 ? "sagte sie." : "sagte er.")"
        }.joined(separator: "\n")
    }

    static func main() {
        print("DIALOG-SUBTEXT – Kalibrierung\n")

        // ------------------------------------------------------------------
        // 1. MESSUNG DER UEBERLAPPUNG
        // ------------------------------------------------------------------
        print("GEMESSENE UEBERLAPPUNG (Frage → Antwort)")

        func wert(_ frage: String, _ antwort: String) -> Double {
            EreignisRegister.uebereinstimmung(
                EreignisRegister.inhaltswoerter(frage),
                EreignisRegister.inhaltswoerter(antwort))
        }

        // Direkte Antworten OHNE Partikel – hier muss die Ueberlappung greifen.
        let direkt: [(String, String)] = [
            ("Wo warst du gestern Abend?", "Ich war gestern Abend bei Thomas."),
            ("Wer hat den Brief geoeffnet?", "Den Brief hat mein Vater geoeffnet."),
            ("Warum hast du das Boot verkauft?", "Ich habe das Boot verkauft, weil ich Geld brauchte."),
            ("Wann kommt der Anwalt zurueck?", "Der Anwalt kommt am Freitag zurueck."),
        ]

        // Ausweichend: Themenwechsel, Nicht-Antwort, Antwort auf etwas anderes.
        let ausweichend: [(String, String)] = [
            ("Wo warst du gestern Abend?", "Der Kaffee ist kalt geworden."),
            ("Wer hat den Brief geoeffnet?", "Es regnet seit heute Morgen ununterbrochen."),
            ("Warum hast du das Boot verkauft?", "Du hast dich nie dafuer interessiert."),
            ("Liebst du mich noch?", "Ich habe den Tisch schon reserviert."),
        ]

        var minDirekt = 1.0, maxAusweichend = 0.0
        for (f, a) in direkt {
            let w = wert(f, a); minDirekt = min(minDirekt, w)
            print(String(format: "       DIREKT     %.2f  %@", w, a))
        }
        for (f, a) in ausweichend {
            let w = wert(f, a); maxAusweichend = max(maxAusweichend, w)
            print(String(format: "       AUSWEICHEND %.2f  %@", w, a))
        }
        print(String(format: "       → direkt ab %.2f, ausweichend bis %.2f, Schwelle %.2f",
                     minDirekt, maxAusweichend, DialogSubtext.ueberlappungsSchwelle))

        pruefe("Schwelle trennt beide Gruppen",
               DialogSubtext.ueberlappungsSchwelle > maxAusweichend
                && DialogSubtext.ueberlappungsSchwelle <= minDirekt,
               String(format: "ausweichend bis %.2f, direkt ab %.2f", maxAusweichend, minDirekt))
        pruefe("Abstand zu den Ausweichenden >= 0,10",
               DialogSubtext.ueberlappungsSchwelle - maxAusweichend >= 0.10,
               String(format: "%.2f", DialogSubtext.ueberlappungsSchwelle - maxAusweichend))

        // ------------------------------------------------------------------
        // 2. EINZELNE ANTWORTEN
        // ------------------------------------------------------------------
        print("\nEINZELURTEIL")
        pruefe("Ja gilt als direkt",
               DialogSubtext.istDirekteAntwort(auf: "Hast du den Brief gelesen?", antwort: "Ja, gestern."))
        pruefe("Nein gilt als direkt",
               DialogSubtext.istDirekteAntwort(auf: "Kommst du mit ins Haus?", antwort: "Nein."))
        pruefe("Gegenfrage gilt nie als direkt",
               !DialogSubtext.istDirekteAntwort(auf: "Wo warst du gestern Abend?",
                                                antwort: "Warum fragst du mich das gerade jetzt?"))
        pruefe("Gegenfrage mit gleichen Woertern gilt nicht als direkt",
               !DialogSubtext.istDirekteAntwort(auf: "Wo warst du gestern Abend?",
                                                antwort: "Wo warst du denn gestern Abend?"))
        pruefe("Vielleicht gilt nicht als direkt",
               !DialogSubtext.istDirekteAntwort(auf: "Kommst du zur Beerdigung?",
                                                antwort: "Vielleicht. Das haengt davon ab."))
        pruefe("Themenwechsel gilt nicht als direkt",
               !DialogSubtext.istDirekteAntwort(auf: "Wo warst du gestern Abend?",
                                                antwort: "Der Kaffee ist kalt geworden."))
        pruefe("wortwoertliche Antwort gilt als direkt",
               DialogSubtext.istDirekteAntwort(auf: "Wo warst du gestern Abend?",
                                               antwort: "Ich war gestern Abend bei Thomas."))
        pruefe("leere Antwort gilt nicht als direkt",
               !DialogSubtext.istDirekteAntwort(auf: "Wo warst du?", antwort: "   "))

        // ------------------------------------------------------------------
        // 3. REPLIKEN AUS PROSA
        // ------------------------------------------------------------------
        print("\nREPLIKEN AUS PROSA")
        let text = gespraech([
            "Wo warst du gestern Abend?",
            "Ich war gestern Abend bei Thomas.",
            "Und was habt ihr da gemacht?",
            "Wir haben ueber das Haus gesprochen.",
        ])
        let reden = DialogSubtext.repliken(in: text)
        pruefe("vier Repliken erkannt", reden.count == 4, "\(reden.count)")
        pruefe("Reihenfolge bleibt erhalten", reden.first == "Wo warst du gestern Abend?")
        let paare = DialogSubtext.fragePaare(in: text)
        pruefe("zwei Frage-Paare gebildet", paare.count == 2, "\(paare.count)")
        pruefe("kurzer Einwurf zaehlt nicht als Frage",
               DialogSubtext.fragePaare(in: gespraech(["Wie bitte?", "Nichts."])).isEmpty)

        // ------------------------------------------------------------------
        // 4. GANZE SZENEN
        // ------------------------------------------------------------------
        print("\nSZENEN-URTEIL")

        let verhoer = gespraech([
            "Wo warst du gestern Abend?", "Ich war gestern Abend bei Thomas.",
            "Wer hat den Brief geoeffnet?", "Den Brief hat mein Vater geoeffnet.",
            "Wann kommt der Anwalt zurueck?", "Der Anwalt kommt am Freitag zurueck.",
            "Hast du das Geld genommen?", "Ja, ich habe das Geld genommen.",
            "Warum hast du das Boot verkauft?", "Ich habe das Boot verkauft, weil ich Geld brauchte.",
        ])
        let kVerhoer = DialogSubtext.messe(in: verhoer)
        print(String(format: "       Verhoer:   %d Fragen, %d direkt (%.0f %%)",
                     kVerhoer.fragen, kVerhoer.direkt, kVerhoer.anteilDirekt * 100))
        pruefe("Verhoerprotokoll wird erkannt", kVerhoer.istVerhoerprotokoll,
               String(format: "%.2f", kVerhoer.anteilDirekt))
        pruefe("Verhoer bekommt einen Befund",
               DialogSubtext.befund(in: verhoer)?.contains("Verhör") == true,
               DialogSubtext.befund(in: verhoer) ?? "-")

        let gut = gespraech([
            "Wo warst du gestern Abend?", "Der Kaffee ist kalt geworden.",
            "Wer hat den Brief geoeffnet?", "Ja, ich war es.",
            "Wann kommt der Anwalt zurueck?", "Fragst du das wegen des Hauses?",
            "Hast du das Geld genommen?", "Du hast mir nie geglaubt.",
            "Warum hast du das Boot verkauft?", "Ich habe das Boot verkauft, weil ich Geld brauchte.",
        ])
        let kGut = DialogSubtext.messe(in: gut)
        print(String(format: "       Gut:       %d Fragen, %d direkt (%.0f %%)",
                     kGut.fragen, kGut.direkt, kGut.anteilDirekt * 100))
        pruefe("guter Dialog gilt nicht als Verhoer", !kGut.istVerhoerprotokoll)
        pruefe("guter Dialog gilt nicht als beliebig", !kGut.istBeliebig)
        pruefe("guter Dialog bekommt keinen Befund", DialogSubtext.befund(in: gut) == nil,
               DialogSubtext.befund(in: gut) ?? "-")

        let beliebig = gespraech([
            "Wo warst du gestern Abend?", "Der Kaffee ist kalt geworden.",
            "Wer hat den Brief geoeffnet?", "Es regnet seit heute Morgen.",
            "Wann kommt der Anwalt zurueck?", "Fragst du das wegen des Hauses?",
            "Hast du das Geld genommen?", "Du hast mir nie geglaubt.",
            "Warum hast du das Boot verkauft?", "Der Hund muss noch raus.",
        ])
        let kBeliebig = DialogSubtext.messe(in: beliebig)
        print(String(format: "       Beliebig:  %d Fragen, %d direkt (%.0f %%)",
                     kBeliebig.fragen, kBeliebig.direkt, kBeliebig.anteilDirekt * 100))
        pruefe("Beliebigkeit wird erkannt", kBeliebig.istBeliebig)
        pruefe("Beliebigkeit bekommt einen Befund",
               DialogSubtext.befund(in: beliebig)?.contains("beliebig") == true,
               DialogSubtext.befund(in: beliebig) ?? "-")

        // ------------------------------------------------------------------
        // 5. KEINE AUSSAGE OHNE DATENGRUNDLAGE
        // ------------------------------------------------------------------
        print("\nDATENGRUNDLAGE")
        let wenig = gespraech([
            "Wo warst du gestern Abend?", "Ich war gestern Abend bei Thomas.",
            "Wer hat den Brief geoeffnet?", "Den Brief hat mein Vater geoeffnet.",
        ])
        let kWenig = DialogSubtext.messe(in: wenig)
        pruefe("zwei Fragen sind nicht belastbar", !kWenig.belastbar, "\(kWenig.fragen) Fragen")
        pruefe("zu wenig Daten erzeugt keinen Befund", DialogSubtext.befund(in: wenig) == nil)
        pruefe("Text ohne Dialog erzeugt keinen Befund",
               DialogSubtext.befund(in: "Sie ging zum Fenster und sah hinaus. Es regnete.") == nil)
        pruefe("Kapitelweise Messung summiert",
               DialogSubtext.messe(inChapters: [verhoer, gut]).fragen
                == kVerhoer.fragen + kGut.fragen)

        print("\n" + (fehler == 0
            ? "ALLE \(geprueft) PRUEFUNGEN BESTANDEN"
            : "\(fehler) VON \(geprueft) PRUEFUNGEN FEHLGESCHLAGEN"))
        if fehler > 0 { exit(1) }
    }
}
