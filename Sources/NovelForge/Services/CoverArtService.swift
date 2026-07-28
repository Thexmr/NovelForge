import Foundation
import AppKit

/// Erzeugt KDP-taugliche eBook-Cover. Zwei Anbieter:
///  • `.pollinations` (KOSTENLOS, ohne API-Key, ohne Konto — Flux-basiert). Standard.
///  • `.openAI` (gpt-image, braucht OpenAI-API-Key mit Guthaben — höhere Kontrolle/Qualität).
///
/// Das ChatGPT-/OpenAI-ABO kann per Programm KEINE Bilder erzeugen (getestet:
/// dem OAuth-Token fehlen die Scopes `api.model.images.request`/`api.responses.write`).
/// Deshalb ist der kostenlose lokale-freie Weg (Pollinations) der Standard.
///
/// Ergebnis: JPG in KDP-Empfehlungsauflösung 1600×2560 im Exportordner des Projekts
/// (<Exportwurzel>/<Titel>/cover_ebook.jpg). Kein SwiftData-Schema-Change.
enum CoverArtService {

    enum Provider: String, CaseIterable, Identifiable {
        case pollinations   // kostenlos, kein Key
        case openAI         // gpt-image, API-Key nötig
        var id: String { rawValue }
        var label: String {
            switch self {
            case .pollinations: return "Kostenlos (Flux, ohne Key)"
            case .openAI: return "OpenAI gpt-image (API-Key)"
            }
        }
    }

    struct CoverResult { let url: URL; let provider: Provider }

    /// KDP-Empfehlung fürs eBook-Cover: 2560 px hoch, 1600 px breit.
    static let targetWidth = 1600
    static let targetHeight = 2560

    private static let providerDefaultsKey = "novelforge.cover.provider"

