import Foundation
import SwiftData

@Model
final class PipelineJob {
    @Attribute(.unique) var id: UUID
    var agentName: String
    var phase: PipelinePhase
    var status: JobStatus
    var startTime: Date?
    var endTime: Date?
    var errorCount: Int
    var lastHeartbeat: Date?
    var result: String?
    var chapterNumber: Int?
    var sceneNumber: Int?
    var tokenUsage: Int
    var createdAt: Date
    
    @Relationship(inverse: \Project.pipelineJobs) var project: Project?
    
    init(agentName: String, phase: PipelinePhase, chapterNumber: Int? = nil, sceneNumber: Int? = nil) {
        self.id = UUID()
        self.agentName = agentName
        self.phase = phase
        self.status = .waiting
        self.errorCount = 0
        self.tokenUsage = 0
        self.chapterNumber = chapterNumber
        self.sceneNumber = sceneNumber
        self.createdAt = Date()
    }
}

enum PipelinePhase: String, Codable, CaseIterable {
    case projectSetup = "Projektanlage"
    case conceptDevelopment = "Konzeptentwicklung"
    case structurePlanning = "Strukturplanung"
    case chapterPlanning = "Kapitelplanung"
    case scenePlanning = "Szenenplanung"
    case drafting = "Rohfassung"
    case chapterRevision = "Kapitelrevision"
    case manuscriptRevision = "Gesamtlektorat"
    case proofreading = "Proofreading"
    case copyrightCheck = "Copyright-Prüfung"
    case kdpFormatting = "KDP-Formatierung"
    case export = "Export"
    case completed = "Abgeschlossen"
    
    var weight: Double {
        switch self {
        case .projectSetup: return 0.02
        case .conceptDevelopment: return 0.05
        case .structurePlanning: return 0.10
        case .chapterPlanning: return 0.08
        case .scenePlanning: return 0.08
        case .drafting: return 0.40
        case .chapterRevision: return 0.10
        case .manuscriptRevision: return 0.07
        case .proofreading: return 0.05
        case .copyrightCheck: return 0.02
        case .kdpFormatting: return 0.03
        case .export: return 0.02
        case .completed: return 0.0
        }
    }
}

enum JobStatus: String, Codable {
    case waiting = "wartet"
    case running = "läuft"
    case writing = "schreibt"
    case checking = "prüft"
    case revising = "überarbeitet"
    case retrying = "wiederholt"
    case failed = "fehlgeschlagen"
    case completed = "abgeschlossen"
    case paused = "pausiert"
}

@Model
final class QualityReport {
    @Attribute(.unique) var id: UUID
    var checkedArea: String
    var checkType: String
    var result: String
    var severity: Severity
    var recommendation: String
    var autoFixed: Bool
    var createdAt: Date
    
    @Relationship(inverse: \Project.qualityReports) var project: Project?
    
    init(checkedArea: String, checkType: String, result: String, severity: Severity, recommendation: String) {
        self.id = UUID()
        self.checkedArea = checkedArea
        self.checkType = checkType
        self.result = result
        self.severity = severity
        self.recommendation = recommendation
        self.autoFixed = false
        self.createdAt = Date()
    }
}

enum Severity: String, Codable {
    case info = "Info"
    case warning = "Warnung"
    case error = "Fehler"
    case critical = "Kritisch"
}