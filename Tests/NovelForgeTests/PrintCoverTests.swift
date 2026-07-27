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

        // Das Barcode-Feld MUSS weiß und leer sein – dort druckt Amazon den EAN.
        let dpi = PrintCoverService.dpi
        let x = Int((PrintCoverService.bleedInch + dim.trim.widthInch - PrintCoverService.safeInch
                     - PrintCoverService.barcodeWidthInch / 2) * dpi)
        let yFromBottom = Int((PrintCoverService.bleedInch + PrintCoverService.safeInch
                               + PrintCoverService.barcodeHeightInch / 2) * dpi)
        let mitte = try XCTUnwrap(rep.colorAt(x: x, y: rep.pixelsHigh - yFromBottom))
        XCTAssertGreaterThan(mitte.whiteComponent, 0.9, "Barcode-Feld ist nicht frei")
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