    static var selectedProvider: Provider {
        get {
            let raw = UserDefaults.standard.string(forKey: providerDefaultsKey) ?? Provider.pollinations.rawValue
            return Provider(rawValue: raw) ?? .pollinations
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: providerDefaultsKey) }
    }

    /// Ist der gewählte Anbieter einsatzbereit? Pollinations immer; OpenAI nur mit Key.
    static func isReady(_ provider: Provider = selectedProvider) -> Bool {
        switch provider {
        case .pollinations: return true
        case .openAI: return !(KeychainService.getAPIKey(for: .openAI) ?? "").isEmpty
        }
    }

    static func coverURL(for project: Project) -> URL? {
        guard let dir = try? ExportEngine.exportDirectory(for: project) else { return nil }
        let url = dir.appendingPathComponent("cover_ebook.jpg")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Kunstrichtung je Genre – abgeleitet aus den Gestaltungskonventionen, an denen
    /// Leser ein Genre im Regal und im Thumbnail sofort erkennen.
    ///
    /// Bewusst OHNE Menschen und OHNE Schrift im Motiv: Gesichter und Hände sind die
    /// stärksten KI-Verräter, und Bildmodelle können keine lesbaren Buchstaben setzen.
    /// Titel und Autor kommen später als gestochen scharfe Typografie darüber.
    static func artDirection(for genre: String) -> String {
        let g = genre.lowercased()

        if g.contains("dark romance") || g.contains("erotik") || g.contains("erotic") || g.contains("spicy") {
            // Beobachtet an erfolgreichen deutschen Titeln: fast schwarzer oder tief
            // weinroter Grund mit weichem Leuchten aus der Mitte, ein KRANZ aus dunklen
            // Rosen, der die Bildmitte umschließt, dazu Samt und ein einzelnes goldenes
            // Objekt. Die Mitte bleibt ruhig – dort steht später der Titel.
            // Der Kranz rahmt die RÄNDER, und die Mitte wird ausdrücklich benannt.
            // Sagt man nur "ein Kranz umschließt die Mitte", füllt das Modell die Mitte
            // mit einem Gesicht – Verneinungen ignorieren Bild-KIs zuverlässig.
            return "tief weinroter bis fast schwarzer Grund mit weichem Leuchten, ein üppiger Kranz aus "
                + "dunkelroten und magentafarbenen Rosen rahmt die BILDRÄNDER, IN DER BILDMITTE liegt "
                + "ausschließlich glatter dunkler Samtstoff in weichen Falten, darauf ein einzelnes "
                + "goldenes Schmuckstück, vereinzelt schwebende weiße Federn, satte Sättigung, "
                + "weiches Studio-Gegenlicht, reine Objektfotografie eines Stilllebens, opulent und edel"
        }

        if g.contains("liebes") || g.contains("romance") || g.contains("romantasy") || g.contains("chick") {
            return "warmer, leuchtender Farbverlauf von Puderrosa zu Altrosa mit goldenem Licht, "
                + "zarte Blütenzweige und Blätter rahmen die Bildränder, ein einzelnes Objekt mit "
                + "Gefühlswert in der unteren Bildhälfte, Lichtpunkte und weiches Bokeh, "
                + "ruhige, helle Fläche in der Bildmitte, romantisch und hochwertig"
        }

        if g.contains("horror") || g.contains("grusel") || g.contains("gothic") {
            // Beobachtet: Doppelbelichtung (Silhouette verschmilzt mit Schauplatz),
            // Pergament-/Papiertextur, herablaufende Tinte, entsättigt mit einem
            // einzigen blutroten Akzent.
            return "entsättigter Grund in Grau und Papierbeige mit sichtbarer Pergamenttextur und "
                + "herablaufenden Tintenschlieren, eine Doppelbelichtung: die Silhouette eines "
                + "verlassenen Hauses mit kahlen Bäumen verschmilzt zu einer größeren Form, "
                + "ein einziger blutroter Lichtakzent, Nebel und Körnung, klamm und beklemmend"
        }

        if g.contains("fantasy") || g.contains("mythol") || g.contains("saga") {
            // Beobachtet: goldener Zierrahmen, Hell-Dunkel-Teilung, opulente Szene mit
            // Schloss/Bergen, florale Ränder, metallische Ornamentik.
            return "opulente LANDSCHAFTSSZENE mit goldenem Ornamentrahmen an den Bildkanten, deutliche "
                + "Hell-Dunkel-Teilung zwischen warmem Goldlicht und tiefem Violett-Schwarz, IN DER "
                + "BILDMITTE eine ferne gotische Burg auf einem Berg, Blitz über dem Tal, Ranken mit "
                + "dunklen Rosen und hellen Blüten an den Rändern, metallische Goldakzente, "
                + "Mondsichel-Emblem, märchenhafte Landschaftsmalerei ohne Lebewesen"
        }

        if g.contains("thriller") || g.contains("krimi") || g.contains("suspense") || g.contains("noir")
            || g.contains("viral") {
            return "kalte blaugraue Farbwelt mit einem einzigen warmen Lichtpunkt, ein Objekt aus dem "
                + "Tatgeschehen groß im Vordergrund, nasser Asphalt mit Spiegelungen, hartes Seitenlicht "
                + "einer Straßenlaterne, Regen, unruhige Schärfentiefe, bedrohliche Stille"
        }

        return "atmosphärische Szene mit weichem Gegenlicht, florale Elemente an den Bildrändern, "
            + "satte abgestimmte Farben, ruhige Fläche in der Bildmitte, hochwertige Anmutung"
    }

    /// Baut den Bild-Prompt für das MOTIV.
    ///
    /// WICHTIG: Der Prompt verlangt ausdrücklich KEINE Schrift im Bild. Vorher stand hier
    /// „Titel groß und gut lesbar: … Autor dezent unten: …" – das Bildmodell malte also
    /// verkrüppelte Buchstaben ins Motiv, über die anschließend die echte Typografie
    /// gelegt wurde. Doppelter Text und der typische KI-Look waren die Folge.
    /// Titel und Autorname setzt `CoverComposer` als scharfe Typografie darüber, und
    /// der Autorname stammt IMMER aus den Angaben im Programm.
    static func buildPrompt(for project: Project) -> String {
        let profilePrompt = project.bookProfile?.coverPrompts
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let premise = project.bookProfile?.premise
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let scene = profilePrompt.isEmpty
            ? String(premise.prefix(200))
            : String(profilePrompt.prefix(400))
        let bezug = scene.isEmpty ? "" : " Greife einen konkreten Gegenstand aus dieser Geschichte auf: \(scene)."
        return """
        Buchcover-Motiv für einen deutschen \(project.genre), Hochformat 2:3, Bestseller-Anmutung. \
        \(artDirection(for: project.genre)).\(bezug) \
        Analoge Kleinbildfotografie mit feinem Filmkorn, cineastische Farbabstufung, natürliches unperfektes Licht, \
        geringe Schärfentiefe, sichtbare Materialtextur. \
        Ruhige, dunkle Fläche im oberen Drittel und im unteren Viertel als Platz für die Typografie. \
        Reines Bildmotiv ohne jede Schrift, ohne Buchstaben, ohne Zahlen, ohne Zifferblätter, ohne Wasserzeichen, \
        ohne Rahmen, ohne Logos, ohne Menschen, ohne Gesichter, ohne Hände. \
        Auch als kleines Thumbnail sofort erkennbar.
        """
    }

    /// Erzeugt das Cover mit dem gewählten Anbieter und speichert es als JPG.
    /// Pfad des rohen, textfreien Motivs (Grundlage für das Druckcover).
    static func motifURL(for project: Project) -> URL? {
        guard let dir = try? ExportEngine.exportDirectory(for: project) else { return nil }
        let url = dir.appendingPathComponent("cover_motiv.jpg")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func generateCover(for project: Project,
                              provider: Provider = selectedProvider) async throws -> CoverResult {
        let prompt = buildPrompt(for: project)
        let rawImage: Data
        switch provider {
        case .pollinations:
            rawImage = try await requestPollinations(prompt: prompt)
        case .openAI:
            guard let apiKey = KeychainService.getAPIKey(for: .openAI), !apiKey.isEmpty else {
                throw AIError.systemError(
                    "Für OpenAI-Cover fehlt der API-Key. In Einstellungen → KI-Provider → OpenAI hinterlegen — oder den kostenlosen Anbieter wählen.")
            }
            rawImage = try await requestOpenAI(prompt: prompt, apiKey: apiKey)
        }
        guard let jpeg = scaleFillToJPEG(rawImage, width: targetWidth, height: targetHeight) else {
            throw AIError.systemError("Cover-Bild konnte nicht auf KDP-Maß skaliert werden.")
        }
        let dir = try ExportEngine.exportDirectory(for: project)
        let url = dir.appendingPathComponent("cover_ebook.jpg")
        try jpeg.write(to: url, options: .atomic)
        // Das ROHE, textfreie Motiv separat sichern. Das Druckcover braucht genau dieses
        // Bild – nimmt man das fertige eBook-Cover, ist dessen Titel schon eingebrannt und
        // erscheint auf dem Wrap ein zweites Mal quer über Rück- und Vorderseite.
        try? rawImage.write(to: dir.appendingPathComponent("cover_motiv.jpg"), options: .atomic)
        return CoverResult(url: url, provider: provider)
    }

    // MARK: - Pollinations (kostenlos, kein Key)

    private static func requestPollinations(prompt: String) async throws -> Data {
        // Deterministischer Seed aus dem Prompt (reproduzierbar, aber pro Buch anders).
        let seed = abs(prompt.hashValue) % 1_000_000
        let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? prompt
        // Höhere Auflösung anfordern; wird anschließend auf 1600×2560 gebracht.
        let urlString = "https://image.pollinations.ai/prompt/\(encoded)"
            + "?width=1024&height=1536&model=flux&nologo=true&enhance=true&seed=\(seed)"
        guard let url = URL(string: urlString) else {
            throw AIError.systemError("Ungültige Pollinations-URL.")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 120
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, !data.isEmpty else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw AIError.systemError("Kostenloser Bild-Dienst nicht erreichbar (HTTP \(code)). Später erneut versuchen oder OpenAI-Anbieter wählen.")
        }
        guard NSBitmapImageRep(data: data) != nil else {
            throw AIError.systemError("Kostenloser Bild-Dienst lieferte kein gültiges Bild.")
        }
        return data
    }

    // MARK: - OpenAI Images API

    private static let openAIModels = ["gpt-image-1"]

    private static func requestOpenAI(prompt: String, apiKey: String) async throws -> Data {
        var lastError: Error?
        for model in openAIModels {
            do { return try await openAICall(prompt: prompt, model: model, apiKey: apiKey) }
            catch { lastError = error
                if let ai = error as? AIError, case .systemError(let m) = ai,
                   m.contains("model_not_found") || m.contains("does not exist") { continue }
                throw error
            }
        }
        throw lastError ?? AIError.systemError("OpenAI-Cover-Erzeugung fehlgeschlagen.")
    }

    private static func openAICall(prompt: String, model: String, apiKey: String) async throws -> Data {
        guard let url = URL(string: "https://api.openai.com/v1/images/generations") else {
            throw AIError.systemError("Ungültige OpenAI-Bilder-URL.")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 240
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": model, "prompt": prompt, "size": "1024x1536", "quality": "high", "n": 1,
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AIError.systemError("Keine Antwort von der OpenAI-Bilder-API.")
        }
        guard http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? ""
            if http.statusCode == 401 {
                throw AIError.systemError("OpenAI-API-Key ungültig (401). Key in den Einstellungen prüfen.")
            }
            throw AIError.systemError("OpenAI-Bilder-API-Fehler \(http.statusCode): \(text.prefix(240))")
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["data"] as? [[String: Any]], let first = items.first else {
            throw AIError.systemError("Unerwartete Antwort der OpenAI-Bilder-API.")
        }
        if let b64 = first["b64_json"] as? String, let raw = Data(base64Encoded: b64) { return raw }
        if let s = first["url"] as? String, let imgURL = URL(string: s) {
            let (raw, _) = try await URLSession.shared.data(from: imgURL); return raw
        }
        throw AIError.systemError("OpenAI-Bilder-API lieferte kein Bild zurück.")
    }

    // MARK: - Skalierung auf KDP-Maß (scale-fill mit Mittel-Beschnitt)

    private static func scaleFillToJPEG(_ data: Data, width: Int, height: Int) -> Data? {
        guard let source = NSBitmapImageRep(data: data)?.cgImage else { return nil }
        let srcW = CGFloat(source.width), srcH = CGFloat(source.height)
        let dstW = CGFloat(width), dstH = CGFloat(height)
        let scale = max(dstW / srcW, dstH / srcH)
        let drawW = srcW * scale, drawH = srcH * scale
        let originX = (dstW - drawW) / 2, originY = (dstH - drawH) / 2
        guard let ctx = CGContext(data: nil, width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(source, in: CGRect(x: originX, y: originY, width: drawW, height: drawH))
        guard let scaled = ctx.makeImage() else { return nil }
        return NSBitmapImageRep(cgImage: scaled)
            .representation(using: .jpeg, properties: [.compressionFactor: 0.9])
    }
}
