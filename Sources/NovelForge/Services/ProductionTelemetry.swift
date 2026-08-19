import Foundation

/// Schreibt jeden Qualitätsbefund als eine Zeile JSON mit.
///
/// **Warum es das gibt.** Es existieren rund 90 Prüfungen und 79 Befundstellen, aber
/// gespeichert wurde bisher genau EIN String in UserDefaults: der letzte Zwischenfall
/// (`ProductionIncidentStore`). Damit ließ sich nicht beantworten, welches Gate wie oft
/// feuert, welche Reparatur einen Befund wirklich auflöst und welche nur Tokens
/// verbrennt. Jede Schwellenänderung war deshalb geraten.
///
/// **Was hier NICHT passiert.** Kein Manuskripttext. Gespeichert werden Kennung, Phase,
/// Kapitel/Szene, Prüfungsname, Schweregrad und eine gekürzte Ergebniszeile – genug für
/// Statistik, zu wenig für einen Nachdruck des Buches.
///
/// **Robustheit.** Die Telemetrie darf eine Produktion niemals stören: Alle Fehler
/// werden geschluckt, es wird nie geworfen, und ein nicht beschreibbarer Ordner
/// deaktiviert sie still.
enum ProductionTelemetry {

    /// Eine Befundzeile. `Codable`, damit das Format stabil bleibt.
    struct Eintrag: Codable {
        let zeit: String
        let lauf: String
        let projekt: String
        let phase: String
        let bereich: String
        let pruefung: String
        let schwere: String
        let ergebnis: String
    }

    /// Kennung des laufenden Produktionslaufs. Wird beim Start gesetzt; ohne sie
    /// schreibt die Telemetrie in eine Datei „ohne-lauf“.
    @MainActor private static var laufID: String = "ohne-lauf"

    /// Einmal pro Produktionslauf setzen. Danach landen alle Befunde in einer Datei.
    @MainActor
    static func starteLauf(_ id: String) {
        laufID = id.isEmpty ? "ohne-lauf" : id
    }

    /// Zielordner. Liegt neben den übrigen App-Daten und wird bei Bedarf angelegt.
    static func ordner() -> URL? {
        guard let basis = FileManager.default.urls(for: .applicationSupportDirectory,
                                                   in: .userDomainMask).first else { return nil }
        let ziel = basis.appendingPathComponent("NovelForge/telemetrie", isDirectory: true)
        if !FileManager.default.fileExists(atPath: ziel.path) {
            try? FileManager.default.createDirectory(at: ziel, withIntermediateDirectories: true)
        }
        return FileManager.default.fileExists(atPath: ziel.path) ? ziel : nil
    }

    /// Eine Zeile anhängen. Schluckt jeden Fehler.
    @MainActor
    static func schreibe(projekt: String, phase: String, bereich: String,
                         pruefung: String, schwere: String, ergebnis: String) {
        let eintrag = Eintrag(
            zeit: ISO8601DateFormatter().string(from: Date()),
            lauf: laufID,
            projekt: projekt,
            phase: phase,
            bereich: bereich,
            pruefung: pruefung,
            schwere: schwere,
            ergebnis: String(ergebnis.prefix(240))
        )
        anhaengen(eintrag)
    }

    /// Trennung von der @MainActor-Fassade, damit die Datei-Arbeit testbar bleibt.
    static func anhaengen(_ eintrag: Eintrag, in verzeichnis: URL? = nil) {
        guard let ziel = verzeichnis ?? ordner() else { return }
        guard let daten = try? JSONEncoder().encode(eintrag),
              var zeile = String(data: daten, encoding: .utf8) else { return }
        zeile += "\n"
        let datei = ziel.appendingPathComponent("\(eintrag.lauf).jsonl")
        guard let roh = zeile.data(using: .utf8) else { return }
        if let griff = try? FileHandle(forWritingTo: datei) {
            defer { try? griff.close() }
            _ = try? griff.seekToEnd()
            try? griff.write(contentsOf: roh)
        } else {
            try? roh.write(to: datei, options: .atomic)
        }
    }

    // MARK: - Auswertung

    /// Häufigkeit je Prüfung, absteigend. Grundlage für die Frage „welches Gate feuert
    /// überhaupt, und welches nur ins Leere“.
    static func haeufigkeiten(inDatei datei: URL) -> [(pruefung: String, anzahl: Int)] {
        guard let inhalt = try? String(contentsOf: datei, encoding: .utf8) else { return [] }
        var zaehler: [String: Int] = [:]
        let decoder = JSONDecoder()
        for zeile in inhalt.split(separator: "\n") {
            guard let daten = zeile.data(using: .utf8),
                  let eintrag = try? decoder.decode(Eintrag.self, from: daten) else { continue }
            zaehler[eintrag.pruefung, default: 0] += 1
        }
        return zaehler.sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .map { (pruefung: $0.key, anzahl: $0.value) }
    }
}
