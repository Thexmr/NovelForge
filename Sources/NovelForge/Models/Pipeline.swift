import Foundation
import Observation
import SwiftData

final class PipelineJob: NovelForgePersistentModel {
    private var _$backingData: any BackingData<PipelineJob> = PipelineJob.createBackingData()
    private let _$observationRegistrar = ObservationRegistrar()

    var novelForgeObservationRegistrar: ObservationRegistrar { _$observationRegistrar }

    var persistentBackingData: any BackingData<PipelineJob> {
        get { _$backingData }
        set { _$backingData = newValue }
    }

    static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            Schema.PropertyMetadata(name: "id", keypath: \PipelineJob.id,
                                    metadata: Schema.Attribute(.unique)),
            Schema.PropertyMetadata(name: "agentName", keypath: \PipelineJob.agentName),
            Schema.PropertyMetadata(name: "phase", keypath: \PipelineJob.phase),
            Schema.PropertyMetadata(name: "status", keypath: \PipelineJob.status),
            Schema.PropertyMetadata(name: "startTime", keypath: \PipelineJob.startTime),
            Schema.PropertyMetadata(name: "endTime", keypath: \PipelineJob.endTime),
            Schema.PropertyMetadata(name: "errorCount", keypath: \PipelineJob.errorCount),
            Schema.PropertyMetadata(name: "lastHeartbeat", keypath: \PipelineJob.lastHeartbeat),
            Schema.PropertyMetadata(name: "result", keypath: \PipelineJob.result),
            Schema.PropertyMetadata(name: "chapterNumber", keypath: \PipelineJob.chapterNumber),
            Schema.PropertyMetadata(name: "sceneNumber", keypath: \PipelineJob.sceneNumber),
            Schema.PropertyMetadata(name: "tokenUsage", keypath: \PipelineJob.tokenUsage),
            Schema.PropertyMetadata(name: "createdAt", keypath: \PipelineJob.createdAt),
            Schema.PropertyMetadata(name: "project", keypath: \PipelineJob.project,
                                    metadata: Schema.Relationship(inverse: \Project.pipelineJobs)),
        ]
    }

    @PersistedValue var id: UUID = UUID()
    @PersistedValue var agentName: String = ""
    @PersistedValue var phase: PipelinePhase = .projectSetup
    @PersistedValue var status: JobStatus = .waiting
    @PersistedValue var startTime: Date? = nil
    @PersistedValue var endTime: Date? = nil
    @PersistedValue var errorCount: Int = 0
    @PersistedValue var lastHeartbeat: Date? = nil
    @PersistedValue var result: String? = nil
    @PersistedValue var chapterNumber: Int? = nil
    @PersistedValue var sceneNumber: Int? = nil
    @PersistedValue var tokenUsage: Int = 0
    @PersistedValue var createdAt: Date = .distantPast
    
    @PersistedToOne var project: Project? = nil
    
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

    required init(backingData: any BackingData<PipelineJob>) {
        self._$backingData = backingData
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
    
    /// Reihenfolge, in der die Pipeline die Phasen tatsächlich abarbeitet.
    static var executionOrder: [PipelinePhase] {
        [.projectSetup, .conceptDevelopment, .structurePlanning, .chapterPlanning,
         .scenePlanning, .drafting, .chapterRevision, .manuscriptRevision,
         .proofreading, .copyrightCheck, .kdpFormatting, .export]
    }

    // Gewichte summieren sich über executionOrder exakt zu 1.0.
    var weight: Double {
        switch self {
        case .projectSetup: return 0.01
        case .conceptDevelopment: return 0.05
        case .structurePlanning: return 0.09
        case .chapterPlanning: return 0.08
        case .scenePlanning: return 0.08
        case .drafting: return 0.40
        case .chapterRevision: return 0.12
        case .manuscriptRevision: return 0.05
        case .proofreading: return 0.07
        case .copyrightCheck: return 0.01
        case .kdpFormatting: return 0.02
        case .export: return 0.02
        case .completed: return 0.0
        }
    }

    var iconName: String {
        switch self {
        case .projectSetup: return "checkmark.shield"
        case .conceptDevelopment: return "lightbulb"
        case .structurePlanning: return "square.grid.3x3"
        case .chapterPlanning: return "list.number"
        case .scenePlanning: return "rectangle.split.3x1"
        case .drafting: return "pencil.line"
        case .chapterRevision: return "arrow.triangle.2.circlepath"
        case .manuscriptRevision: return "doc.text.magnifyingglass"
        case .proofreading: return "textformat.abc"
        case .copyrightCheck: return "c.circle"
        case .kdpFormatting: return "book.closed"
        case .export: return "square.and.arrow.up"
        case .completed: return "checkmark.seal"
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

final class QualityReport: NovelForgePersistentModel {
    private var _$backingData: any BackingData<QualityReport> = QualityReport.createBackingData()
    private let _$observationRegistrar = ObservationRegistrar()

    var novelForgeObservationRegistrar: ObservationRegistrar { _$observationRegistrar }

    var persistentBackingData: any BackingData<QualityReport> {
        get { _$backingData }
        set { _$backingData = newValue }
    }

    static var schemaMetadata: [Schema.PropertyMetadata] {
        [
            Schema.PropertyMetadata(name: "id", keypath: \QualityReport.id,
                                    metadata: Schema.Attribute(.unique)),
            Schema.PropertyMetadata(name: "checkedArea", keypath: \QualityReport.checkedArea),
            Schema.PropertyMetadata(name: "checkType", keypath: \QualityReport.checkType),
            Schema.PropertyMetadata(name: "result", keypath: \QualityReport.result),
            Schema.PropertyMetadata(name: "severity", keypath: \QualityReport.severity),
            Schema.PropertyMetadata(name: "recommendation", keypath: \QualityReport.recommendation),
            Schema.PropertyMetadata(name: "autoFixed", keypath: \QualityReport.autoFixed),
            Schema.PropertyMetadata(name: "createdAt", keypath: \QualityReport.createdAt),
            Schema.PropertyMetadata(name: "project", keypath: \QualityReport.project,
                                    metadata: Schema.Relationship(inverse: \Project.qualityReports)),
        ]
    }

    @PersistedValue var id: UUID = UUID()
    @PersistedValue var checkedArea: String = ""
    @PersistedValue var checkType: String = ""
    @PersistedValue var result: String = ""
    @PersistedValue var severity: Severity = .info
    @PersistedValue var recommendation: String = ""
    @PersistedValue var autoFixed: Bool = false
    @PersistedValue var createdAt: Date = .distantPast
    
    @PersistedToOne var project: Project? = nil
    
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

    required init(backingData: any BackingData<QualityReport>) {
        self._$backingData = backingData
    }
}

enum Severity: String, Codable {
    case info = "Info"
    case warning = "Warnung"
    case error = "Fehler"
    case critical = "Kritisch"
}
