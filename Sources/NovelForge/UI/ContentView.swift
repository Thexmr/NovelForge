import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var selectedSidebarItem: SidebarItem? = .dashboard
    @State private var showingNewBookSheet = false

    enum SidebarItem: String, CaseIterable, Identifiable, Hashable {
        case dashboard = "Dashboard"
        case projects = "Projekte"
        case production = "Produktion"
        case agents = "Agenten-Monitor"
        case manuscript = "Manuskript"
        case storyBible = "Story Bible"
        case export = "Export"
        case settings = "Einstellungen"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .projects: return "books.vertical"
            case .production: return "gearshape.2"
            case .agents: return "cpu"
            case .manuscript: return "doc.text"
            case .storyBible: return "book.closed"
            case .export: return "square.and.arrow.up"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                Section("Studio") {
                    sidebarRow(.dashboard)
                    sidebarRow(.projects)
                    sidebarRow(.production)
                    sidebarRow(.agents)
                }
                Section("Inhalt") {
                    sidebarRow(.manuscript)
                    sidebarRow(.storyBible)
                }
                Section("Ausgabe") {
                    sidebarRow(.export)
                }
                Section {
                    sidebarRow(.settings)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("NovelForge")
            .frame(minWidth: 210)
            .safeAreaInset(edge: .bottom) {
                Button {
                    showingNewBookSheet = true
                } label: {
                    Label("Neues Buch", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("n", modifiers: .command)
                .padding(12)
            }
        } detail: {
            Group {
                switch selectedSidebarItem {
                case .dashboard:
                    DashboardView()
                case .projects:
                    ProjectsListView()
                case .production:
                    ProductionView()
                case .agents:
                    AgentMonitorView()
                case .manuscript:
                    ManuscriptView()
                case .storyBible:
                    StoryBibleView()
                case .export:
                    ExportView()
                case .settings:
                    SettingsView()
                case .none:
                    ContentUnavailableView("Bereich wählen", systemImage: "sidebar.left")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingNewBookSheet) {
            NewBookWizardView(onStarted: {
                selectedSidebarItem = .production
            })
        }
        .onAppear {
            PipelineOrchestrator.shared.configure(with: modelContext)
        }
    }

    private func sidebarRow(_ item: SidebarItem) -> some View {
        NavigationLink(value: item) {
            Label(item.rawValue, systemImage: item.icon)
        }
    }
}

// MARK: - Produktion (laufende Pipeline + Warteschlange)

struct ProductionView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) private var allProjects: [Project]
    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @State private var showingNewBookSheet = false

    private var resumableProjects: [Project] {
        allProjects.filter { project in
            project.status != .completed && project.id != orchestrator.currentProject?.id
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if orchestrator.isRunning {
                    PipelineProgressView()
                }

                if !resumableProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(orchestrator.isRunning ? "Wartende Projekte" : "Fortsetzbare Projekte")
                            .font(.headline)

                        ForEach(resumableProjects) { project in
                            ResumableProjectRow(project: project,
                                                disabled: orchestrator.isRunning)
                        }
                    }
                }

                if !orchestrator.isRunning && resumableProjects.isEmpty {
                    ContentUnavailableView {
                        Label("Keine aktiven Produktionen", systemImage: "gearshape.2")
                    } description: {
                        Text("Starten Sie eine neue Buchproduktion – die Pipeline arbeitet danach vollautomatisch.")
                    } actions: {
                        Button("Neues Buch") {
                            showingNewBookSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 80)
                }
            }
            .padding(24)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Produktion")
        .sheet(isPresented: $showingNewBookSheet) {
            NewBookWizardView()
        }
    }
}

