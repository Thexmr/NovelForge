import SwiftUI
import SwiftData
import AppKit

struct KDPSalesSheetView: View {
    let project: Project

    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @Environment(\.modelContext) private var modelContext
    @State private var isGenerating = false
    @State private var statusNote: String?

    private var sheet: KDPSalesSheet {
        // Defensive: gelöschtes Projekt (modelContext == nil) → keine toten
        // @Model-Relationen lesen (sonst EXC_BREAKPOINT wie bei früherem Export-Crash).
        guard project.modelContext != nil else { return .empty }
        return KDPSalesSheet.make(for: project)
    }

    private var canGenerate: Bool {
        project.modelContext != nil && project.bookProfile != nil
            && project.status == .completed && !isGenerating && !orchestrator.isRunning
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label("KDP-Verkaufsseite", systemImage: "cart.badge.plus")
                    .font(.headline)
                    .foregroundStyle(StudioTheme.heroGradient)
                Spacer()
                StudioStatusPill(text: sheet.hasGeneratedMetadata ? "bereit" : "wartet",
                                 systemImage: sheet.hasGeneratedMetadata ? "checkmark.seal" : "clock",
                                 color: sheet.hasGeneratedMetadata ? StudioTheme.lime : StudioTheme.amber)
                Button {
                    generate()
                } label: {
                    if isGenerating {
                        StudioLiveIndicator(color: StudioTheme.cyan, isActive: true)
                    } else {
                        Label(sheet.hasGeneratedMetadata ? "Neu generieren" : "Generieren",
                              systemImage: "sparkles")
                    }
                }
                .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.cyan))
                .disabled(!canGenerate)
                .help("Viralen Verkaufstitel, Untertitel, Verkaufstext, Keywords und Kategorien per KI erzeugen.")
            }

            if let statusNote {
                Text(statusNote)
                    .font(.caption2)
                    .foregroundStyle(StudioTheme.textMuted)
            }

            VStack(alignment: .leading, spacing: 10) {
                salesField("Verkaufstitel", sheet.title, accent: StudioTheme.cyan)
                if project.modelContext != nil, !sheet.title.isEmpty, sheet.title != project.title {
                    Button {
                        project.title = sheet.title
                        project.updatedAt = Date()
                        modelContext.saveOrLog()
                    } label: {
                        Label("Als Buchtitel übernehmen", systemImage: "arrow.up.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                if !sheet.series.isEmpty {
                    salesField("Serie / Reihe", sheet.series, accent: StudioTheme.violet)
                }
                if !sheet.hook.isEmpty {
                    salesField("Untertitel / Hook", sheet.hook, accent: StudioTheme.violet)
                }
                if !sheet.salesDescription.isEmpty {
                    salesField("Verkaufstext", sheet.salesDescription, accent: StudioTheme.cyan)
                }
                if !sheet.keywords.isEmpty {
                    salesField("Keywords", sheet.keywords, accent: StudioTheme.violet)
                }
                if !sheet.categories.isEmpty {
                    salesField("Kategorien", sheet.categories, accent: StudioTheme.cyan)
                }
                if !sheet.authorProfile.isEmpty {
                    salesField("Autorprofil", sheet.authorProfile, accent: StudioTheme.cyan)
                }
                if !sheet.hasGeneratedMetadata {
                    Label("Verkaufstext, Keywords und Kategorien entstehen automatisch in der KDP-Formatierung.",
                          systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(StudioTheme.textMuted)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .studioGlassTile(cornerRadius: 8, accent: StudioTheme.cyan, opacity: 0.9)

            if !sheet.keywordSlots.isEmpty || !sheet.categorySlots.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline) {
                        Label("KDP-Upload · Tags & Felder", systemImage: "tag")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(StudioTheme.heroGradient)
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(sheet.exportText, forType: .string)
                        } label: {
                            Label("Komplettes Blatt kopieren", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    Text("Genau die Felder, die Amazon KDP beim Hochladen abfragt.")
                        .font(.caption2).foregroundStyle(StudioTheme.textFaint)

                    if !sheet.keywordSlots.isEmpty {
                        Text("7 SUCHBEGRIFFE (KEYWORDS)")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .foregroundStyle(StudioTheme.textFaint)
                        ForEach(Array(sheet.keywordSlots.prefix(7).enumerated()), id: \.offset) { i, kw in
                            uploadSlot("\(i + 1)", kw, accent: StudioTheme.violet)
                        }
                    }
                    if !sheet.categorySlots.isEmpty {
                        Text("KATEGORIEN (MAX. 3)")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .foregroundStyle(StudioTheme.textFaint)
                            .padding(.top, 4)
                        ForEach(Array(sheet.categorySlots.prefix(3).enumerated()), id: \.offset) { i, cat in
                            uploadSlot("\(i + 1)", cat, accent: StudioTheme.cyan)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .studioGlassTile(cornerRadius: 8, accent: StudioTheme.violet, opacity: 0.9)
            }
        }
    }

    private func uploadSlot(_ index: String, _ value: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            Text(index)
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 16)
            Text(value)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc").frame(width: 22, height: 22)
            }
            .buttonStyle(.borderless)
            .help("Kopieren")
            .accessibilityLabel("Kopieren")
        }
    }

    private func generate() {
        guard canGenerate else { return }
        isGenerating = true
        statusNote = nil
        Task { @MainActor in
            let result = await orchestrator.generateKDPSalesSheet(project: project)
            modelContext.saveOrLog()
            statusNote = result
            isGenerating = false
        }
    }

    private func salesField(_ label: String, _ value: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 3)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(StudioTheme.textFaint)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("\(label) kopieren")
            .accessibilityLabel("\(label) kopieren")
        }
    }
}

