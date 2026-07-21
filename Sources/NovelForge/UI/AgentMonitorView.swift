import SwiftUI
import SwiftData

struct AgentMonitorView: View {
    private static let queriedJobLimit = 1_000
    private static let visibleJobLimit = 250

    private var _jobs: Query<PipelineJob, [PipelineJob]>
    private var jobs: [PipelineJob] { _jobs.wrappedValue }
    private var _projects = Query<Project, [Project]>(sort: \Project.updatedAt, order: .reverse)
    var projects: [Project] { _projects.wrappedValue }
    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @State private var selectedStatus: JobStatusFilter = .all
    @State private var selectedProjectID: UUID?

    init() {
        var descriptor = FetchDescriptor<PipelineJob>(
            sortBy: [SortDescriptor(\PipelineJob.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = Self.queriedJobLimit
        _jobs = Query(descriptor)
    }

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
            result = jobs.filter {
                $0.status == .running || $0.status == .writing || $0.status == .checking
                    || $0.status == .revising || $0.status == .retrying
            }
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

    private var displayedJobs: [PipelineJob] {
        Array(filteredJobs.prefix(Self.visibleJobLimit))
    }

    private var entryCountText: String {
        let filteredCount = filteredJobs.count
        let loadedSuffix = jobs.count >= Self.queriedJobLimit ? " · letzte 1.000 geladen" : ""
        if filteredCount > displayedJobs.count {
            return "\(displayedJobs.count) von \(filteredCount) Einträgen\(loadedSuffix)"
        }
        return "\(filteredCount) Einträge\(loadedSuffix)"
    }

    private var activeJobs: [PipelineJob] {
        jobs.filter { $0.status == .running || $0.status == .writing || $0.status == .checking || $0.status == .revising || $0.status == .retrying }
    }

    private var completedJobs: [PipelineJob] {
        jobs.filter { $0.status == .completed }
    }

    private var failedJobs: [PipelineJob] {
        jobs.filter { $0.status == .failed }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                monitorHeader

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                    monitorMetric(title: "Aktiv", value: activeJobs.count,
                                  icon: "bolt.horizontal.fill", color: StudioTheme.cyan)
                    monitorMetric(title: "Abgeschlossen", value: completedJobs.count,
                                  icon: "checkmark.seal.fill", color: StudioTheme.lime)
                    monitorMetric(title: "Fehlgeschlagen", value: failedJobs.count,
                                  icon: "exclamationmark.triangle.fill", color: StudioTheme.danger)
                    monitorMetric(title: "Tokens", value: jobs.reduce(0) { $0 + $1.tokenUsage },
                                  icon: "number", color: StudioTheme.amber, formatted: true)
                }

                HStack(spacing: 12) {
                    Picker("Status", selection: $selectedStatus) {
                        ForEach(JobStatusFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: 390)

                    Picker("Projekt", selection: $selectedProjectID) {
                        Text("Alle Projekte").tag(UUID?.none)
                        ForEach(projects) { project in
                            Text(project.title).tag(Optional(project.id))
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 250)

                    Spacer()

                    Text(entryCountText)
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(StudioTheme.textMuted)
                }
                .padding(12)
                .studioPanel(cornerRadius: 8, accent: StudioTheme.violet)

                if filteredJobs.isEmpty {
                    monitorEmptyState
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(displayedJobs) { job in
                            AgentJobRow(job: job)
                        }
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 1080, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(StudioBackground())
        .animation(Motion.standard, value: filteredJobs.count)
        .navigationTitle("Agenten-Monitor")
    }

    private var monitorHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    StudioLiveIndicator(color: StudioTheme.lime, isActive: orchestrator.isRunning)
                    Text(orchestrator.isRunning ? "Live-Überwachung" : "Produktionsprotokoll")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(orchestrator.isRunning ? StudioTheme.lime : StudioTheme.textMuted)
                }
                Text("Agentenaktivität")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(StudioTheme.heroGradient)
                Text("Alle Produktionsschritte, Laufzeiten, Wiederholungen und Fehler chronologisch nachvollziehen.")
                    .font(.subheadline)
                    .foregroundStyle(StudioTheme.textMuted)
            }
            Spacer()
            if orchestrator.isRunning {
                VStack(alignment: .trailing, spacing: 5) {
                    Text(orchestrator.currentAgent.isEmpty ? orchestrator.currentPhase.rawValue : orchestrator.currentAgent)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text("\(Int(orchestrator.progress * 100)) %")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(StudioTheme.textMuted)
                    StudioProgressBar(value: orchestrator.progress)
                        .frame(width: 180)
                }
            }
        }
        .padding(18)
        .studioFeaturedPanel(cornerRadius: 8)
    }

    private func monitorMetric(title: String, value: Int, icon: String,
                               color: Color, formatted: Bool = false) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(StudioTheme.textMuted)
                Text(formatted ? FormattingHelpers.formatWordCount(value) : "\(value)")
                    .font(.title3.weight(.semibold).monospacedDigit())
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .studioGlassTile(cornerRadius: 8, accent: color, opacity: 0.86)
    }