struct ResumableProjectRow: View {
    let project: Project
    let disabled: Bool
    @ObservedObject private var orchestrator = PipelineOrchestrator.shared

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(project.title)
                    .font(.headline)
                HStack(spacing: 8) {
                    StatusBadge(status: project.status)
                    Text("\(FormattingHelpers.formatWordCount(project.totalWordCount)) Wörter")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(project.status == .created ? "Starten" : "Fortsetzen") {
                orchestrator.resumePipeline(project: project)
            }
            .buttonStyle(.borderedProminent)
            .disabled(disabled)
        }
        .padding(14)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Live-Fortschritt

struct PipelineProgressView: View {
    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @State private var confirmCancel = false

    private var currentPhaseIndex: Int {
        PipelinePhase.executionOrder.firstIndex(of: orchestrator.currentPhase) ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Kopf
            HStack(spacing: 12) {
                Image(systemName: "gearshape.2.fill")
                    .font(.title)
                    .foregroundStyle(.tint)
                    .symbolEffect(.pulse)

                VStack(alignment: .leading, spacing: 2) {
                    Text(orchestrator.currentProject?.title ?? "Buchproduktion")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(orchestrator.currentAgent.isEmpty ? orchestrator.currentPhase.rawValue : orchestrator.currentAgent)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(orchestrator.progress * 100)) %")
                    .font(.system(.title2, design: .rounded))
                    .fontWeight(.bold)
                    .monospacedDigit()
            }

            ProgressView(value: orchestrator.progress)
                .progressViewStyle(.linear)

            // Detailzeile
            HStack(spacing: 16) {
                if orchestrator.currentPhase == .drafting && orchestrator.currentChapter > 0 {
                    Label("Kapitel \(orchestrator.currentChapter)", systemImage: "doc.text")
                }
                if orchestrator.currentScene > 0 && orchestrator.currentPhase == .drafting {
                    Label("Szene \(orchestrator.currentScene)", systemImage: "text.alignleft")
                }
                if orchestrator.totalScenes > 0 && orchestrator.currentPhase == .drafting {
                    Label("\(orchestrator.completedScenes)/\(orchestrator.totalScenes) Szenen", systemImage: "checklist")
                }
                if !orchestrator.estimatedTimeRemaining.isEmpty {
                    Label("Restzeit ca. \(orchestrator.estimatedTimeRemaining)", systemImage: "clock")
                }
                Spacer()
                if orchestrator.totalTokensUsed > 0 {
                    Text("\(FormattingHelpers.formatWordCount(orchestrator.totalTokensUsed)) Tokens · ca. \(FormattingHelpers.formatCost(orchestrator.estimatedCostUSD))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            // Phasen-Checkliste
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(PipelinePhase.executionOrder.enumerated()), id: \.element) { index, phase in
                    HStack(spacing: 10) {
                        if index < currentPhaseIndex {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if index == currentPhaseIndex {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .foregroundStyle(.tint)
                                .symbolEffect(.pulse)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.quaternary)
                        }
                        Image(systemName: phase.iconName)
                            .frame(width: 18)
                            .foregroundStyle(index <= currentPhaseIndex ? .primary : .tertiary)
                        Text(phase.rawValue)
                            .foregroundStyle(index <= currentPhaseIndex ? .primary : .tertiary)
                            .fontWeight(index == currentPhaseIndex ? .semibold : .regular)
                        Spacer()
                    }
                    .font(.callout)
                }
            }

            if let error = orchestrator.lastError {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(10)
                .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Button {
                    orchestrator.pausePipeline()
                } label: {
                    Label("Pausieren", systemImage: "pause.fill")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    confirmCancel = true
                } label: {
                    Label("Abbrechen", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .confirmationDialog("Produktion wirklich abbrechen?",
                                isPresented: $confirmCancel) {
                Button("Produktion abbrechen", role: .destructive) {
                    orchestrator.cancelPipeline()
                }
                Button("Weiter produzieren", role: .cancel) {}
            } message: {
                Text("Der bisherige Fortschritt bleibt gespeichert und kann später fortgesetzt werden.")
            }
        }
        .padding(20)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 14))
    }
}
