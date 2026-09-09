import AppKit
import CoreGraphics
import Foundation

/// Vollcover für das gedruckte Taschenbuch: Rückseite + Buchrücken + Vorderseite
/// in EINER Datei, exakt in den Maßen, die Amazon KDP für den Druck verlangt.
///
/// Warum eigener Dienst: `CoverComposer` baut das eBook-Cover (nur Vorderseite).
/// Beim Druck hängt die Breite von der SEITENZAHL ab – der Buchrücken wächst mit
/// dem Umfang. Ein falsch gerechneter Rücken ist der häufigste Ablehnungsgrund
/// bei KDP, deshalb wird hier exakt gerechnet statt geschätzt.
///
/// KDP-Vorgaben (Zoll, gerendert bei 300 dpi):
///   Beschnitt        0,125" an Ober-, Unter- und Außenkante
///   Gesamthöhe       Endformat-Höhe + 2 × 0,125"
///   Gesamtbreite     2 × Endformat-Breite + Rückenbreite + 2 × 0,125"
///   Rückenbreite     Seitenzahl × Papierfaktor
///   Rückentext       erst ab 79 Seiten erlaubt
///   Barcode-Feld     2,0" × 1,2" unten rechts auf der Rückseite MUSS frei bleiben
enum PrintCoverService {

    static let dpi: CGFloat = 300
    static let bleedInch: CGFloat = 0.125
    static let safeInch: CGFloat = 0.25
    static let barcodeWidthInch: CGFloat = 2.0
    static let barcodeHeightInch: CGFloat = 1.2
    static let spineTextMinPages = 79

    /// Papierstärke pro Blatt in Zoll (KDP-Werte).
    enum Paper: String, CaseIterable {
        case white, cream, color
        var factor: CGFloat {
            switch self {
            case .white: return 0.002252   // Schwarz-Weiß auf weißem Papier
            case .cream: return 0.0025     // Schwarz-Weiß auf cremefarbenem Papier
            case .color: return 0.002347   // Farbdruck
            }
        }
        var german: String {
            switch self {
            case .white: return "weiß"
            case .cream: return "creme"
            case .color: return "Farbe"
            }
        }
    }

    /// Gängige KDP-Endformate. `.fiveByEight` ist das übliche Roman-Format.
    enum TrimSize: String, CaseIterable {
        case fiveByEight = "5x8"
        case fiveQuarterByEight = "5.25x8"
        case fiveHalfByEightHalf = "5.5x8.5"
        case sixByNine = "6x9"

        var widthInch: CGFloat {
            switch self {
            case .fiveByEight: return 5
            case .fiveQuarterByEight: return 5.25
            case .fiveHalfByEightHalf: return 5.5
            case .sixByNine: return 6
            }
        }
        var heightInch: CGFloat {
            switch self {
            case .fiveByEight, .fiveQuarterByEight: return 8
            case .fiveHalfByEightHalf: return 8.5
            case .sixByNine: return 9
            }
        }
        /// Wörter pro Druckseite im üblichen Taschenbuchsatz.
        var wordsPerPage: Int {
            switch self {
            case .fiveByEight: return 280
            case .fiveQuarterByEight, .fiveHalfByEightHalf: return 300
            case .sixByNine: return 330
            }
        }
    }

    /// Alle gerechneten Maße – auch ohne zu zeichnen abrufbar (praktisch zum Prüfen).
    struct Dimensions {
        let trim: TrimSize
        let paper: Paper
        let pages: Int
        let spineInch: CGFloat
        let totalWidthInch: CGFloat
        let totalHeightInch: CGFloat
        let widthPx: Int
        let heightPx: Int
        let spinePx: Int
        var spineTextAllowed: Bool { pages >= spineTextMinPages }

        var summary: String {
            String(format: "%d×%d px @ 300 dpi · Rücken %.4f\" bei %d Seiten",
                   widthPx, heightPx, spineInch, pages)
        }
    }

    /// Übersetzt das Buchformat (Project.trimSizeRaw) in das Druckcover-Format.
    ///
    /// Fehlte diese Übersetzung, lief jeder Wrap im Default 5×8 – auch für Bücher,
    /// deren Buchblock in 6×9 gesetzt war. KDP misst das Cover am Buchblock und
    /// lehnt ein Cover mit falschem Endformat ab. Unbekannte Werte fallen auf das
    /// gängigste Format zurück (6×9 = Projekt-Default).
    static func printTrim(forBookTrimRaw raw: String) -> TrimSize {
        switch raw {
        case "5x8": return .fiveByEight
        case "5.25x8": return .fiveQuarterByEight
        case "5.5x8.5": return .fiveHalfByEightHalf
        default: return .sixByNine
        }
    }

