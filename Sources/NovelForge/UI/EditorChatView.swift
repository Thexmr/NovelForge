import SwiftUI
import SwiftData

/// Lektor-Chat: Nach Fertigstellung kann der Autor Wünsche/Korrekturen schreiben.
/// Ist ein Kapitel gewählt, überarbeitet der Agent es direkt; sonst beantwortet er.
@MainActor
struct EditorChatView: View {
    @Environment(\.modelContext) private var modelContext
    private var _projects = Query<Project, [Project]>(sort: \Project.updatedAt, order: .reverse)
    private var projects: [Project] { _projects.wrappedValue }
    private var _allMessages = Query<ChatMessage, [ChatMessage]>(sort: \ChatMessage.createdAt)
    private var allMessages: [ChatMessage] { _allMessages.wrappedValue }
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var orchestrator = PipelineOrchestrator.shared

    @State private var selectedChapterID: PersistentIdentifier?
    @State private var input = ""
    @State private var isProcessing = false
    @State private var isRepairing = false

    private var project: Project? {
        // modelContext == nil ⇒ gelöscht: dann nicht weiter darauf zugreifen.
        if let p = appState.selectedProject, p.modelContext != nil { return p }
        return projects.first
    }

    private var chapters: [Chapter] {
        (project?.chapters ?? []).sorted { $0.chapterNumber < $1.chapterNumber }
    }

    private var selectedChapter: Chapter? {
        guard let id = selectedChapterID else { return nil }
        return chapters.first { $0.persistentModelID == id }
    }

    private var messages: [ChatMessage] {
        guard let pid = project?.id else { return [] }
        return allMessages.filter { $0.projectID == pid }
    }

    var body: some View {
        ZStack {
            StudioBackground()
            VStack(spacing: 0) {
                header
                Divider().overlay(StudioTheme.hairline)
                if project == nil {
                    ContentUnavailableView("Noch kein Buch", systemImage: "text.bubble",
                                           description: Text("Erstelle erst ein Buch, dann kannst du es hier mit dem Lektor besprechen."))
                        .frame(maxHeight: .infinity)
                } else {
                    messageList
                    inputBar
                }
            }
        }
        .navigationTitle("Lektor")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Lektorat")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(StudioTheme.heroGradient)
                    Text("Fragen klären oder gezielte Kapiteländerungen beauftragen.")
                        .font(.caption)
                        .foregroundStyle(StudioTheme.textMuted)
                }
                Spacer()
                if isProcessing || isRepairing {
                    HStack(spacing: 5) {
                        StudioLiveIndicator(color: StudioTheme.cyan, isActive: true)
                        Text(isRepairing ? "Buchprüfung läuft" : "Lektor arbeitet")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(StudioTheme.cyan)
                }
            }

            ViewThatFits(in: .horizontal) {
                headerControls
                VStack(alignment: .leading, spacing: 8) {
                    projectPicker
                    chapterPicker
                    repairButton
                }
            }

            Text(selectedChapter == nil
                 ? "Stelle eine Frage oder besprich Änderungen. Für eine konkrete Überarbeitung wähle rechts ein Kapitel."
                 : "Schreib deinen Wunsch – der Lektor überarbeitet Kapitel \(selectedChapter!.chapterNumber) direkt.")
                .font(.caption)
                .foregroundStyle(StudioTheme.textMuted)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headerControls: some View {
        HStack(spacing: 12) {
            projectPicker
            chapterPicker
            repairButton
        }
    }

    private var projectPicker: some View {
        Picker("Buch", selection: Binding(
            get: { project },
            set: { appState.selectedProject = $0; selectedChapterID = nil })) {
            ForEach(projects) { p in Text(p.title).tag(p as Project?) }
        }
        .frame(maxWidth: 240)
    }

    private var chapterPicker: some View {
        Picker("Bezug", selection: $selectedChapterID) {
            Text("Allgemeine Frage").tag(PersistentIdentifier?.none)
            ForEach(chapters) { chapter in
                Text("Kapitel \(chapter.chapterNumber) überarbeiten")
                    .tag(Optional(chapter.persistentModelID))
            }
        }
        .frame(maxWidth: 260)
    }

