import SwiftUI
import SwiftData

struct AgentMonitorView: View {
    @Query(sort: \PipelineJob.createdAt, order: .reverse) var jobs: [PipelineJob]
    @Query(sort: \Project.updatedAt, order: .reverse) var projects: [Project]
    @State private var selectedStatus: JobStatusFilter = .all
    @State private var selectedProjectID: UUID?

    enum JobStatusFilter: String, CaseIterable {
        case all = "Alle"
        case active = "Aktiv"
        case completed = "Abgeschlossen"
        case failed = "Fehlgeschlagen"
    }

    var filteredJobs: [PipelineJob] {
        var result: [PipelineJob]
        switch selectedStatus {
        case .all:
            result = jobs
        case .active:
            result = jobs.filter { $0.status == .running || $0.status == .writing || $0.status == .checking || $0.status == .revising }
        case .completed:
            result = jobs.filter { $0.status == .completed }
        case .failed:
            result = jobs.filter { $0.status == .failed }
        }
        if let projectID = selectedProjectID {
            result = result.filter { $0.project?.id == projectID }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Status", selection: $selectedStatus) {
                    ForEach(JobStatusFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 380)

                Picker("Projekt", selection: $selectedProjectID) {
                    Text("Alle Projekte").tag(UUID?.none)
                    ForEach(projects) { project in
                        Text(project.title).tag(Optional(project.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 220)

                Spacer()

                Text("\(filteredJobs.count) Einträge")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)

            Divider()

            if filteredJobs.isEmpty {
                ContentUnavailableView("Keine Agenten-Aktivität", systemImage: "cpu",
                                       description: Text("Hier erscheinen alle Arbeitsschritte der KI-Agenten in Echtzeit."))
            } else {
                List(filteredJobs) { job in
                    AgentJobRow(job: job)
                }
            }
        }
        .navigationTitle("Agenten-Monitor")
    }
}

struct AgentJobRow: View {
    let job: PipelineJob

    var statusColor: Color {
        switch job.status {
        case .running, .writing, .checking, .revising, .retrying: return .blue
        case .completed: return .green
        case .failed: return .red
        case .paused: return .orange
        default: return .gray
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(job.agentName)
                        .font(.headline)
                    Spacer()
                    Text(job.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.1), in: Capsule())
                }

                HStack(spacing: 6) {
                    if let projectTitle = job.project?.title {
                        Text(projectTitle)
                            .fontWeight(.medium)
                    }
                    Text(job.phase.rawValue)
                    if let chapter = job.chapterNumber {
                        Text("· Kapitel \(chapter)")
                    }
                    if let scene = job.sceneNumber {
                        Text("· Szene \(scene)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    if let start = job.startTime {
                        Text("Start: \(start, style: .time)")
                        if let end = job.endTime {
                            Text("Dauer: \(FormattingHelpers.formatDuration(end.timeIntervalSince(start)))")
                        }
                    }
                    if job.tokenUsage > 0 {
                        Text("\(FormattingHelpers.formatWordCount(job.tokenUsage)) Tokens")
                    }
                    if job.errorCount > 0 {
                        Text("Fehler: \(job.errorCount)")
                            .foregroundStyle(.red)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)

                if job.status == .failed, let result = job.result, !result.isEmpty {
                    Text(result)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Export

struct ExportView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) var projects: [Project]
    @ObservedObject private var appState = AppState.shared

    /// Alle Projekte mit mindestens einem Kapitel sind exportierbar (auch Zwischenstände).
    private var exportableProjects: [Project] {
        projects.filter { !($0.chapters ?? []).isEmpty }
    }

    var body: some View {
        HSplitView {
            Group {
                if exportableProjects.isEmpty {
                    ContentUnavailableView("Nichts zu exportieren", systemImage: "square.and.arrow.up",
                                           description: Text("Sobald ein Projekt Kapitel enthält, erscheint es hier."))
                } else {
                    List(selection: $appState.selectedProject) {
                        ForEach(exportableProjects) { project in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.title)
                                    .lineLimit(1)
                                StatusBadge(status: project.status)
                            }
                            .tag(project)
                        }
                    }
                }
            }
            .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)

            Group {
                if let project = appState.selectedProject {
                    ExportDetailView(project: project)
                } else {
                    ContentUnavailableView("Projekt wählen", systemImage: "square.and.arrow.up")
                }
            }
            .frame(minWidth: 440, maxWidth: .infinity)
        }
        .navigationTitle("Export")
    }
}

struct ExportDetailView: View {
    let project: Project

