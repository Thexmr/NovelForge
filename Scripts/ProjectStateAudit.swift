import Foundation
import SwiftData

@main
@MainActor
enum ProjectStateAudit {
    static func main() throws {
        let storePath = ProcessInfo.processInfo.environment["NF_AUDIT_STORE"]
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/default.store").path
        let schema = Schema([
            Project.self, BookProfile.self, StoryBible.self, CharacterProfile.self,
            LocationProfile.self, Chapter.self, StoryScene.self, PipelineJob.self,
            QualityReport.self, ChatMessage.self,
        ])
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, url: URL(fileURLWithPath: storePath))]
        )
        let projects = try container.mainContext.fetch(FetchDescriptor<Project>())
            .sorted { $0.updatedAt > $1.updatedAt }
        let formatter = ISO8601DateFormatter()

        for project in projects {
            print("PROJECT|\(project.title)|\(project.status.rawValue)|\(project.recordedWordCount)|updated=\(formatter.string(from: project.updatedAt))")
            let jobs = (project.pipelineJobs ?? []).sorted { $0.createdAt > $1.createdAt }
            for job in jobs.prefix(15) {
                let location = [
                    job.chapterNumber.map { "K\($0)" },
                    job.sceneNumber.map { "S\($0)" },
                ].compactMap { $0 }.joined(separator: "/")
                let heartbeat = job.lastHeartbeat.map(formatter.string(from:)) ?? "-"
                let result = (job.result ?? "-").replacingOccurrences(of: "\n", with: " ")
                print("JOB|\(job.status.rawValue)|\(job.phase.rawValue)|\(job.agentName)|\(location)|heartbeat=\(heartbeat)|\(result.prefix(500))")
            }
            let open = (project.qualityReports ?? [])
                .filter { !$0.autoFixed && ($0.severity == .critical || $0.severity == .error) }
                .sorted { $0.createdAt > $1.createdAt }
            print("OPEN_REPORTS|\(open.count)")
            for report in open.prefix(25) {
                print("REPORT|\(report.severity.rawValue)|\(report.checkType)|\(report.checkedArea)|\(report.result.prefix(500))")
            }
        }
    }
}
