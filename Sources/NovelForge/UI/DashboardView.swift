import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) var projects: [Project]
    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @ObservedObject private var providerStore = ProviderSettingsStore.shared
    @State private var showingNewBookSheet = false

    var activeProjects: [Project] {
        projects.filter { $0.status != .completed && $0.status != .failed }
    }

    var completedProjects: [Project] {
        projects.filter { $0.status == .completed }
    }

    var failedProjects: [Project] {
        projects.filter { $0.status == .failed }
    }

    var totalWords: Int {
        projects.reduce(0) { $0 + $1.totalWordCount }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                let providerReady = hasUsableProvider()
                headerSection(providerReady: providerReady)

                if !providerReady {
                    setupChecklist(providerReady: providerReady)
                }

                if orchestrator.isRunning {
                    runningBanner
                }

                statsSection

                if projects.isEmpty {
                    emptyState
                } else {
                    HStack(alignment: .top, spacing: 18) {
                        activeProductionsSection
                        completedProjectsSection
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 1120, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(StudioBackground())
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
            HStack {
                StudioSectionLabel(text: "Setup erforderlich")
                Spacer()
                StudioStatusPill(text: "2 Schritte", systemImage: "checklist", color: StudioTheme.amber)
            }

            checklistRow(done: providerReady,
                         title: "KI-Provider einrichten",
                         subtitle: "Ollama Cloud oder ein anderer aktiver Provider muss bereit sein, bevor Auto-Produktion startet.",
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
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioPanel(cornerRadius: 8, accent: StudioTheme.amber)
    }

    private func checklistRow(done: Bool, title: String, subtitle: String,
                              actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(done ? StudioTheme.lime : StudioTheme.textFaint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(StudioTheme.textMuted)
            }
            Spacer()
            if !done {
                Button(actionTitle, action: action)
                    .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.amber))
            }
        }
    }

    private func headerSection(providerReady: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        StudioStatusPill(text: providerReady ? "Provider bereit" : "Provider fehlt",
                                         systemImage: providerReady ? "checkmark.seal.fill" : "key",
                                         color: providerReady ? StudioTheme.cyan : StudioTheme.amber)
                        StudioStatusPill(text: orchestrator.isUnlimitedMode ? "Dauerproduktion" : "Command Center",
                                         systemImage: orchestrator.isUnlimitedMode ? "infinity" : "rectangle.grid.2x2",
                                         color: StudioTheme.cyan)
                    }
                    Text("NovelForge")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundStyle(StudioTheme.heroGradient)
                    Text("Autonome Buchproduktion mit Story-Gedächtnis, Qualitäts-Agenten, KDP-Export und kontrollierbarer Parallelität.")
                        .font(.subheadline)
                        .foregroundStyle(StudioTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 18)
                VStack(alignment: .trailing, spacing: 10) {
                    Button {
                        showingNewBookSheet = true
                    } label: {
                        Label("Neues Buch", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(StudioPrimaryButtonStyle())
                    .frame(width: 188)

                    Button {
                        AppState.shared.open(.production)
                    } label: {
                        Label("Auto-Modus", systemImage: "infinity")
                    }
                    .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.violet))
                }
            }

            HStack(spacing: 10) {
                commandTile(title: "Provider",
                            value: activeProviderName,
                            detail: activeModelName,
                            icon: "cloud.fill",
                            color: providerReady ? StudioTheme.cyan : StudioTheme.amber)
                commandTile(title: "Pipeline",
                            value: orchestrator.isRunning ? "Schreibt" : "Bereit",
                            detail: orchestrator.isRunning ? orchestrator.currentAgent : "Auto oder Einzelbuch starten",
                            icon: orchestrator.isRunning ? "bolt.horizontal.fill" : "sparkles",
                            color: StudioTheme.violet)
                commandTile(title: "Gedächtnis",
                            value: "\(projects.count) Projekte",
                            detail: "Titel, Figuren und Plots werden abgeglichen",
                            icon: "brain.head.profile",
                            color: StudioTheme.cyan)
            }
        }
        .padding(22)
        .studioFeaturedPanel(cornerRadius: 10)
    }

    private var runningBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "gearshape.2.fill")
                .font(.title3)
                .foregroundStyle(StudioTheme.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text("Produktion läuft: \(orchestrator.currentProject?.title ?? "")")
                    .font(.headline)
                Text(orchestrator.currentAgent)
                    .font(.caption)
                    .foregroundStyle(StudioTheme.textMuted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("\(Int(orchestrator.progress * 100)) %")
                    .font(.headline)
                    .monospacedDigit()
                StudioProgressBar(value: orchestrator.progress)
                    .frame(width: 140)
            }
        }
        .padding(18)
        .studioFeaturedPanel(cornerRadius: 8)
    }

    private var statsSection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
            StatCard(title: "Aktive Projekte", value: "\(activeProjects.count)",
                     icon: "book.fill", color: StudioTheme.cyan)
            StatCard(title: "Abgeschlossen", value: "\(completedProjects.count)",
                     icon: "checkmark.circle.fill", color: StudioTheme.violet)
            StatCard(title: "Geschriebene Wörter", value: FormattingHelpers.formatWordCount(totalWords),
                     icon: "text.word.spacing", color: StudioTheme.cyan)
            StatCard(title: "Fehlgeschlagen", value: "\(failedProjects.count)",
                     icon: "exclamationmark.triangle.fill", color: StudioTheme.danger)
        }
    }

    private var activeProductionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StudioSectionLabel(text: "In Arbeit")
                Spacer()
                StudioStatusPill(text: "\(activeProjects.count)", systemImage: "tray.full", color: StudioTheme.cyan)
            }
            if activeProjects.isEmpty {
                Text("Keine aktive Pipeline. Der Auto-Modus kann sofort gestartet werden.")
                    .font(.caption)
                    .foregroundStyle(StudioTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .studioGlassTile(cornerRadius: 8, accent: StudioTheme.cyan, opacity: 0.82)
            } else {
                ForEach(activeProjects.prefix(5)) { project in
                    Button {
                        AppState.shared.showProjectDetail(project)
                    } label: {
                        ProjectCard(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioPanel(cornerRadius: 8, accent: StudioTheme.cyan)
    }

    private var completedProjectsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                StudioSectionLabel(text: "Kürzlich abgeschlossen")
                Spacer()
                StudioStatusPill(text: "\(completedProjects.count)", systemImage: "checkmark.seal", color: StudioTheme.lime)
            }
            if completedProjects.isEmpty {
                Text("Fertige KDP-Exporte erscheinen hier mit Wortzahl und Kapitelstand.")
                    .font(.caption)
                    .foregroundStyle(StudioTheme.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .studioGlassTile(cornerRadius: 8, accent: StudioTheme.lime, opacity: 0.82)
            } else {
                ForEach(completedProjects.prefix(5)) { project in
                    Button {
                        AppState.shared.showProjectDetail(project)
                    } label: {
                        CompletedProjectCard(project: project)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioPanel(cornerRadius: 8, accent: StudioTheme.lime)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "book.pages.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(StudioTheme.heroGradient)
                    .frame(width: 44, height: 44)
                    .studioGlassTile(cornerRadius: 8, accent: StudioTheme.violet)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Noch kein Buchprojekt")
                        .font(.title3.weight(.semibold))
                    Text("NovelForge kann Konzept, Plot, Kapitel, Szenen, Rohfassung, Lektorat und Export vollautomatisch vorbereiten.")
                        .font(.subheadline)
                        .foregroundStyle(StudioTheme.textMuted)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    showingNewBookSheet = true
                } label: {
                    Label("Erstes Buch erstellen", systemImage: "plus.circle.fill")
                }
                .buttonStyle(StudioPrimaryButtonStyle())
                .frame(maxWidth: 220)

                Button {
                    AppState.shared.open(.production)
                } label: {
                    Label("Auto-Produktion konfigurieren", systemImage: "infinity")
                }
                .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.lime))
            }
        }
        .padding(18)
        .studioPanel(cornerRadius: 8, accent: StudioTheme.violet)
    }

    private var activeProviderName: String {
        providerStore.configurations.first(where: \.isActive)?.provider.rawValue
            ?? providerStore.configurations.first?.provider.rawValue
            ?? "Nicht verbunden"
    }

    private var activeModelName: String {
        providerStore.configurations.first(where: \.isActive)?.defaultModel
            ?? providerStore.configurations.first?.defaultModel
            ?? "Modell auswaehlen"
    }

    private func commandTile(title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(color.opacity(0.22), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(StudioTheme.textFaint)
                Text(value)
                    .font(.callout.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(StudioTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioGlassTile(cornerRadius: 8, accent: color, opacity: 0.86)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(color.opacity(0.22), lineWidth: 1)
                )
            StudioStatNumber(value: value, gradient: StudioTheme.accentGradient(color))
            Text(title.uppercased())
                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                .foregroundStyle(StudioTheme.textFaint)
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(StudioTheme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(StudioTheme.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 6)
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
                        .lineLimit(1)
                    Text("\(project.authorName) · \(project.genre)")
                        .font(.subheadline)
                        .foregroundStyle(StudioTheme.textMuted)
                        .lineLimit(1)
                }
                Spacer()
                StatusBadge(status: project.status)
            }

            StudioProgressBar(value: project.status.progressFraction, height: 7)

            HStack {
                Text("\(FormattingHelpers.formatWordCount(project.totalWordCount)) von ca. \(FormattingHelpers.formatWordCount(project.targetWordCount)) Wörtern")
                    .font(.caption)
                    .foregroundStyle(StudioTheme.textMuted)
                Spacer()
                Text(project.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(StudioTheme.textFaint)
            }
        }
        .padding(14)
        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.cyan, opacity: 0.86)
    }
}

