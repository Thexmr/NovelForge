import AppKit
import XCTest
@testable import NovelForge

/// Stellt sicher, dass ein Cover OHNE Titel und Autornamen als Mangel auffällt.
///
/// Hintergrund: Der Knopf „Cover erzeugen" schrieb das nackte Motiv direkt als fertiges
/// eBook-Cover – der Baustein, der die Typografie auflegt, wurde von der
/// Erzeugungsfunktion nie aufgerufen. Der Selbstbeweis prüfte nur Dateigröße und
/// Pixelmaße, und die waren tadellos. So ging ein Cover ohne ein einziges Wort darauf
/// als fertig durch.
/// Am MainActor, weil die geprüften Typen (PipelineOrchestrator, ProofService,
/// SpellCheckService) dort isoliert sind. Ohne das schlägt schon das Kompilieren
/// fehl – und das fiel lange nicht auf, weil der Test-Schritt der CI
/// `continue-on-error` setzt und dieser Mac kein XCTest hat.
@MainActor
final class CoverLetteringTests: XCTestCase {

    /// Zeichnet ein Motiv mit weichen Verläufen – so, wie es der Bild-Prompt verlangt
    /// (geringe Schärfentiefe, keine harten Kanten).
    private func motiv() -> NSBitmapImageRep {
        let w = 800, h = 1200
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let verlauf = NSGradient(starting: NSColor(white: 0.06, alpha: 1),
                                 ending: NSColor(white: 0.42, alpha: 1))!
        verlauf.draw(in: NSRect(x: 0, y: 0, width: w, height: h), angle: 90)
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    private func mitTypografie() -> NSBitmapImageRep {
        let rep = motiv()
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let titel: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 96), .foregroundColor: NSColor.white]
        let autor: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 44), .foregroundColor: NSColor.white]
        // Der Composer setzt den Autornamen oben, den Titel darunter. In diesem
        // Bitmap-Kontext liegt der Ursprung unten links.
        NSString(string: "DAVE DEMARÉ").draw(at: NSPoint(x: 80, y: 1080), withAttributes: autor)
        NSString(string: "DAS LETZTE").draw(at: NSPoint(x: 60, y: 900), withAttributes: titel)
        NSString(string: "STREICHHOLZ").draw(at: NSPoint(x: 60, y: 790), withAttributes: titel)
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }

    func testNacktesMotivFaelltDurch() {
        let dichte = ProofService.schriftDichte(motiv())
        XCTAssertLessThan(dichte, ProofService.minimaleSchriftDichte,
                          "Ein Motiv ohne jede Schrift wurde als beschriftet durchgewinkt")
    }

    func testCoverMitTitelUndAutorBesteht() {
        let dichte = ProofService.schriftDichte(mitTypografie())
        XCTAssertGreaterThanOrEqual(dichte, ProofService.minimaleSchriftDichte,
                                    "Aufgelegte Typografie wurde nicht erkannt")
    }

    func testDieSchwelleLiegtZwischenBeidenGemessenenWerten() {
        // An den echten Dateien von „Das letzte Streichholz" gemessen:
        // nacktes Motiv 0,19 %, dasselbe Motiv mit Typografie 2,17 %.
        XCTAssertGreaterThan(ProofService.minimaleSchriftDichte, 0.19)
        XCTAssertLessThan(ProofService.minimaleSchriftDichte, 2.17)
    }
}
