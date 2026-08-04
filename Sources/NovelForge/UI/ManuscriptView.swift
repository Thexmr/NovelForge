import SwiftUI
import SwiftData

@MainActor
struct ManuscriptView: View {
    private var _projects = Query<Project, [Project]>(sort: \Project.updatedAt, order: .reverse)
    var projects: [Project] { _projects.wrappedValue }
    @ObservedObject private var appState = AppState.shared
    @State private var selectedChapter: Chapter?
    @State private var viewMode: ViewMode = .read
    @State private var readingWholeBook = false

    enum ViewMode: String, CaseIterable {
        case read = "Lesen"
        case edit = "Bearbeiten"
        case compare = "Vergleichen"
        case scenes = "Szenenplan"
    }

    private var sortedChapters: [Chapter] {
        // modelContext == nil ⇒ Objekt wurde gelöscht (z.B. resetChapterPlan während
        // einer laufenden Produktion). Zugriff darauf würde den Prozess beenden.
        guard let project = appState.selectedProject, project.modelContext != nil else { return [] }
        return (project.chapters ?? []).sorted { $0.chapterNumber < $1.chapterNumber }
    }

    /// Liefert das gewählte Kapitel nur, solange es noch im Datenspeicher existiert.
    /// Verhindert „use-of-deleted-object"-Crashes, wenn die Pipeline Kapitel neu plant.
    private var liveSelectedChapter: Chapter? {
        guard let chapter = selectedChapter, chapter.modelContext != nil else { return nil }
        return chapter
    }

    private var liveSelectedProject: Project? {
        guard let project = appState.selectedProject, project.modelContext != nil else { return nil }
        return project
    }