/// Eigenständiger Sidebar-Bereich „KDP-Verkauf": Buch wählen und die Amazon-KDP-
/// Verkaufstexte (viraler Titel, Untertitel, Verkaufstext, Keywords, Kategorien)
/// ansehen, kopieren oder neu generieren.
struct KDPMarketingView: View {
    private var _projects = Query<Project, [Project]>(sort: \Project.updatedAt, order: .reverse)
    private var projects: [Project] { _projects.wrappedValue }
    @ObservedObject private var appState = AppState.shared

    private var eligibleProjects: [Project] {
        projects.filter { $0.bookProfile != nil }
    }

    var body: some View {
        HSplitView {
            Group {
                if eligibleProjects.isEmpty {
                    ContentUnavailableView("Noch keine Bücher", systemImage: "cart",
                        description: Text("Sobald ein Buch ein Konzept hat, entstehen hier die KDP-Verkaufstexte."))
                } else {
                    List(selection: $appState.selectedProject) {
                        ForEach(eligibleProjects) { project in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.title).lineLimit(1)
                                StatusBadge(status: project.status)
                            }
                            .tag(project)
                        }
                    }
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)

            Group {
                if let project = appState.selectedProject, project.modelContext != nil {
                    PublishingDetailView(project: project)
                } else {
                    ContentUnavailableView("Buch wählen", systemImage: "shippingbox")
                }
            }
            .frame(minWidth: 440, maxWidth: .infinity)
        }
        .background(StudioBackground())
        .navigationTitle("Veröffentlichung")
    }
}

/// Veröffentlichungs-Studio für ein fertiges Buch: komplettes Paket per Pipeline
/// (Nachbearbeitung + KDP-Verkaufstexte + Cover-Prompts) oder einzeln, alles
/// passgenau auf dieses Buch.
struct PublishingDetailView: View {
    let project: Project

    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @Environment(\.modelContext) private var modelContext
    @State private var isRunningPackage = false
    @State private var packageNote: String?
    @State private var isRepairing = false
    @State private var repairNote: String?
    @State private var isOptimizingOpening = false
    @State private var openingNote: String?
    @State private var isAddingCliffhanger = false
    @State private var cliffhangerNote: String?
    @State private var isExpanding = false
    @State private var expandNote: String?
    @State private var expandTargetPages = 0

    private var busy: Bool {
        project.status != .completed || isRunningPackage || isRepairing
            || isOptimizingOpening || isAddingCliffhanger || isExpanding || orchestrator.isRunning
    }

