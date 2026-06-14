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
        pendingProjectDetail = nil
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
    case editorChat = "Lektor"
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
        case .editorChat: return "text.bubble"
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
        HStack(spacing: 0) {
            StudioSidebar(showingNewBookSheet: $showingNewBookSheet)
                .frame(width: 268)

            Rectangle()
                .fill(StudioTheme.hairline)
                .frame(width: 1)

            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id(appState.selectedSidebarItem)
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

    @ViewBuilder
    private var detailContent: some View {
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
        case .editorChat:
            EditorChatView()
        case .export:
            ExportView()
        case .settings:
            SettingsView()
        case .none:
            ContentUnavailableView("Bereich wählen", systemImage: "sidebar.left")
        }
    }
}

struct StudioSidebar: View {
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @Binding var showingNewBookSheet: Bool

    private let sections: [(String, [SidebarItem])] = [
        ("Studio", [.dashboard, .projects, .production, .agents]),
        ("Inhalt", [.manuscript, .storyBible, .editorChat]),
        ("Ausgabe", [.export]),
        ("System", [.settings])
    ]

    var body: some View {
        ZStack {
            StudioBackground()
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        brandHeader

                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(sections, id: \.0) { section in
                                VStack(alignment: .leading, spacing: 7) {
                                    StudioSectionLabel(text: section.0)
                                        .padding(.horizontal, 4)
                                    ForEach(section.1) { item in
                                        SidebarButton(item: item,
                                                      isSelected: appState.selectedSidebarItem == item,
                                                      badge: badge(for: item)) {
                                            withAnimation(.snappy(duration: 0.18)) {
                                                appState.open(item)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        productionCapsule
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)

                Button {
                    showingNewBookSheet = true
                } label: {
                    Label("Neues Buch", systemImage: "plus.circle.fill")
                }
                .buttonStyle(StudioPrimaryButtonStyle())
                .keyboardShortcut("n", modifiers: .command)
                .padding(16)
                .background(StudioTheme.glassInk.opacity(0.72))
                .overlay(alignment: .top) {
                    LinearGradient(colors: [StudioTheme.hairlineBright, .clear],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 1)
                }
            }
        }
        .frame(minWidth: 238, maxWidth: 310, maxHeight: .infinity, alignment: .topLeading)
    }

    private var brandHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(StudioTheme.brandGradient)
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.black.opacity(0.84))
                }
                .frame(width: 38, height: 38)
                .shadow(color: StudioTheme.cyan.opacity(0.18), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 1) {
                    Text("NovelForge")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                    Text("KDP Auto Studio")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(StudioTheme.textMuted)
                }
            }

            HStack(spacing: 8) {
                StudioStatusPill(text: "Cloud", systemImage: "cloud.fill", color: StudioTheme.cyan)
                StudioStatusPill(text: orchestrator.isUnlimitedMode ? "Loop aktiv" : "Bereit",
                                 systemImage: orchestrator.isUnlimitedMode ? "infinity" : "bolt.fill",
                                 color: orchestrator.isUnlimitedMode ? StudioTheme.lime : StudioTheme.violet)
            }
        }
        .padding(12)
        .studioFeaturedPanel(cornerRadius: 8)
    }

    private var productionCapsule: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                StudioSectionLabel(text: "Live Produktion")
                Spacer()
                Circle()
                    .fill(orchestrator.isRunning ? StudioTheme.lime : StudioTheme.textFaint)
                    .frame(width: 7, height: 7)
                    .shadow(color: orchestrator.isRunning ? StudioTheme.lime.opacity(0.6) : .clear,
                            radius: 7)
            }

            Text(orchestrator.currentProject?.title ?? (orchestrator.isRunning ? "Pipeline aktiv" : "Wartet auf Start"))
                .font(.callout.weight(.semibold))
                .lineLimit(2)

            HStack(spacing: 7) {
                Image(systemName: orchestrator.isRunning ? "arrow.triangle.2.circlepath" : "pause.circle")
                    .foregroundStyle(orchestrator.isRunning ? StudioTheme.cyan : StudioTheme.textFaint)
                Text(orchestrator.isRunning ? orchestrator.currentAgent : "Keine aktive Produktion")
                    .font(.caption)
                    .foregroundStyle(StudioTheme.textMuted)
                    .lineLimit(1)
            }

            StudioProgressBar(value: orchestrator.isRunning ? orchestrator.progress : 0, height: 6)
        }
        .padding(12)
        .studioPanel(cornerRadius: 8, accent: orchestrator.isRunning ? StudioTheme.lime : StudioTheme.violet)
    }

    private func badge(for item: SidebarItem) -> String? {
        switch item {
        case .production:
            if orchestrator.isUnlimitedMode {
                return "\(orchestrator.activeUnlimitedBooks)/\(orchestrator.parallelUnlimitedBooks)"
            }
            return orchestrator.isRunning ? "\(Int(orchestrator.progress * 100))%" : nil
        case .agents:
            return orchestrator.isRunning ? "Live" : nil
        default:
            return nil
        }
    }
}