    var body: some View {
        HSplitView {
            // Projekte
            List(selection: $appState.selectedProject) {
                ForEach(projects) { project in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.title)
                            .font(.callout)
                            .lineLimit(1)
                        Text("\(project.chapters?.count ?? 0) Kapitel")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .tag(project)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(minWidth: 190, idealWidth: 220, maxWidth: 280)

            // Kapitel
            Group {
                if liveSelectedProject != nil {
                    if sortedChapters.isEmpty {
                        ContentUnavailableView("Noch keine Kapitel", systemImage: "doc.text",
                                               description: Text("Kapitel entstehen während der Produktion."))
                    } else {
                        VStack(spacing: 0) {
                        Button {
                            readingWholeBook = true
                            selectedChapter = nil
                        } label: {
                            Label("Gesamtes Buch lesen", systemImage: "book")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.cyan))
                        .padding(10)

                        Divider()

                        List(selection: $selectedChapter) {
                            ForEach(sortedChapters) { chapter in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(chapter.chapterNumber). \(chapter.displayTitle)")
                                            .lineLimit(1)
                                        Text(chapterStatusText(chapter))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(FormattingHelpers.formatWordCount(chapter.displayWordCount))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .tag(chapter)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        }
                    }
                } else {
                    ContentUnavailableView("Projekt wählen", systemImage: "books.vertical")
                }
            }
            .frame(minWidth: 220, idealWidth: 260, maxWidth: 340)

            // Inhalt
            Group {
                if readingWholeBook, let project = liveSelectedProject {
                    BookReaderView(project: project)
                } else if let chapter = liveSelectedChapter {
                    ChapterDetailView(chapter: chapter, viewMode: $viewMode)
                        .id(chapter.id) // erzwingt frischen Editor-Zustand beim Kapitelwechsel
                } else {
                    ContentUnavailableView("Kapitel wählen", systemImage: "doc.text")
                }
            }
            .frame(minWidth: 400, maxWidth: .infinity)
        }
        .background(StudioBackground())
        .navigationTitle("Manuskript")
        .onAppear { autoSelect() }
        .onChange(of: projects.count) { autoSelect() }
        .onChange(of: appState.selectedProject) {
            // Beim Projektwechsel direkt das erste Kapitel zeigen, statt einen
            // leeren „Kapitel wählen"-Platzhalter.
            readingWholeBook = false
            selectedChapter = sortedChapters.first
        }
        .onChange(of: selectedChapter) {
            if selectedChapter != nil {
                readingWholeBook = false
            }
        }
    }

    /// Wählt beim Öffnen automatisch ein Projekt und dessen erstes Kapitel, damit
    /// die Manuskript-Ansicht sofort Inhalt zeigt (nicht erst nach einem Klick).
    private func autoSelect() {
        if liveSelectedProject == nil {
            appState.selectedProject = projects.first
        }
        if liveSelectedChapter == nil, !readingWholeBook {
            selectedChapter = sortedChapters.first
        }
    }

    private func chapterStatusText(_ chapter: Chapter) -> String {
        switch chapter.status {
        case .planned: return "Geplant"
        case .scenesPlanned: return "Szenen geplant"
        case .drafting: return "Wird geschrieben"
        case .draftComplete: return "Rohfassung"
        case .revising: return "Wird überarbeitet"
        case .revised: return "Überarbeitet"
        case .proofreading: return "Im Korrektorat"
        case .finalized: return "Final"
        }
    }
}

/// Liest große Bücher kapitelweise, damit 500-Seiten-Manuskripte nicht komplett
/// auf einmal gelayoutet werden.
@MainActor
struct BookReaderView: View {
    let project: Project
    @State private var selectedIndex = 0

    private var chapters: [Chapter] {
        (project.chapters ?? []).sorted { $0.chapterNumber < $1.chapterNumber }
    }

    private var readingTimeText: String {
        let minutes = max(1, project.totalWordCount / 220)
        if minutes >= 60 {
            return "\(minutes / 60) h \(minutes % 60) min"
        }
        return "\(minutes) min"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(1)
                    Text("\(project.authorName) · \(FormattingHelpers.formatWordCount(project.totalWordCount)) Wörter · \(chapters.count) Kapitel · Lesezeit ca. \(readingTimeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !chapters.isEmpty {
                    Text("Kapitel \(selectedIndex + 1) / \(chapters.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()

                    Button {
                        withAnimation(Motion.standard) {
                            selectedIndex = max(0, selectedIndex - 1)
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(selectedIndex == 0)
                    .help("Vorheriges Kapitel")
                    .accessibilityLabel("Vorheriges Kapitel")

                    Button {
                        withAnimation(Motion.standard) {
                            selectedIndex = min(chapters.count - 1, selectedIndex + 1)
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(selectedIndex >= chapters.count - 1)
                    .help("Nächstes Kapitel")
                    .accessibilityLabel("Nächstes Kapitel")
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)

            Divider()

            if chapters.isEmpty {
                ContentUnavailableView("Noch keine Kapitel", systemImage: "doc.text")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let chapter = chapters[min(selectedIndex, chapters.count - 1)]
                ScrollView {
                    ChapterReaderSection(chapter: chapter)
                        .padding(32)
                        .frame(maxWidth: 720, alignment: .leading)
                        .frame(maxWidth: .infinity)
                }
                .id(chapter.id)
            }
        }
    }
}

@MainActor
struct ChapterReaderSection: View {
    let chapter: Chapter

    private var paragraphs: [String] {
        (chapter.rawBestText ?? "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(chapter.displayTitle)
                .font(.system(.title, design: .serif))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 12)

            if paragraphs.isEmpty {
                Text("Für dieses Kapitel liegt noch kein Text vor.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    if paragraph.replacingOccurrences(of: " ", with: "") == "***" {
                        Text("* * *")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    } else {
                        Text(paragraph)
                            .font(.system(.body, design: .serif))
                            .lineSpacing(7)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }
}

@MainActor
struct ChapterDetailView: View {
    let chapter: Chapter
    @Binding var viewMode: ManuscriptView.ViewMode
    @State private var editedText: String = ""
    @State private var hasUnsavedChanges = false
    @State private var editingChapter: Chapter?

    var body: some View {
        VStack(spacing: 0) {
            // Der segmentierte Picker hat eine feste Mindestbreite (vier deutsche
            // Segmenttitel) und lässt sich nicht weiter komprimieren. Reicht die
            // Detail-Spalte nicht für Picker + Wortzahl (z. B. bei minimalem
            // Fenster), blendet ViewThatFits die Wortzahl aus, statt sie
            // abzuschneiden – sie steht ohnehin in der Kapitelliste daneben.
            ViewThatFits(in: .horizontal) {
                HStack {
                    viewModePicker
                    Spacer()
                    wordCountLabel
                }
                HStack {
                    viewModePicker
                    Spacer()
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)

            Divider()

            switch viewMode {
            case .read:
                readView
            case .edit:
                editView
            case .compare:
                compareView
            case .scenes:
                scenesView
            }
        }
        .onAppear { loadEditor(for: chapter) }
        .onChange(of: chapter.chapterNumber) { _, _ in loadEditor(for: chapter) }
        .onDisappear { saveEdits() }
    }

    private var viewModePicker: some View {
        Picker("Ansicht", selection: $viewMode) {
            ForEach(ManuscriptView.ViewMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 420)
    }

    private var wordCountLabel: some View {
        Text("\(FormattingHelpers.formatWordCount(chapter.displayWordCount)) Wörter")
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .fixedSize(horizontal: true, vertical: false)
    }

    /// Lädt den Editor-Text für ein Kapitel und sichert vorher ungespeicherte
    /// Änderungen am zuvor bearbeiteten Kapitel – verhindert stillen Datenverlust
    /// beim Kapitelwechsel.
    private func loadEditor(for newChapter: Chapter) {
        saveEdits()
        editingChapter = newChapter
        editedText = newChapter.rawBestText ?? ""
        hasUnsavedChanges = false
    }

    /// Schreibt ungespeicherte Editor-Änderungen ins zugehörige Kapitel zurück.
    private func saveEdits() {
        guard hasUnsavedChanges, let target = editingChapter, target.modelContext != nil else { return }
        target.finalText = editedText
        target.actualWordCount = editedText.wordCount
        target.updatedAt = Date()
        hasUnsavedChanges = false
    }

    private var readView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(chapter.displayTitle)
                    .font(.system(.largeTitle, design: .serif))
                    .fontWeight(.semibold)

                if let text = chapter.rawBestText {
                    Text(text)
                        .font(.system(.body, design: .serif))
                        .lineSpacing(7)
                        .textSelection(.enabled)
                } else {
                    Text("Für dieses Kapitel liegt noch kein Text vor.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(32)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var editView: some View {
        VStack(spacing: 0) {
            TextEditor(text: $editedText)
                .font(.system(.body, design: .serif))
                .lineSpacing(6)
                .padding(8)
                .onChange(of: editedText) {
                    hasUnsavedChanges = editedText != (chapter.rawBestText ?? "")
                }

            Divider()

            HStack {
                if hasUnsavedChanges {
                    Label("Ungespeicherte Änderungen", systemImage: "circle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Button("Speichern") {
                    guard chapter.modelContext != nil else { hasUnsavedChanges = false; return }
                    chapter.finalText = editedText
                    chapter.actualWordCount = editedText.wordCount
                    chapter.updatedAt = Date()
                    hasUnsavedChanges = false
                }
                .buttonStyle(StudioPrimaryButtonStyle())
                .frame(width: 130)
                .disabled(!hasUnsavedChanges)
            }
            .padding(12)
        }
    }

    private var scenesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                let scenes = (chapter.scenes ?? []).sorted { $0.sceneNumber < $1.sceneNumber }
                if scenes.isEmpty {
                    ContentUnavailableView("Keine Szenen geplant", systemImage: "rectangle.split.3x1",
                                           description: Text("Der Szenenplan entsteht in der Phase „Szenenplanung“."))
                } else {
                    ForEach(scenes) { scene in
                        SceneCard(scene: scene)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private var compareView: some View {
        HStack(spacing: 0) {
            comparePane(title: "Rohfassung", text: chapter.draftText)
            Divider()
            comparePane(title: "Finale Fassung", text: chapter.finalText ?? chapter.revisedText)
        }
    }

    private func comparePane(title: String, text: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(12)
            Divider()
            ScrollView {
                Text(text ?? "Noch nicht vorhanden.")
                    .font(.system(.callout, design: .serif))
                    .lineSpacing(5)
                    .textSelection(.enabled)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Karte mit allen Planungsdaten einer Szene (Ziel, Hindernis, Wendung, Status, Umfang).
@MainActor
struct SceneCard: View {
    let scene: StoryScene

    private var statusText: String {
        switch scene.status {
        case .planned: return "Geplant"
        case .writing: return "Wird geschrieben"
        case .written: return "Geschrieben"
        case .checking: return "In Prüfung"
        case .needsRevision: return "Braucht Revision"
        case .finalized: return "Final"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Szene \(scene.sceneNumber)")
                    .font(.headline)
                Spacer()
                Text(statusText)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.12), in: Capsule())
                    .foregroundStyle(.tint)
                Text("\(FormattingHelpers.formatWordCount(scene.text?.wordCount ?? 0)) / \(FormattingHelpers.formatWordCount(scene.targetWordCount)) Wörter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      alignment: .leading, spacing: 6) {
                field("Perspektive", scene.perspective)
                field("Ort", scene.location)
                field("Zeit", scene.time)
                field("Ziel", scene.goal)
                field("Hindernis", scene.obstacle)
                field("Wendung", scene.cliffhanger)
            }

            if let summary = scene.summary, !summary.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Zusammenfassung")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.violet, opacity: 0.82)
    }

    @ViewBuilder
    private func field(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Story Bible

@MainActor
struct StoryBibleView: View {
    private var _projects = Query<Project, [Project]>(sort: \Project.updatedAt, order: .reverse)
    var projects: [Project] { _projects.wrappedValue }
    @ObservedObject private var appState = AppState.shared
    @State private var selectedTab: BibleTab = .characters

    enum BibleTab: String, CaseIterable {
        case characters = "Figuren"
        case locations = "Orte"
        case plot = "Plot"
        case style = "Stilregeln"
    }

    var body: some View {
        HSplitView {
            List(selection: $appState.selectedProject) {
                ForEach(projects) { project in
                    Text(project.title)
                        .lineLimit(1)
                        .tag(project)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .frame(minWidth: 190, idealWidth: 220, maxWidth: 280)

            Group {
                if let project = appState.selectedProject, let bible = project.storyBible {
                    VStack(spacing: 0) {
                        Picker("Bereich", selection: $selectedTab) {
                            ForEach(BibleTab.allCases, id: \.self) { tab in
                                Text(tab.rawValue).tag(tab)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .padding(12)

                        Divider()

                        switch selectedTab {
                        case .characters:
                            CharactersTabView(bible: bible)
                        case .locations:
                            LocationsTabView(bible: bible)
                        case .plot:
                            bibleTextView(text: bible.plotPoints,
                                          emptyHint: "Der Plot wird in der Phase „Strukturplanung“ erstellt.")
                        case .style:
                            bibleTextView(text: bible.styleRules,
                                          emptyHint: "Die Stilregeln werden zu Produktionsbeginn festgelegt.")
                        }
                    }
                } else {
                    ContentUnavailableView("Projekt wählen", systemImage: "book.closed")
                }
            }
            .frame(minWidth: 420, maxWidth: .infinity)
        }
        .background(StudioBackground())
        .navigationTitle("Story Bible")
    }

    private func bibleTextView(text: String, emptyHint: String) -> some View {
        Group {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView("Noch keine Inhalte", systemImage: "doc.plaintext",
                                       description: Text(emptyHint))
            } else {
                ScrollView {
                    Text(text)
                        .textSelection(.enabled)
                        .lineSpacing(5)
                        .padding(20)
                        .frame(maxWidth: 760, alignment: .leading)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

@MainActor
struct CharactersTabView: View {
    let bible: StoryBible

    private var characters: [CharacterProfile] {
        (bible.characters ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        if characters.isEmpty {
            ContentUnavailableView("Noch keine Figuren", systemImage: "person.2",
                                   description: Text("Figuren werden in der Phase „Strukturplanung“ entwickelt."))
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(characters) { character in
                        CharacterCard(character: character)
                    }
                }
                .padding(16)
            }
        }
    }
}

@MainActor
struct CharacterCard: View {
    let character: CharacterProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(character.name)
                    .font(.headline)
                Spacer()
                Text(character.role)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.tint.opacity(0.12), in: Capsule())
                    .foregroundStyle(.tint)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                      alignment: .leading, spacing: 6) {
                field("Alter", character.age)
                field("Beruf", character.occupation)
                field("Ziel", character.goal)
                field("Angst", character.fear)
                field("Schwäche", character.weakness)
                field("Entwicklung", character.development)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .studioGlassTile(cornerRadius: 8, accent: StudioTheme.amber, opacity: 0.82)
    }

    @ViewBuilder
    private func field(_ label: String, _ value: String) -> some View {
        if !value.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.caption)
            }
        }
    }
}

@MainActor
struct LocationsTabView: View {
    let bible: StoryBible

    private var locations: [LocationProfile] {
        bible.locations ?? []
    }

    var body: some View {
        if locations.isEmpty {
            ContentUnavailableView("Noch keine Orte", systemImage: "mappin.and.ellipse",
                                   description: Text("Schauplätze werden während der Produktion erfasst."))
        } else {
            List(locations) { location in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(location.name)
                            .font(.headline)
                        Spacer()
                        Text(location.type)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !location.locationDescription.isEmpty {
                        Text(location.locationDescription)
                            .font(.caption)
                    }
                    if !location.atmosphere.isEmpty {
                        Text("Atmosphäre: \(location.atmosphere)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !location.relevantChapters.isEmpty {
                        Text("Kapitel: \(location.relevantChapters)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}