    private var readinessIssues: [String] {
        PublicationReadiness.cachedCompletionBlockingIssues(project: project)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.title)
                            .font(.title.weight(.bold))
                            .foregroundStyle(StudioTheme.heroGradient)
                        Text("\(project.authorName) · \(project.genre) · \(FormattingHelpers.formatWordCount(project.totalWordCount)) Wörter")
                            .foregroundStyle(StudioTheme.textMuted)
                    }
                    Spacer()
                    StudioStatusPill(text: readinessIssues.isEmpty ? "veröffentlichungsbereit" : "Prüfung nötig",
                                     systemImage: readinessIssues.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                                     color: readinessIssues.isEmpty ? StudioTheme.lime : StudioTheme.amber)
                }
                .padding(18)
                .studioFeaturedPanel(cornerRadius: 8)

                if project.status != .completed {
                    Label("Das Buch befindet sich noch in Produktion. Veröffentlichungsaktionen werden nach Abschluss freigeschaltet.",
                          systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(StudioTheme.amber)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.amber, opacity: 0.88)
                } else if !readinessIssues.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Label("Vor dem Export prüfen", systemImage: "checklist")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(StudioTheme.amber)
                        ForEach(readinessIssues.prefix(4), id: \.self) { issue in
                            Text("• \(issue)")
                                .font(.caption)
                                .foregroundStyle(StudioTheme.textMuted)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .studioGlassTile(cornerRadius: 8, accent: StudioTheme.amber, opacity: 0.88)
                }

                CoverSection(project: project)

                // Master: komplette Veröffentlichungs-Pipeline
                VStack(alignment: .leading, spacing: 8) {
                    Text("Veröffentlichungs-Paket")
                        .font(.headline)
                    Text("Eine eigene Agenten-Pipeline veredelt das fertige Buch nach: Konsistenz-Reparatur → perfekte KDP-Verkaufstexte → Cover-Prompts – alles passend zu diesem Buch.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            runPackage()
                        } label: {
                            if isRunningPackage {
                                HStack(spacing: 6) { StudioLiveIndicator(color: StudioTheme.cyan); Text("Pipeline läuft …") }
                            } else {
                                Label("Komplettes Paket erstellen", systemImage: "sparkles")
                            }
                        }
                        .buttonStyle(StudioPrimaryButtonStyle())
                        .frame(maxWidth: 230)
                        .disabled(busy || project.status != .completed)
                    }
                    if let packageNote {
                        Text(packageNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .studioFeaturedPanel(cornerRadius: 8)

                // Nachbearbeitung einzeln
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nachbearbeitung").font(.headline)
                    Text("Die Nachbearbeitung prüft das fertige Buch auf Unstimmigkeiten (Zeitlinie, Figurenwissen, Kontinuität, Logik) und Lesesog und korrigiert gezielt nur die betroffenen Stellen – nach dem Proofreading.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            repair()
                        } label: {
                            if isRepairing {
                                HStack(spacing: 6) { StudioLiveIndicator(color: StudioTheme.lime); Text("Wird geprüft …") }
                            } else {
                                Label("Konsistenz & Spannung prüfen", systemImage: "wand.and.stars")
                            }
                        }
                        .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.lime))
                        .disabled(busy)
                        if let repairNote {
                            Text(repairNote).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // Buch erweitern (Umfang vergrößern, Handlung bewahren)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Buch erweitern").font(.headline)
                    Text("Bringt das Buch stimmig auf mehr Umfang: Jedes Kapitel wird vertieft, während Handlung, Figuren und Reihenfolge erhalten bleiben.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Stepper("Zielumfang: \(expandTargetPages) Seiten", value: $expandTargetPages,
                                in: AppConstants.minPageCount...AppConstants.maxPageCount, step: 50)
                            .frame(maxWidth: 280)
                        Button {
                            expandBook()
                        } label: {
                            if isExpanding {
                                HStack(spacing: 6) { StudioLiveIndicator(color: StudioTheme.violet); Text("Wird erweitert …") }
                            } else {
                                Label("Buch erweitern", systemImage: "book")
                            }
                        }
                        .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.violet))
                        .disabled(busy || expandTargetPages <= project.targetPageCount)
                    }
                    if let expandNote {
                        Text(expandNote).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .onAppear {
                    if expandTargetPages == 0 {
                        let currentPages = max(project.totalWordCount / 250, project.targetPageCount)
                        expandTargetPages = min(AppConstants.maxPageCount,
                                                max(currentPages + 50, currentPages * 2))
                    }
                }

                // Blick ins Buch (Conversion-Hebel)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Blick ins Buch").font(.headline)
                    Text("Die Amazon-Leseprobe entscheidet häufig über den Kauf. Die Nachbearbeitung schärft den Anfang des ersten Kapitels auf Lesesog, ohne die Handlung zu ändern.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            optimizeOpening()
                        } label: {
                            if isOptimizingOpening {
                                HStack(spacing: 6) { StudioLiveIndicator(color: StudioTheme.cyan); Text("Wird optimiert …") }
                            } else {
                                Label("Anfang optimieren", systemImage: "text.alignleft")
                            }
                        }
                        .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.cyan))
                        .disabled(busy)
                        if let openingNote {
                            Text(openingNote).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // Serie / Read-Through
                VStack(alignment: .leading, spacing: 8) {
                    Text("Serie · Read-Through").font(.headline)
                    Text("Für Reihen kann am Ende ein Cliffhanger mit Teaser auf den nächsten Band ergänzt werden, während der Abschluss dieses Buches erhalten bleibt.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            addCliffhanger()
                        } label: {
                            if isAddingCliffhanger {
                                HStack(spacing: 6) { StudioLiveIndicator(color: StudioTheme.amber); Text("Wird eingebaut …") }
                            } else {
                                Label("Cliffhanger + Teaser einbauen", systemImage: "books.vertical")
                            }
                        }
                        .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.amber))
                        .disabled(busy)
                        if let cliffhangerNote {
                            Text(cliffhangerNote).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                KDPSalesSheetView(project: project)
                CoverPromptsView(project: project)
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func runPackage() {
        guard project.modelContext != nil, !busy else { return }
        isRunningPackage = true
        packageNote = nil
        Task { @MainActor in
            let result = await orchestrator.runPublishingPackage(project: project)
            modelContext.saveOrLog()
            packageNote = result
            isRunningPackage = false
        }
    }

    private func repair() {
        guard project.modelContext != nil, !busy else { return }
        isRepairing = true
        repairNote = nil
        Task { @MainActor in
            let reply = await orchestrator.repairBookAfterProofreading(project: project)
            repairNote = reply
            isRepairing = false
        }
    }

    private func expandBook() {
        guard project.modelContext != nil, !busy, expandTargetPages > project.targetPageCount else { return }
        isExpanding = true
        expandNote = nil
        Task { @MainActor in
            let reply = await orchestrator.expandBook(project: project, targetPageCount: expandTargetPages)
            modelContext.saveOrLog()
            expandNote = reply
            isExpanding = false
        }
    }

    private func optimizeOpening() {
        guard project.modelContext != nil, !busy else { return }
        isOptimizingOpening = true
        openingNote = nil
        Task { @MainActor in
            let reply = await orchestrator.optimizeOpening(project: project)
            modelContext.saveOrLog()
            openingNote = reply
            isOptimizingOpening = false
        }
    }

    private func addCliffhanger() {
        guard project.modelContext != nil, !busy else { return }
        isAddingCliffhanger = true
        cliffhangerNote = nil
        Task { @MainActor in
            let reply = await orchestrator.addSeriesCliffhanger(project: project)
            modelContext.saveOrLog()
            cliffhangerNote = reply
            isAddingCliffhanger = false
        }
    }
}