struct SidebarButton: View {
    let item: SidebarItem
    let isSelected: Bool
    let badge: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 22)
                    .foregroundStyle(isSelected ? StudioTheme.cyan : StudioTheme.textMuted)
                Text(item.rawValue)
                    .font(.callout.weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? Color.primary : StudioTheme.textMuted)
                    .lineLimit(1)
                Spacer(minLength: 8)
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? Color.black.opacity(0.84) : StudioTheme.cyan)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background {
                            if isSelected {
                                Capsule().fill(StudioTheme.brandGradient)
                            } else {
                                Capsule().fill(StudioTheme.cyan.opacity(0.12))
                            }
                        }
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(colors: [
                                StudioTheme.cyan.opacity(0.16),
                                StudioTheme.glassInk.opacity(0.20)
                            ], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(StudioTheme.cyan.opacity(0.12)))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(StudioTheme.cyan.opacity(0.36), lineWidth: 1))
                        .shadow(color: StudioTheme.cyan.opacity(0.16), radius: 12, y: 6)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(item.rawValue)
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
            VStack(alignment: .leading, spacing: 22) {
                productionHeader

                if orchestrator.isUnlimitedMode {
                    unlimitedBanner
                }

                if orchestrator.isRunning {
                    PipelineProgressView()
                }

                if !orchestrator.isRunning, let error = orchestrator.lastError {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(StudioTheme.danger)
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
                    .studioPanel(cornerRadius: 8, accent: StudioTheme.danger)
                }

                if !resumableProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            StudioSectionLabel(text: orchestrator.isRunning ? "Wartende Projekte" : "Fortsetzbare Projekte")
                            Spacer()
                            StudioStatusPill(text: "\(resumableProjects.count)", systemImage: "tray.full", color: StudioTheme.amber)
                        }

                        ForEach(resumableProjects) { project in
                            ResumableProjectRow(project: project,
                                                disabled: orchestrator.isRunning)
                        }
                    }
                }

                if !orchestrator.isRunning && resumableProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: "sparkles")
                                .font(.title2)
                                .foregroundStyle(StudioTheme.heroGradient)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Keine aktive Produktion")
                                    .font(.headline)
                                Text("Starte den Auto-Modus oder lege ein einzelnes Buchprojekt an.")
                                    .font(.caption)
                                    .foregroundStyle(StudioTheme.textMuted)
                            }
                            Spacer()
                        }
                        HStack {
                            Button {
                                showingUnlimitedSheet = true
                            } label: {
                                Label("Auto-Modus", systemImage: "infinity")
                            }
                            .buttonStyle(StudioPrimaryButtonStyle())
                            .frame(maxWidth: 190)

                            Button {
                                showingNewBookSheet = true
                            } label: {
                                Label("Einzelnes Buch", systemImage: "plus")
                            }
                            .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.violet))
                        }
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .studioPanel(cornerRadius: 8, accent: StudioTheme.violet)
                }
            }
            .padding(24)
            .frame(maxWidth: 980, alignment: .leading)
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

    private var productionHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        StudioStatusPill(text: "Autonom", systemImage: "infinity", color: StudioTheme.lime)
                        StudioStatusPill(text: "\(orchestrator.parallelUnlimitedBooks)x parallel",
                                         systemImage: "square.grid.3x3",
                                         color: StudioTheme.cyan)
                    }
                    Text("Produktions-Cockpit")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                    Text("Steuert Einzelprojekte, Dauerproduktion, Fortschritt, Restzeit und parallele Buch-Worker an einem Ort.")
                        .font(.subheadline)
                        .foregroundStyle(StudioTheme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 10) {
                    if !orchestrator.isRunning {
                        Button {
                            showingUnlimitedSheet = true
                        } label: {
                            Label("Auto-Produktion starten", systemImage: "play.fill")
                        }
                        .buttonStyle(StudioPrimaryButtonStyle())
                        .frame(width: 230)
                    }
                    Button {
                        showingNewBookSheet = true
                    } label: {
                        Label("Neues Buch", systemImage: "plus")
                    }
                    .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.violet))
                }
            }

            HStack(spacing: 10) {
                commandMetric(title: "Status",
                              value: orchestrator.isRunning ? "Aktiv" : "Bereit",
                              icon: orchestrator.isRunning ? "bolt.fill" : "checkmark.seal",
                              color: orchestrator.isRunning ? StudioTheme.lime : StudioTheme.cyan)
                commandMetric(title: "Fertige Bücher",
                              value: "\(orchestrator.unlimitedBooksCompleted)",
                              icon: "books.vertical",
                              color: StudioTheme.violet)
                commandMetric(title: "Aktive Worker",
                              value: "\(orchestrator.activeUnlimitedBooks)",
                              icon: "cpu",
                              color: StudioTheme.amber)
            }
        }
        .padding(20)
        .studioFeaturedPanel(cornerRadius: 10)
    }

    private func commandMetric(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 24, height: 24)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(StudioTheme.textFaint)
                Text(value)
                    .font(.callout.weight(.semibold))
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioGlassTile(cornerRadius: 8, accent: color, opacity: 0.86)
    }

    private var unlimitedBanner: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "infinity.circle.fill")
                    .font(.title2)
                    .foregroundStyle(StudioTheme.heroGradient)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Dauerproduktion aktiv – läuft bis Stopp")
                        .font(.headline)
                    Text("\(orchestrator.unlimitedBooksCompleted) Bücher fertig · \(orchestrator.activeUnlimitedBooks)/\(orchestrator.parallelUnlimitedBooks) parallel aktiv")
                        .font(.caption)
                        .foregroundStyle(StudioTheme.textMuted)
                    if let title = orchestrator.currentProject?.title, orchestrator.parallelUnlimitedBooks == 1 {
                        Text("Aktuell: \(title)")
                            .font(.caption2)
                            .foregroundStyle(StudioTheme.textMuted)
                    }
                    if !orchestrator.currentBookElapsed.isEmpty {
                        Text("Aktueller Durchlauf: \(orchestrator.currentBookElapsed)"
                             + (orchestrator.currentBookEstimatedTotal.isEmpty ? "" : " · gesamt ca. \(orchestrator.currentBookEstimatedTotal)"))
                            .font(.caption2)
                            .foregroundStyle(StudioTheme.textMuted)
                    }
                    if !orchestrator.lastBookDuration.isEmpty {
                        Text("Letzter Durchlauf: \(orchestrator.lastBookDuration)"
                             + (orchestrator.averageBookDuration.isEmpty ? "" : " · Ø/Buch: \(orchestrator.averageBookDuration)"))
                            .font(.caption2)
                            .foregroundStyle(StudioTheme.textMuted)
                    }
                }
                Spacer()
                Button(role: .destructive) {
                    confirmStopUnlimited = true
                } label: {
                    Label("Stoppen", systemImage: "stop.fill")
                }
                .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.danger))
            }

            if orchestrator.parallelUnlimitedBooks > 1 && !orchestrator.workerStatuses.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 10)],
                          alignment: .leading, spacing: 10) {
                    ForEach(orchestrator.workerStatuses) { worker in
                        WorkerStatusChip(worker: worker)
                    }
                }
            }
        }
        .padding(16)
        .studioFeaturedPanel(cornerRadius: 10)
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

                Section("KI-Provider & Parallelität") {
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

                    Stepper(maxBooks == 0 ? "Anzahl Bücher: unbegrenzt (bis Stopp)" : "Anzahl Bücher: \(maxBooks)",
                            value: $maxBooks, in: 0...100)
                    Stepper("Parallele Bücher: \(parallelBooks)",
                            value: $parallelBooks, in: 1...10)
                    Text("NovelForge arbeitet weiter, bis Sie stoppen oder der Provider selbst einen echten Kontingentfehler meldet.")
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

        let settings = UnlimitedSettings(
            authorName: authorName.trimmingCharacters(in: .whitespaces),
            language: language,
            selectedGenres: UnlimitedSettings.genrePool.filter { selectedGenres.contains($0) },
            style: style,
            pageCount: pageCount,
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
                        .foregroundStyle(StudioTheme.textMuted)
                }
            }
            Spacer()
            Button(project.status == .created ? "Starten" : "Fortsetzen") {
                orchestrator.resumePipeline(project: project)
            }
            .buttonStyle(StudioSecondaryButtonStyle(accent: disabled ? StudioTheme.textFaint : StudioTheme.lime))
            .disabled(disabled)
        }
        .padding(14)
        .studioPanel(cornerRadius: 8, accent: disabled ? StudioTheme.textFaint : StudioTheme.lime)
    }
}