    /// Schätzt die Seitenzahl aus der Wortzahl. KDP druckt nur GERADE Seitenzahlen.
    static func estimatePages(words: Int, trim: TrimSize = .fiveByEight) -> Int {
        let raw = Int(ceil(Double(words) / Double(trim.wordsPerPage))) + 6  // Titelei, Impressum
        let pages = max(24, raw)                                            // KDP-Mindestumfang
        return pages % 2 == 0 ? pages : pages + 1
    }

    /// Rechnet alle Maße aus, ohne zu zeichnen.
    static func dimensions(pages: Int, trim: TrimSize = .fiveByEight, paper: Paper = .white) -> Dimensions {
        let p = max(24, pages)
        let spine = CGFloat(p) * paper.factor
        let width = 2 * trim.widthInch + spine + 2 * bleedInch
        let height = trim.heightInch + 2 * bleedInch
        return Dimensions(
            trim: trim, paper: paper, pages: p,
            spineInch: spine, totalWidthInch: width, totalHeightInch: height,
            widthPx: Int((width * dpi).rounded()),
            heightPx: Int((height * dpi).rounded()),
            spinePx: Int((spine * dpi).rounded())
        )
    }

    // MARK: - Zeichnen

    struct Texts {
        let title: String
        let author: String
        /// Der Haken: der erste Satz des Klappentexts, groß über dem Verkaufstext.
        let hook: String
        /// Der Verkaufstext – auf der Rückseite entscheidet sich der Kauf.
        let blurb: String
    }

    struct Result {
        let jpegURL: URL
        let pdfURL: URL?
        let dimensions: Dimensions
    }

