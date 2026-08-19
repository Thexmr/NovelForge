import Foundation

@main
enum FinalScenePlanRetryProbe {
    static func main() throws {
        let sourceURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/NovelForge/Services/PipelineOrchestrator.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        guard let start = source.range(of: "let stagnationRepairChapters = pending.filter") else {
            fatalError("Letzte Szenenplan-Reparaturrunde fehlt")
        }
        let tail = source[start.lowerBound...]
        guard let end = tail.range(of: "for (index, chapter) in") else {
            fatalError("Reparaturrunden-Filter ist nicht abgrenzbar")
        }
        let block = tail[..<end.lowerBound]
        precondition(
            !block.localizedCaseInsensitiveContains("stagnier")
                && !block.localizedCaseInsensitiveContains("wiederholen"),
            "Formell unbrauchbare Szenenplaene erhalten weiterhin keinen letzten Reparaturversuch"
        )
        print("PASS: Letzte Szenenplan-Reparatur umfasst alle unbrauchbaren Plaene")
    }
}