/// Kompakte Live-Kachel eines parallelen Buch-Workers (Titel, Phase, Fortschritt).
struct WorkerStatusChip: View {
    let worker: PipelineOrchestrator.UnlimitedWorkerStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "book.pages")
                    .font(.caption2)
                    .foregroundStyle(StudioTheme.cyan)
                Text(worker.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(Int(worker.progress * 100)) %")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(StudioTheme.textMuted)
            }
            StudioProgressBar(value: worker.progress, height: 5)
            Text(worker.phase.rawValue + (worker.totalScenes > 0 ? " · \(worker.completedScenes)/\(worker.totalScenes) Szenen" : ""))
                .font(.caption2)
                .foregroundStyle(StudioTheme.textFaint)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.cyan, opacity: 0.82)
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
                    .foregroundStyle(StudioTheme.cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text(orchestrator.currentProject?.title ?? "Buchproduktion")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(orchestrator.currentAgent.isEmpty ? orchestrator.currentPhase.rawValue : orchestrator.currentAgent)
                        .font(.subheadline)
                        .foregroundStyle(StudioTheme.textMuted)
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
                StudioProgressBar(value: Double(orchestrator.activeUnlimitedBooks) / max(1, Double(orchestrator.parallelUnlimitedBooks)))
            } else {
                StudioProgressBar(value: orchestrator.progress)
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
                        .foregroundStyle(StudioTheme.textMuted)
                }
            }
            .font(.caption)
            .foregroundStyle(StudioTheme.textMuted)

            Divider()

            // Phasen-Checkliste
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(PipelinePhase.executionOrder.enumerated()), id: \.element) { index, phase in
                    HStack(spacing: 10) {
                        if index < currentPhaseIndex {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(StudioTheme.lime)
                        } else if index == currentPhaseIndex {
                            Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                                .foregroundStyle(StudioTheme.cyan)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(StudioTheme.textFaint)
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
                        .foregroundStyle(StudioTheme.danger)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(StudioTheme.danger)
                }
                .padding(10)
                .background(StudioTheme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(StudioTheme.danger.opacity(0.25), lineWidth: 1))
            }

            HStack {
                Button {
                    orchestrator.pausePipeline()
                } label: {
                    Label("Pausieren", systemImage: "pause.fill")
                }
                .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.amber))

                Button(role: .destructive) {
                    confirmCancel = true
                } label: {
                    Label("Abbrechen", systemImage: "stop.fill")
                }
                .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.danger))

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