    private var monitorEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(StudioTheme.violet)
            Text(jobs.isEmpty ? "Noch keine Produktionsschritte" : "Keine passenden Einträge")
                .font(.headline)
            Text(jobs.isEmpty
                 ? "Beim Start einer Produktion erscheinen die Arbeitsschritte hier in Echtzeit."
                 : "Der gewählte Status- oder Projektfilter liefert keine Treffer.")
                .font(.caption)
                .foregroundStyle(StudioTheme.textMuted)
                .multilineTextAlignment(.center)
            if !jobs.isEmpty {
                Button {
                    selectedStatus = .all
                    selectedProjectID = nil
                } label: {
                    Label("Filter zurücksetzen", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.violet))
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .studioPanel(cornerRadius: 8, accent: StudioTheme.violet)
    }
}

struct AgentJobRow: View {
    let job: PipelineJob

    var statusColor: Color {
        switch job.status {
        case .running, .writing, .checking, .revising: return StudioTheme.cyan
        case .retrying: return StudioTheme.amber
        case .completed: return StudioTheme.lime
        case .failed: return StudioTheme.danger
        case .paused: return StudioTheme.amber
        default: return StudioTheme.textFaint
        }
    }

    private var isActive: Bool {
        job.status == .running || job.status == .writing || job.status == .checking
            || job.status == .revising || job.status == .retrying
    }

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(statusColor.opacity(0.10))
                Image(systemName: job.phase.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(statusColor)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(job.agentName)
                        .font(.headline)
                    Spacer()
                    Text(job.status.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(statusColor.opacity(0.10),
                                    in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    if isActive {
                        StudioLiveIndicator(color: statusColor, isActive: true)
                    }
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

                if (job.status == .failed || job.status == .paused),
                   let result = job.result, !result.isEmpty {
                    Text(result)
                        .font(.caption2)
                        .foregroundStyle(job.status == .failed ? StudioTheme.danger : StudioTheme.amber)
                        .lineLimit(4)
                }
            }
        }
        .padding(13)
        .studioGlassTile(cornerRadius: 8, accent: statusColor, opacity: isActive ? 0.96 : 0.76)
        .studioHoverable()
    }
}

// MARK: - Export

struct ExportView: View {
    private var _projects = Query<Project, [Project]>(sort: \Project.updatedAt, order: .reverse)
    var projects: [Project] { _projects.wrappedValue }
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
                    .listStyle(.sidebar)
                    .scrollContentBackground(.hidden)
                }
            }
            .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)

            Group {
                // modelContext == nil ⇒ Projekt von der Pipeline gelöscht (z.B. resetChapterPlan
                // während laufender Produktion). Zugriff auf gelöschte @Model-Relationen würde
                // den Prozess beenden (SwiftData assertionFailure) – daher hier abfangen.
                if let project = appState.selectedProject, project.modelContext != nil {
                    ExportDetailView(project: project)
                } else {
                    ContentUnavailableView("Projekt wählen", systemImage: "square.and.arrow.up")
                }
            }
            .frame(minWidth: 440, maxWidth: .infinity)
        }
        .background(StudioBackground())
        .navigationTitle("Export")
    }
}

