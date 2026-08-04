import Foundation
import Combine

/// Autonome KDP-Buchfabrik: Warteschlange + harte Upload-Drossel + Ein/Aus.
///
/// Prinzip: Fertige Bücher (Status .completed, Cover + EPUB vorhanden) werden in
/// die Warteschlange gelegt. Der Dispatcher lädt sie – NUR wenn die Fabrik AN ist
/// und ein Upload-Slot frei ist – über den KDP-Sidecar als ENTWURF hoch (Stopp vor
/// Veröffentlichen). Die Drossel schützt das KDP-Konto: rollierende Fenster
/// 3/24 h · 10/7 Tage · 40/30 Tage (konfigurierbar).
///
/// Alles wird in Application Support als JSON persistiert (kein SwiftData-Schema-
/// Change). Der Zustand ist @Published für die Überwachungs-UI.
@MainActor
final class KDPFactory: ObservableObject {
    static let shared = KDPFactory()

    // MARK: - Persistierter Zustand

    struct Limits: Codable, Equatable {
        var perDay = 3
        var perWeek = 10
        var perMonth = 40
    }

    /// Upload-Kalender: an welchen Wochentagen, in welchem Tages-Zeitfenster und
    /// mit welchem Mindestabstand zwischen zwei Uploads hochgeladen werden darf.
    /// `active == false` → Uploads jederzeit erlaubt (nur die Drossel greift).
    struct Schedule: Codable, Equatable {
        var active = false
        /// Erlaubte Wochentage (1 = Montag … 7 = Sonntag).
        var weekdays: Set<Int> = [1, 2, 3, 4, 5]
        /// Tages-Zeitfenster (Stunde, 0–23). Upload nur zwischen startHour und endHour.
        var startHour = 9
        var endHour = 21
        /// Mindestabstand zwischen zwei Uploads (Stunden).
        var minHoursBetween = 2
    }

    enum EntryStage: String, Codable {
        case queued          // wartet in der Warteschlange
        case waitingSlot     // fertig, aber Drossel/aus → wartet auf Slot
        case uploading       // Sidecar läuft gerade
        case draftReady      // Entwurf in KDP, Nutzer muss Preis prüfen + veröffentlichen
        case failed          // Upload fehlgeschlagen (erneut versuchbar)
    }

    struct QueueEntry: Codable, Identifiable {
        var id: UUID
        var projectID: UUID
        var title: String
        var author: String
        var priceEUR: Double
        var aiDisclosure: String     // "ai-generated" | "ai-assisted" | "none"
        var stage: EntryStage
        var lastMessage: String
        var draftURL: String?
        var enqueuedAt: Date
        var updatedAt: Date
        /// Zahl der Fehlversuche – Grundlage für die wachsende Wartezeit.
        var attempts: Int = 0
        /// Zeitpunkt des letzten Versuchs (auch des gescheiterten).
        var lastTriedAt: Date? = nil

        /// Darf dieser Eintrag JETZT (wieder) versucht werden?
        ///
        /// Nach einem Fehlversuch wächst die Wartezeit: 15 min, 30 min, 1 h, 2 h … bis 12 h.
        /// Ohne das lief ein dauerhaft scheiternder Eintrag im Minutentakt in denselben
        /// Fehler und blockierte dabei alle folgenden Bücher, weil er vorn in der
        /// Warteschlange stehen blieb.
        func retryDue(at now: Date) -> Bool {
            guard attempts > 0, let last = lastTriedAt else { return true }
            let wartezeit = min(12 * 3600, 900 * pow(2, Double(attempts - 1)))
            return now.timeIntervalSince(last) >= wartezeit
        }
    }

    struct UploadRecord: Codable, Identifiable {
        var id: UUID
        var projectID: UUID
        var title: String
        var uploadedAt: Date
    }