    private var repairButton: some View {
        Button {
            repairBook()
        } label: {
            Label(isRepairing ? "Prüfung läuft" : "Buch prüfen & reparieren",
                  systemImage: "wrench.and.screwdriver")
        }
        .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.lime))
        .disabled(project == nil || isProcessing || isRepairing || orchestrator.isRunning)
        .help(orchestrator.isRunning
              ? "Während einer laufenden Produktion nicht verfügbar"
              : "Prüft das gesamte Buch und repariert nur kapitelgenaue Inkonsistenzen")
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Neue Besprechung")
                                .font(.headline)
                            Text("Wähle eine häufige Prüfung oder formuliere unten einen eigenen Auftrag.")
                                .font(.caption)
                                .foregroundStyle(StudioTheme.textMuted)
                            HStack(spacing: 8) {
                                suggestionButton("Figurenlogik prüfen")
                                suggestionButton("Spannungsbogen bewerten")
                                suggestionButton("Offene Handlungsfäden finden")
                            }
                        }
                        .padding(16)
                        .studioPanel(cornerRadius: 8, accent: StudioTheme.violet)
                        .padding(.top, 12)
                    }
                    ForEach(messages) { msg in
                        bubble(msg).id(msg.id)
                    }
                    if isProcessing || isRepairing {
                        HStack(spacing: 8) {
                            StudioLiveIndicator(color: StudioTheme.cyan, isActive: true)
                            Text(isRepairing ? "Lektor prüft und repariert …" : "Lektor denkt nach …")
                                .font(.caption)
                                .foregroundStyle(StudioTheme.textMuted)
                        }
                        .padding(.leading, 4)
                    }
                }
                .padding(18)
            }
            .onChange(of: messages.count) {
                if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private func suggestionButton(_ text: String) -> some View {
        Button(text) { input = text }
            .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.violet))
    }

    private func bubble(_ msg: ChatMessage) -> some View {
        HStack {
            if msg.role == .user { Spacer(minLength: 60) }
            Text(msg.text)
                .font(.callout)
                .foregroundStyle(msg.role == .user ? Color.black.opacity(0.86) : Color.white)
                .textSelection(.enabled)
                .padding(.vertical, 10).padding(.horizontal, 14)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(msg.role == .user
                              ? AnyShapeStyle(StudioTheme.brandGradient)
                              : AnyShapeStyle(StudioTheme.surfaceElevated))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(StudioTheme.hairline))
                }
            if msg.role == .assistant { Spacer(minLength: 60) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(selectedChapter == nil ? "Frage oder Wunsch …" : "Wunsch für Kapitel \(selectedChapter!.chapterNumber) …",
                      text: $input, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.plain)
                .padding(10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(StudioTheme.hairline))
                .onSubmit(send)

            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.86))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(StudioTheme.brandGradient))
            }
            .buttonStyle(.plain)
            .disabled(isProcessing || isRepairing || orchestrator.isRunning
                      || input.trimmingCharacters(in: .whitespaces).isEmpty)
            .help("Senden")
            .accessibilityLabel("Nachricht senden")
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) { StudioTheme.hairline.frame(height: 1) }
    }

    private func send() {
        guard let project,
              !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !isProcessing, !isRepairing, !orchestrator.isRunning else { return }
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        input = ""
        modelContext.insert(ChatMessage(projectID: project.id, role: .user, text: text))
        modelContext.saveOrLog()
        isProcessing = true
        let chapter = selectedChapter
        Task { @MainActor in
            let reply = await PipelineOrchestrator.shared.processEditorMessage(text, project: project, chapter: chapter)
            // Projekt könnte während des Aufrufs gelöscht worden sein → nicht darauf zugreifen.
            if project.modelContext != nil {
                modelContext.insert(ChatMessage(projectID: project.id, role: .assistant, text: reply))
                modelContext.saveOrLog()
            }
            isProcessing = false
        }
    }

    private func repairBook() {
        guard let project, !isRepairing, !isProcessing else { return }
        isRepairing = true
        modelContext.insert(ChatMessage(projectID: project.id,
                                        role: .user,
                                        text: "Buch prüfen & reparieren"))
        modelContext.saveOrLog()

        Task { @MainActor in
            let reply = await orchestrator.repairBookAfterProofreading(project: project)
            if project.modelContext != nil {
                modelContext.insert(ChatMessage(projectID: project.id, role: .assistant, text: reply))
                modelContext.saveOrLog()
            }
            isRepairing = false
        }
    }
}