/// Eigenes Feld mit fertigen, kopierbaren Cover-Bild-Prompts (für ChatGPT/DALL·E).
struct CoverPromptsView: View {
    let project: Project

    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @ObservedObject private var coverStore = CoverImageSettingsStore.shared
    @Environment(\.modelContext) private var modelContext
    @AppStorage("kdpCoverStudioPath") private var coverStudioPath = "/Users/dave/AMZ KDP KI"
    @State private var isGenerating = false
    @State private var statusNote: String?
    @State private var imageStatus: String?
    @State private var generatingImageIndex: Int?

    private var prompts: String {
        project.bookProfile?.coverPrompts.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    struct CoverConcept: Identifiable { let id: Int; let text: String }

    /// Zerlegt den Prompt-Block in einzelne Cover-Konzepte (PROMPT 1/2/3 …).
    private var concepts: [CoverConcept] {
        guard !prompts.isEmpty else { return [] }
        var result: [CoverConcept] = []
        var current = ""
        func flush() {
            let t = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty { result.append(CoverConcept(id: result.count + 1, text: t)) }
        }
        for line in prompts.components(separatedBy: .newlines) {
            if line.range(of: #"^\s*PROMPT\s*\d+\s*:"#, options: .regularExpression) != nil {
                flush()
                current = line.replacingOccurrences(of: #"^\s*PROMPT\s*\d+\s*:\s*"#,
                                                    with: "", options: .regularExpression)
            } else {
                current += "\n" + line
            }
        }
        flush()
        return result
    }

    private var canGenerate: Bool {
        project.modelContext != nil && project.bookProfile != nil
            && project.status == .completed && !isGenerating && !orchestrator.isRunning
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label("Cover-Prompts (für ChatGPT/DALL·E)", systemImage: "photo.artframe")
                    .font(.headline)
                    .foregroundStyle(StudioTheme.heroGradient)
                Spacer()
                StudioStatusPill(text: prompts.isEmpty ? "wartet" : "bereit",
                                 systemImage: prompts.isEmpty ? "clock" : "checkmark.seal",
                                 color: prompts.isEmpty ? StudioTheme.amber : StudioTheme.lime)
                Button {
                    generate()
                } label: {
                    if isGenerating {
                        StudioLiveIndicator(color: StudioTheme.violet, isActive: true)
                    } else {
                        Label(prompts.isEmpty ? "Generieren" : "Neu generieren", systemImage: "sparkles")
                    }
                }
                .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.violet))
                .disabled(!canGenerate)
                .help("Fertige Bild-Prompts erzeugen, die du direkt in ChatGPT/DALL·E einfügst, um das Cover zu erstellen.")
            }

            if let statusNote {
                Text(statusNote).font(.caption2).foregroundStyle(StudioTheme.textMuted)
            }
            if let imageStatus {
                Text(imageStatus).font(.caption2).foregroundStyle(StudioTheme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if prompts.isEmpty {
                Label("Noch keine Cover-Prompts. „Generieren“ erzeugt 3 fertige, einfügefertige Prompts für dieses Buch.",
                      systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(StudioTheme.textMuted)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .studioGlassTile(cornerRadius: 8, accent: StudioTheme.violet, opacity: 0.9)
            } else {
                ForEach(concepts) { concept in
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Konzept \(concept.id)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(StudioTheme.textFaint)
                        Text(concept.text)
                            .font(.callout)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 10) {
                            Button {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(concept.text, forType: .string)
                            } label: {
                                Label("Kopieren", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.violet))
                            Button {
                                generateImage(prompt: concept.text, index: concept.id)
                            } label: {
                                if generatingImageIndex == concept.id {
                                    HStack(spacing: 6) { StudioLiveIndicator(color: StudioTheme.cyan); Text("Bild wird erstellt …") }
                                } else {
                                    Label("Als Cover-Bild erzeugen", systemImage: "photo.badge.plus")
                                }
                            }
                            .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.cyan))
                            .disabled(generatingImageIndex != nil || orchestrator.isRunning)
                        }
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .studioGlassTile(cornerRadius: 8, accent: StudioTheme.violet, opacity: 0.9)
                }
            }

            Button {
                openCoverStudio()
            } label: {
                Label("Im KDP Cover Studio öffnen (druckfertiges Cover)", systemImage: "shippingbox")
            }
            .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.amber))
            .help("Öffnet das KDP Cover Studio für druckfertige Paperback-/Hardcover-Wraps (exakte KDP-Maße, 300 DPI, mehrere Bild-Anbieter). Der erste Cover-Prompt wird in die Zwischenablage gelegt.")
        }
    }

    private func openCoverStudio() {
        let dir = URL(fileURLWithPath: coverStudioPath)
        let command = dir.appendingPathComponent("Start KDP Cover Studio.command")
        let html = dir.appendingPathComponent("index.html")
        let fm = FileManager.default
        let target: URL
        if fm.fileExists(atPath: command.path) { target = command }
        else if fm.fileExists(atPath: html.path) { target = html }
        else {
            imageStatus = "KDP Cover Studio nicht gefunden unter \(coverStudioPath) – Pfad in den Einstellungen anpassen."
            return
        }
        let clip = concepts.first?.text ?? "\(project.title) — \(project.genre)"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(clip, forType: .string)
        NSWorkspace.shared.open(target)
        imageStatus = "KDP Cover Studio geöffnet · Cover-Prompt liegt in der Zwischenablage (im Studio einfügen)."
    }

    private func generateImage(prompt: String, index: Int) {
        guard coverStore.hasAPIKey() else {
            imageStatus = "Für die direkte Cover-Bild-Erzeugung fehlt der Bild-API-Key (in den Einstellungen hinterlegen). Du kannst den Prompt aber kopieren und in ChatGPT/DALL·E nutzen."
            return
        }
        generatingImageIndex = index
        imageStatus = nil
        let settings = coverStore.runtimeSettings()
        Task {
            do {
                let dest = try CoverDesignService.artworkURL(for: project)
                let artwork = try await CoverImageGateway.shared.generateImage(
                    prompt: prompt, destination: dest, settings: settings)
                let cover = try CoverComposer.composeCover(artworkURL: artwork, project: project)
                await MainActor.run {
                    imageStatus = "Cover-Bild aus Konzept \(index) erstellt: \(cover.lastPathComponent)"
                    generatingImageIndex = nil
                }
            } catch {
                await MainActor.run {
                    imageStatus = error.localizedDescription
                    generatingImageIndex = nil
                }
            }
        }
    }

    private func generate() {
        guard canGenerate else { return }
        isGenerating = true
        statusNote = nil
        Task { @MainActor in
            let result = await orchestrator.generateCoverPrompts(project: project)
            modelContext.saveOrLog()
            statusNote = result
            isGenerating = false
        }
    }
}