    private var scores: QualityScores {
        QualityScores.compute(for: project)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("\(project.authorName) · \(project.genre) · \(FormattingHelpers.formatWordCount(project.totalWordCount)) Wörter")
                        .foregroundStyle(.secondary)
                }

                if project.status != .completed {
                    Label("Dieses Projekt ist noch nicht fertig produziert – Exporte enthalten den aktuellen Zwischenstand.",
                          systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }

                CoverStudioPanel(project: project)
                KDPSalesSheetView(project: project)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Buchformate")
                        .font(.headline)
                    ExportFormatRow(format: .epub, project: project)
                    ExportFormatRow(format: .pdf, project: project)
                    ExportFormatRow(format: .docx, project: project)
                    ExportFormatRow(format: .sample, project: project)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Veröffentlichung & Berichte")
                        .font(.headline)
                    ExportFormatRow(format: .metadata, project: project)
                    ExportFormatRow(format: .report, project: project)
                    ExportFormatRow(format: .log, project: project)
                    ExportFormatRow(format: .disclosure, project: project)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Qualitätsmetriken")
                        .font(.headline)
                    QualityMetricRow(label: "Struktur", score: scores.structure)
                    QualityMetricRow(label: "Figuren", score: scores.characters)
                    QualityMetricRow(label: "Stil", score: scores.style)
                    QualityMetricRow(label: "Konsistenz", score: scores.consistency)
                    QualityMetricRow(label: "KDP-Format", score: scores.kdp)
                    Text("Automatisch aus den Projektdaten berechnet.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if let issues = project.qualityReports?.filter({ $0.checkType == "Konsistenz" && $0.severity != .info }),
                   !issues.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Konsistenz-Hinweise")
                            .font(.headline)
                        ForEach(issues) { issue in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle")
                                    .foregroundStyle(issue.severity == .critical || issue.severity == .error ? .red : .orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(issue.result)
                                        .font(.caption)
                                    if !issue.recommendation.isEmpty {
                                        Text(issue.recommendation)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

struct CoverStudioPanel: View {
    let project: Project

    @ObservedObject private var coverStore = CoverImageSettingsStore.shared
    @State private var prompt = ""
    @State private var promptURL: URL?
    @State private var coverURL: URL?
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var statusMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Buchcover")
                        .font(.headline)
                    Text("Cover-Bild oder professioneller Prompt aus Buchprofil, KDP-Text und Kapitelkontext.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StudioStatusPill(text: coverStore.hasAPIKey() ? "Bild-API bereit" : "Prompt-Modus",
                                 systemImage: coverStore.hasAPIKey() ? "wand.and.stars" : "text.quote",
                                 color: coverStore.hasAPIKey() ? StudioTheme.lime : StudioTheme.amber)
            }

            HStack(alignment: .top, spacing: 16) {
                coverPreview
                    .frame(width: 160, height: 240)

                VStack(alignment: .leading, spacing: 10) {
                    if prompt.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Noch kein Cover-Prompt")
                                .font(.callout.weight(.semibold))
                            Text("Erzeuge zuerst den Prompt. Mit Bild-API-Key kann daraus direkt ein KDP-Cover gespeichert werden.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.amber, opacity: 0.78)
                    } else {
                        TextEditor(text: $prompt)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 132)
                            .scrollContentBackground(.hidden)
                            .background(StudioTheme.glassInk.opacity(0.28), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(StudioTheme.hairline, lineWidth: 1))
                    }

                    if isGenerating {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Cover wird vom Bildmodell erzeugt …")
                                .font(.caption.weight(.semibold))
                            StudioProgressBar(value: 0.72, height: 6)
                        }
                    }

                    if let statusMessage {
                        Label(statusMessage, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(StudioTheme.lime)
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(StudioTheme.danger)
                    }

                    HStack(spacing: 8) {
                        Button {
                            generatePrompt()
                        } label: {
                            Label("Prompt erstellen", systemImage: "text.badge.star")
                        }
                        .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.cyan))
                        .disabled(isGenerating)

                        Button {
                            copyPrompt()
                        } label: {
                            Label("Kopieren", systemImage: "doc.on.doc")
                        }
                        .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.violet))
                        .disabled(prompt.isEmpty || isGenerating)

                        Button {
                            generateCover()
                        } label: {
                            Label(isGenerating ? "Generiert …" : "Cover generieren",
                                  systemImage: "photo.badge.sparkles")
                        }
                        .buttonStyle(StudioPrimaryButtonStyle())
                        .frame(width: 178)
                        .disabled(isGenerating || !coverStore.hasAPIKey())
                        .help(coverStore.hasAPIKey() ? "Cover mit Bildmodell erzeugen" : "API-Key unter Einstellungen > Cover-KI hinterlegen")
                    }

                    HStack(spacing: 8) {
                        if let promptURL {
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([promptURL])
                            } label: {
                                Label("Prompt-Datei", systemImage: "doc.text")
                            }
                            .buttonStyle(.bordered)
                        }
                        if let coverURL {
                            Button {
                                NSWorkspace.shared.activateFileViewerSelecting([coverURL])
                            } label: {
                                Label("Cover-Datei", systemImage: "folder")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
        }
        .padding(16)
        .studioPanel(cornerRadius: 8, accent: StudioTheme.violet)
        .onAppear(perform: loadExistingArtifacts)
    }

    @ViewBuilder
    private var coverPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(StudioTheme.glassInk.opacity(0.54))
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(StudioTheme.hairlineBright, lineWidth: 1)

            if let coverURL, let image = NSImage(contentsOf: coverURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(alignment: .bottom) {
                        LinearGradient(colors: [.clear, .black.opacity(0.58)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: 68)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(StudioTheme.violet)
                    Text("Cover")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(StudioTheme.textMuted)
                }
            }
        }
        .shadow(color: StudioTheme.violet.opacity(0.18), radius: 12, y: 6)
    }

    private func loadExistingArtifacts() {
        prompt = CoverDesignService.existingPrompt(for: project) ?? ""
        promptURL = try? CoverDesignService.promptURL(for: project)
        coverURL = CoverDesignService.existingImageURL(for: project)
    }

    private func generatePrompt() {
        errorMessage = nil
        statusMessage = nil
        do {
            let generated = CoverDesignService.buildPrompt(for: project)
            prompt = generated
            promptURL = try CoverDesignService.writePrompt(generated, for: project)
            statusMessage = "Cover-Prompt gespeichert."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func copyPrompt() {
        guard !prompt.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)
        statusMessage = "Prompt in die Zwischenablage kopiert."
        errorMessage = nil
    }

    private func generateCover() {
        errorMessage = nil
        statusMessage = nil
        guard coverStore.hasAPIKey() else {
            errorMessage = "Für direkte Cover-Erzeugung fehlt der Bild-API-Key."
            return
        }

        let activePrompt: String
        do {
            activePrompt = prompt.isEmpty ? CoverDesignService.buildPrompt(for: project) : prompt
            prompt = activePrompt
            promptURL = try CoverDesignService.writePrompt(activePrompt, for: project)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        let settings = coverStore.runtimeSettings()
        let artworkDestination: URL
        do {
            // Das Bildmodell liefert textfreies Artwork; Titel/Autor kommen danach
            // als scharfer Overlay in CoverComposer.
            artworkDestination = try CoverDesignService.artworkURL(for: project)
        } catch {
            errorMessage = error.localizedDescription
            return
        }

        isGenerating = true
        Task {
            do {
                let artworkURL = try await CoverImageGateway.shared.generateImage(
                    prompt: activePrompt,
                    destination: artworkDestination,
                    settings: settings
                )
                let coverFile = try CoverComposer.composeCover(artworkURL: artworkURL, project: project)
                await MainActor.run {
                    coverURL = coverFile
                    statusMessage = "Cover als \(CoverDesignService.coverImageFileName) gespeichert (Artwork + scharfer Titel-Overlay)."
                    isGenerating = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
}

enum ExportFormat: String {
    case epub = "EPUB"
    case pdf = "PDF"
    case docx = "DOCX"
    case sample = "Leseprobe"
    case metadata = "KDP-Metadaten"
    case report = "KDP-Bericht"
    case log = "Produktionsprotokoll"
    case disclosure = "KI-Offenlegung"

    var icon: String {
        switch self {
        case .epub: return "book.fill"
        case .pdf: return "doc.fill"
        case .docx: return "doc.text.fill"
        case .sample: return "text.book.closed"
        case .metadata: return "tag"
        case .report: return "chart.bar.doc.horizontal"
        case .log: return "list.clipboard"
        case .disclosure: return "checkmark.shield"
        }
    }

    var subtitle: String {
        switch self {
        case .epub: return "eBook mit Verlags-Stylesheet für Amazon KDP"
        case .pdf: return "KDP-konformer Buchsatz (Trim-Größe, Bundsteg, Seitenzahlen)"
        case .docx: return "Bearbeitbares Word-Dokument mit Formatvorlagen"
        case .sample: return "Die ersten 3 Kapitel als EPUB – für Marketing und Testleser"
        case .metadata: return "Verkaufstext, 7 Keywords & Kategorien für die Veröffentlichung"
        case .report: return "Formatprüfung und Qualitätsbewertung"
        case .log: return "Alle Pipeline-Schritte im Detail"
        case .disclosure: return "Nachweis der KI-Unterstützung (KDP-Richtlinie)"
        }
    }
}

struct ExportFormatRow: View {
    let format: ExportFormat
    let project: Project

    @State private var isExporting = false
    @State private var exportedURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: format.icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(format.rawValue)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(format.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let error = errorMessage {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            if let url = exportedURL {
                Button("Im Finder zeigen") {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                .buttonStyle(.bordered)
            }

            Button(isExporting ? "Exportiere …" : "Exportieren") {
                export()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExporting)
        }
        .padding(12)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }

    private func export() {
        isExporting = true
        errorMessage = nil

        Task { @MainActor in
            defer { isExporting = false }
            do {
                let url: URL
                switch format {
                case .epub:
                    url = try ExportEngine.exportToEPUB(project: project)
                case .pdf:
                    url = try ExportEngine.exportToPDF(project: project)
                case .docx:
                    url = try ExportEngine.exportToDOCX(project: project)
                case .sample:
                    url = try ExportEngine.exportToEPUB(project: project, sampleChapterCount: 3)
                case .metadata:
                    url = try writeText(ExportEngine.generateKDPMetadataReport(project: project),
                                        fileName: "KDP-Metadaten.txt")
                case .report:
                    url = try writeText(ExportEngine.generateKDPReport(project: project),
                                        fileName: "KDP-Bericht.txt")
                case .log:
                    url = try writeText(ExportEngine.generateProductionLog(project: project),
                                        fileName: "Produktionsprotokoll.txt")
                case .disclosure:
                    url = try writeText(generateDisclosureReport(project: project),
                                        fileName: "KI-Offenlegung.txt")
                }
                exportedURL = url
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func writeText(_ text: String, fileName: String) throws -> URL {
        let url = try ExportEngine.exportDirectory(for: project).appendingPathComponent(fileName)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}

func generateDisclosureReport(project: Project) -> String {
    var report = "KI-OFFENLEGUNGSBERICHT\n"
    report += String(repeating: "=", count: 25) + "\n\n"
    report += "Projekt: \(project.title)\n"
    report += "Autor: \(project.authorName)\n"
    report += "Erstellt am: \(Date().formattedString())\n\n"

    report += "Dieses Werk wurde mit Unterstützung von Künstlicher Intelligenz (KI) erstellt.\n\n"
    report += "Verwendete KI-Tools:\n"
    report += "- NovelForge (autonome Buchproduktions-Pipeline)\n"
    report += "- Provider: \(project.preferredProviderRaw)"
    if !project.preferredModel.isEmpty {
        report += ", Modell: \(project.preferredModel)"
    }
    report += "\n\n"

    if let jobs = project.pipelineJobs {
        report += "Pipeline-Schritte: \(jobs.count)\n"
        report += "Beteiligte Agenten:\n"
        for agent in Set(jobs.map { $0.agentName }).sorted() {
            report += "- \(agent)\n"
        }
    }

    report += "\nHinweis:\n"
    report += "Gemäß den Richtlinien von Amazon KDP und anderen Verlagsplattformen\n"
    report += "müssen KI-generierte Inhalte offengelegt werden.\n"
    report += "Dieser Bericht dient als Nachweis der KI-Unterstützung.\n"
    return report
}

struct QualityMetricRow: View {
    let label: String
    let score: Double

    var color: Color {
        if score >= 0.85 { return .green }
        if score >= 0.6 { return .yellow }
        return .orange
    }

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            ProgressView(value: score)
                .progressViewStyle(.linear)
                .frame(width: 160)
                .tint(color)
            Text("\(Int(score * 100)) %")
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 44, alignment: .trailing)
                .monospacedDigit()
        }
    }
}
