import Foundation

@main
enum FinalRepairPhaseProbe {
    static func main() throws {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/NovelForge/Services/PipelineOrchestrator.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        guard let callRange = source.range(
            of: "try await runFinalReadinessRepairs(project: project, config: config)"
        ) else {
            fatalError("Endabnahme-Aufruf fehlt")
        }

        let before = source[..<callRange.lowerBound].suffix(900)
        let after = source[callRange.upperBound...].prefix(900)
        precondition(
            before.contains("currentPhase = .manuscriptRevision"),
            "Endabnahme wird in der UI weiterhin faelschlich als Export angezeigt"
        )
        precondition(
            after.contains("currentPhase = .export"),
            "Exportphase wird nach der Endabnahme nicht wiederhergestellt"
        )
        precondition(
            before.contains("catch") || after.contains("catch"),
            "Fehlerpfad stellt die Exportphase nicht sicher wieder her"
        )
        print("PASS: Endabnahme hat eine eigene sichtbare Arbeitsphase")
    }
}
