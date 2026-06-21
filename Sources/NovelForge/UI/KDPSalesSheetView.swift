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
        KDPSalesSheet.make(for: project)
    }

    private var canGenerate: Bool {
        project.modelContext != nil && project.bookProfile != nil
            && !isGenerating && !orchestrator.isRunning
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
                        ProgressView().controlSize(.small)
                    } else {
                        Label(sheet.hasGeneratedMetadata ? "Neu generieren" : "Generieren",
                              systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderless)
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
                        try? modelContext.save()
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
                            .tracking(1).foregroundStyle(StudioTheme.textFaint)
                        ForEach(Array(sheet.keywordSlots.prefix(7).enumerated()), id: \.offset) { i, kw in
                            uploadSlot("\(i + 1)", kw, accent: StudioTheme.violet)
                        }
                    }
                    if !sheet.categorySlots.isEmpty {
                        Text("KATEGORIEN (MAX. 3)")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .tracking(1).foregroundStyle(StudioTheme.textFaint)
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
        }
    }

    private func generate() {
        guard canGenerate else { return }
        isGenerating = true
        statusNote = nil
        Task { @MainActor in
            let result = await orchestrator.generateKDPSalesSheet(project: project)
            try? modelContext.save()
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
        }
    }
}

/// Eigenständiger Sidebar-Bereich „KDP-Verkauf": Buch wählen und die Amazon-KDP-
/// Verkaufstexte (viraler Titel, Untertitel, Verkaufstext, Keywords, Kategorien)
/// ansehen, kopieren oder neu generieren.
struct KDPMarketingView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]
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

    private var busy: Bool { isRunningPackage || isRepairing || isOptimizingOpening || isAddingCliffhanger || orchestrator.isRunning }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title).font(.title).fontWeight(.bold)
                    Text("\(project.authorName) · \(project.genre)")
                        .foregroundStyle(.secondary)
                }

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
                                HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Pipeline läuft …") }
                            } else {
                                Label("Komplettes Paket erstellen", systemImage: "sparkles")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(busy)
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
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))

                // Nachbearbeitung einzeln
                VStack(alignment: .leading, spacing: 8) {
                    Text("Nachbearbeitung").font(.headline)
                    Text("Die KI prüft das fertige Buch auf Unstimmigkeiten (Zeitlinie, Figurenwissen, Kontinuität, Logik) UND Lesesog (schwache Kapitel-Enden, durchhängende Spannung) und korrigiert gezielt nur die betroffenen Stellen – nach dem Proofreading.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            repair()
                        } label: {
                            if isRepairing {
                                HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Wird geprüft …") }
                            } else {
                                Label("Konsistenz & Spannung prüfen", systemImage: "wand.and.stars")
                            }
                        }
                        .disabled(busy)
                        if let repairNote {
                            Text(repairNote).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                // Blick ins Buch (Conversion-Hebel)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Blick ins Buch").font(.headline)
                    Text("Die Amazon-Leseprobe (erste Seiten) entscheidet den Kauf. Die KI schärft den Anfang des ersten Kapitels auf maximalen Lesesog – Hook in Zeile 1, sofort Stakes, ohne die Handlung zu ändern.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            optimizeOpening()
                        } label: {
                            if isOptimizingOpening {
                                HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Wird optimiert …") }
                            } else {
                                Label("Anfang optimieren", systemImage: "text.alignleft")
                            }
                        }
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
                    Text("Auf Kindle liegt das Geld in Reihen: Leser bingen Band für Band. Die KI baut am Ende einen Cliffhanger + Teaser auf den nächsten Band ein – der Abschluss dieses Buches bleibt erhalten.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            addCliffhanger()
                        } label: {
                            if isAddingCliffhanger {
                                HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Wird eingebaut …") }
                            } else {
                                Label("Cliffhanger + Teaser einbauen", systemImage: "books.vertical")
                            }
                        }
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
            try? modelContext.save()
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

    private func optimizeOpening() {
        guard project.modelContext != nil, !busy else { return }
        isOptimizingOpening = true
        openingNote = nil
        Task { @MainActor in
            let reply = await orchestrator.optimizeOpening(project: project)
            try? modelContext.save()
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
            try? modelContext.save()
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
            && !isGenerating && !orchestrator.isRunning
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
                        ProgressView().controlSize(.small)
                    } else {
                        Label(prompts.isEmpty ? "Generieren" : "Neu generieren", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderless)
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
                            .buttonStyle(.borderless)
                            Button {
                                generateImage(prompt: concept.text, index: concept.id)
                            } label: {
                                if generatingImageIndex == concept.id {
                                    HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Bild …") }
                                } else {
                                    Label("Als Cover-Bild erzeugen", systemImage: "photo.badge.plus")
                                }
                            }
                            .buttonStyle(.borderless)
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
            .buttonStyle(.borderless)
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
            try? modelContext.save()
            statusNote = result
            isGenerating = false
        }
    }
}
