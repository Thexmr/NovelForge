import SwiftUI
import SwiftData

struct KDPSalesSheetView: View {
    let project: Project

    @ObservedObject private var orchestrator = PipelineOrchestrator.shared
    @Environment(\.modelContext) private var modelContext
    @State private var isGenerating = false
    @State private var statusNote: String?

    private var sheet: KDPSalesSheet {
        KDPSalesSheet.make(for: project)
    }

    private var canGenerate: Bool {
        project.modelContext != nil && project.bookProfile != nil
            && !isGenerating && !orchestrator.isRunning
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label("KDP-Verkaufsseite", systemImage: "cart.badge.plus")
                    .font(.headline)
                    .foregroundStyle(StudioTheme.heroGradient)
                Spacer()
                StudioStatusPill(text: sheet.hasGeneratedMetadata ? "bereit" : "wartet",
                                 systemImage: sheet.hasGeneratedMetadata ? "checkmark.seal" : "clock",
                                 color: sheet.hasGeneratedMetadata ? StudioTheme.lime : StudioTheme.amber)
                Button {
                    generate()
                } label: {
                    if isGenerating {
                        ProgressView().controlSize(.small)
                    } else {
                        Label(sheet.hasGeneratedMetadata ? "Neu generieren" : "Generieren",
                              systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(!canGenerate)
                .help("Viralen Verkaufstitel, Untertitel, Verkaufstext, Keywords und Kategorien per KI erzeugen.")
            }

            if let statusNote {
                Text(statusNote)
                    .font(.caption2)
                    .foregroundStyle(StudioTheme.textMuted)
            }

            VStack(alignment: .leading, spacing: 10) {
                salesField("Verkaufstitel", sheet.title, accent: StudioTheme.cyan)
                if !sheet.hook.isEmpty {
                    salesField("Untertitel / Hook", sheet.hook, accent: StudioTheme.violet)
                }
                if !sheet.salesDescription.isEmpty {
                    salesField("Verkaufstext", sheet.salesDescription, accent: StudioTheme.magenta)
                }
                if !sheet.keywords.isEmpty {
                    salesField("Keywords", sheet.keywords, accent: StudioTheme.lime)
                }
                if !sheet.categories.isEmpty {
                    salesField("Kategorien", sheet.categories, accent: StudioTheme.amber)
                }
                if !sheet.authorProfile.isEmpty {
                    salesField("Autorprofil", sheet.authorProfile, accent: StudioTheme.cyan)
                }
                if !sheet.hasGeneratedMetadata {
                    Label("Verkaufstext, Keywords und Kategorien entstehen automatisch in der KDP-Formatierung.",
                          systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(StudioTheme.textMuted)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .studioGlassTile(cornerRadius: 8, accent: StudioTheme.cyan, opacity: 0.9)
        }
    }

    private func generate() {
        guard canGenerate else { return }
        isGenerating = true
        statusNote = nil
        Task { @MainActor in
            let result = await orchestrator.generateKDPSalesSheet(project: project)
            try? modelContext.save()
            statusNote = result
            isGenerating = false
        }
    }

    private func salesField(_ label: String, _ value: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accent)
                .frame(width: 3)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(StudioTheme.textFaint)
                Text(value)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(value, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("\(label) kopieren")
        }
    }
}

/// Eigenständiger Sidebar-Bereich „KDP-Verkauf": Buch wählen und die Amazon-KDP-
/// Verkaufstexte (viraler Titel, Untertitel, Verkaufstext, Keywords, Kategorien)
/// ansehen, kopieren oder neu generieren.
struct KDPMarketingView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) private var projects: [Project]
    @ObservedObject private var appState = AppState.shared

    private var eligibleProjects: [Project] {
        projects.filter { $0.bookProfile != nil }
    }

    var body: some View {
        HSplitView {
            Group {
                if eligibleProjects.isEmpty {
                    ContentUnavailableView("Noch keine Bücher", systemImage: "cart",
                        description: Text("Sobald ein Buch ein Konzept hat, entstehen hier die KDP-Verkaufstexte."))
                } else {
                    List(selection: $appState.selectedProject) {
                        ForEach(eligibleProjects) { project in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(project.title).lineLimit(1)
                                StatusBadge(status: project.status)
                            }
                            .tag(project)
                        }
                    }
                }
            }
            .frame(minWidth: 200, idealWidth: 240, maxWidth: 300)

            Group {
                if let project = appState.selectedProject, project.modelContext != nil {
                    ScrollView {
                        KDPSalesSheetView(project: project)
                            .padding(24)
                            .frame(maxWidth: 760, alignment: .leading)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ContentUnavailableView("Buch wählen", systemImage: "cart.badge.plus")
                }
            }
            .frame(minWidth: 440, maxWidth: .infinity)
        }
        .navigationTitle("KDP-Verkauf")
    }
}
