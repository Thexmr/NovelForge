import SwiftUI
import SwiftData

struct AgentMonitorView: View {
    @Query var jobs: [PipelineJob]
    @State private var selectedStatus: JobStatusFilter = .all
    
    enum JobStatusFilter: String, CaseIterable {
        case all = "Alle"
        case active = "Aktiv"
        case completed = "Abgeschlossen"
        case failed = "Fehlgeschlagen"
    }
    
    var filteredJobs: [PipelineJob] {
        switch selectedStatus {
        case .all:
            return jobs
        case .active:
            return jobs.filter { $0.status == .running || $0.status == .writing || $0.status == .checking }
        case .completed:
            return jobs.filter { $0.status == .completed }
        case .failed:
            return jobs.filter { $0.status == .failed }
        }
    }
    
    var body: some View {
        VStack {
            Picker("Status", selection: $selectedStatus) {
                ForEach(JobStatusFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            List(filteredJobs) { job in
                AgentJobRow(job: job)
            }
        }
        .navigationTitle("Agenten-Monitor")
    }
}

struct AgentJobRow: View {
    let job: PipelineJob
    
    var statusColor: Color {
        switch job.status {
        case .running, .writing, .checking: return .blue
        case .completed: return .green
        case .failed: return .red
        case .paused: return .orange
        default: return .gray
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(statusColor.opacity(0.3), lineWidth: 4)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(job.agentName)
                        .font(.headline)
                    Spacer()
                    Text(job.status.rawValue)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(statusColor.opacity(0.1))
                        .cornerRadius(4)
                }
                
                HStack {
                    Text(job.phase.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if let chapter = job.chapterNumber {
                        Text("• Kapitel \(chapter)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let scene = job.sceneNumber {
                        Text("• Szene \(scene)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if let start = job.startTime {
                    HStack {
                        Text("Start: \(start, style: .time)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        if let end = job.endTime {
                            let duration = end.timeIntervalSince(start)
                            Text("Dauer: \(formatDuration(duration))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                if job.errorCount > 0 {
                    Text("Fehler: \(job.errorCount)")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
                
                if let lastHeartbeat = job.lastHeartbeat {
                    Text("Letzter Heartbeat: \(lastHeartbeat, style: .relative)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct ExportView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) var projects: [Project]
    @State private var selectedProject: Project?
    @State private var showingExportSheet = false
    @State private var exportURL: URL?
    @State private var exportType: ExportType = .epub
    
    enum ExportType: String, CaseIterable {
        case epub = "EPUB"
        case pdf = "PDF"
        case docx = "DOCX"
        case report = "KDP-Bericht"
        case log = "Protokoll"
    }
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selectedProject) {
                ForEach(projects.filter { $0.status == .completed || $0.status == .export }) { project in
                    NavigationLink(value: project) {
                        Text(project.title)
                    }
                    .tag(project)
                }
            }
            .navigationTitle("Exportbereit")
            .frame(minWidth: 200)
        } detail: {
            if let project = selectedProject {
                ExportDetailView(project: project)
            } else {
                ContentUnavailableView("Projekt wählen", systemImage: "square.and.arrow.up")
            }
        }
    }
}

struct ExportDetailView: View {
    let project: Project
    @State private var showingSavePanel = false
    @State private var exportURL: URL?
    @State private var selectedFormat: ExportView.ExportType = .epub
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Project info
                VStack(alignment: .leading, spacing: 8) {
                    Text(project.title)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("\(project.authorName) • \(project.genre)")
                        .foregroundStyle(.secondary)
                }
                
                Divider()
                
                // Export formats
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exportformate")
                        .font(.headline)
                    
                    ForEach(ExportView.ExportType.allCases, id: \.self) { format in
                        ExportFormatRow(format: format, project: project)
                    }
                }
                
                Divider()
                
                // Reports
                VStack(alignment: .leading, spacing: 12) {
                    Text("Berichte")
                        .font(.headline)
                    
                    Button("KDP-Bericht anzeigen") {
                        let report = ExportEngine.generateKDPReport(project: project)
                        // Show report in new window
                    }
                    
                    Button("Produktionsprotokoll anzeigen") {
                        let log = ExportEngine.generateProductionLog(project: project)
                        // Show log in new window
                    }
                    
                    Button("KI-Offenlegungsbericht") {
                        // Generate disclosure report
                    }
                }
                
                Divider()
                
                // Quality metrics
                VStack(alignment: .leading, spacing: 12) {
                    Text("Qualitätsmetriken")
                        .font(.headline)
                    
                    QualityMetricRow(label: "Struktur", score: 0.85)
                    QualityMetricRow(label: "Figuren", score: 0.78)
                    QualityMetricRow(label: "Stil", score: 0.82)
                    QualityMetricRow(label: "Konsistenz", score: 0.90)
                    QualityMetricRow(label: "KDP-Format", score: 0.95)
                }
            }
            .padding()
        }
    }
}

struct ExportFormatRow: View {
    let format: ExportView.ExportType
    let project: Project
    @State private var isExporting = false
    @State private var exportURL: URL?
    
    var body: some View {
        HStack {
            Image(systemName: iconForFormat(format))
                .font(.title2)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading) {
                Text(format.rawValue)
                    .font(.headline)
                Text(descriptionForFormat(format))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Exportieren") {
                exportFile()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isExporting)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private func exportFile() {
        isExporting = true
        
        Task {
            do {
                let url: URL
                switch format {
                case .epub:
                    url = try ExportEngine.exportToEPUB(project: project)
                case .pdf:
                    url = try ExportEngine.exportToPDF(project: project)
                case .docx:
                    url = try ExportEngine.exportToDOCX(project: project)
                case .report:
                    let report = ExportEngine.generateKDPReport(project: project)
                    url = FileManager.default.temporaryDirectory.appendingPathComponent("\(project.title)_kdp_report.txt")
                    try report.write(to: url, atomically: true, encoding: .utf8)
                case .log:
                    let log = ExportEngine.generateProductionLog(project: project)
                    url = FileManager.default.temporaryDirectory.appendingPathComponent("\(project.title)_production_log.txt")
                    try log.write(to: url, atomically: true, encoding: .utf8)
                }
                
                exportURL = url
                
                // Open save panel
                let savePanel = NSSavePanel()
                savePanel.nameFieldStringValue = url.lastPathComponent
                savePanel.canCreateDirectories = true
                
                if savePanel.runModal() == .OK, let destinationURL = savePanel.url {
                    try FileManager.default.copyItem(at: url, to: destinationURL)
                }
                
            } catch {
                print("Export failed: \(error)")
            }
            
            isExporting = false
        }
    }
    
    private func iconForFormat(_ format: ExportView.ExportType) -> String {
        switch format {
        case .epub: return "book.fill"
        case .pdf: return "doc.fill"
        case .docx: return "doc.text.fill"
        case .report: return "chart.bar.fill"
        case .log: return "list.clipboard.fill"
        }
    }
    
    private func descriptionForFormat(_ format: ExportView.ExportType) -> String {
        switch format {
        case .epub: return "eBook-Format für Amazon KDP"
        case .pdf: return "Print-Format für Paperback/Hardcover"
        case .docx: return "Bearbeitbares Dokument"
        case .report: return "KDP-Formatbericht und Qualitätsprüfung"
        case .log: return "Vollständiges Produktionsprotokoll"
        }
    }
}

struct QualityMetricRow: View {
    let label: String
    let score: Double
    
    var color: Color {
        if score >= 0.9 { return .green }
        if score >= 0.7 { return .yellow }
        return .orange
    }
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            ProgressView(value: score)
                .progressViewStyle(.linear)
                .frame(width: 150)
                .tint(color)
            Text("\(Int(score * 100))%")
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 40, alignment: .trailing)
        }
    }
}