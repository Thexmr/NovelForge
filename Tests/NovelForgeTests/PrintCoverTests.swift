import AppKit
import XCTest
@testable import NovelForge

/// Prüft die Maßrechnung des Druckcovers gegen die KDP-Formeln und stellt sicher,
/// dass das gerenderte Vollcover wirklich in der berechneten Größe herauskommt.
/// Ein falsch gerechneter Buchrücken ist der häufigste Ablehnungsgrund bei KDP –
/// deshalb ist das hier festgenagelt und nicht dem Zufall überlassen.
final class PrintCoverTests: XCTestCase {

    func testSpineAndTotalSizeFollowKDPFormula() {
        let d = PrintCoverService.dimensions(pages: 500, trim: .fiveByEight, paper: .white)
        // 500 Blatt × 0,002252" = 1,126"
        XCTAssertEqual(d.spineInch, 1.126, accuracy: 0.0001)
        // 2 × 5" + 1,126" + 2 × 0,125" Beschnitt
        XCTAssertEqual(d.totalWidthInch, 11.376, accuracy: 0.0001)
        XCTAssertEqual(d.totalHeightInch, 8.25, accuracy: 0.0001)
        XCTAssertEqual(d.widthPx, 3413)
        XCTAssertEqual(d.heightPx, 2475)
        XCTAssertTrue(d.spineTextAllowed)
    }

    /// Werte aus der offiziellen KDP-Cover-Vorlage
    /// PAPERBACK_6.000x9.000_500_STANDARD_WHITE_de_DE:
    ///   Gesamtabmessungen 13.376" x 9.250"  (339.75 mm x 234.95 mm)
    ///   Buchrückenbreite  1.126"            (28.60 mm)
    /// Weicht die Rechnung davon ab, lehnt KDP das Cover ab.
    func testMatchesOfficialKDPTemplate6x9With500Pages() {
        let d = PrintCoverService.dimensions(pages: 500, trim: .sixByNine, paper: .white)
        XCTAssertEqual(d.spineInch, 1.126, accuracy: 0.0001, "Buchrückenbreite")
        XCTAssertEqual(d.totalWidthInch, 13.376, accuracy: 0.0001, "Gesamtbreite")
        XCTAssertEqual(d.totalHeightInch, 9.250, accuracy: 0.0001, "Gesamthöhe")
        // Gegenprobe in Millimetern, wie sie in der Vorlage stehen.
        XCTAssertEqual(String(format: "%.2f", d.totalWidthInch * 25.4), "339.75")
        XCTAssertEqual(String(format: "%.2f", d.totalHeightInch * 25.4), "234.95")
        XCTAssertEqual(String(format: "%.2f", d.spineInch * 25.4), "28.60")
    }

    func testPanelsFillCanvasExactly() throws {
        // Links Rückseite, mittig Buchrücken, rechts Vorderseite – und die Teile müssen
        // die Leinwand GENAU ausfüllen. Rundet man die Teile einzeln und addiert sie,
        // steht die Vorderseite je nach Format ein Pixel über den Rand hinaus.
        for (trim, pages) in [(PrintCoverService.TrimSize.sixByNine, 500),
                              (.fiveByEight, 48),
                              (.fiveHalfByEightHalf, 300)] {
            let d = PrintCoverService.dimensions(pages: pages, trim: trim)
            let bleed = Int((PrintCoverService.bleedInch * PrintCoverService.dpi).rounded())
            let trimW = Int((trim.widthInch * PrintCoverService.dpi).rounded())
            let frontX = d.widthPx - bleed - trimW
            let spineX = bleed + trimW
            XCTAssertGreaterThan(frontX, spineX, "\(trim.rawValue): Buchrücken liegt nicht zwischen den Deckeln")
            XCTAssertEqual(frontX + trimW + bleed, d.widthPx,
                           "\(trim.rawValue): Vorderseite endet nicht bündig am rechten Rand")
            XCTAssertLessThanOrEqual(abs((frontX - spineX) - d.spinePx), 1,
                                     "\(trim.rawValue): gezeichneter Rücken weicht von der Rechnung ab")
        }
    }

    func testSpineTextForbiddenBelow79Pages() {
        // KDP erlaubt Text auf dem Buchrücken erst ab 79 Seiten.
        XCTAssertFalse(PrintCoverService.dimensions(pages: 60).spineTextAllowed)
        XCTAssertTrue(PrintCoverService.dimensions(pages: 79).spineTextAllowed)
    }

    func testCreamPaperMakesThickerSpine() {
        let weiss = PrintCoverService.dimensions(pages: 400, paper: .white).spineInch
        let creme = PrintCoverService.dimensions(pages: 400, paper: .cream).spineInch
        XCTAssertGreaterThan(creme, weiss, "Cremefarbenes Papier trägt dicker auf")
    }

