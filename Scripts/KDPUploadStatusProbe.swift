import Foundation

@main
enum KDPUploadStatusProbe {
    static func main() throws {
        let complete = Data(#"{"ok":true,"draftUrl":"https://kdp.amazon.com/de_DE/title-setup/kindle/123/details","probleme":[]}"#.utf8)
        let completeResult = try KDPUploadService.interpretStatus(
            data: complete, exitCode: 0, dryRun: false
        )
        precondition(completeResult.isComplete && !completeResult.isDryRun)

        let incomplete = Data(#"{"ok":false,"draftUrl":"https://kdp.amazon.com/de_DE/title-setup/kindle/123/details","probleme":["Cover fehlt"]}"#.utf8)
        let incompleteResult = try KDPUploadService.interpretStatus(
            data: incomplete, exitCode: 0, dryRun: false
        )
        precondition(!incompleteResult.isComplete)
        precondition(incompleteResult.offenePunkte == ["Cover fehlt"])

        let offline = Data(#"{"ok":true,"offline":true,"draftUrl":null,"probleme":[]}"#.utf8)
        let offlineResult = try KDPUploadService.interpretStatus(
            data: offline, exitCode: 0, dryRun: true
        )
        precondition(offlineResult.isComplete && offlineResult.isDryRun)

        let unsafeDryRun = Data(#"{"ok":true,"probleme":[]}"#.utf8)
        precondition(throwsError {
            _ = try KDPUploadService.interpretStatus(
                data: unsafeDryRun, exitCode: 0, dryRun: true
            )
        })
        precondition(throwsError {
            _ = try KDPUploadService.interpretStatus(
                data: nil, exitCode: 0, dryRun: false
            )
        })
        precondition(throwsError {
            _ = try KDPUploadService.interpretStatus(
                data: Data("kein json".utf8), exitCode: 0, dryRun: false
            )
        })
        precondition(throwsError {
            _ = try KDPUploadService.interpretStatus(
                data: Data(#"{"ok":false,"error":"Nicht bei KDP eingeloggt."}"#.utf8),
                exitCode: 1, dryRun: false
            )
        })

        print("NovelForge KDP upload status probe: PASS")
    }

    private static func throwsError(_ work: () throws -> Void) -> Bool {
        do {
            try work()
            return false
        } catch {
            return true
        }
    }
}
