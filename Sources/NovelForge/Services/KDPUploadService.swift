import Foundation

/// Startet den Node/Puppeteer-Sidecar, der KDP autonom bedient (Login-Persistenz,
/// eBook-Entwurf anlegen, EPUB+Cover hochladen, Preis, ENTWURF speichern – Stopp
/// vor Veröffentlichen). Reine Datei-Schnittstelle: Job-JSON rein, Status-JSON raus.
enum KDPUploadService {

    struct UploadResult {
        let draftURL: String?
        /// Pflichtfelder, die der Sidecar NICHT setzen konnte (Cover, Kategorie, …).
        /// Der Entwurf ist gespeichert, aber unvollständig – der Nutzer muss nachbessern.
        let offenePunkte: [String]
    }

    enum SidecarError: LocalizedError {
        case nodeMissing, sidecarMissing(String), depsMissing, notLoggedIn, failed(String)
        var errorDescription: String? {
            switch self {
            case .nodeMissing: return "Node.js nicht gefunden. Bitte Node installieren (z.B. via Homebrew: brew install node)."
            case .sidecarMissing(let p): return "KDP-Sidecar nicht gefunden unter \(p)."
            case .depsMissing: return "Sidecar-Abhängigkeiten fehlen. Einmalig einrichten (npm install im kdp-sidecar-Ordner)."
            case .notLoggedIn: return "Nicht bei KDP eingeloggt. Bitte zuerst den KDP-Login ausführen."
            case .failed(let m): return m
            }
        }
    }

    /// Schlüssel für das in den Einstellungen hinterlegte Sicht-Modell.
    static let visionModelDefaultsKey = "novelforge.visionModel"