    /// Baut das druckfertige Vollcover als JPEG UND als PDF.
    /// KDP nimmt das Taschenbuch-Cover nur als PDF an – das JPEG dient der Vorschau.
    /// - Parameter artworkURL: dasselbe Motiv wie beim eBook-Cover (ein Buch, ein Bild).
    @discardableResult
    static func makeWrap(artworkURL: URL,
                         pages: Int,
                         trim: TrimSize = .fiveByEight,
                         paper: Paper = .white,
                         texts: Texts,
                         jpegURL: URL,
                         pdfURL: URL?) throws -> Result {
        let dim = dimensions(pages: pages, trim: trim, paper: paper)
        guard let artwork = NSImage(contentsOf: artworkURL) else {
            throw NSError(domain: "PrintCoverService", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Das Motiv konnte nicht geladen werden: \(artworkURL.lastPathComponent)"
            ])
        }
        guard let jpeg = renderJPEG(artwork: artwork, dim: dim, texts: texts) else {
            throw NSError(domain: "PrintCoverService", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Das Druckcover konnte nicht gezeichnet werden."
            ])
        }
        try FileManager.default.createDirectory(at: jpegURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try jpeg.write(to: jpegURL, options: .atomic)

        var writtenPDF: URL? = nil
        if let pdfURL {
            try writePDF(jpegData: jpeg, dim: dim, to: pdfURL)
            writtenPDF = pdfURL
        }
        return Result(jpegURL: jpegURL, pdfURL: writtenPDF, dimensions: dim)
    }

    /// Reine Render-Funktion – ohne Dateisystem, damit sie testbar bleibt.
    static func renderJPEG(artwork: NSImage, dim: Dimensions, texts: Texts) -> Data? {
        let W = CGFloat(dim.widthPx), H = CGFloat(dim.heightPx)
        let bleed = bleedInch * dpi
        let safe = safeInch * dpi
        let trimW = dim.trim.widthInch * dpi
        let trimH = dim.trim.heightInch * dpi
        let spineW = CGFloat(dim.spinePx)

        // Panels im Gesamtbild (AppKit: y = 0 UNTEN).
        let backX = bleed
        let spineX = bleed + trimW
        let frontX = spineX + spineW
        let trimBottom = bleed

        // Direkt in eine Bitmap mit FESTER Pixelgröße zeichnen, nicht über
        // NSImage.lockFocus(): das übernimmt auf Retina-Bildschirmen den Skalierungs-
        // faktor und liefert dann die doppelte Pixelzahl – KDP würde das Cover
        // wegen falscher Maße ablehnen. So ist das Ergebnis geräteunabhängig.
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: dim.widthPx, pixelsHigh: dim.heightPx,
                        // Alpha ist Pflicht: ohne Alphakanal liefert NSGraphicsContext(bitmapImageRep:)
            // nil, weil CoreGraphics für RGB keinen Kontext ohne Alpha anlegt.
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let ctxGraphics = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        bitmap.size = NSSize(width: W, height: H)   // 1 Punkt = 1 Pixel

        let vorher = NSGraphicsContext.current
        NSGraphicsContext.current = ctxGraphics

        // 1) Motiv über die volle Fläche – Vorder- und Rückseite bilden ein Bild.
        drawAspectFill(artwork, in: NSRect(x: 0, y: 0, width: W, height: H))

        // 2) Rückseite gleichmäßig abdunkeln, damit der Verkaufstext sicher lesbar ist.
        NSColor.black.withAlphaComponent(0.72).setFill()
        NSRect(x: 0, y: 0, width: spineX, height: H).fill()

        // 3) Vorderseite: Verläufe oben (Titel) und unten (Autor).
        let rgb = NSColorSpace.deviceRGB
        let frontRect = NSRect(x: frontX, y: 0, width: W - frontX, height: H)
        NSGradient(colors: [NSColor.black.withAlphaComponent(0.0),
                            NSColor.black.withAlphaComponent(0.92),
                            NSColor.black.withAlphaComponent(1.0)],
                   atLocations: [0.0, 0.6, 1.0], colorSpace: rgb)?
            .draw(in: NSRect(x: frontRect.minX, y: H * 0.64, width: frontRect.width, height: H * 0.36), angle: 90)
        NSGradient(colors: [NSColor.black.withAlphaComponent(0.0),
                            NSColor.black.withAlphaComponent(0.92),
                            NSColor.black.withAlphaComponent(1.0)],
                   atLocations: [0.0, 0.6, 1.0], colorSpace: rgb)?
            .draw(in: NSRect(x: frontRect.minX, y: 0, width: frontRect.width, height: H * 0.36), angle: -90)

        // 4) Rückseite beschriften: Haken, Verkaufstext, Autorzeile.
        let textWidth = trimW - 2 * safe
        let barcodeRect = NSRect(x: backX + trimW - safe - barcodeWidthInch * dpi,
                                 y: trimBottom + safe,
                                 width: barcodeWidthInch * dpi,
                                 height: barcodeHeightInch * dpi)

        // Der Rückseitentext darf NIE über sein Panel hinauslaufen. Sonst schiebt er sich
        // unter den Buchrücken und wird dort abgeschnitten – im Druck sähe das aus wie
        // ein Satzfehler. Die Begrenzung erzwingt das unabhängig davon, wie gut die
        // Breitenschätzung des Umbruchs trifft.
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(rect: NSRect(x: backX + safe, y: trimBottom,
                                  width: textWidth, height: trimH)).setClip()

        var cursorY = trimBottom + trimH - safe     // von oben nach unten arbeiten
        if !texts.hook.isEmpty {
            let hookAttr = attributes(size: 54, weight: .bold, color: NSColor(calibratedRed: 0.91, green: 0.78, blue: 0.40, alpha: 1), kern: 2, font: .systemFont)
            let hookBox = NSRect(x: backX + safe, y: trimBottom + safe, width: textWidth, height: cursorY - trimBottom - safe)
            let used = drawWrapped(texts.hook.uppercased(), in: hookBox, topY: cursorY, attributes: hookAttr)
            cursorY -= used + 40
        }
        if !texts.blurb.isEmpty {
            // Der Verkaufstext darf das Barcode-Feld nicht berühren.
            let untereGrenze = barcodeRect.maxY + 70
            let blurbAttr = attributes(size: 40, weight: .regular, color: NSColor(calibratedWhite: 0.94, alpha: 1), kern: 0, font: .serif)
            // Der Haken IST der erste Satz des Klappentexts. Stünde er groß oben und
            // gleich darunter noch einmal als erster Absatz, läse sich die Rückseite
            // wie ein Fehler.
            let norm: (String) -> String = {
                $0.components(separatedBy: .whitespacesAndNewlines)
                    .filter { !$0.isEmpty }.joined(separator: " ").lowercased()
            }
            let hakenNorm = norm(texts.hook)
            let absaetze = texts.blurb.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }.filter { !$0.isEmpty }
                .enumerated()
                .filter { !($0.offset == 0 && !hakenNorm.isEmpty && norm($0.element) == hakenNorm) }
                .map(\.element)
            for absatz in absaetze {
                if cursorY <= untereGrenze { break }
                let box = NSRect(x: backX + safe, y: untereGrenze, width: textWidth, height: cursorY - untereGrenze)
                let used = drawWrapped(absatz, in: box, topY: cursorY, attributes: blurbAttr)
                cursorY -= used + 22
            }
            let autorAttr = attributes(size: 38, weight: .semibold, color: NSColor(calibratedRed: 0.79, green: 0.64, blue: 0.29, alpha: 1), kern: 3, font: .systemFont)
            if cursorY - 50 > barcodeRect.maxY {
                (texts.author.uppercased() as NSString).draw(
                    at: NSPoint(x: backX + safe, y: cursorY - 50), withAttributes: autorAttr)
            }
        }

        NSGraphicsContext.current?.restoreGraphicsState()

        // 5) Barcode-Feld: KDP druckt hier den EAN und empfiehlt ausdrücklich, den
        //    Bereich mit dem eigenen HINTERGRUND zu füllen statt mit Weiß – ein weißer
        //    Kasten sähe im Regal wie ein Druckfehler aus. Freigehalten wird er trotzdem:
        //    die Textausgabe oben endet vor dieser Zone.

        // 6) Buchrücken (erst ab 79 Seiten mit Text).
        NSColor.black.withAlphaComponent(0.82).setFill()
        NSRect(x: spineX, y: 0, width: spineW, height: H).fill()
        if dim.spineTextAllowed {
            drawSpine(title: texts.title, author: texts.author,
                      x: spineX, width: spineW, trimBottom: trimBottom, trimHeight: trimH, safe: safe)
        }

        // 7) Vorderseite: Titel oben, Trennlinie, Autor unten.
        drawFront(title: texts.title, author: texts.author,
                  x: frontX, width: trimW, trimBottom: trimBottom, trimHeight: trimH)

        ctxGraphics.flushGraphics()
        NSGraphicsContext.current = vorher
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
    }

    // MARK: - Teilzeichnungen

    private static func drawFront(title: String, author: String,
                                  x: CGFloat, width: CGFloat, trimBottom: CGFloat, trimHeight: CGFloat) {
        let upper = title.uppercased()
        let size: CGFloat = upper.count <= 12 ? 190 : upper.count <= 20 ? 150 : upper.count <= 30 ? 120 : 96
        let attr = attributes(size: size, weight: .bold, color: NSColor(calibratedWhite: 0.97, alpha: 1), kern: 3, font: .serif, centered: true)
        let top = trimBottom + trimHeight * 0.87
        let box = NSRect(x: x + width * 0.08, y: trimBottom + trimHeight * 0.5,
                         width: width * 0.84, height: trimHeight * 0.37)
        let used = drawWrapped(upper, in: box, topY: top, attributes: attr)

        NSColor(calibratedRed: 0.79, green: 0.64, blue: 0.29, alpha: 1).setFill()
        NSRect(x: x + width / 2 - 95, y: top - used - 44, width: 190, height: 4).fill()

        let autorAttr = attributes(size: 62, weight: .semibold, color: NSColor(calibratedWhite: 0.94, alpha: 1), kern: 8, font: .systemFont, centered: true)
        let autorBox = NSRect(x: x, y: trimBottom + trimHeight * 0.075, width: width, height: 80)
        (author.uppercased() as NSString).draw(in: autorBox, withAttributes: autorAttr)
    }

    private static func drawSpine(title: String, author: String,
                                  x: CGFloat, width: CGFloat,
                                  trimBottom: CGFloat, trimHeight: CGFloat, safe: CGFloat) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let spineSafe = 0.0625 * dpi
        let size = min(64, max(18, width - 2 * spineSafe - 8))
        let shortTitle = title.count > 42 ? String(title.prefix(40)) + "…" : title

        ctx.saveGState()
        ctx.translateBy(x: x + width / 2, y: trimBottom + trimHeight / 2)
        ctx.rotate(by: -.pi / 2)                       // Rückentext läuft von oben nach unten
        let attr = attributes(size: size, weight: .bold, color: NSColor(calibratedWhite: 0.97, alpha: 1), kern: 4, font: .serif, centered: true)
        let s = shortTitle.uppercased() as NSString
        let sz = s.size(withAttributes: attr)
        s.draw(at: NSPoint(x: -sz.width / 2, y: -sz.height / 2), withAttributes: attr)
        ctx.restoreGState()

        ctx.saveGState()
        ctx.translateBy(x: x + width / 2, y: trimBottom + safe)
        ctx.rotate(by: -.pi / 2)
        let aAttr = attributes(size: size * 0.62, weight: .semibold,
                               color: NSColor(calibratedRed: 0.79, green: 0.64, blue: 0.29, alpha: 1), kern: 3, font: .systemFont)
        let a = author.uppercased() as NSString
        let asz = a.size(withAttributes: aAttr)
        // Nach der Drehung zeigt die lokale x-Achse NACH UNTEN. Vom unteren Sicherheits-
        // rand aus in +x zu zeichnen ließ den Autornamen unten aus dem Bild laufen –
        // er muss von dort aus nach OBEN gesetzt werden, also um seine eigene Länge
        // nach hinten versetzt.
        a.draw(at: NSPoint(x: -asz.width, y: -asz.height / 2), withAttributes: aAttr)
        ctx.restoreGState()
    }

    // MARK: - Hilfen

    private enum FontKind { case serif, systemFont }

    private static func attributes(size: CGFloat, weight: NSFont.Weight, color: NSColor,
                                   kern: CGFloat, font kind: FontKind, centered: Bool = false) -> [NSAttributedString.Key: Any] {
        let font: NSFont
        switch kind {
        case .serif:
            // Fett nur, wo es hingehört (Titel, Rücken). Der Verkaufstext auf der
            // Rückseite wird in normaler Schnittstärke gesetzt – durchgehend fetter
            // Fließtext liest sich schwer und wirkt nach Selbstverlag.
            let bold = weight == .bold || weight == .heavy || weight == .black
            font = (bold ? NSFont(name: "Georgia-Bold", size: size) : NSFont(name: "Georgia", size: size))
                ?? NSFont(name: "Georgia", size: size)
                ?? NSFont.systemFont(ofSize: size, weight: weight)
        case .systemFont:
            font = NSFont.systemFont(ofSize: size, weight: weight)
        }
        let para = NSMutableParagraphStyle()
        para.alignment = centered ? .center : .left
        para.lineSpacing = size * 0.16
        return [.font: font, .foregroundColor: color, .kern: kern, .paragraphStyle: para]
    }

    /// Zeichnet Text mit Wortumbruch ab `topY` nach unten und liefert die verbrauchte Höhe.
    @discardableResult
    private static func drawWrapped(_ text: String, in box: NSRect, topY: CGFloat,
                                    attributes attr: [NSAttributedString.Key: Any]) -> CGFloat {
        let s = NSAttributedString(string: text, attributes: attr)
        let height = s.boundingRect(with: NSSize(width: box.width, height: .greatestFiniteMagnitude),
                                    options: [.usesLineFragmentOrigin, .usesFontLeading]).height
        let target = NSRect(x: box.minX, y: max(box.minY, topY - height), width: box.width, height: height)
        s.draw(with: target, options: [.usesLineFragmentOrigin, .usesFontLeading])
        return height
    }

    private static func drawAspectFill(_ image: NSImage, in rect: NSRect) {
        let iw = image.size.width, ih = image.size.height
        guard iw > 0, ih > 0 else { return }
        let scale = max(rect.width / iw, rect.height / ih)
        let w = iw * scale, h = ih * scale
        let target = NSRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
        image.draw(in: target, from: .zero, operation: .copy, fraction: 1.0)
    }

    // MARK: - PDF

    /// Wandelt ein Bild in den Druckfarbraum CMYK.
    ///
    /// KDP verlangt für den Druck ein PDF „in Druckqualität mit CMYK-Farbprofil"
    /// (so steht es in der offiziellen Cover-Vorlage). Ein RGB-PDF wird zwar meist
    /// angenommen, aber die Farbumrechnung übernimmt dann Amazon – das Ergebnis
    /// weicht dann von dem ab, was hier zu sehen war.
    private static func toCMYK(_ image: CGImage) -> CGImage? {
        guard let cmyk = CGColorSpace(name: CGColorSpace.genericCMYK) else { return nil }
        guard let ctx = CGContext(data: nil,
                                  width: image.width, height: image.height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cmyk,
                                  bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage()
    }

    /// Schreibt das Cover als druckfertiges PDF in exakter Seitengröße.
    /// KDP misst genau daran, ob Rücken und Beschnitt stimmen (1 Punkt = 1/72 Zoll).
    static func writePDF(jpegData: Data, dim: Dimensions, to url: URL) throws {
        let mediaBox = CGRect(x: 0, y: 0,
                              width: dim.totalWidthInch * 72,
                              height: dim.totalHeightInch * 72)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        var box = mediaBox
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else {
            throw NSError(domain: "PrintCoverService", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Das Cover-PDF konnte nicht angelegt werden: \(url.path)"
            ])
        }
        guard let src = CGImageSourceCreateWithData(jpegData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
            throw NSError(domain: "PrintCoverService", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Das Cover-JPEG konnte nicht gelesen werden."
            ])
        }
        ctx.beginPDFPage(nil)
        ctx.draw(toCMYK(image) ?? image, in: mediaBox)
        ctx.endPDFPage()
        ctx.closePDF()
    }
}
