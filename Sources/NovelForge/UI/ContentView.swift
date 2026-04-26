import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]
    
    @State private var selectedSidebarItem: SidebarItem? = .dashboard
    @State private var selectedProject: Project?
    @State private var showingNewBookSheet = false
    
    enum SidebarItem: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case projects = "Projekte"
        case newBook = "Neues Buch"
        case queue = "Warteschlange"
        case settings = "Einstellungen"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .projects: return "folder"
            case .newBook: return "plus.circle"
            case .queue: return "list.bullet"
            case .settings: return "gear"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selectedSidebarItem) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("NovelForge")
            .frame(minWidth: 200)
        } detail: {
            Group {
                switch selectedSidebarItem {
                case .dashboard:
                    DashboardView()
                case .projects:
                    ProjectsListView()
                case .newBook:
                    NewBookWizardView()
                case .queue:
                    PipelineQueueView()
                case .settings:
                    SettingsView()
                case .none:
                    Text("Wählen Sie einen Bereich")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

func getLastProviderConfig(for project: Project) -> ProviderConfiguration? {
    var config = ProviderConfiguration(provider: .openAI)
    config.isActive = true
    config.defaultModel = "gpt-4o"
    
    if let apiKey = KeychainService.getAPIKey(for: .openAI) {
        config.apiKey = apiKey
    }
    
    return config
}

struct ProjectsListView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) var projects: [Project]
    @State private var selectedProject: Project?
    @State private var showingNewBookWizard = false
    
    var body: some View {
        List(selection: $selectedProject) {
            ForEach(projects) { project in
                NavigationLink(value: project) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(project.title)
                                .font(.headline)
                            Text("\(project.authorName) • \(project.genre)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(status: project.status)
                    }
                    .padding(.vertical, 4)
                }
                .tag(project)
            }
        }
        .navigationTitle("Projekte")
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
    }
}

struct PipelineQueueView: View {
    @Query var allProjects: [Project]
    @StateObject private var orchestrator = PipelineOrchestrator.shared
    
    var activeProjects: [Project] {
        allProjects.filter { $0.status != .completed && $0.status != .failed }
    }
    
    var body: some View {
        VStack {
            if orchestrator.isRunning {
                PipelineProgressView()
            } else if activeProjects.isEmpty {
                ContentUnavailableView(
                    "Keine aktiven Produktionen",
                    systemImage: "list.bullet.clipboard",
                    description: Text("Starten Sie eine neue Buchproduktion")
                )
            } else {
                List(activeProjects) { project in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(project.title)
                                .font(.headline)
                            Text("Status: \(project.status.rawValue)")
                                .font(.caption)
                        }
                        Spacer()
                        if let config = getLastProviderConfig(for: project) {
                            Button("Fortsetzen") {
                                orchestrator.startPipeline(project: project, providerConfig: config)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
        .navigationTitle("Warteschlange")
    }
}

struct PipelineProgressView: View {
    @StateObject private var orchestrator = PipelineOrchestrator.shared
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "gear")
                    .imageScale(.large)
                    .foregroundStyle(.blue)
                    .symbolEffect(.pulse)
                
                VStack(alignment: .leading) {
                    Text(orchestrator.currentPhase.rawValue)
                        .font(.headline)
                    Text(orchestrator.currentAgent)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            VStack(alignment: .leading) {
                HStack {
                    Text("\(Int(orchestrator.progress * 100))%")
                        .font(.caption)
                    Spacer()
                    if !orchestrator.estimatedTimeRemaining.isEmpty {
                        Text("Geschätzte Restzeit: \(orchestrator.estimatedTimeRemaining)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                ProgressView(value: orchestrator.progress)
                    .progressViewStyle(.linear)
                    .scaleEffect(y: 2)
            }
            
            if orchestrator.currentChapter > 0 {
                HStack {
                    Label("Kapitel \(orchestrator.currentChapter)", systemImage: "doc.text")
                    if orchestrator.currentScene > 0 {
                        Label("Szene \(orchestrator.currentScene)", systemImage: "doc.text.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            
            if let error = orchestrator.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            
            HStack {
                Button("Pause") {
                    orchestrator.pausePipeline()
                }
                .buttonStyle(.bordered)
                
                Button("Abbrechen") {
                    orchestrator.cancelPipeline()
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding()
    }
}