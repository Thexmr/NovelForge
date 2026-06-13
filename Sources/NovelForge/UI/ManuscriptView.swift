import SwiftUI
import SwiftData

struct ManuscriptView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) var projects: [Project]
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
                        .buttonStyle(.bordered)
                        .padding(10)

                        Divider()

                        List(selection: $selectedChapter) {
                            ForEach(sortedChapters) { chapter in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(chapter.chapterNumber). \(chapter.title)")
                                            .lineLimit(1)
                                        Text(chapterStatusText(chapter))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(FormattingHelpers.formatWordCount(chapter.computedWordCount))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .tag(chapter)
                            }
                        }
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
        .navigationTitle("Manuskript")
        .onChange(of: appState.selectedProject) {
            selectedChapter = nil
            readingWholeBook = false
        }
        .onChange(of: selectedChapter) {
            if selectedChapter != nil {
                readingWholeBook = false
            }
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

/// Liest das gesamte Buch als durchgehenden Lesefluss (Serifen-Typografie,
/// zentrierte Szenentrenner, Lesezeit-Anzeige).
struct BookReaderView: View {
    let project: Project

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
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(project.title)
                        .font(.system(.largeTitle, design: .serif))
                        .fontWeight(.bold)
                    Text("\(project.authorName) · \(FormattingHelpers.formatWordCount(project.totalWordCount)) Wörter · Lesezeit ca. \(readingTimeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 16)

                ForEach(chapters) { chapter in
                    ChapterReaderSection(chapter: chapter)
                }
            }
            .padding(32)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

struct ChapterReaderSection: View {
    let chapter: Chapter

    private var paragraphs: [String] {
        (chapter.bestText ?? "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(chapter.title)
                .font(.system(.title, design: .serif))
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 32)

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

struct ChapterDetailView: View {
    let chapter: Chapter
    @Binding var viewMode: ManuscriptView.ViewMode
    @State private var editedText: String = ""
    @State private var hasUnsavedChanges = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("Ansicht", selection: $viewMode) {
                    ForEach(ManuscriptView.ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 380)

                Spacer()

                Text("\(FormattingHelpers.formatWordCount(chapter.computedWordCount)) Wörter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(.bar)

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
        .onAppear {
            editedText = chapter.bestText ?? ""
        }
    }

    private var readView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(chapter.title)
                    .font(.system(.largeTitle, design: .serif))
                    .fontWeight(.semibold)

                if let text = chapter.bestText {
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
                    hasUnsavedChanges = editedText != (chapter.bestText ?? "")
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
                    chapter.finalText = editedText
                    chapter.actualWordCount = editedText.wordCount
                    chapter.updatedAt = Date()
                    hasUnsavedChanges = false
                }
                .buttonStyle(.borderedProminent)
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
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
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

struct StoryBibleView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) var projects: [Project]
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
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
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
        }
    }
}
