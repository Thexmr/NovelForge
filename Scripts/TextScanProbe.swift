import Foundation

/// Misst ein FERTIGES Manuskript gegen die Lesbarkeits-Prüfungen.
///
/// Zweck: Schwellen und neue Prüfungen an echter Ausgabe belegen statt am Prompt-Wortlaut.
/// Erwartet reinen Text (ein Kapitel oder ein ganzes Buch) über `NF_SCAN_FILE`.
///
///     NF_SCAN_FILE=/pfad/buch.txt ./textscan
@main
enum TextScanProbe {
    static func main() {
        guard let pfad = ProcessInfo.processInfo.environment["NF_SCAN_FILE"],
              let text = try? String(contentsOfFile: pfad, encoding: .utf8) else {
            print("NF_SCAN_FILE fehlt oder ist nicht lesbar")
            exit(2)
        }
        let woerter = text.wordCount
        print("DATEI:   \((pfad as NSString).lastPathComponent)")
        print("UMFANG:  \(woerter) Wörter")
        print("")

        let filter = AutonomousContentQuality.filterwoerter(in: text)
        let filterBudget = max(1, woerter / 500)
        print("FILTERWOERTER (Deep POV)")
        print("  gefunden: \(filter.count)   Budget: \(filterBudget)   \(filter.count > filterBudget ? "ÜBERSCHRITTEN" : "im Rahmen")")
        let filterHaeufig = Dictionary(grouping: filter, by: { $0.stelle.lowercased() })
            .mapValues(\.count).sorted { ($0.value, $1.key) > ($1.value, $0.key) }.prefix(6)
        for (stelle, anzahl) in filterHaeufig { print("    \(anzahl)×  \(stelle)") }
        print("")

        let bilder = AutonomousContentQuality.vergleichsDichte(in: text)
        print("VERGLEICHE")
        print("  gefunden: \(bilder.anzahl)   Budget: \(bilder.budget)   \(bilder.anzahl > bilder.budget ? "ÜBERSCHRITTEN" : "im Rahmen")")
        let je1000 = woerter > 0 ? Double(bilder.anzahl) * 1000.0 / Double(woerter) : 0
        print("  Dichte:   \(String(format: "%.1f", je1000)) je 1000 Wörter")
        for stelle in bilder.stellen.prefix(8) { print("    \(stelle)") }
        print("")

        let kennzahlen = AutonomousContentQuality.stilKennzahlen(inChapters: [text])
        print("FREIGABE-GATE (buchweit)")
        print(String(format: "  Bilder je 1000 Wörter:      %.1f   Grenze: 1,0   %@",
                     kennzahlen.bilder, kennzahlen.bilder > 1.0 ? "BLOCKIERT" : "frei"))
        print(String(format: "  Filterwörter je 1000 W.:    %.1f   Grenze: 1,0   %@",
                     kennzahlen.filter, kennzahlen.filter > 1.0 ? "BLOCKIERT" : "frei"))
        print("")

        let altschreibung = SpellCheckService.veralteteRechtschreibung(in: text)
        print("RECHTSCHREIBUNG")
        print("  Vor-1996-Formen: \(altschreibung.count)   \(altschreibung.isEmpty ? "aktuell" : "VERALTET")")
        if !altschreibung.isEmpty {
            print("      " + altschreibung.prefix(8).map { "\($0.alt)→\($0.neu)" }
                .joined(separator: ", "))
        }
        print("")

        print("MODERNITAET (wuerde NovelForge diesen Text schreiben?)")
        let altmodisch = AutonomousContentQuality.altmodischeWendungen(in: text)
        let fremd = AutonomousContentQuality.schwereFremdwoerter(in: text)
        let archaisch = AutonomousContentQuality.archaicTellCount(text)
        print("  altmodische Wendungen: \(altmodisch.count)   Grenze im Draft-Loop: 1")
        for a in altmodisch.prefix(5) { print("      \(a)") }
        print("  schwere Fremdwörter:   \(fremd.count)   Grenze: 0")
        if !fremd.isEmpty { print("      \(fremd.prefix(6).joined(separator: ", "))") }
        print("  archaische Marker:     \(archaisch)   ab 2 gilt der Text als KI/antiquiert")
        let abgelehnt = altmodisch.count > 1 || !fremd.isEmpty || archaisch >= 2
        print("  ERGEBNIS: \(abgelehnt ? "WUERDE ABGELEHNT" : "wuerde angenommen")")
        print("")

        print("TYPOGRAFIE")
        let gerade = text.filter { $0 == "\u{22}" }.count
        print("  gerade Zoll-Zeichen: \(gerade)   \(gerade > 0 ? "SATZFEHLER" : "sauber")")
        print("")

        // NF_SCAN_FIX=1 schreibt die reparierte Fassung daneben. Nützlich für bereits
        // exportierte Bücher: Typografie und Rechtschreibung lassen sich nachträglich
        // ohne Modellaufruf in Ordnung bringen.
        if ProcessInfo.processInfo.environment["NF_SCAN_FIX"] == "1" {
            var fix = SpellCheckService.korrigiereVeralteteRechtschreibung(text)
            fix = AutonomousContentQuality.vereinheitlicheAnfuehrungszeichen(fix)
            let ziel = pfad + ".korrigiert.txt"
            try? fix.write(toFile: ziel, atomically: true, encoding: .utf8)
            print("REPARIERT -> \((ziel as NSString).lastPathComponent)")
            print("  gerade Zoll-Zeichen danach: \(fix.filter { $0 == "\u{22}" }.count)")
            print("")
        }

        print("WEITERE BEFUNDE")
        let ticks = AutonomousContentQuality.styleTicViolations(in: text)
        if ticks.isEmpty {
            print("  keine")
        } else {
            for t in ticks { print("  - \(t)") }
        }
    }
}