struct CompletedProjectCard: View {
    let project: Project

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(project.authorName) · \(FormattingHelpers.formatWordCount(project.totalWordCount)) Wörter · \(project.chapters?.count ?? 0) Kapitel")
                    .font(.subheadline)
                    .foregroundStyle(StudioTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.title3)
                .foregroundStyle(StudioTheme.lime)
        }
        .padding(14)
        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.lime, opacity: 0.86)
    }
}

struct StatusBadge: View {
    let status: ProjectStatus

    var color: Color {
        switch status {
        case .completed: return StudioTheme.lime
        case .failed: return StudioTheme.danger
        case .paused: return StudioTheme.amber
        case .created: return StudioTheme.textFaint
        default: return StudioTheme.cyan
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .overlay(Capsule().strokeBorder(color.opacity(0.28), lineWidth: 1))
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

    private func isRunning(_ project: Project) -> Bool {
        orchestrator.currentProject?.id == project.id || orchestrator.activeProjectIDs.contains(project.id)
    }

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
                    VStack(alignment: .leading, spacing: 14) {
                        Image(systemName: "books.vertical.fill")
                            .font(.largeTitle)
                            .foregroundStyle(StudioTheme.heroGradient)
                        Text("Keine Projekte")
                            .font(.title2.weight(.semibold))
                        Text("Erstellen Sie ein neues Buchprojekt oder starten Sie die Auto-Produktion im Produktions-Cockpit.")
                            .font(.subheadline)
                            .foregroundStyle(StudioTheme.textMuted)
                        Button {
                            showingNewBookWizard = true
                        } label: {
                            Label("Neues Buch", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(StudioPrimaryButtonStyle())
                        .frame(maxWidth: 220)
                    }
                    .padding(24)
                    .frame(maxWidth: 520, alignment: .leading)
                    .studioPanel(cornerRadius: 8, accent: StudioTheme.violet)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                                .disabled(isRunning(project))
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    projectToDelete = project
                                } label: {
                                    Label("Löschen", systemImage: "trash")
                                }
                                .disabled(isRunning(project))
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(StudioBackground())
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
                    Button {
                        showingNewBookWizard = true
                    } label: {
                        Label("Neues Buch", systemImage: "plus")
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
                    if let project = projectToDelete, !isRunning(project) {
                        // Globale Auswahl lösen, sonst zeigt sie auf ein gelöschtes
                        // Objekt und andere Views stürzen beim Lesen ab.
                        if AppState.shared.selectedProject?.id == project.id {
                            AppState.shared.selectedProject = nil
                        }
                        ChatMessage.deleteMessages(forProjectID: project.id, in: modelContext)
                        modelContext.delete(project)
                        modelContext.saveOrLog()
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
            Image(systemName: "book.closed.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(StudioTheme.cyan)
                .frame(width: 32, height: 32)
                .background(StudioTheme.cyan.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(StudioTheme.cyan.opacity(0.22), lineWidth: 1))
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)
                    .lineLimit(1)
                Text("\(project.authorName) · \(project.genre) · \(project.language)")
                    .font(.caption)
                    .foregroundStyle(StudioTheme.textMuted)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                StatusBadge(status: project.status)
                Text("\(FormattingHelpers.formatWordCount(project.totalWordCount)) Wörter")
                    .font(.caption2)
                    .foregroundStyle(StudioTheme.textFaint)
            }
        }
        .padding(12)
        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.cyan, opacity: 0.88)
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

    /// True, sobald dieses Projekt aktiv produziert wird – auch von einem
    /// parallelen Hintergrund-Worker (dessen currentProject NICHT auf .shared zeigt).
    /// Schützt das Löschen vor einem Use-of-deleted-object-Crash in SwiftData.
    private var isProjectActive: Bool {
        isRunningThisProject || orchestrator.activeProjectIDs.contains(project.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(StudioTheme.heroGradient)
                        Text("\(project.authorName) · \(project.genre)")
                            .foregroundStyle(StudioTheme.textMuted)
                    }
                    Spacer()
                    StatusBadge(status: project.status)
                }
                .padding(18)
                .studioFeaturedPanel(cornerRadius: 10)

                // Aktionsleiste: Produktion, Querverweise, Löschen
                HStack(spacing: 10) {
                    if isRunningThisProject {
                        Button {
                            orchestrator.pausePipeline()
                        } label: {
                            Label("Pausieren", systemImage: "pause.fill")
                        }
                        .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.amber))
                    } else if project.status != .completed {
                        Button {
                            orchestrator.resumePipeline(project: project)
                        } label: {
                            Label(project.status == .created ? "Produktion starten" : "Fortsetzen",
                                  systemImage: "play.fill")
                        }
                        .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.lime))
                        .disabled(orchestrator.isRunning)
                    }

                    Button {
                        openProjectArea(.manuscript)
                    } label: {
                        Label("Manuskript", systemImage: "doc.text")
                    }

                    Button {
                        openProjectArea(.storyBible)
                    } label: {
                        Label("Story Bible", systemImage: "book.closed")
                    }

                    Button {
                        openProjectArea(.export)
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }

                    Spacer()

                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .help(isProjectActive ? "Während der Produktion nicht löschbar" : "Projekt löschen")
                    .disabled(isProjectActive)
                    .accessibilityLabel("Projekt löschen")
                }
                .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.cyan))
                .padding(12)
                .studioPanel(cornerRadius: 8, accent: StudioTheme.cyan)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Gesamtfortschritt")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(StudioTheme.textMuted)
                        Spacer()
                        Text("\(Int(project.status.progressFraction * 100)) %")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(StudioTheme.cyan)
                    }
                    StudioProgressBar(value: project.status.progressFraction)
                }
                .padding(12)
                .studioPanel(cornerRadius: 8, accent: StudioTheme.cyan)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    InfoTile(label: "Sprache", value: project.language)
                    InfoTile(label: "Zielseiten", value: "\(project.targetPageCount)")
                    InfoTile(label: "Wörter", value: FormattingHelpers.formatWordCount(project.totalWordCount))
                    InfoTile(label: "Kapitel", value: "\(project.chapters?.count ?? 0)")
                    InfoTile(label: "Provider", value: project.preferredProviderRaw)
                    InfoTile(label: "Modell", value: project.preferredModel.isEmpty ? "–" : project.preferredModel)
                    InfoTile(label: "Trim-Größe", value: shortTrimSize)
                    InfoTile(label: "Tokens verbraucht", value: FormattingHelpers.formatWordCount(totalTokens))
                }

                if let profile = project.bookProfile {
                    conceptSection(profile)
                }
                KDPSalesSheetView(project: project)

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
                                        .foregroundStyle(StudioTheme.textMuted)
                                    if !report.recommendation.isEmpty {
                                        Text(report.recommendation)
                                            .font(.caption2)
                                            .foregroundStyle(StudioTheme.textFaint)
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
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(StudioBackground())
        .navigationTitle(project.title)
        .confirmationDialog("Projekt \"\(project.title)\" wirklich löschen?",
                            isPresented: $confirmDelete) {
            Button("Endgültig löschen", role: .destructive) {
                guard !isProjectActive else { return }
                if AppState.shared.selectedProject?.id == project.id {
                    AppState.shared.selectedProject = nil
                }
                ChatMessage.deleteMessages(forProjectID: project.id, in: modelContext)
                modelContext.delete(project)
                modelContext.saveOrLog()
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

    private func openProjectArea(_ item: SidebarItem) {
        AppState.shared.open(item, project: project)
        dismiss()
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
                                .foregroundStyle(StudioTheme.textMuted)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 6)
                        }
                        .font(.caption)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .studioGlassTile(cornerRadius: 8, accent: StudioTheme.violet, opacity: 0.86)
            }
        }
    }

    private func conceptField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(StudioTheme.textFaint)
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
        case .info: return StudioTheme.cyan
        case .warning: return StudioTheme.amber
        case .error, .critical: return StudioTheme.danger
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
                .foregroundStyle(StudioTheme.textMuted)
            Text(value)
                .font(.callout)
                .fontWeight(.medium)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.violet, opacity: 0.82)
    }
}