    /// Zugangsdaten für die Sicht-Kontrolle des Sidecars.
    /// Nur der lokale Ollama wird verwendet: ein Bildschirmfoto der KDP-Seite soll das
    /// Gerät nicht verlassen.
    private static func visionConfig() -> [String: Any]? {
        let modell = (UserDefaults.standard.string(forKey: visionModelDefaultsKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !modell.isEmpty else { return nil }
        return [
            "baseUrl": AIProvider.ollamaLocal.defaultBaseURL ?? "http://localhost:11434",
            "model": modell,
            "visionModel": modell,
            "apiKey": "",
        ]
    }

    // MARK: - Pfade

    private static var appSupport: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("NovelForge", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    /// Persistentes Chrome-Profil für die KDP-Session (einmal einloggen, bleibt erhalten).
    static var chromeProfile: URL {
        let dir = appSupport.appendingPathComponent("kdp_chrome_profile", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Sidecar-Ordner: gebündelt in Resources, sonst im Entwicklungsbaum.
    static func sidecarDir() -> URL? {
        if let res = Bundle.main.resourceURL {
            let bundled = res.appendingPathComponent("kdp-sidecar", isDirectory: true)
            if FileManager.default.fileExists(atPath: bundled.appendingPathComponent("index.js").path) { return bundled }
        }
        // Entwicklungs-Fallback. ZUERST relativ zu DIESEM Quellbaum suchen
        // (#filePath = …/NovelForge/Sources/NovelForge/Services/KDPUploadService.swift,
        // vier Ebenen höher liegt die Repo-Wurzel mit kdp-sidecar/).
        //
        // Vorher stand hier ausschließlich ein fest verdrahteter Pfad auf ein
        // älteres Repo-Checkout (/Users/dave/Documents/Codex/…). Der existierte
        // noch – mit einem ALTEN Stand des Sidecars. Entwicklungsläufe benutzten
        // also stillschweigend den veralteten Upload-Code, während man die aktuelle
        // Version bearbeitete und sich über wirkungslose Fixes wunderte.
        var kandidaten: [URL] = []
        let quellDatei = URL(fileURLWithPath: #filePath)
        let repoWurzel = quellDatei
            .deletingLastPathComponent()   // Services
            .deletingLastPathComponent()   // NovelForge (Target)
            .deletingLastPathComponent()   // Sources
            .deletingLastPathComponent()   // Repo-Wurzel
        kandidaten.append(repoWurzel.appendingPathComponent("kdp-sidecar", isDirectory: true))
        // Ältere Checkouts nur als letzte Reserve.
        kandidaten.append(URL(fileURLWithPath:
            "/Users/dave/Documents/Codex/2026-06-12/gehe-in-mein-github-repo-in/NovelForge/kdp-sidecar"))
        return kandidaten.first {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("index.js").path)
        }
    }

    private static func nodePath() -> String? {
        for p in ["/opt/homebrew/bin/node", "/usr/local/bin/node", "/usr/bin/node"] {
            if FileManager.default.isExecutableFile(atPath: p) { return p }
        }
        return nil
    }

    static var sidecarReady: Bool {
        guard let dir = sidecarDir() else { return false }
        return FileManager.default.fileExists(atPath: dir.appendingPathComponent("node_modules").path)
    }

    // MARK: - Prozess-Ausführung

    @discardableResult
    private static func runSidecar(_ arguments: [String],
                                   onLine: ((String) -> Void)? = nil) async throws -> Int32 {
        guard let node = nodePath() else { throw SidecarError.nodeMissing }
        guard let dir = sidecarDir() else { throw SidecarError.sidecarMissing("(Bundle/Resources/kdp-sidecar)") }
        let index = dir.appendingPathComponent("index.js")

        return try await withCheckedThrowingContinuation { cont in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: node)
            process.arguments = [index.path] + arguments
            process.currentDirectoryURL = dir
            // Hinterlegte KDP-Zugangsdaten NUR als Umgebungsvariable weitergeben:
            // über die Kommandozeile stünden sie in der Prozessliste, in der Job-Datei
            // auf der Platte. So bleiben sie im Speicher dieses einen Prozesses.
            if let zugang = KeychainService.kdpCredentials() {
                var umgebung = ProcessInfo.processInfo.environment
                umgebung["NF_KDP_EMAIL"] = zugang.email
                umgebung["NF_KDP_PASSWORD"] = zugang.password
                process.environment = umgebung
            }
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                for raw in text.split(separator: "\n") {
                    let line = raw.trimmingCharacters(in: .whitespaces)
                    if !line.isEmpty { onLine?(line) }
                }
            }
            process.terminationHandler = { proc in
                pipe.fileHandleForReading.readabilityHandler = nil
                cont.resume(returning: proc.terminationStatus)
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }
    }

    // MARK: - Öffentliche Aktionen

    /// Öffnet ein sichtbares Browserfenster für den einmaligen KDP-Login (inkl. 2FA).
    static func login(onProgress: @escaping (String) -> Void) async throws {
        let code = try await runSidecar(
            ["login", "--profile", chromeProfile.path], onLine: onProgress)
        if code != 0 { throw SidecarError.failed("Login nicht abgeschlossen.") }
    }

    /// Prüft ohne Nutzeraktion, ob eine gültige KDP-Session besteht.
    static func checkLogin() async -> Bool {
        guard sidecarReady else { return false }
        // WICHTIG: dieselbe Sitzungsquelle wie der Upload. Der Upload läuft mit
        // --use-my-chrome-copy (übernimmt die Cookies aus dem echten Chrome), die
        // Prüfung tat das nicht - sie sah nur ins leere Arbeitsprofil und meldete
        // deshalb "nicht eingeloggt", während der Upload gleichzeitig funktionierte.
        let code = (try? await runSidecar(
            ["check", "--profile", chromeProfile.path, "--use-my-chrome-copy"])) ?? 2
        return code == 0
    }

    /// Legt für das Projekt einen KDP-eBook-ENTWURF an (kein Veröffentlichen).
    static func uploadDraft(project: Project, priceEUR: Double, aiDisclosure: String,
                            dryRun: Bool = false,
                            progress: @escaping (String) -> Void) async throws -> UploadResult {
        guard sidecarReady else { throw SidecarError.depsMissing }

        // EPUB + Cover: fehlen sie, werden sie JETZT erzeugt – die Fabrik soll autonom
        // arbeiten und nicht abbrechen, nur weil vorher niemand exportiert hat.
        var epubOptional = latestEPUB(for: project)
        if epubOptional == nil {
            progress("Kein EPUB vorhanden – exportiere jetzt …")
            // ExportEngine ist an den Main-Actor gebunden (arbeitet auf SwiftData-Objekten).
            epubOptional = try? await MainActor.run { try ExportEngine.exportToEPUB(project: project) }
        }
        guard let epub = epubOptional else {
            throw SidecarError.failed("EPUB konnte nicht erzeugt werden – bitte Buch prüfen.")
        }

        var cover = CoverArtService.coverURL(for: project)
        if cover == nil {
            progress("Kein Cover vorhanden – erzeuge jetzt …")
            // generateCover liefert ein CoverResult; danach steht die Datei unter coverURL.
            _ = try? await CoverArtService.generateCover(for: project)
            cover = CoverArtService.coverURL(for: project)
        }

        // Unveränderliche Kopie: `cover` ist eine var, und ein var-Zugriff in einer
        // nebenläufigen Closure ist im Swift-6-Modus ein Fehler.
        let coverURL = cover

        // DRUCKCOVER: Vorderseite + Buchrücken + Rückseite mit Verkaufstext.
        // Kein Abbruchgrund – das eBook erscheint auch ohne Taschenbuch-Fassung.
        let druckcover = await MainActor.run { () -> (URL, PrintCoverService.Dimensions)? in
            guard let cover = coverURL else { return nil }
            let woerter = (project.chapters ?? []).reduce(0) {
                $0 + ($1.finalText ?? $1.revisedText ?? $1.draftText ?? "")
                    .split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            }
            // Endformat des BUCHBLOCKS übernehmen. Vorher lief alles im Default 5×8 –
            // für ein 6×9-Buch (Projekt-Default) bekam KDP damit ein Cover im falschen
            // Endformat samt falsch gerechnetem Rücken und lehnte es ab.
            let buchTrim = PrintCoverService.printTrim(forBookTrimRaw: project.trimSizeRaw)
            let seiten = PrintCoverService.estimatePages(words: woerter, trim: buchTrim)
            let jpeg = cover.deletingLastPathComponent().appendingPathComponent("druckcover.jpg")
            let pdf = cover.deletingLastPathComponent().appendingPathComponent("druckcover.pdf")
            let blatt = KDPSalesSheet.make(for: project)
            let texte = PrintCoverService.Texts(
                title: blatt.title.isEmpty ? project.title : blatt.title,
                author: project.authorName,
                hook: blatt.hook,
                blurb: blatt.salesDescription)
            // Rohes Motiv bevorzugen: das fertige eBook-Cover trägt den Titel bereits
            // eingebrannt, er erschiene auf dem Wrap sonst ein zweites Mal.
            let motiv = CoverArtService.motifURL(for: project) ?? cover
            guard let r = try? PrintCoverService.makeWrap(artworkURL: motiv, pages: seiten,
                                                          trim: buchTrim,
                                                          texts: texte, jpegURL: jpeg, pdfURL: pdf)
            else { return nil }
            return (r.jpegURL, r.dimensions)
        }
        if let druckcover {
            progress("Druckcover erzeugt: \(druckcover.1.summary)")
        }

        // SELBSTBEWEIS vor dem Upload. Das Programm misst sein eigenes Ergebnis –
        // Umfang, EPUB-Struktur, Cover-Maße, Keyword-Deckung, Verkaufstext. Fällt eine
        // Pflichtprüfung durch, wird NICHT hochgeladen: ein fehlerhaftes Buch im echten
        // KDP-Konto kostet mehr Zeit, als der Abbruch hier spart.
        progress("Prüfe das eigene Ergebnis …")
        let nachweis = await MainActor.run {
            ProofService.prove(project: project, epubURL: epub, coverURL: coverURL,
                               wrapURL: druckcover?.0, wrapDimensions: druckcover?.1)
        }
        guard nachweis.passed else {
            let offen = nachweis.openRequired.map { "\($0.name) (\($0.evidence))" }.joined(separator: "; ")
            throw SidecarError.failed("Selbstprüfung nicht bestanden – deshalb kein Upload. Offen: \(offen)")
        }
        progress("Selbstprüfung bestanden: \(nachweis.allChecks.count) Einzelnachweise.")

        let sheet = KDPSalesSheet.make(for: project)
        let job: [String: Any] = [
            "title": sheet.title.isEmpty ? project.title : sheet.title,
            "subtitle": sheet.hook,
            "author": project.authorName,
            "description": sheet.salesDescription,
            "keywords": Array(sheet.keywordSlots.prefix(7)),
            "categories": Array(sheet.categorySlots.prefix(3)),
            "language": project.language,
            "aiDisclosure": aiDisclosure,
            "priceEUR": priceEUR,
            "epubPath": epub.path,
            "coverPath": coverURL?.path ?? "",
        ]
        // SICHT-KONTROLLE: Ohne dieses Feld übersprang der Sidecar seine Bildprüfung
        // still – der Code dafür war vorhanden, lief aber nie. Ein multimodales Modell
        // sieht damit nach, was wirklich im KDP-Formular steht. Ist keines hinterlegt,
        // bleibt die Prüfung bewusst aus und der Upload verlässt sich allein auf das
        // Zurücklesen aus dem Formular.
        var vollstaendigerJob = job
        if let sicht = visionConfig() { vollstaendigerJob["ai"] = sicht }
        let jobURL = appSupport.appendingPathComponent("kdp_job_\(project.id.uuidString).json")
        let statusURL = appSupport.appendingPathComponent("kdp_status_\(project.id.uuidString).json")
        try JSONSerialization.data(withJSONObject: vollstaendigerJob, options: .prettyPrinted).write(to: jobURL)

        var args = ["upload", "--job", jobURL.path, "--status", statusURL.path,
                    "--profile", chromeProfile.path]
        // Die bestehende KDP-Anmeldung aus dem ECHTEN Chrome des Nutzers übernehmen:
        // der Sidecar kopiert nur die Sitzungsdateien (Cookies), das normale Chrome
        // bleibt geöffnet und nutzbar. Ohne diese Angabe bräuchte die App eine
        // zweite, eigene Anmeldung.
        args.append("--use-my-chrome-copy")
        if dryRun { args.append("--dry-run") }

        let code = try await runSidecar(args, onLine: progress)
        // Status-Datei auswerten.
        var draftURL: String?
        var offenePunkte: [String] = []
        if let data = try? Data(contentsOf: statusURL),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            draftURL = obj["draftUrl"] as? String
            offenePunkte = (obj["probleme"] as? [String]) ?? []
            if let err = obj["error"] as? String, code != 0 {
                if err.contains("eingeloggt") { throw SidecarError.notLoggedIn }
                throw SidecarError.failed(err)
            }
        }
        if code != 0 { throw SidecarError.failed("Sidecar endete mit Fehlercode \(code).") }
        return UploadResult(draftURL: draftURL, offenePunkte: offenePunkte)
    }

    private static func latestEPUB(for project: Project) -> URL? {
        guard let dir = try? ExportEngine.exportDirectory(for: project) else { return nil }
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey]))
            ?? []
        return files.filter { $0.pathExtension.lowercased() == "epub" }
            .sorted { (a, b) in
                let da = (try? a.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return da > db
            }
            .first
    }
}
