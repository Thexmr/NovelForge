import SwiftUI
import SwiftData

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
                if !sheet.hook.isEmpty {
                    salesField("Untertitel / Hook", sheet.hook, accent: StudioTheme.violet)
                }
                if !sheet.salesDescription.isEmpty {
                    salesField("Verkaufstext", sheet.salesDescription, accent: StudioTheme.magenta)
                }
                if !sheet.keywords.isEmpty {
                    salesField("Keywords", sheet.keywords, accent: StudioTheme.lime)
                }
                if !sheet.categories.isEmpty {
                    salesField("Kategorien", sheet.categories, accent: StudioTheme.amber)
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

    private var busy: Bool { isRunningPackage || isRepairing || orchestrator.isRunning }

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
                    Text("Die KI prüft das fertige Buch auf Unstimmigkeiten (Zeitlinie, Figurenwissen, Kontinuität, Logik) und korrigiert gezielt nur die betroffenen Stellen – nach dem Proofreading.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            repair()
                        } label: {
                            if isRepairing {
                                HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Wird geprüft …") }
                            } else {
                                Label("Konsistenz prüfen & reparieren", systemImage: "wand.and.stars")
                            }
                        }
                        .disabled(busy)
                        if let repairNote {
                            Text(repairNote).font(.caption).foregroundStyle(.secondary)
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
}

/// Eigenes Feld mit fertigen, kopierbaren Cover-Bild-Prompts (für ChatGPT/DALL·E).
struct CoverPromptsView: View {
    let project: Project

    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @ObservedObject private var coverStore = CoverImageSettingsStore.shared
    @Environment(\.modelContext) private var modelContext
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
        }
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
