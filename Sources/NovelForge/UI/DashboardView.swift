import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) var projects: [Project]
    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @State private var showingNewBookSheet = false

    var activeProjects: [Project] {
        projects.filter { $0.status != .completed && $0.status != .failed }
    }

    var completedProjects: [Project] {
        projects.filter { $0.status == .completed }
    }

    var totalWords: Int {
        projects.reduce(0) { $0 + $1.totalWordCount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection

                let providerReady = hasUsableProvider()
                if !providerReady {
                    setupChecklist(providerReady: providerReady)
                }

                if orchestrator.isRunning {
                    runningBanner
                }

                statsSection

                if projects.isEmpty {
                    ContentUnavailableView {
                        Label("Noch keine Buchprojekte", systemImage: "book")
                    } description: {
                        Text("Erstellen Sie Ihr erstes Buch – NovelForge übernimmt Konzept, Plot, Kapitel, Szenen, Rohfassung, Lektorat und Export vollautomatisch.")
                    } actions: {
                        Button("Erstes Buch erstellen") {
                            showingNewBookSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding(.top, 40)
                } else {
                    activeProductionsSection
                    completedProjectsSection
                }
            }
            .padding(24)
            .frame(maxWidth: 900, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Dashboard")
        .sheet(isPresented: $showingNewBookSheet) {
            NewBookWizardView()
        }
    }

    /// Gibt es mindestens einen aktiven Provider, der sofort einsatzbereit ist?
    @MainActor
    private func hasUsableProvider() -> Bool {
        let store = ProviderSettingsStore.shared
        return store.configurations.contains { config in
            config.isActive && (!config.provider.requiresAPIKey || store.hasAPIKey(for: config.provider))
        }
    }

    private func setupChecklist(providerReady: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Erste Schritte")
                .font(.headline)

            checklistRow(done: providerReady,
                         title: "KI-Provider einrichten",
                         subtitle: "OpenAI, Anthropic Claude, Ollama (lokal & kostenlos), Kimi oder ein eigener Endpunkt – der API-Key landet sicher in der Keychain.",
                         actionTitle: "Zu den Einstellungen") {
                AppState.shared.open(.settings)
            }

            checklistRow(done: !projects.isEmpty,
                         title: "Erstes Buch erstellen",
                         subtitle: "Der Assistent startet die autonome Produktion direkt im Anschluss. Der Provider kann auch dort eingerichtet werden.",
                         actionTitle: "Neues Buch") {
                showingNewBookSheet = true
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private func checklistRow(done: Bool, title: String, subtitle: String,
                              actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(done ? Color.green : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !done {
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NovelForge")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Autonome KI-Buchproduktion – von der Idee bis zum Export")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var runningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.2.fill")
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)
            VStack(alignment: .leading, spacing: 2) {
                Text("Produktion läuft: \(orchestrator.currentProject?.title ?? "")")
                    .font(.headline)
                Text(orchestrator.currentAgent)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(Int(orchestrator.progress * 100)) %")
                    .font(.headline)
                    .monospacedDigit()
                ProgressView(value: orchestrator.progress)
                    .frame(width: 140)
            }
        }
        .padding(16)
        .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                            GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            StatCard(title: "Aktive Projekte", value: "\(activeProjects.count)",
                     icon: "book.fill", color: .blue)
            StatCard(title: "Abgeschlossen", value: "\(completedProjects.count)",
                     icon: "checkmark.circle.fill", color: .green)
            StatCard(title: "Geschriebene Wörter", value: FormattingHelpers.formatWordCount(totalWords),
                     icon: "text.word.spacing", color: .purple)
            StatCard(title: "Fehlgeschlagen", value: "\(projects.filter { $0.status == .failed }.count)",
                     icon: "exclamationmark.triangle.fill", color: .red)
        }
    }

    private var activeProductionsSection: some View {
        Group {
            if !activeProjects.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("In Arbeit")
                        .font(.headline)
                    ForEach(activeProjects.prefix(4)) { project in
                        Button {
                            AppState.shared.showProjectDetail(project)
                        } label: {
                            ProjectCard(project: project)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var completedProjectsSection: some View {
        Group {
            if !completedProjects.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Kürzlich abgeschlossen")
                        .font(.headline)
                    ForEach(completedProjects.prefix(4)) { project in
                        Button {
                            AppState.shared.showProjectDetail(project)
                        } label: {
                            CompletedProjectCard(project: project)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ProjectCard: View {
    let project: Project

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .font(.headline)
                    Text("\(project.authorName) · \(project.genre)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(status: project.status)
            }

            ProgressView(value: project.status.progressFraction)
                .progressViewStyle(.linear)

            HStack {
                Text("\(FormattingHelpers.formatWordCount(project.totalWordCount)) von ca. \(FormattingHelpers.formatWordCount(project.targetWordCount)) Wörtern")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(project.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct CompletedProjectCard: View {
    let project: Project

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(.headline)
                Text("\(project.authorName) · \(FormattingHelpers.formatWordCount(project.totalWordCount)) Wörter · \(project.chapters?.count ?? 0) Kapitel")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(.green)
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }
}

struct StatusBadge: View {
    let status: ProjectStatus

    var color: Color {
        switch status {
        case .completed: return .green
        case .failed: return .red
        case .paused: return .orange
        case .created: return .gray
        default: return .blue
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Projektliste

struct ProjectsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) var projects: [Project]
    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @ObservedObject private var appState = AppState.shared
    @State private var showingNewBookWizard = false
    @State private var projectToDelete: Project?
    @State private var navigationPath: [Project] = []

    /// Öffnet ein per Querverweis (z.B. Dashboard-Karte) angefordertes Projektdetail.
    @MainActor
    private func consumePendingDetail() {
        if let project = appState.pendingProjectDetail {
            navigationPath = [project]
            appState.pendingProjectDetail = nil
        }
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if projects.isEmpty {
                    ContentUnavailableView {
                        Label("Keine Projekte", systemImage: "books.vertical")
                    } description: {
                        Text("Erstellen Sie ein neues Buchprojekt, um zu starten.")
                    } actions: {
                        Button("Neues Buch") { showingNewBookWizard = true }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(projects) { project in
                            NavigationLink(value: project) {
                                ProjectListRow(project: project)
                            }
                            .contextMenu {
                                if project.status != .completed && !orchestrator.isRunning {
                                    Button {
                                        orchestrator.resumePipeline(project: project)
                                    } label: {
                                        Label(project.status == .created ? "Produktion starten" : "Produktion fortsetzen",
                                              systemImage: "play.fill")
                                    }
                                }
                                Button(role: .destructive) {
                                    projectToDelete = project
                                } label: {
                                    Label("Projekt löschen", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Projekte")
            .navigationDestination(for: Project.self) { project in
                ProjectDetailView(project: project)
            }
            .onAppear {
                consumePendingDetail()
            }
            .onChange(of: appState.pendingProjectDetail) {
                consumePendingDetail()
            }
            .toolbar {
                ToolbarItem {
                    Button("Neues Buch", systemImage: "plus") {
                        showingNewBookWizard = true
                    }
                }
            }
            .sheet(isPresented: $showingNewBookWizard) {
                NewBookWizardView()
            }
            .confirmationDialog("Projekt \"\(projectToDelete?.title ?? "")\" wirklich löschen?",
                                isPresented: Binding(
                                    get: { projectToDelete != nil },
                                    set: { if !$0 { projectToDelete = nil } })) {
                Button("Endgültig löschen", role: .destructive) {
                    if let project = projectToDelete {
                        modelContext.delete(project)
                        try? modelContext.save()
                    }
                    projectToDelete = nil
                }
                Button("Abbrechen", role: .cancel) {
                    projectToDelete = nil
                }
            } message: {
                Text("Alle Kapitel, Szenen und Berichte dieses Projekts werden gelöscht. Das kann nicht rückgängig gemacht werden.")
            }
        }
    }
}

struct ProjectListRow: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)
                Text("\(project.authorName) · \(project.genre) · \(project.language)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: project.status)
                Text("\(FormattingHelpers.formatWordCount(project.totalWordCount)) Wörter")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Projektdetail

struct ProjectDetailView: View {
    let project: Project
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @State private var confirmDelete = false

    private var scores: QualityScores {
        QualityScores.compute(for: project)
    }

    private var isRunningThisProject: Bool {
        orchestrator.isRunning && orchestrator.currentProject?.id == project.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("\(project.authorName) · \(project.genre)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: project.status)
                }

                // Aktionsleiste: Produktion, Querverweise, Löschen
                HStack(spacing: 10) {
                    if isRunningThisProject {
                        Button {
                            orchestrator.pausePipeline()
                        } label: {
                            Label("Pausieren", systemImage: "pause.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    } else if project.status != .completed {
                        Button {
                            orchestrator.resumePipeline(project: project)
                        } label: {
                            Label(project.status == .created ? "Produktion starten" : "Fortsetzen",
                                  systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(orchestrator.isRunning)
                    }

                    Button {
                        AppState.shared.open(.manuscript, project: project)
                    } label: {
                        Label("Manuskript", systemImage: "doc.text")
                    }

                    Button {
                        AppState.shared.open(.storyBible, project: project)
                    } label: {
                        Label("Story Bible", systemImage: "book.closed")
                    }

                    Button {
                        AppState.shared.open(.export, project: project)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }

                    Spacer()

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help("Projekt löschen")
                    .disabled(isRunningThisProject)
                }
                .buttonStyle(.bordered)

                ProgressView(value: project.status.progressFraction) {
                    Text("Gesamtfortschritt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    InfoTile(label: "Sprache", value: project.language)
                    InfoTile(label: "Zielseiten", value: "\(project.targetPageCount)")
                    InfoTile(label: "Wörter", value: FormattingHelpers.formatWordCount(project.totalWordCount))
                    InfoTile(label: "Kapitel", value: "\(project.chapters?.count ?? 0)")
                    InfoTile(label: "Provider", value: project.preferredProviderRaw)
                    InfoTile(label: "Modell", value: project.preferredModel.isEmpty ? "–" : project.preferredModel)
                    InfoTile(label: "Trim-Größe", value: shortTrimSize)
                    InfoTile(label: "Kostenlimit", value: project.costLimitUSD > 0 ? "\(Int(project.costLimitUSD)) USD" : "–")
                    InfoTile(label: "Tokens verbraucht", value: FormattingHelpers.formatWordCount(totalTokens))
                }

                if let profile = project.bookProfile {
                    conceptSection(profile)
                    kdpMetadataSection(profile)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Qualitätsmetriken")
                        .font(.headline)
                    QualityMetricRow(label: "Struktur", score: scores.structure)
                    QualityMetricRow(label: "Figuren", score: scores.characters)
                    QualityMetricRow(label: "Stil", score: scores.style)
                    QualityMetricRow(label: "Konsistenz", score: scores.consistency)
                    QualityMetricRow(label: "KDP-Format", score: scores.kdp)
                }

                if !visibleReports.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Berichte aus der Produktion")
                            .font(.headline)
                        ForEach(visibleReports) { report in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: severityIcon(report.severity))
                                    .foregroundStyle(severityColor(report.severity))
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(report.checkedArea) · \(report.checkType)")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Text(report.result)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !report.recommendation.isEmpty {
                                        Text(report.recommendation)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }

                Button {
                    if let url = try? ExportEngine.exportDirectory(for: project) {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                } label: {
                    Label("Exportordner im Finder öffnen", systemImage: "folder")
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle(project.title)
        .confirmationDialog("Projekt \"\(project.title)\" wirklich löschen?",
                            isPresented: $confirmDelete) {
            Button("Endgültig löschen", role: .destructive) {
                if AppState.shared.selectedProject?.id == project.id {
                    AppState.shared.selectedProject = nil
                }
                modelContext.delete(project)
                try? modelContext.save()
                dismiss()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle Kapitel, Szenen und Berichte dieses Projekts werden unwiderruflich gelöscht.")
        }
    }

    private var shortTrimSize: String {
        project.trimSize.displayName.components(separatedBy: " (").first ?? project.trimSize.rawValue
    }

    private var totalTokens: Int {
        (project.pipelineJobs ?? []).reduce(0) { $0 + $1.tokenUsage }
    }

    @ViewBuilder
    private func conceptSection(_ profile: BookProfile) -> some View {
        if let logline = profile.logline, !logline.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Konzept")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 10) {
                    conceptField("Logline", logline)
                    if !profile.premise.isEmpty {
                        conceptField("Prämisse", profile.premise)
                    }
                    if !profile.theme.isEmpty {
                        conceptField("Thema", profile.theme)
                    }
                    if let synopsis = profile.synopsis, !synopsis.isEmpty {
                        DisclosureGroup("Exposé anzeigen") {
                            Text(synopsis)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 6)
                        }
                        .font(.caption)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func conceptField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func kdpMetadataSection(_ profile: BookProfile) -> some View {
        if !profile.kdpDescription.isEmpty || !profile.kdpKeywords.isEmpty || !profile.kdpCategories.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("KDP-Metadaten")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 10) {
                    if !profile.kdpDescription.isEmpty {
                        metadataRow(label: "Produktbeschreibung", value: profile.kdpDescription)
                    }
                    if !profile.kdpKeywords.isEmpty {
                        metadataRow(label: "Keywords (7)", value: profile.kdpKeywords)
                    }
                    if !profile.kdpCategories.isEmpty {
                        metadataRow(label: "Kategorie-Vorschläge", value: profile.kdpCategories)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.caption)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("In die Zwischenablage kopieren")
        }
    }

    /// Score-Einträge sind bereits als Metriken visualisiert – hier nur echte Befunde.
    private var visibleReports: [QualityReport] {
        (project.qualityReports ?? [])
            .filter { $0.checkType != "Score" }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private func severityIcon(_ severity: Severity) -> String {
        switch severity {
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "xmark.octagon"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    private func severityColor(_ severity: Severity) -> Color {
        switch severity {
        case .info: return .blue
        case .warning: return .orange
        case .error, .critical: return .red
        }
    }
}

struct InfoTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
    }
}