    func testEstimatedPagesAreAlwaysEven() {
        // KDP druckt nur paarweise – ungerade Seitenzahlen gibt es nicht.
        for words in [30_000, 80_000, 128_192, 1] {
            let pages = PrintCoverService.estimatePages(words: words)
            XCTAssertEqual(pages % 2, 0, "\(words) Wörter ergaben ungerade Seitenzahl \(pages)")
            XCTAssertGreaterThanOrEqual(pages, 24, "KDP verlangt mindestens 24 Seiten")
        }
    }

    func testRenderedWrapHasExactPixelSizeAndFreeBarcodeArea() throws {
        let dim = PrintCoverService.dimensions(pages: 300, trim: .fiveByEight, paper: .white)
        let artwork = NSImage(size: NSSize(width: 800, height: 1200))
        artwork.lockFocus()
        NSColor.darkGray.setFill()
        NSRect(x: 0, y: 0, width: 800, height: 1200).fill()
        artwork.unlockFocus()

        let texts = PrintCoverService.Texts(
            title: "Die Schleusenhalle",
            author: "Dave Demaré",
            hook: "Um 4:12 Uhr bleibt die Schleuse offen.",
            blurb: "Marek kontrolliert seit elf Jahren dieselbe Kammer.\nDann meldet die Anlage einen Druckabfall, den es nicht geben kann.")

        let data = try XCTUnwrap(PrintCoverService.renderJPEG(artwork: artwork, dim: dim, texts: texts))
        let rep = try XCTUnwrap(NSBitmapImageRep(data: data))
        XCTAssertEqual(rep.pixelsWide, dim.widthPx)
        XCTAssertEqual(rep.pixelsHigh, dim.heightPx)

        // Das Barcode-Feld muss TEXTFREI sein – aber nicht weiß: KDP empfiehlt
        // ausdrücklich, dort den eigenen Hintergrund zu zeigen. Geprüft wird deshalb
        // gegen dieselbe Fassung OHNE Rückseitentext: ist der Ausschnitt identisch,
        // wurde dort nichts gezeichnet.
        let ohneText = try XCTUnwrap(PrintCoverService.renderJPEG(
            artwork: artwork, dim: dim,
            texts: .init(title: texts.title, author: texts.author, hook: "", blurb: "")))
        let repOhne = try XCTUnwrap(NSBitmapImageRep(data: ohneText))
        let dpi = PrintCoverService.dpi
        let links = Int((PrintCoverService.bleedInch + dim.trim.widthInch - PrintCoverService.safeInch
                         - PrintCoverService.barcodeWidthInch) * dpi) + 4
        let untenAbstand = Int((PrintCoverService.bleedInch + PrintCoverService.safeInch) * dpi) + 4
        let breite = Int(PrintCoverService.barcodeWidthInch * dpi) - 8
        let hoehe = Int(PrintCoverService.barcodeHeightInch * dpi) - 8
        var maxAbweichung = 0.0
        var y = rep.pixelsHigh - untenAbstand - hoehe
        while y < rep.pixelsHigh - untenAbstand {
            var x = links
            while x < links + breite {
                if let a = rep.colorAt(x: x, y: y), let b = repOhne.colorAt(x: x, y: y) {
                    maxAbweichung = max(maxAbweichung, abs(a.brightnessComponent - b.brightnessComponent))
                }
                x += 16
            }
            y += 16
        }
        XCTAssertLessThan(maxAbweichung, 0.12, "Im Barcode-Feld wurde Text gezeichnet")
    }

    func testPDFHasExactPageSizeInPoints() throws {
        let dim = PrintCoverService.dimensions(pages: 300)
        let artwork = NSImage(size: NSSize(width: 400, height: 600))
        artwork.lockFocus(); NSColor.black.setFill(); NSRect(x: 0, y: 0, width: 400, height: 600).fill(); artwork.unlockFocus()
        let jpeg = try XCTUnwrap(PrintCoverService.renderJPEG(
            artwork: artwork, dim: dim,
            texts: .init(title: "T", author: "A", hook: "", blurb: "")))

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("nf-wrap-test-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: url) }
        try PrintCoverService.writePDF(jpegData: jpeg, dim: dim, to: url)

        let doc = try XCTUnwrap(CGPDFDocument(url as CFURL))
        let page = try XCTUnwrap(doc.page(at: 1))
        let box = page.getBoxRect(.mediaBox)
        // KDP misst die Seitengröße in Punkt (1 pt = 1/72 Zoll).
        XCTAssertEqual(box.width, dim.totalWidthInch * 72, accuracy: 0.5)
        XCTAssertEqual(box.height, dim.totalHeightInch * 72, accuracy: 0.5)
    }
}
