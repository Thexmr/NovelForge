import SwiftUI
import SwiftData

struct ManuscriptView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) var projects: [Project]
    @State private var selectedProject: Project?
    @State private var selectedChapter: Chapter?
    @State private var viewMode: ViewMode = .read
    
    enum ViewMode: String, CaseIterable {
        case read = "Lesen"
        case edit = "Bearbeiten"
        case compare = "Vergleichen"
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedProject) {
                ForEach(projects) { project in
                    NavigationLink(value: project) {
                        Text(project.title)
                    }
                    .tag(project)
                }
            }
            .navigationTitle("Projekte")
            .frame(minWidth: 200)
        } content: {
            if let project = selectedProject {
                List(selection: $selectedChapter) {
                    if let chapters = project.chapters?.sorted(by: { $0.chapterNumber < $1.chapterNumber }) {
                        ForEach(chapters) { chapter in
                            NavigationLink(value: chapter) {
                                HStack {
                                    Text("\(chapter.chapterNumber). \(chapter.title)")
                                    Spacer()
                                    Text("\(chapter.computedWordCount) Wörter")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(chapter)
                        }
                    }
                }
                .navigationTitle("Kapitel")
            } else {
                ContentUnavailableView("Projekt wählen", systemImage: "doc.text")
            }
        } detail: {
            if let chapter = selectedChapter {
                ChapterDetailView(chapter: chapter, viewMode: $viewMode)
            } else {
                ContentUnavailableView("Kapitel wählen", systemImage: "doc.text.fill")
            }
        }
    }
}

struct ChapterDetailView: View {
    let chapter: Chapter
    @Binding var viewMode: ManuscriptView.ViewMode
    @State private var editedText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Picker("Ansicht", selection: $viewMode) {
                    ForEach(ManuscriptView.ViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
                
                Spacer()
                
                Text("\(chapter.computedWordCount) Wörter")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(chapter.title)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    switch viewMode {
                    case .read:
                        Text(chapter.finalText ?? chapter.revisedText ?? chapter.draftText ?? "Kein Text verfügbar")
                            .font(.body)
                            .lineSpacing(6)
                    
                    case .edit:
                        VStack {
                            TextEditor(text: $editedText)
                                .font(.body)
                                .lineSpacing(6)
                                .frame(minHeight: 400)
                                .onAppear {
                                    editedText = chapter.finalText ?? chapter.revisedText ?? chapter.draftText ?? ""
                                }
                            
                            HStack {
                                Spacer()
                                Button("Speichern") {
                                    chapter.finalText = editedText
                                    chapter.updatedAt = Date()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        }
                    
                    case .compare:
                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("Rohfassung")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                ScrollView {
                                    Text(chapter.draftText ?? "-")
                                        .font(.body)
                                }
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading) {
                                Text("Finale Fassung")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                ScrollView {
                                    Text(chapter.finalText ?? "-")
                                        .font(.body)
                                }
                            }
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct StoryBibleView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) var projects: [Project]
    @State private var selectedProject: Project?
    @State private var selectedTab: BibleTab = .characters
    
    enum BibleTab: String, CaseIterable {
        case characters = "Figuren"
        case locations = "Orte"
        case timeline = "Zeitlinie"
        case plotPoints = "Plotpunkte"
        case openQuestions = "Offene Fragen"
        case terms = "Begriffe"
        case styleRules = "Stilregeln"
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedProject) {
                ForEach(projects) { project in
                    NavigationLink(value: project) {
                        Text(project.title)
                    }
                    .tag(project)
                }
            }
            .navigationTitle("Projekte")
            .frame(minWidth: 200)
        } detail: {
            if let project = selectedProject, let bible = project.storyBible {
                TabView(selection: $selectedTab) {
                    CharactersTabView(bible: bible)
                        .tabItem { Label("Figuren", systemImage: "person.2") }
                        .tag(BibleTab.characters)
                    
                    LocationsTabView(bible: bible)
                        .tabItem { Label("Orte", systemImage: "mappin") }
                        .tag(BibleTab.locations)
                    
                    TimelineTabView(bible: bible)
                        .tabItem { Label("Zeitlinie", systemImage: "calendar") }
                        .tag(BibleTab.timeline)
                    
                    Text(bible.plotPoints)
                        .tabItem { Label("Plotpunkte", systemImage: "list.bullet") }
                        .tag(BibleTab.plotPoints)
                    
                    Text(bible.openQuestions)
                        .tabItem { Label("Fragen", systemImage: "questionmark.circle") }
                        .tag(BibleTab.openQuestions)
                    
                    Text(bible.terms)
                        .tabItem { Label("Begriffe", systemImage: "textformat") }
                        .tag(BibleTab.terms)
                    
                    Text(bible.styleRules)
                        .tabItem { Label("Stil", systemImage: "paintbrush") }
                        .tag(BibleTab.styleRules)
                }
                .navigationTitle("Story Bible")
            } else {
                ContentUnavailableView("Projekt wählen", systemImage: "book.closed")
            }
        }
    }
}

struct CharactersTabView: View {
    let bible: StoryBible
    
    var body: some View {
        List {
            if let characters = bible.characters {
                ForEach(characters) { character in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(character.name)
                                .font(.headline)
                            Spacer()
                            Text(character.role)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if !character.age.isEmpty {
                            Text("Alter: \(character.age)")
                                .font(.caption)
                        }
                        if !character.occupation.isEmpty {
                            Text("Beruf: \(character.occupation)")
                                .font(.caption)
                        }
                        if !character.goal.isEmpty {
                            Text("Ziel: \(character.goal)")
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct LocationsTabView: View {
    let bible: StoryBible
    
    var body: some View {
        List {
            if let locations = bible.locations {
                ForEach(locations) { location in
                    VStack(alignment: .leading, spacing: 8) {
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
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

struct TimelineTabView: View {
    let bible: StoryBible
    
    var body: some View {
        ScrollView {
            Text(bible.timeline)
                .padding()
        }
    }
}