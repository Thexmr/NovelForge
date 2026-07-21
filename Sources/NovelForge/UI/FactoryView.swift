import SwiftUI
import SwiftData

/// Überwachungs- und Steuerzentrale der autonomen KDP-Buchfabrik:
/// Ein/Aus, Drossel-Slots, KDP-Login, Warteschlange mit Live-Status.
@MainActor
struct FactoryView: View {
    @ObservedObject private var factory = KDPFactory.shared
    @Environment(\.modelContext) private var modelContext
    private var _projects = Query<Project, [Project]>(sort: \Project.updatedAt, order: .reverse)
    private var projects: [Project] { _projects.wrappedValue }

    @State private var loginRunning = false
    @State private var loginNote: String?

    private func project(_ id: UUID) -> Project? { projects.first { $0.id == id } }

    /// Fertige Bücher (mit Cover + EPUB), die noch nicht in der Warteschlange sind.
    private var uploadReady: [Project] {
        projects.filter {
            $0.status == .completed
                && !factory.isQueued($0.id)
                && CoverArtService.coverURL(for: $0) != nil
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                loginCard
                slotsCard
                calendarCard
                if !uploadReady.isEmpty { readyCard }
                queueCard
            }
            .padding(22)
            .frame(maxWidth: 900, alignment: .leading)
        }
        .background(StudioBackground())
        .navigationTitle("Buchfabrik")
        .onAppear {
            factory.setProjectResolver { id in projects.first { $0.id == id } }
            if factory.enabled { factory.startDispatcher() }
            Task { await factory.refreshLoginState() }
        }
    }

    // MARK: - Kopf mit Ein/Aus

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Autonome KDP-Buchfabrik")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(StudioTheme.heroGradient)
                Text("Fertige Bücher werden mit Cover und allen Texten automatisch als KDP-ENTWURF hochgeladen. Der letzte Veröffentlichen-Klick bleibt bei dir.")
                    .font(.callout)
                    .foregroundStyle(StudioTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Toggle("", isOn: Binding(
                    get: { factory.enabled },
                    set: { on in
                        factory.enabled = on
                        if on { factory.startDispatcher() } else { factory.stopDispatcher() }
                    }))
                    .toggleStyle(.switch)
                    .labelsHidden()
                Text(factory.enabled ? "FABRIK AN" : "Fabrik aus")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(factory.enabled ? StudioTheme.lime : StudioTheme.textFaint)
            }
        }
        .padding(18)
        .studioFeaturedPanel(cornerRadius: 10)
    }

    // MARK: - Login

    private var loginCard: some View {
        HStack(spacing: 14) {
            Image(systemName: factory.loginState == "eingeloggt" ? "person.badge.shield.checkmark" : "person.crop.circle.badge.exclamationmark")
                .font(.title2)
                .foregroundStyle(factory.loginState == "eingeloggt" ? StudioTheme.lime : StudioTheme.amber)
            VStack(alignment: .leading, spacing: 2) {
                Text("KDP-Konto: \(factory.loginState)")
                    .font(.callout.weight(.semibold))
                Text("Einmalig im Browser einloggen (inkl. 2FA). Danach lädt die Fabrik autonom – die Session bleibt gespeichert.")
                    .font(.caption).foregroundStyle(StudioTheme.textMuted)
                if let loginNote { Text(loginNote).font(.caption2).foregroundStyle(StudioTheme.cyan) }
            }
            Spacer()
            Button {
                doLogin()
            } label: {
                if loginRunning { HStack(spacing: 6) { StudioLiveIndicator(color: StudioTheme.cyan); Text("Browser offen …") } }
                else { Label("KDP-Login", systemImage: "safari") }
            }
            .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.cyan))
            .disabled(loginRunning || !KDPUploadService.sidecarReady)
        }
        .padding(16)
        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.cyan, opacity: 0.9)
        .overlay(alignment: .bottomLeading) {
            if !KDPUploadService.sidecarReady {
                Text("Sidecar noch nicht eingerichtet – Setup nötig (siehe Anleitung).")
                    .font(.caption2).foregroundStyle(StudioTheme.amber).padding(.leading, 16).padding(.bottom, 4)
            }
        }
    }

    // MARK: - Slots / Drossel

    private var slotsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upload-Drossel (Konto-Schutz)")
                .font(.headline)
            HStack(spacing: 16) {
                slotBox("Heute", factory.usedToday, factory.limits.perDay, StudioTheme.lime)
                slotBox("Diese Woche", factory.usedThisWeek, factory.limits.perWeek, StudioTheme.cyan)
                slotBox("Dieser Monat", factory.usedThisMonth, factory.limits.perMonth, StudioTheme.violet)
            }
            if let reason = factory.throttleReason {
                Label(reason, systemImage: "hourglass")
                    .font(.caption).foregroundStyle(StudioTheme.amber)
            } else {
                Label("\(factory.freeSlots) Upload-Slot(s) frei.", systemImage: "checkmark.circle")
                    .font(.caption).foregroundStyle(StudioTheme.lime)
            }
            HStack(spacing: 12) {
                stepper("Tag", value: Binding(get: { factory.limits.perDay }, set: { factory.limits.perDay = $0 }), range: 1...10)
                stepper("Woche", value: Binding(get: { factory.limits.perWeek }, set: { factory.limits.perWeek = $0 }), range: 1...30)
                stepper("Monat", value: Binding(get: { factory.limits.perMonth }, set: { factory.limits.perMonth = $0 }), range: 1...100)
            }
        }
        .padding(16)
        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.lime, opacity: 0.9)
    }

    private func slotBox(_ label: String, _ used: Int, _ limit: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(max(0, limit - used))/\(limit)")
                .font(.system(.title2, design: .rounded).weight(.bold))
                .foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(StudioTheme.textMuted)
            Text("frei").font(.caption2).foregroundStyle(StudioTheme.textFaint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(StudioTheme.glassInk.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }

    private func stepper(_ label: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption).foregroundStyle(StudioTheme.textMuted)
            Stepper("\(value.wrappedValue)", value: value, in: range).labelsHidden()
            Text("\(value.wrappedValue)").font(.caption.weight(.semibold)).frame(width: 22)
        }
    }

    // MARK: - Upload-Kalender

    private let weekdayNames = [(1, "Mo"), (2, "Di"), (3, "Mi"), (4, "Do"), (5, "Fr"), (6, "Sa"), (7, "So")]

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Upload-Kalender")
                    .font(.headline)
                Spacer()
                Toggle("aktiv", isOn: Binding(
                    get: { factory.schedule.active },
                    set: { factory.schedule.active = $0 }))
                    .toggleStyle(.switch)
            }
            Text("Lege fest, an welchen Tagen und in welchem Zeitfenster automatisch hochgeladen wird. Ohne Kalender lädt die Fabrik jederzeit (nur die Drossel begrenzt).")
                .font(.caption).foregroundStyle(StudioTheme.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            if factory.schedule.active {
                // Wochentage
                HStack(spacing: 6) {
                    ForEach(weekdayNames, id: \.0) { day in
                        let on = factory.schedule.weekdays.contains(day.0)
                        Button {
                            if on { factory.schedule.weekdays.remove(day.0) }
                            else { factory.schedule.weekdays.insert(day.0) }
                        } label: {
                            Text(day.1)
                                .font(.caption.weight(.semibold))
                                .frame(width: 34, height: 30)
                                .background(on ? StudioTheme.cyan.opacity(0.85) : StudioTheme.glassInk.opacity(0.5),
                                           in: RoundedRectangle(cornerRadius: 7))
                                .foregroundStyle(on ? Color.black : StudioTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                // Zeitfenster + Intervall
                HStack(spacing: 18) {
                    HStack(spacing: 4) {
                        Text("von").font(.caption).foregroundStyle(StudioTheme.textMuted)
                        Stepper("\(factory.schedule.startHour)", value: Binding(
                            get: { factory.schedule.startHour },
                            set: { factory.schedule.startHour = min($0, factory.schedule.endHour - 1) }), in: 0...22).labelsHidden()
                        Text("\(factory.schedule.startHour) Uhr").font(.caption.weight(.semibold)).frame(width: 48)
                    }
                    HStack(spacing: 4) {
                        Text("bis").font(.caption).foregroundStyle(StudioTheme.textMuted)
                        Stepper("\(factory.schedule.endHour)", value: Binding(
                            get: { factory.schedule.endHour },
                            set: { factory.schedule.endHour = max($0, factory.schedule.startHour + 1) }), in: 1...23).labelsHidden()
                        Text("\(factory.schedule.endHour) Uhr").font(.caption.weight(.semibold)).frame(width: 48)
                    }
                    HStack(spacing: 4) {
                        Text("Abstand").font(.caption).foregroundStyle(StudioTheme.textMuted)
                        Stepper("\(factory.schedule.minHoursBetween)", value: Binding(
                            get: { factory.schedule.minHoursBetween },
                            set: { factory.schedule.minHoursBetween = $0 }), in: 0...24).labelsHidden()
                        Text("\(factory.schedule.minHoursBetween) h").font(.caption.weight(.semibold)).frame(width: 34)
                    }
                }
                if let reason = factory.scheduleReason {
                    Label(reason, systemImage: "calendar.badge.clock")
                        .font(.caption).foregroundStyle(StudioTheme.amber)
                } else {
                    Label("Kalender erlaubt jetzt Uploads.", systemImage: "calendar.badge.checkmark")
                        .font(.caption).foregroundStyle(StudioTheme.lime)
                }
            }
        }
        .padding(16)
        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.cyan, opacity: 0.9)
    }

    // MARK: - Bereit zum Einreihen

    private var readyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fertig – in die Warteschlange legen")
                .font(.headline)
            ForEach(uploadReady) { p in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(p.title).font(.callout.weight(.medium))
                        Text("\(p.genre) · \(FormattingHelpers.formatWordCount(p.totalWordCount)) Wörter · Cover ✓")
                            .font(.caption2).foregroundStyle(StudioTheme.textMuted)
                    }
                    Spacer()
                    Button {
                        _ = factory.enqueue(project: p, priceEUR: defaultPrice, aiDisclosure: "ai-assisted")
                    } label: { Label("Einreihen", systemImage: "plus.circle") }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
                Divider().opacity(0.3)
            }
        }
        .padding(16)
        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.cyan, opacity: 0.9)
    }
    private var defaultPrice: Double { 3.99 }

    // MARK: - Warteschlange

    private var queueCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Warteschlange")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await factory.uploadNext { id in project(id) } }
                } label: { Label("Nächsten jetzt hochladen", systemImage: "arrow.up.circle") }
                    .buttonStyle(.borderless).font(.caption)
                    .disabled(factory.isDispatching || factory.freeSlots <= 0 || factory.queue.isEmpty)
            }
            if factory.queue.isEmpty {
                Text("Leer. Fertige Bücher erscheinen oben zum Einreihen.")
                    .font(.caption).foregroundStyle(StudioTheme.textFaint)
            } else {
                ForEach(factory.queue) { entry in
                    HStack(alignment: .top, spacing: 10) {
                        stageIcon(entry.stage)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title).font(.callout.weight(.medium))
                            Text(entry.lastMessage).font(.caption2).foregroundStyle(StudioTheme.textMuted)
                                .fixedSize(horizontal: false, vertical: true)
                            if entry.stage == .draftReady, let u = entry.draftURL, let url = URL(string: u) {
                                Link("Entwurf in KDP öffnen → Preis prüfen & veröffentlichen", destination: url)
                                    .font(.caption2)
                            }
                        }
                        Spacer()
                        Text("\(String(format: "%.2f", entry.priceEUR)) €")
                            .font(.caption.weight(.semibold)).foregroundStyle(StudioTheme.textMuted)
                        Button { factory.remove(entry.id) } label: { Image(systemName: "xmark.circle") }
                            .buttonStyle(.borderless).foregroundStyle(StudioTheme.textFaint)
                    }
                    .padding(.vertical, 5)
                    Divider().opacity(0.3)
                }
            }
        }
        .padding(16)
        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.violet, opacity: 0.9)
    }

    @ViewBuilder
    private func stageIcon(_ stage: KDPFactory.EntryStage) -> some View {
        switch stage {
        case .queued: Image(systemName: "tray.and.arrow.down").foregroundStyle(StudioTheme.textMuted)
        case .waitingSlot: Image(systemName: "hourglass").foregroundStyle(StudioTheme.amber)
        case .uploading: StudioLiveIndicator(color: StudioTheme.cyan)
        case .draftReady: Image(systemName: "checkmark.seal.fill").foregroundStyle(StudioTheme.lime)
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(StudioTheme.amber)
        }
    }

    // MARK: - Aktionen

    private func doLogin() {
        loginRunning = true; loginNote = "Bitte im Browserfenster bei Amazon KDP einloggen (inkl. 2FA)…"
        Task {
            do {
                try await KDPUploadService.login { msg in Task { @MainActor in loginNote = msg } }
                await factory.refreshLoginState()
                await MainActor.run { loginNote = "Login abgeschlossen."; loginRunning = false }
            } catch {
                await MainActor.run {
                    loginNote = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    loginRunning = false
                }
            }
        }
    }
}
