import Foundation

/// MISST FERTIGE BÜCHER MIT DEN PRÜFERN DES PROGRAMMS.
///
/// Der Unterschied zu den anderen Prüfprogrammen: Die messen Testdaten, dieses misst das
/// ausgelieferte Ergebnis. Solange eine Verbesserung nur an erfundenen Beispielen
/// verifiziert ist, weiß niemand, ob sie im Buch ankommt.
///
///   NF_BUECHER=/pfad/zu/txt-dateien
///   swiftc -wmo -parse-as-library -module-name Probe -o /tmp/bs Scripts/BuchScanProbe.swift ${=SRC}
@main
struct BuchScanProbe {

    struct Zeile {
        let titel: String
        let woerter: Int
        let bilder: Double
        let filter: Double
        let fragen: Int
        let direkt: Double
        let dialog: Double
    }

    static func main() {
        let ordner = ProcessInfo.processInfo.environment["NF_BUECHER"] ?? ""
        guard !ordner.isEmpty,
              let dateien = try? FileManager.default.contentsOfDirectory(atPath: ordner) else {
            print("NF_BUECHER nicht gesetzt oder nicht lesbar."); exit(1)
        }

        var zeilen: [Zeile] = []
        for datei in dateien.sorted() where datei.hasSuffix(".txt") {
            guard let text = try? String(contentsOfFile: "\(ordner)/\(datei)", encoding: .utf8)
            else { continue }
            let woerter = text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
            guard woerter > 20_000 else { continue }   // Leseproben und Fragmente raus
            let stil = AutonomousContentQuality.stilKennzahlen(inChapters: [text])
            let subtext = DialogSubtext.messe(in: text)
            zeilen.append(Zeile(
                titel: String(datei.dropLast(4)),
                woerter: woerter,
                bilder: stil.bilder,
                filter: stil.filter,
                fragen: subtext.fragen,
                direkt: subtext.anteilDirekt,
                dialog: AutonomousContentQuality.dialoganteil(in: text)))
        }
        guard !zeilen.isEmpty else { print("Keine Bücher gefunden."); exit(1) }

        // Nach dem auffälligsten Wert sortiert: Was oben steht, kostet am meisten Leser.
        print("BUCH                                     Wörter  Bilder  Filter  Dialog  Fragen  direkt")
        print(String(repeating: "─", count: 88))
        for z in zeilen.sorted(by: { $0.direkt > $1.direkt }) {
            print(String(format: "%-40@ %7d %7.1f %7.1f %6.0f%% %7d %6.0f%%",
                         String(z.titel.prefix(40)) as NSString, z.woerter,
                         z.bilder, z.filter, z.dialog * 100, z.fragen, z.direkt * 100))
        }

        func schnitt(_ f: (Zeile) -> Double) -> Double {
            zeilen.map(f).reduce(0, +) / Double(zeilen.count)
        }
        print(String(repeating: "─", count: 88))
        print(String(format: "%-40@ %7d %7.1f %7.1f %6.0f%% %7d %6.0f%%",
                     "MITTELWERT (\(zeilen.count) Bücher)" as NSString,
                     zeilen.map(\.woerter).reduce(0, +) / zeilen.count,
                     schnitt(\.bilder), schnitt(\.filter), schnitt(\.dialog) * 100,
                     zeilen.map(\.fragen).reduce(0, +) / zeilen.count,
                     schnitt(\.direkt) * 100))

        // Referenz aus 13 gemeinfreien, professionell lektorierten Romanen.
        print("\nREFERENZ (13 gemeinfreie Romane, 1.119.025 Wörter)")
        print("  Bilder je 1000 Wörter   Median 2,5   Maximum 6,9")
        print("  Filterwörter je 1000    Median 0,3   Maximum 0,5")
        print("  Subtext                 Zielband 20–70 % direkt beantwortete Fragen")

        // ------------------------------------------------------------------
        // ERREICHBARKEIT DER FREIGABE-SPERREN.
        //
        // Der eigentliche Zweck dieses Programms. Ein Grenzwert, den kein gutes Buch
        // erreicht, blockiert die Produktion für immer – gefunden wurde genau das beim
        // Bilder-Limit (stand auf 1,0; 34 von 34 Büchern und alle 13 Referenzromane
        // lagen darüber). Deshalb laufen die textbasierten Sperren hier gegen echte
        // Bücher, statt gegen erfundene Beispiele.
        // ------------------------------------------------------------------
        print("\nFREIGABE-SPERREN AN ECHTEN BUECHERN")
        var gesperrt = 0
        for datei in dateien.sorted() where datei.hasSuffix(".txt") {
            guard let text = try? String(contentsOfFile: "\(ordner)/\(datei)", encoding: .utf8),
                  text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count > 20_000
            else { continue }
            // Kapitelweise trennen, damit die kapitelübergreifenden Prüfer arbeiten können.
            let kapitel = text.components(separatedBy: "\n\n")
                .filter { $0.split(separator: " ").count > 200 }
            var gruende: [String] = []
            let stil = AutonomousContentQuality.stilKennzahlen(inChapters: [text])
            if stil.bilder > 5.5 { gruende.append(String(format: "Bilder %.1f", stil.bilder)) }
            if stil.filter > 1.0 { gruende.append(String(format: "Filter %.1f", stil.filter)) }
            let saetze = AutonomousContentQuality.blockingRepeatedSentences(inChapters: kapitel)
            if !saetze.isEmpty { gruende.append("\(saetze.count) Satzdopplungen") }
            let phrasen = AutonomousContentQuality.blockingRepeatedPhrases(inChapters: kapitel)
            if !phrasen.isEmpty { gruende.append("\(phrasen.count) Floskeln") }
            if !gruende.isEmpty {
                gesperrt += 1
                print("  GESPERRT  \(String(datei.dropLast(4)).prefix(38)) — "
                      + gruende.joined(separator: ", "))
            }
        }
        print("  → \(gesperrt) von \(zeilen.count) Büchern würden die Freigabe NICHT bestehen")

        let ueberVerhoer = zeilen.filter { $0.direkt >= DialogSubtext.verhoerSchwelle }
        let ueberBilder = zeilen.filter { $0.bilder > 6.9 }
        let ueberFilter = zeilen.filter { $0.filter > 0.5 }
        print("\nBEFUND")
        print("  \(ueberVerhoer.count) von \(zeilen.count) Büchern über der Verhör-Schwelle (70 % direkt)")
        print("  \(ueberBilder.count) von \(zeilen.count) über dem Bilder-Maximum aller Referenzromane")
        print("  \(ueberFilter.count) von \(zeilen.count) über dem Filterwort-Maximum")
    }
}
