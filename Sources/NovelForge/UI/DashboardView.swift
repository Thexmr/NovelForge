import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Project.updatedAt, order: .reverse) var projects: [Project]
    @State private var showingNewBookSheet = false
    
    var activeProjects: [Project] {
        projects.filter { $0.status != .completed && $0.status != .failed }
    }
    
    var completedProjects: [Project] {
        projects.filter { $0.status == .completed }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    VStack(alignment: .leading) {
                        Text("NovelForge")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("KI-gestützte Buchproduktion")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Neues Buch") {
                        showingNewBookSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                
                // Stats Cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    StatCard(title: "Aktive Projekte", value: "\(activeProjects.count)", icon: "book.fill", color: .blue)
                    StatCard(title: "Abgeschlossen", value: "\(completedProjects.count)", icon: "checkmark.circle.fill", color: .green)
                    StatCard(title: "In Produktion", value: "\(activeProjects.filter { $0.status == .drafting }.count)", icon: "gear", color: .orange)
                    StatCard(title: "Fehler", value: "\(projects.filter { $0.status == .failed }.count)", icon: "exclamationmark.triangle.fill", color: .red)
                }
                .padding(.horizontal)
                
                // Active Productions
                if !activeProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Aktuell in Produktion")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(activeProjects.prefix(3)) { project in
                            ProjectCard(project: project)
                        }
                    }
                }
                
                // Recent Completed
                if !completedProjects.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Kürzlich abgeschlossen")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        ForEach(completedProjects.prefix(3)) { project in
                            CompletedProjectCard(project: project)
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .sheet(isPresented: $showingNewBookSheet) {
            NewBookWizardView()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
            }
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct ProjectCard: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(project.title)
                        .font(.headline)
                    Text(project.authorName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusBadge(status: project.status)
            }
            
            ProgressView(value: calculateProgress(for: project))
                .progressViewStyle(.linear)
            
            HStack {
                Text("\(project.targetPageCount) Seiten Ziel")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(project.updatedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func calculateProgress(for project: Project) -> Double {
        let statusOrder: [ProjectStatus] = [.created, .conceptDevelopment, .structurePlanning, .chapterPlanning, .scenePlanning, .drafting, .chapterRevision, .manuscriptRevision, .proofreading, .copyrightCheck, .kdpFormatting, .export, .completed]
        guard let currentIndex = statusOrder.firstIndex(of: project.status) else { return 0 }
        return Double(currentIndex) / Double(statusOrder.count - 1)
    }
}

struct CompletedProjectCard: View {
    let project: Project
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(project.title)
                    .font(.headline)
                Text(project.authorName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct StatusBadge: View {
    let status: ProjectStatus
    
    var color: Color {
        switch status {
        case .completed: return .green
        case .failed: return .red
        case .paused: return .orange
        case .drafting: return .blue
        default: return .gray
        }
    }
    
    var body: some View {
        Text(status.rawValue)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .cornerRadius(8)
    }
}