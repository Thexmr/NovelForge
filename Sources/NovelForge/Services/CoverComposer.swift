import AppKit
import Foundation

/// Legt Titel und Autor als gestochen scharfe Typografie über das (textfreie)
/// KI-Artwork. So entsteht ein professionelles, perfekt lesbares KDP-Cover ohne
/// den verzerrten Text, den Bildmodelle direkt erzeugen ("Artwork + scharfer
/// Text-Overlay"). Schlägt das Compositing fehl, wird das reine Artwork als
/// Cover verwendet, damit die Funktion nie bricht.
enum CoverComposer {

    /// Komponiert das finale Cover (Artwork + Titel/Autor) und schreibt es nach
    /// `CoverDesignService.imageURL`. Gibt die Cover-URL zurück.
    @discardableResult
    static func composeCover(artworkURL: URL, project: Project) throws -> URL {
        let target = try CoverDesignService.imageURL(for: project)
        guard let artwork = NSImage(contentsOf: artworkURL) else {
            try useArtworkAsCover(artworkURL: artworkURL, target: target)
            return target
        }
        if let data = composedPNGData(artwork: artwork,
                                      title: project.title,
                                      author: project.authorName,
                                      genre: project.genre) {
            try data.write(to: target, options: .atomic)
        } else {
            try useArtworkAsCover(artworkURL: artworkURL, target: target)
        }
        return target
    }

    private static func useArtworkAsCover(artworkURL: URL, target: URL) throws {
        guard artworkURL != target else { return }
        if FileManager.default.fileExists(atPath: target.path) {
            try? FileManager.default.removeItem(at: target)
        }
        try FileManager.default.copyItem(at: artworkURL, to: target)
    }

    /// Reine Render-Funktion: zeichnet das Artwork als Aspect-Fill, legt
    /// Lesbarkeits-Verläufe und Titel/Autor darüber und liefert PNG-Daten.
    static func composedPNGData(artwork: NSImage, title: String, author: String, genre: String) -> Data? {
        // KDP-Frontcover im Verhältnis 2:3.
        let width: CGFloat = 1600
        let height: CGFloat = 2400
        let canvas = NSImage(size: NSSize(width: width, height: height))
        let full = NSRect(x: 0, y: 0, width: width, height: height)

        canvas.lockFocus()
        // 1) Artwork als Aspect-Fill (füllt das Cover ohne Verzerrung).
        drawAspectFill(artwork, in: full)

        // 2) Dunkle Verläufe oben (Titel) und unten (Autor) – in der Textzone NAHEZU
        //    DECKEND, damit vom KI-Motiv evtl. eingebackener Text-Müll sicher überdeckt
        //    wird. Mehrstufig, damit der Übergang zum Motiv weich bleibt.
        //    Koordinaten sind nicht geflippt: y = 0 unten, y = height oben.
        let rgb = NSColorSpace.deviceRGB
        NSGradient(colors: [NSColor.black.withAlphaComponent(0.0),
                            NSColor.black.withAlphaComponent(0.88),
                            NSColor.black.withAlphaComponent(0.98)],
                   atLocations: [0.0, 0.62, 1.0], colorSpace: rgb)?
            .draw(in: NSRect(x: 0, y: height * 0.62, width: width, height: height * 0.38), angle: 90)
        NSGradient(colors: [NSColor.black.withAlphaComponent(0.99),
                            NSColor.black.withAlphaComponent(0.9),
                            NSColor.black.withAlphaComponent(0.0)],
                   atLocations: [0.0, 0.5, 1.0], colorSpace: rgb)?
            .draw(in: NSRect(x: 0, y: 0, width: width, height: height * 0.30), angle: 90)

        // 3) Titel im oberen Drittel, Autor unten. usesLineFragmentOrigin legt den
        //    Text vom oberen Rand des Rechtecks nach unten an.
        let margin = width * 0.08
        let textWidth = width - 2 * margin

        let titleRect = NSRect(x: margin, y: height * 0.66, width: textWidth, height: height * 0.28)
        drawText(title.uppercased(),
                 in: titleRect,
                 font: coverFont(for: genre, size: titleFontSize(for: title), bold: true),
                 tracking: 1.5)

        let authorRect = NSRect(x: margin, y: height * 0.07, width: textWidth, height: height * 0.09)
        drawText(author,
                 in: authorRect,
                 font: coverFont(for: genre, size: 64, bold: false),
                 tracking: 3.0)
        canvas.unlockFocus()

        guard let tiff = canvas.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }

    // MARK: - Hilfsfunktionen

    private static func drawAspectFill(_ image: NSImage, in rect: NSRect) {
        let imgSize = image.size
        guard imgSize.width > 0, imgSize.height > 0 else {
            image.draw(in: rect)
            return
        }
        let scale = max(rect.width / imgSize.width, rect.height / imgSize.height)
        let w = imgSize.width * scale
        let h = imgSize.height * scale
        let target = NSRect(x: rect.midX - w / 2, y: rect.midY - h / 2, width: w, height: h)
        image.draw(in: target, from: .zero, operation: .copy, fraction: 1.0)
    }

    /// Längere Titel werden kleiner gesetzt, damit sie nicht überlaufen.
    static func titleFontSize(for title: String) -> CGFloat {
        switch title.count {
        case ..<14: return 196
        case ..<24: return 150
        case ..<40: return 112
        default: return 88
        }
    }

    /// Schriftwahl nach Genre-Konvention.
    ///
    /// Die Zuordnung folgt dem, woran Leser ein Genre im Regal erkennen:
    /// – Liebesroman/Romance: moderne Serifenschrift (die verspielten Schreibschriften
    ///   sind bei aktuellen Titeln der klaren Serife gewichen)
    /// – Horror/Gothic/Fantasy: Serife mit Gewicht, ernst und altertümlich
    /// – Dark Romance/Erotik: breite, harte Versalien – der Kontrast zum weichen Motiv
    ///   ist genau das Genre-Signal
    /// – Thriller/Krimi: kräftige Grotesk, gedrängt und laut
    private static func coverFont(for genre: String, size: CGFloat, bold: Bool) -> NSFont {
        let g = genre.lowercased()

        // Dark Romance/Erotik: harte Grotesk in schwerem Schnitt.
        if g.contains("dark romance") || g.contains("erotik") || g.contains("erotic") || g.contains("spicy") {
            return NSFont.systemFont(ofSize: size, weight: bold ? .black : .semibold)
        }
        // Liebesroman, historischer Roman, Horror, Gothic, Fantasy: Serife.
        let usesSerif = g.contains("liebes") || g.contains("romance") || g.contains("romantasy")
            || g.contains("histor") || g.contains("horror") || g.contains("gothic")
            || g.contains("grusel") || g.contains("fantasy") || g.contains("mythol") || g.contains("saga")
        if usesSerif, let serif = NSFont(name: bold ? "Georgia-Bold" : "Georgia", size: size) {
            return serif
        }
        // Thriller, Krimi, Viral Hit und alles Übrige: kräftige Grotesk.
        return NSFont.systemFont(ofSize: size, weight: bold ? .heavy : .medium)
    }

    private static func drawText(_ string: String, in rect: NSRect, font: NSFont, tracking: CGFloat) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineHeightMultiple = 1.02

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.85)
        shadow.shadowBlurRadius = 16
        shadow.shadowOffset = NSSize(width: 0, height: -3)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
            .shadow: shadow,
            .kern: tracking
        ]
        NSAttributedString(string: string, attributes: attrs)
            .draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
}
