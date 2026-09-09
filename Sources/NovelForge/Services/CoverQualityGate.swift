import Foundation
import AppKit
import Vision

/// COVER-QUALITÄTS-GATE: Bisher wurde das Motiv des Bildmodells ungeprüft übernommen.
/// Die zwei häufigsten, messbaren Cover-Fehler eines Bildmodells sind:
///
/// 1. EINGEBACKENE SCHRIFT – der Prompt verbietet Buchstaben ausdrücklich, aber
///    Bildmodelle malen trotzdem gern verkrüppelte „Titel" oder Schilder ins Motiv.
///    Über so ein Motiv legt der CoverComposer danach die echte Typografie: doppelter
///    Text, der typische KI-Look, auf Amazon sofort als billig erkennbar.
///    Erkennung: Apple Vision OCR (lokal, kostenlos, kein Extra-Modell).
///
/// 2. FLACHE / LEERE MOTIVE – fast einfarbige Flächen oder verwaschene Brei-Bilder,
///    die als Thumbnail zu einem Farbfleck werden. Erkennung: Farb- und
///    Helligkeitsstreuung auf einer kleinen Pixelprobe.
///
/// Alles läuft deterministisch und lokal – kein weiterer KI-Call, keine Kosten,
/// funktioniert auch offline (bis auf die Bildgenerierung selbst).
enum CoverQualityGate {

    /// Erkannte Schrift im Motiv (nur Treffer mit brauchbarer Sicherheit).
    /// Leer = das Motiv ist sauber textfrei.
    static func bakedInText(in imageData: Data) -> [String] {
        guard let source = NSImage(data: imageData)?.cgImage(
            forProposedRect: nil, context: nil, hints: nil
        ) else { return ["Bild nicht dekodierbar"] }

        // Thumbnail-Analyse genügt: OCR auf 1024px-Breite ist schnell und findet
        // covergroße Schrift zuverlässig (winzige Kritzelei interessiert nicht –
        // sie ist im fertigen Cover ohnehin unsichtbar).
        var erkannt: [String] = []
        let request = VNRecognizeTextRequest { request, _ in
            for result in (request.results as? [VNRecognizedTextObservation]) ?? [] {
                guard let kandidat = result.topCandidates(1).first else { continue }
                // Sicherheit ≥ 0.5 und mindestens 4 Buchstaben: Einzelzeichen-Rauschen
                // (ein Ast, der wie ein „T" aussieht) darf kein Cover verwerfen.
                let text = kandidat.string.trimmingCharacters(in: .whitespacesAndNewlines)
                let buchstaben = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
                if kandidat.confidence >= 0.5 && buchstaben.count >= 4 {
                    erkannt.append(text)
                }
            }
        }
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["de-DE", "en-US"]
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: source, options: [:])
        try? handler.perform([request])
        // Doppler entfernen (OCR findet dasselbe Wort gern zweimal in Box-Nachbarn).
        var gesehen = Set<String>()
        return erkannt.filter { wort in
            let schluessel = wort.lowercased()
            return gesehen.insert(schluessel).inserted
        }
    }

    /// Ist das Motiv farblich/tonal flach? Ein gutes Cover-Motiv hat sowohl helle
    /// als auch dunkle Bereiche und mehrere Farbfamilien – sonst wird es im
    /// Thumbnail zu einem undefinierbaren Fleck.
    static func isFlat(_ imageData: Data) -> Bool {
        guard let rep = NSBitmapImageRep(data: imageData) else { return true }
        // Kleine Pixelprobe (64×102 im Cover-Seitenverhältnis) reicht für die
        // Verteilungsstatistik und hält die Prüfung bei jedem Cover im Millisekunden-
        // bereich.
        let breite = 64, hoehe = 102
        guard let ctx = CGContext(
            data: nil, width: breite, height: hoehe,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ), let cg = rep.cgImage else { return true }
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: breite, height: hoehe))
        guard let daten = ctx.data else { return true }
        let pixel = daten.bindMemory(to: UInt8.self, capacity: breite * hoehe * 4)

        var farbEimer = Set<UInt16>()
        var helligkeiten: [Double] = []
        helligkeiten.reserveCapacity(breite * hoehe)
        for i in stride(from: 0, to: breite * hoehe * 4, by: 4) {
            let r = Double(pixel[i]), g = Double(pixel[i + 1]), b = Double(pixel[i + 2])
            helligkeiten.append(0.299 * r + 0.587 * g + 0.114 * b)
            // 4 bit pro Kanal = 4096 mögliche Farbeimer.
            farbEimer.insert(UInt16(Int(r) >> 4) << 8 | UInt16(Int(g) >> 4) << 4 | UInt16(Int(b) >> 4))
        }
        let mittel = helligkeiten.reduce(0, +) / Double(helligkeiten.count)
        let varianz = helligkeiten.reduce(0) { $0 + ($1 - mittel) * ($1 - mittel) }
            / Double(helligkeiten.count)
        let streuung = varianz.squareRoot()

        // Schwellen aus Praxiswerten: Ein normales Motiv (Landschaft, Stillleben,
        // Textur) liegt bei Helligkeitsstreuung ≥ 25 und ≥ 60 Farbeimern; ein
        // verunglücktes Brei-/Nebelbild deutlich darunter. Bewusst niedrig angesetzt,
        // damit bewusst düstere Cover (Horror, Thriller) nicht verworfen werden –
        // die haben trotz Dunkelheit klare Hell-Dunkel-Struktur.
        return streuung < 16 || farbEimer.count < 24
    }

    /// Gesamturteil über ein ROHMOTIV (vor dem Auflegen der Typografie).
    /// Leeres Array = Qualitäts-Gate bestanden.
    static func probleme(motiv imageData: Data) -> [String] {
        var liste: [String] = []
        let schrift = bakedInText(in: imageData)
        if !schrift.isEmpty {
            liste.append("Eingebackene Schrift im Motiv: \(schrift.prefix(4).joined(separator: ", "))")
        }
        if isFlat(imageData) {
            liste.append("Motiv ist farblich/tonal flach – würde als Thumbnail zum Farbfleck")
        }
        return liste
    }
}
