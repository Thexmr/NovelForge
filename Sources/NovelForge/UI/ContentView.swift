import SwiftUI
import SwiftData

/// Globaler UI-Zustand: gewählter Bereich + projektübergreifende Auswahl.
/// Manuskript, Story Bible und Export folgen damit immer demselben Projekt,
/// und Querverweise („Im Manuskript öffnen“) funktionieren aus jedem Bereich.
@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var selectedSidebarItem: SidebarItem? = .dashboard
    @Published var selectedProject: Project?
    /// Projekt, das die Projektliste beim nächsten Erscheinen direkt im Detail öffnen soll.
    @Published var pendingProjectDetail: Project?

    func open(_ item: SidebarItem, project: Project? = nil) {
        if let project {
            selectedProject = project
        }
        selectedSidebarItem = item
    }

    func showProjectDetail(_ project: Project) {
        selectedProject = project
        pendingProjectDetail = project
        selectedSidebarItem = .projects
    }
}

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

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @ObservedObject private var appState = AppState.shared
    @State private var showingNewBookSheet = false

    var body: some View {
        NavigationSplitView {
            List(selection: $appState.selectedSidebarItem) {
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
                switch appState.selectedSidebarItem {
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
                appState.selectedSidebarItem = .production
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
    @State private var showingUnlimitedSheet = false
    @State private var confirmStopUnlimited = false

    private var resumableProjects: [Project] {
        allProjects.filter { project in
            project.status != .completed && project.id != orchestrator.currentProject?.id
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if orchestrator.isUnlimitedMode {
                    unlimitedBanner
                }

                if orchestrator.isRunning {
                    PipelineProgressView()
                }

                if !orchestrator.isRunning {
                    HStack {
                        Button {
                            showingUnlimitedSheet = true
                        } label: {
                            Label("Auto-Produktion starten", systemImage: "infinity")
                        }
                        .buttonStyle(.borderedProminent)
                        Spacer()
                    }
                }

                if !orchestrator.isRunning, let error = orchestrator.lastError {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Letzte Produktion abgebrochen")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("Der gesamte Fortschritt ist gespeichert – die Produktion kann unten fortgesetzt werden.")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
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
        .background(StudioBackground())
        .navigationTitle("Produktion")
        .sheet(isPresented: $showingNewBookSheet) {
            NewBookWizardView()
        }
        .sheet(isPresented: $showingUnlimitedSheet) {
            UnlimitedProductionSheet()
        }
    }

    private var unlimitedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "infinity.circle.fill")
                .font(.title2)
                .foregroundStyle(.tint)
                .symbolEffect(.pulse)
            VStack(alignment: .leading, spacing: 2) {
                Text("Dauerproduktion aktiv – läuft bis Stopp")
                    .font(.headline)
                Text("\(orchestrator.unlimitedBooksCompleted) Bücher fertig · \(orchestrator.activeUnlimitedBooks)/\(orchestrator.parallelUnlimitedBooks) parallel aktiv")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let title = orchestrator.currentProject?.title, orchestrator.parallelUnlimitedBooks == 1 {
                    Text("Aktuell: \(title)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if !orchestrator.currentBookElapsed.isEmpty {
                    Text("Aktueller Durchlauf: \(orchestrator.currentBookElapsed)"
                         + (orchestrator.currentBookEstimatedTotal.isEmpty ? "" : " · gesamt ca. \(orchestrator.currentBookEstimatedTotal)"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if !orchestrator.lastBookDuration.isEmpty {
                    Text("Letzter Durchlauf: \(orchestrator.lastBookDuration)"
                         + (orchestrator.averageBookDuration.isEmpty ? "" : " · Ø/Buch: \(orchestrator.averageBookDuration)"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button(role: .destructive) {
                confirmStopUnlimited = true
            } label: {
                Label("Stoppen", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .studioPanel(accent: StudioTheme.cyan)
        .confirmationDialog("Dauerproduktion stoppen?", isPresented: $confirmStopUnlimited) {
            Button("Stoppen", role: .destructive) {
                orchestrator.stopUnlimitedProduction()
            }
            Button("Weiterlaufen lassen", role: .cancel) {}
        } message: {
            Text("Das aktuelle Buch bleibt gespeichert und kann später regulär fortgesetzt werden.")
        }
    }
}

/// Konfiguration und Start der Dauerproduktion (Unlimited-Modus).
@MainActor
struct UnlimitedProductionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultAuthor") private var defaultAuthor = ""
    @AppStorage("defaultImprint") private var defaultImprint = DefaultBookSettings.imprint
    @AppStorage("defaultAuthorBio") private var defaultAuthorBio = DefaultBookSettings.authorBio
    @AppStorage(ExportEngine.exportRootDefaultsKey) private var exportRoot = ""

    @State private var authorName = ""
    @State private var language = "Deutsch"
    @State private var selectedGenres: Set<String> = ["Thriller"]
    @State private var style = UnlimitedSettings.randomToken
    @State private var pageCount = 150
    @State private var costLimitPerBook = 0.0
    @State private var maxBooks = 0
    @State private var parallelBooks = 1
    @State private var imprint = ""
    @State private var authorBio = ""
    @State private var epubFormat = true
    @State private var pdfFormat = true
    @State private var docxFormat = false

    @State private var selectedProvider = AIProvider.ollamaCloud
    @State private var selectedModel = AIProvider.ollamaCloud.suggestedModels.first ?? ""
    @State private var customModel = ""

    private var effectiveModel: String {
        let custom = customModel.trimmingCharacters(in: .whitespaces)
        return custom.isEmpty ? selectedModel : custom
    }

    private var hasStoredKey: Bool {
        ProviderSettingsStore.shared.hasAPIKey(for: selectedProvider)
    }

    private var canStart: Bool {
        !authorName.trimmingCharacters(in: .whitespaces).isEmpty
            && !selectedGenres.isEmpty
            && !effectiveModel.isEmpty
            && (epubFormat || pdfFormat || docxFormat)
    }

    private var selectedFormats: [String] {
        var formats: [String] = []
        if epubFormat { formats.append("EPUB") }
        if pdfFormat { formats.append("PDF") }
        if docxFormat { formats.append("DOCX") }
        return formats
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Dauerproduktion") {
                    Text("NovelForge produziert KDP-fertige Bücher mit Story-Gedächtnis, damit sich Titel, Figuren, Konflikte und zentrale Geschichten nicht wiederholen. Die Produktion läuft weiter, bis Sie Stopp drücken.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Autorname oder Pseudonym", text: $authorName)
                    TextEditor(text: $authorBio)
                        .frame(minHeight: 74)
                        .overlay(alignment: .topLeading) {
                            if authorBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Über den Autor (erscheint im Buch und prägt KDP-Metadaten)")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                    TextEditor(text: $imprint)
                        .frame(minHeight: 74)
                        .overlay(alignment: .topLeading) {
                            if imprint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text("Impressum / Copyright-Hinweis für KDP")
                                    .foregroundStyle(.tertiary)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                    Picker("Sprache", selection: $language) {
                        ForEach(["Deutsch", "Englisch", "Französisch", "Spanisch"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Genres")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), alignment: .leading)], alignment: .leading, spacing: 8) {
                            ForEach(UnlimitedSettings.genrePool, id: \.self) { item in
                                Toggle(item, isOn: Binding(
                                    get: { selectedGenres.contains(item) },
                                    set: { isOn in
                                        if isOn {
                                            selectedGenres.insert(item)
                                        } else {
                                            selectedGenres.remove(item)
                                        }
                                    }
                                ))
                                .toggleStyle(.checkbox)
                            }
                        }
                        Text(selectedGenres.isEmpty
                             ? "Mindestens ein Genre wählen."
                             : "Auto-Produktion rotiert durch die gewählten Genres und prüft jedes neue Konzept gegen das Story-Gedächtnis.")
                            .font(.caption)
                            .foregroundStyle(selectedGenres.isEmpty ? .orange : .secondary)
                    }
                    Picker("Stilprofil", selection: $style) {
                        Text("Zufällig (abwechslungsreich)").tag(UnlimitedSettings.randomToken)
                        ForEach(UnlimitedSettings.stylePool, id: \.self) { Text($0).tag($0) }
                    }
                    Stepper("Seiten pro Buch: \(pageCount)", value: $pageCount,
                            in: AppConstants.minPageCount...AppConstants.maxPageCount, step: 10)
                }

                Section("Formate & Ausgabeordner") {
                    Toggle("EPUB", isOn: $epubFormat)
                    Toggle("PDF (Print)", isOn: $pdfFormat)
                    Toggle("DOCX", isOn: $docxFormat)

                    HStack {
                        Text(exportRoot.isEmpty ? "~/Documents/NovelForge (Standard)" : exportRoot)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Button("Ordner wählen …") {
                            chooseFolder()
                        }
                        if !exportRoot.isEmpty {
                            Button("Standard") {
                                exportRoot = ""
                            }
                        }
                    }
                }

                Section("KI-Provider & Kosten") {
                    Picker("Provider", selection: $selectedProvider) {
                        ForEach(AIProvider.allCases) { provider in
                            Text(provider.rawValue).tag(provider)
                        }
                    }
                    .onChange(of: selectedProvider) {
                        selectedModel = selectedProvider.suggestedModels.first ?? ""
                        customModel = ""
                    }

                    DynamicModelPicker(provider: selectedProvider,
                                       selectedModel: $selectedModel,
                                       customModel: $customModel,
                                       includeCustomField: true)

                    if selectedProvider.requiresAPIKey && !hasStoredKey {
                        Label("Falls der API-Key noch nicht gespeichert ist: zuerst in Einstellungen → KI-Provider eintragen.",
                              systemImage: "key")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                    Stepper(costLimitPerBook == 0 ? "Kostenlimit pro Buch: kein App-Limit" : "Kostenlimit pro Buch: \(Int(costLimitPerBook)) USD",
                            value: $costLimitPerBook, in: 0...1000, step: 10)
                    Stepper(maxBooks == 0 ? "Anzahl Bücher: unbegrenzt (bis Stopp)" : "Anzahl Bücher: \(maxBooks)",
                            value: $maxBooks, in: 0...100)
                    Stepper("Parallele Bücher: \(parallelBooks)",
                            value: $parallelBooks, in: 1...10)
                    Text(costLimitPerBook == 0
                         ? "NovelForge setzt kein eigenes App-Budgetlimit. Provider-Guthaben und Provider-Limits gelten weiterhin."
                         : "Bei \(parallelBooks) parallelen Büchern können bis zu \(Int(costLimitPerBook) * parallelBooks) USD gleichzeitig reserviert werden.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Dauerproduktion")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        start()
                    } label: {
                        Label("Auto starten", systemImage: "infinity")
                    }
                    .disabled(!canStart)
                }
            }
            .onAppear {
                if defaultAuthor.isEmpty { defaultAuthor = DefaultBookSettings.authorName }
                if authorName.isEmpty { authorName = defaultAuthor }
                if imprint.isEmpty { imprint = defaultImprint }
                if authorBio.isEmpty { authorBio = defaultAuthorBio }
            }
        }
        .frame(minWidth: 560, minHeight: 560)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Ordner wählen"
        if panel.runModal() == .OK, let url = panel.url {
            exportRoot = url.path
        }
    }

    private func start() {
        var config = ProviderConfiguration(provider: selectedProvider)
        config.isActive = true
        config.defaultModel = effectiveModel
        ProviderSettingsStore.shared.upsert(config)
        config.apiKey = KeychainService.getAPIKey(for: selectedProvider)
        config.costLimit = costLimitPerBook

        let settings = UnlimitedSettings(
            authorName: authorName.trimmingCharacters(in: .whitespaces),
            language: language,
            selectedGenres: UnlimitedSettings.genrePool.filter { selectedGenres.contains($0) },
            style: style,
            pageCount: pageCount,
            costLimitPerBook: costLimitPerBook,
            maxBooks: maxBooks,
            parallelBooks: parallelBooks,
            formats: selectedFormats,
            imprint: imprint,
            authorBio: authorBio
        )
        defaultAuthor = settings.authorName
        defaultImprint = settings.imprint
        defaultAuthorBio = settings.authorBio

        PipelineOrchestrator.shared.startUnlimitedProduction(settings: settings, providerConfig: config)
        dismiss()
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
        .studioPanel(cornerRadius: 12, accent: disabled ? .gray : StudioTheme.lime)
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
                if orchestrator.isUnlimitedMode && orchestrator.parallelUnlimitedBooks > 1 {
                    Text("\(orchestrator.activeUnlimitedBooks)/\(orchestrator.parallelUnlimitedBooks)")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .monospacedDigit()
                } else {
                    Text("\(Int(orchestrator.progress * 100)) %")
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }

            if orchestrator.isUnlimitedMode && orchestrator.parallelUnlimitedBooks > 1 {
                ProgressView(value: Double(orchestrator.activeUnlimitedBooks),
                             total: Double(orchestrator.parallelUnlimitedBooks))
                    .progressViewStyle(.linear)
            } else {
                ProgressView(value: orchestrator.progress)
                    .progressViewStyle(.linear)
            }

            // Detailzeile
            HStack(spacing: 16) {
                if orchestrator.currentPhase == .drafting && orchestrator.currentChapter > 0 {
                    Label("Kapitel \(orchestrator.currentChapter)", systemImage: "doc.text")
                }
                if orchestrator.isUnlimitedMode && orchestrator.parallelUnlimitedBooks > 1 {
                    Label("\(orchestrator.unlimitedBooksCompleted) Bücher fertig", systemImage: "books.vertical")
                    Label("\(orchestrator.activeUnlimitedBooks) aktiv", systemImage: "bolt.horizontal.circle")
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
                if !orchestrator.currentBookElapsed.isEmpty {
                    Label("Läuft \(orchestrator.currentBookElapsed)", systemImage: "timer")
                }
                if !orchestrator.currentBookEstimatedTotal.isEmpty {
                    Label("Durchlauf ca. \(orchestrator.currentBookEstimatedTotal)", systemImage: "clock.badge.checkmark")
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
        .studioPanel(accent: StudioTheme.cyan)
    }
}