/// Cover-Erzeugung fürs eBook: nutzt die generierten Cover-Prompts + OpenAI-Bild-API,
/// zeigt Vorschau und Regenerieren an. Ohne OpenAI-Key erscheint ein Hinweis.
struct CoverSection: View {
    let project: Project
    @State private var isGenerating = false
    @State private var note: String?
    @State private var coverURL: URL?
    @State private var reloadToken = UUID()
    @State private var provider: CoverArtService.Provider = CoverArtService.selectedProvider

    private var ready: Bool { CoverArtService.isReady(provider) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cover (eBook)")
                .font(.headline)
            Text("Erzeugt ein KDP-fertiges eBook-Cover (1600×2560) aus den Cover-Prompts dieses Buchs.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Bild-Anbieter", selection: $provider) {
                ForEach(CoverArtService.Provider.allCases) { p in
                    Text(p.label).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: provider) { _, new in CoverArtService.selectedProvider = new }

            HStack(alignment: .top, spacing: 14) {
                Group {
                    if let url = coverURL, let img = NSImage(contentsOf: url) {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 96, height: 154)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(StudioTheme.hairline))
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(StudioTheme.glassInk.opacity(0.5))
                            .frame(width: 96, height: 154)
                            .overlay(Image(systemName: "photo").foregroundStyle(StudioTheme.textFaint))
                    }
                }
                .id(reloadToken)

                VStack(alignment: .leading, spacing: 8) {
                    if provider == .openAI && !ready {
                        Label("Kein OpenAI-API-Key hinterlegt. In Einstellungen → KI-Provider → OpenAI eintragen — oder den kostenlosen Anbieter wählen.",
                              systemImage: "key")
                            .font(.caption)
                            .foregroundStyle(StudioTheme.amber)
                    } else if provider == .pollinations {
                        Label("Kostenlos, ohne Key, ohne Konto (Flux). Ideal für die autonome Fabrik.",
                              systemImage: "gift")
                            .font(.caption)
                            .foregroundStyle(StudioTheme.lime)
                    }
                    Button {
                        generate()
                    } label: {
                        if isGenerating {
                            HStack(spacing: 6) { StudioLiveIndicator(color: StudioTheme.cyan); Text("Cover wird erzeugt …") }
                        } else {
                            Label(coverURL == nil ? "Cover erzeugen" : "Cover neu erzeugen",
                                  systemImage: "wand.and.stars")
                        }
                    }
                    .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.cyan))
                    .disabled(isGenerating || !ready || project.status != .completed)

                    if let url = coverURL {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([url])
                        } label: { Label("Im Finder zeigen", systemImage: "folder") }
                        .buttonStyle(.borderless)
                        .font(.caption)
                    }
                    if let note {
                        Text(note).font(.caption).foregroundStyle(StudioTheme.textMuted)
                    }
                }
                Spacer()
            }
        }
        .padding(18)
        .studioFeaturedPanel(cornerRadius: 8)
        .onAppear { coverURL = CoverArtService.coverURL(for: project) }
    }

    private func generate() {
        isGenerating = true
        note = nil
        Task {
            do {
                let result = try await CoverArtService.generateCover(for: project, provider: provider)
                await MainActor.run {
                    coverURL = result.url
                    reloadToken = UUID()
                    note = "Cover erstellt (\(result.provider.label))."
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    note = (error as? AIError)?.errorDescription ?? error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
}