    @Published var enabled: Bool = false { didSet { persistFlags() } }
    @Published var limits = Limits() { didSet { persist() } }
    @Published var schedule = Schedule() { didSet { persist() } }
    @Published private(set) var queue: [QueueEntry] = []
    @Published private(set) var history: [UploadRecord] = []
    @Published private(set) var isDispatching = false
    @Published var loginState: String = "unbekannt"   // "eingeloggt" | "nicht eingeloggt" | "prüft…"

    private var timer: Timer?

    private init() {
        load()
    }

    // MARK: - Persistenz

    private static let dir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("NovelForge", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()
    private static var queueFile: URL { dir.appendingPathComponent("kdp_queue.json") }
    private static var historyFile: URL { dir.appendingPathComponent("kdp_history.json") }
    private static let enabledKey = "novelforge.factory.enabled"
    private static let limitsKey = "novelforge.factory.limits"
    private static let scheduleKey = "novelforge.factory.schedule"

    private func load() {
        enabled = UserDefaults.standard.bool(forKey: Self.enabledKey)
        if let data = UserDefaults.standard.data(forKey: Self.limitsKey),
           let l = try? JSONDecoder().decode(Limits.self, from: data) { limits = l }
        if let data = UserDefaults.standard.data(forKey: Self.scheduleKey),
           let s = try? JSONDecoder().decode(Schedule.self, from: data) { schedule = s }
        queue = ladeListe([QueueEntry].self, aus: Self.queueFile, name: "Upload-Warteschlange") ?? []
        history = ladeListe([UploadRecord].self, aus: Self.historyFile, name: "Upload-Historie") ?? []
        Self.bereinigeAbgestuerzteUploads(&queue)
        persist()
    }

    /// Holt Einträge zurück, die beim Beenden der App mitten im Upload steckten.
    ///
    /// `tick()` nimmt nur .queued/.waitingSlot/.failed – wurde die App während eines
    /// laufenden Sidecar-Uploads beendet (Absturz, Neustart, Update), blieb der Eintrag
    /// dauerhaft auf .uploading stehen und kam NIE wieder an die Reihe. Das Buch war
    /// damit still aus der Fabrik verschwunden. Zurück auf .failed mit Versuchszähler:
    /// die wachsende Wartezeit gilt, ein neuer Versuch wird eingeplant.
    static func bereinigeAbgestuerzteUploads(_ queue: inout [QueueEntry], jetzt: Date = Date()) {
        for i in queue.indices where queue[i].stage == .uploading {
            queue[i].stage = .failed
            queue[i].attempts += 1
            queue[i].lastTriedAt = jetzt
            queue[i].lastMessage = "Upload unterbrochen (App wurde beendet) – neuer Versuch mit Wartezeit."
            queue[i].updatedAt = jetzt
        }
    }

    /// Lädt eine gespeicherte Liste – und verwirft sie NICHT stillschweigend, wenn das
    /// Format nicht passt.
    ///
    /// Vorher stand hier `try? JSONDecoder().decode(...)` ohne Behandlung des Fehlers.
    /// Scheiterte das Dekodieren – etwa nach einer Formatänderung –, blieb die Liste
    /// leer, und das nächste `persist()` überschrieb die Datei mit `[]`. Die gesamte
    /// Upload-Warteschlange wäre damit unwiederbringlich weg gewesen, ohne dass irgendwo
    /// eine Meldung erschien. Beim Testen genau so passiert.
    ///
    /// Jetzt wird die unlesbare Datei zur Seite gelegt statt überschrieben, und der
    /// Grund landet im Fehlerprotokoll.
    private func ladeListe<T: Decodable>(_ typ: T.Type, aus datei: URL, name: String) -> T? {
        guard let data = try? Data(contentsOf: datei), !data.isEmpty else { return nil }
        do {
            return try JSONDecoder().decode(typ, from: data)
        } catch {
            let sicherung = datei.deletingPathExtension()
                .appendingPathExtension("unlesbar.json")
            try? FileManager.default.removeItem(at: sicherung)
            try? FileManager.default.moveItem(at: datei, to: sicherung)
            NSLog("[NovelForge] \(name) nicht lesbar (%@) – Datei gesichert unter %@",
                  String(describing: error), sicherung.lastPathComponent)
            return nil
        }
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(queue) { try? data.write(to: Self.queueFile, options: .atomic) }
        if let data = try? JSONEncoder().encode(history) { try? data.write(to: Self.historyFile, options: .atomic) }
        if let data = try? JSONEncoder().encode(limits) { UserDefaults.standard.set(data, forKey: Self.limitsKey) }
        if let data = try? JSONEncoder().encode(schedule) { UserDefaults.standard.set(data, forKey: Self.scheduleKey) }
    }
    private func persistFlags() { UserDefaults.standard.set(enabled, forKey: Self.enabledKey) }

    // MARK: - Drossel (rollierende Fenster)

    private func uploadsIn(_ interval: TimeInterval) -> Int {
        let cutoff = Date().addingTimeInterval(-interval)
        return history.filter { $0.uploadedAt >= cutoff }.count
    }
    var usedToday: Int { uploadsIn(24 * 3600) }
    var usedThisWeek: Int { uploadsIn(7 * 24 * 3600) }
    var usedThisMonth: Int { uploadsIn(30 * 24 * 3600) }
    var slotsToday: Int { max(0, limits.perDay - usedToday) }
    var slotsThisWeek: Int { max(0, limits.perWeek - usedThisWeek) }
    var slotsThisMonth: Int { max(0, limits.perMonth - usedThisMonth) }

    /// Freie Slots = das Minimum aller drei Fenster.
    var freeSlots: Int { min(slotsToday, slotsThisWeek, slotsThisMonth) }

    // MARK: - Upload-Kalender

    /// Erlaubt der Kalender einen Upload JETZT? nil = ja, sonst der Grund.
    var scheduleReason: String? {
        guard schedule.active else { return nil }
        let cal = Calendar.current
        let now = Date()
        // Wochentag in 1=Mo … 7=So umrechnen (Calendar: 1=So … 7=Sa).
        let wdSun1 = cal.component(.weekday, from: now)
        let weekdayMon1 = ((wdSun1 + 5) % 7) + 1
        let names = ["", "Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        if !schedule.weekdays.contains(weekdayMon1) {
            let allowed = schedule.weekdays.sorted().map { names[$0] }.joined(separator: ", ")
            return "Heute (\(names[weekdayMon1])) ist kein Upload-Tag. Geplant: \(allowed)."
        }
        let hour = cal.component(.hour, from: now)
        if hour < schedule.startHour || hour >= schedule.endHour {
            return "Außerhalb des Zeitfensters (\(schedule.startHour)–\(schedule.endHour) Uhr)."
        }
        if let last = history.map({ $0.uploadedAt }).max() {
            let elapsed = now.timeIntervalSince(last) / 3600
            if elapsed < Double(schedule.minHoursBetween) {
                let wait = Double(schedule.minHoursBetween) - elapsed
                let m = Int(wait * 60)
                return "Mindestabstand \(schedule.minHoursBetween) h – nächster Upload in \(m / 60) h \(m % 60) min."
            }
        }
        return nil
    }
    var scheduleAllowsNow: Bool { scheduleReason == nil }

    /// Grund, warum gerade nicht hochgeladen werden kann (nil = geht).
    var throttleReason: String? {
        if slotsToday <= 0 { return "Tageslimit erreicht (\(limits.perDay)/Tag). Nächster Slot in \(nextSlotText(24 * 3600))." }
        if slotsThisWeek <= 0 { return "Wochenlimit erreicht (\(limits.perWeek)/Woche)." }
        if slotsThisMonth <= 0 { return "Monatslimit erreicht (\(limits.perMonth)/Monat)." }
        return nil
    }
    private func nextSlotText(_ window: TimeInterval) -> String {
        guard let oldest = history.map({ $0.uploadedAt }).filter({ $0 >= Date().addingTimeInterval(-window) }).min()
        else { return "kürze" }
        let free = oldest.addingTimeInterval(window)
        let secs = max(0, free.timeIntervalSinceNow)
        let h = Int(secs) / 3600, m = (Int(secs) % 3600) / 60
        return h > 0 ? "\(h) h \(m) min" : "\(m) min"
    }

    // MARK: - Warteschlange

    func isQueued(_ projectID: UUID) -> Bool { queue.contains { $0.projectID == projectID } }

    /// Standardpreis für automatisch eingereihte Bücher.
    static let standardPreisEUR = 3.99

    /// Reiht ein fertig produziertes Buch selbsttätig ein – gesteuert vom
    /// vorhandenen Fabrik-Schalter: „Fabrik an" heißt jetzt wirklich, dass fertige
    /// Bücher von allein hochgehen.
    ///
    /// Warum das nötig war: `enqueue` hatte genau EINEN Aufrufer – den Knopf
    /// „Einreihen" in der Buchfabrik. Ein fertig produziertes Buch landete nie von
    /// selbst in der Warteschlange; die Produktion endete bei `completed` und hörte dort
    /// auf. Nachgeprüft an vier Büchern: kein einziger Upload-Job in der Datenbank –
    /// obwohl die Fabrikseite genau das versprach ("Fertige Bücher werden mit Cover und
    /// allen Texten automatisch als KDP-ENTWURF hochgeladen").
    ///
    /// Bewusst zurückhaltend: Es entsteht bei KDP ausschließlich ein ENTWURF. Der
    /// Upload-Schritt veröffentlicht nichts – das bleibt ein Klick des Nutzers.
    /// Fehlen EPUB oder Cover, erzeugt `uploadDraft` sie beim Upload selbst.
    @discardableResult
    func reicheFertigesBuchEin(_ project: Project) -> Bool {
        guard enabled else { return false }
        guard !isQueued(project.id) else { return false }
        return enqueue(project: project,
                       priceEUR: Self.standardPreisEUR,
                       // KDP-Definition: „AI-generated" = die KI hat den Inhalt
                       // ERZEUGT (auch bei nachträglicher Bearbeitung); „AI-assisted"
                       // gilt nur, wenn ein Mensch den Text selbst geschrieben hat.
                       // Diese Bücher schreibt die Pipeline – die wahrheitsgemäße
                       // Angabe ist „ai-generated". Eine falsche, weichere Angabe ist
                       // der klassische Sperrgrund, sobald Amazon sie entdeckt.
                       aiDisclosure: "ai-generated")
    }

    @discardableResult
    func enqueue(project: Project, priceEUR: Double, aiDisclosure: String) -> Bool {
        guard !isQueued(project.id) else { return false }
        let entry = QueueEntry(
            id: UUID(), projectID: project.id, title: project.title,
            author: project.authorName, priceEUR: priceEUR, aiDisclosure: aiDisclosure,
            stage: .queued, lastMessage: "In Warteschlange aufgenommen.",
            draftURL: nil, enqueuedAt: Date(), updatedAt: Date())
        queue.append(entry)
        persist()
        return true
    }

    func remove(_ entryID: UUID) {
        queue.removeAll { $0.id == entryID }
        persist()
    }

    private func update(_ entryID: UUID, _ mutate: (inout QueueEntry) -> Void) {
        guard let i = queue.firstIndex(where: { $0.id == entryID }) else { return }
        mutate(&queue[i]); queue[i].updatedAt = Date(); persist()
    }

    // MARK: - Dispatcher

    /// Startet den Hintergrund-Takt (prüft periodisch, ob ein Buch hochgeladen werden kann).
    func startDispatcher() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.tick() }
        }
        Task { await tick() }
    }
    func stopDispatcher() { timer?.invalidate(); timer = nil }

    /// Manuell einen Upload anstoßen (Button „Jetzt hochladen").
    func uploadNext(resolveProject: @escaping (UUID) -> Project?) async {
        await tick(force: true, resolveProject: resolveProject)
    }

    private var projectResolver: ((UUID) -> Project?)?
    func setProjectResolver(_ r: @escaping (UUID) -> Project?) { projectResolver = r }

    private func tick(force: Bool = false, resolveProject: ((UUID) -> Project?)? = nil) async {
        guard !isDispatching else { return }
        guard force || enabled else { return }
        // Kalender greift nur im automatischen Betrieb; „Jetzt hochladen" (force) übergeht ihn.
        if !force, let reason = scheduleReason {
            for e in queue where e.stage == .queued {
                update(e.id) { $0.stage = .waitingSlot; $0.lastMessage = reason }
            }
            return
        }
        guard freeSlots > 0 else {
            // Wartende Einträge markieren, damit die UI den Grund zeigt.
            for e in queue where e.stage == .queued {
                update(e.id) { $0.stage = .waitingSlot; $0.lastMessage = throttleReason ?? "Wartet auf freien Slot." }
            }
            return
        }
        // Nur Einträge, deren Wartezeit abgelaufen ist – sonst blockiert ein dauerhaft
        // scheiterndes Buch (z. B. weil die Selbstprüfung es zurückhält) die gesamte
        // Warteschlange und alle folgenden Bücher kommen nie an die Reihe.
        let jetzt = Date()
        guard let next = queue.first(where: {
            ($0.stage == .queued || $0.stage == .waitingSlot || $0.stage == .failed)
                && $0.retryDue(at: jetzt)
        }) else { return }
        let resolver = resolveProject ?? projectResolver
        guard let project = resolver?(next.projectID) else {
            update(next.id) { $0.lastMessage = "Projekt nicht gefunden – übersprungen." }
            return
        }
        isDispatching = true
        update(next.id) { $0.stage = .uploading; $0.lastMessage = "Upload läuft …" }
        do {
            let result = try await KDPUploadService.uploadDraft(
                project: project, priceEUR: next.priceEUR, aiDisclosure: next.aiDisclosure,
                progress: { [weak self] msg in
                    Task { @MainActor in self?.update(next.id) { $0.lastMessage = msg } }
                })
            history.append(UploadRecord(id: UUID(), projectID: next.projectID, title: next.title, uploadedAt: Date()))
            update(next.id) {
                $0.stage = .draftReady
                $0.attempts = 0
                $0.lastTriedAt = Date()
                $0.draftURL = result.draftURL
                // Offene Pflichtfelder ehrlich anzeigen statt pauschal "fertig".
                // Vorher meldete der Sidecar hier immer Erfolg; ein Entwurf mit
                // fehlendem Cover sah aus wie ein vollständiger.
                $0.lastMessage = result.offenePunkte.isEmpty
                    ? "Entwurf in KDP – Preis prüfen und veröffentlichen."
                    : "Entwurf gespeichert, aber \(result.offenePunkte.count) Pflichtfeld(er) offen: "
                        + result.offenePunkte.prefix(4).joined(separator: " · ")
            }
        } catch {
            update(next.id) {
                $0.stage = .failed
                $0.attempts += 1
                $0.lastTriedAt = Date()
                $0.lastMessage = "Fehlgeschlagen (Versuch \($0.attempts)): "
                    + ((error as? AIError)?.errorDescription ?? error.localizedDescription)
            }
        }
        isDispatching = false
    }

    // MARK: - Login-Status

    func refreshLoginState() async {
        loginState = "prüft…"
        let ok = await KDPUploadService.checkLogin()
        loginState = ok ? "eingeloggt" : "nicht eingeloggt"
    }
}