struct ExportDetailView: View {
    let project: Project

    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @Environment(\.modelContext) private var modelContext
    @State private var isRepairing = false
    @State private var repairNote: String?
    @State private var seriesNote: String?

    private var scores: QualityScores {
        // Defensive: gelöschtes Projekt liefert Null-Scores statt auf tote Relationen zuzugreifen.
        guard project.modelContext != nil else {
            return QualityScores(structure: 0, characters: 0, style: 0, consistency: 0, kdp: 0)
        }
        return QualityScores.cached(for: project)
    }

    private var readinessIssues: [String] {
        guard project.modelContext != nil else { return ["Projekt nicht mehr verfügbar."] }
        return PublicationReadiness.cachedCompletionBlockingIssues(project: project)
    }

    var body: some View {
        // Lastentragender Guard: wird ExportDetailView nach einem Pipeline-Delete erneut
        // gerendert, dürfen keine SwiftData-Relationen des toten Objekts gelesen werden.
        if project.modelContext == nil {
            ContentUnavailableView("Projekt nicht mehr verfügbar", systemImage: "square.and.arrow.up")
        } else {
            let displayedScores = scores
            ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.title)
                            .font(.title.weight(.bold))
                            .foregroundStyle(StudioTheme.heroGradient)
                        Text("\(project.authorName) · \(project.genre) · \(FormattingHelpers.formatWordCount(project.recordedWordCount)) Wörter")
                            .foregroundStyle(StudioTheme.textMuted)
                    }
                    Spacer()
                    StudioStatusPill(text: readinessIssues.isEmpty ? "bereit" : "Prüfung nötig",
                                     systemImage: readinessIssues.isEmpty ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                                     color: readinessIssues.isEmpty ? StudioTheme.lime : StudioTheme.amber)
                }
                .padding(18)
                .studioFeaturedPanel(cornerRadius: 8)

                if project.status == .completed, !readinessIssues.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Abschlussprüfung nicht bestanden", systemImage: "exclamationmark.octagon.fill")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(StudioTheme.danger)
                        ForEach(readinessIssues.prefix(6), id: \.self) { issue in
                            Text("• \(issue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .studioGlassTile(cornerRadius: 8, accent: StudioTheme.danger, opacity: 0.88)
                } else if project.status != .completed {
                    Label("Dieses Projekt ist noch nicht fertig produziert – Exporte enthalten den aktuellen Zwischenstand.",
                          systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(StudioTheme.amber)
                        .padding(10)
                        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.amber, opacity: 0.88)
                }

                CoverStudioPanel(project: project)
                KDPSalesSheetView(project: project)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Nachbearbeitung")
                        .font(.headline)
                    Text("Die Nachbearbeitung prüft das fertige Buch auf inhaltliche Unstimmigkeiten (Zeitlinie, Figurenwissen, Kontinuität, Logik) und korrigiert gezielt nur die betroffenen Stellen – nach dem Proofreading.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 10) {
                        Button {
                            repair()
                        } label: {
                            if isRepairing {
                                HStack(spacing: 6) {
                                    StudioLiveIndicator(color: StudioTheme.lime)
                                    Text("Wird geprüft …")
                                }
                            } else {
                                Label("Konsistenz prüfen & reparieren", systemImage: "wand.and.stars")
                            }
                        }
                        .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.lime))
                        .disabled(isRepairing || orchestrator.isRunning)
                        if let repairNote {
                            Text(repairNote)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Reihe / Serie")
                        .font(.headline)
                    Text("Erzeugt einen Folgeband, der dieselben Figuren und die Welt übernimmt und die Geschichte fortsetzt – mit derselben Stil-DNA für einen einheitlichen Reihen-Ton. Der neue Band erscheint im Dashboard und wird dort produziert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        let next = orchestrator.createNextVolume(from: project)
                        seriesNote = "„\(next.title)“ angelegt (Band \(next.seriesNumber)) – im Dashboard auswählen und Produktion starten."
                    } label: {
                        Label("Nächsten Band erzeugen", systemImage: "books.vertical")
                    }
                    .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.violet))
                    .disabled(orchestrator.isRunning || project.modelContext == nil)
                    if let seriesNote {
                        Text(seriesNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

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
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Qualitätsmetriken")
                        .font(.headline)
                    QualityMetricRow(label: "Struktur", score: displayedScores.structure)
                    QualityMetricRow(label: project.isNonfiction ? "Lesernutzen" : "Figuren",
                                     score: displayedScores.characters)
                    QualityMetricRow(label: "Stil", score: displayedScores.style)
                    QualityMetricRow(label: "Konsistenz", score: displayedScores.consistency)
                    QualityMetricRow(label: "KDP-Format", score: displayedScores.kdp)
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

    private func repair() {
        guard project.modelContext != nil, !isRepairing, !orchestrator.isRunning else { return }
        isRepairing = true
        repairNote = nil
        Task { @MainActor in
            let reply = await orchestrator.repairBookAfterProofreading(project: project)
            repairNote = reply
            isRepairing = false
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

    var icon: String {
        switch self {
        case .epub: return "book.fill"
        case .pdf: return "doc.fill"
        case .docx: return "doc.text.fill"
        case .sample: return "text.book.closed"
        case .metadata: return "tag"
        case .report: return "chart.bar.doc.horizontal"
        case .log: return "list.clipboard"
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
        }
    }
}

@MainActor
struct ExportFormatRow: View {
    let format: ExportFormat
    let project: Project

    @State private var isExporting = false
    @State private var exportedURL: URL?
    @State private var errorMessage: String?

    private var blockingIssues: [String] {
        format == .log ? [] : PublicationReadiness.cachedExportBlockingIssues(project: project)
    }

    private var canExport: Bool {
        project.modelContext != nil && blockingIssues.isEmpty && !isExporting
    }

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
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                } label: {
                    Label("Im Finder", systemImage: "folder")
                }
                .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.violet))
            }

            Button {
                export()
            } label: {
                if isExporting {
                    HStack(spacing: 6) {
                        StudioLiveIndicator(color: StudioTheme.cyan)
                        Text("Exportiert …")
                    }
                } else {
                    Label("Exportieren", systemImage: "square.and.arrow.up")
                }
            }
            .buttonStyle(StudioPrimaryButtonStyle())
            .frame(width: 150)
            .disabled(!canExport)
            .help(blockingIssues.first ?? "\(format.rawValue) erstellen")
        }
        .padding(12)
        .studioGlassTile(cornerRadius: 8,
                         accent: blockingIssues.isEmpty ? StudioTheme.cyan : StudioTheme.amber,
                         opacity: 0.82)
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
                    let snapshot = try ExportEngine.prepareSnapshot(for: project)
                    url = try await ExportEngine.exportPreparedToEPUBInBackground(snapshot)
                case .pdf:
                    let snapshot = try ExportEngine.prepareSnapshot(for: project)
                    url = try await ExportEngine.exportPreparedToPDFInBackground(snapshot)
                case .docx:
                    let snapshot = try ExportEngine.prepareSnapshot(for: project)
                    url = try await ExportEngine.exportPreparedToDOCXInBackground(snapshot)
                case .sample:
                    let snapshot = try ExportEngine.prepareSnapshot(for: project)
                    url = try await ExportEngine.exportPreparedToEPUBInBackground(
                        snapshot,
                        sampleChapterCount: 3
                    )
                case .metadata:
                    try PublicationReadiness.validateForExport(project: project)
                    url = try writeText(ExportEngine.generateKDPMetadataReport(project: project),
                                        fileName: "KDP-Metadaten.txt")
                case .report:
                    try PublicationReadiness.validateForExport(project: project)
                    url = try writeText(ExportEngine.generateKDPReport(project: project),
                                        fileName: "KDP-Bericht.txt")
                case .log:
                    url = try writeText(ExportEngine.generateProductionLog(project: project),
                                        fileName: "Produktionsprotokoll.txt")
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
