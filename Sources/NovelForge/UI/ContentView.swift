import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @State private var selectedTab: SidebarItem = .dashboard
    @StateObject private var orchestrator = PipelineOrchestrator.shared
    
    enum SidebarItem: String, CaseIterable, Identifiable {
        case dashboard = "Dashboard"
        case projects = "Projekte"
        case newBook = "Neues Buch"
        case queue = "Warteschlange"
        case manuscript = "Manuskript"
        case storyBible = "Story Bible"
        case agents = "Agenten"
        case exports = "Exporte"
        case settings = "Einstellungen"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .projects: return "folder"
            case .newBook: return "plus.circle"
            case .queue: return "list.bullet"
            case .manuscript: return "doc.text"
            case .storyBible: return "book.closed"
            case .agents: return "cpu"
            case .exports: return "square.and.arrow.up"
            case .settings: return "gear"
            }
        }
    }
    
    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selectedTab) { item in
                NavigationLink(value: item) {
                    Label(item.rawValue, systemImage: item.icon)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("NovelForge")
            .frame(minWidth: 200)
        } detail: {
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView()
                case .projects:
                    ProjectsListView()
                case .newBook:
                    NewBookWizardView()
                case .queue:
                    PipelineQueueView()
                case .manuscript:
                    ManuscriptView()
                case .storyBible:
                    StoryBibleView()
                case .agents:
                    AgentMonitorView()
                case .exports:
                    ExportView()
                case .settings:
                    SettingsView()
                }
            }
        }
        .onAppear {
            orchestrator.configure(with: modelContext)
        }
    }
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
                        VStack(alignment: .leading) {
                            Text(project.title)
                                .font(.headline)
                            Text("\(project.authorName) • \(project.genre)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusBadge(status: project.status)
                    }
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
    @Query(sort: \Project.updatedAt, order: .reverse) var allProjects: [Project]
    @StateObject private var orchestrator = PipelineOrchestrator.shared
    
    var activeProjects: [Project] {
        allProjects.filter { $0.status != .completed && $0.status != .failed }
    }
    
    var body: some View {
        VStack {
            if orchestrator.isRunning {
                PipelineProgressView()
            } else {
                if activeProjects.isEmpty {
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
                            Button("Fortsetzen") {
                                if let config = getLastProviderConfig(for: project) {
                                    orchestrator.startPipeline(project: project, providerConfig: config)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
        .navigationTitle("Produktionswarteschlange")
    }
}

struct PipelineProgressView: View {
    @StateObject private var orchestrator = PipelineOrchestrator.shared
    
    var body: some View {
        VStack(spacing: 20) {
            // Phase indicator
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
            
            // Progress bar
            VStack(alignment: .leading) {
                HStack {
                    Text("\(Int(orchestrator.progress * 100))%")
                        .font(.caption)
                    Spacer()
                    Text("Geschätzte Restzeit: \(orchestrator.estimatedTimeRemaining)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: orchestrator.progress)
                    .progressViewStyle(.linear)
                    .scaleEffect(y: 2)
            }
            
            // Chapter/Scene info
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
                    orchestrator.pausePipeline()
                    orchestrator.currentProject?.status = .failed
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .padding()
    }
}

func getLastProviderConfig(for project: Project) -> ProviderConfiguration? {
    // In a real implementation, this would retrieve the saved configuration
    // For now, return a default OpenAI configuration
    var config = ProviderConfiguration(provider: .openAI)
    config.isActive = true
    config.defaultModel = "gpt-4o"
    
    // Try to get API key from Keychain
    if let apiKey = KeychainService.getAPIKey(for: .openAI) {
        config.apiKey = apiKey
    }
    
    return config
}