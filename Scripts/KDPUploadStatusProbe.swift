import Foundation

@main
enum KDPUploadStatusProbe {
    static func main() throws {
        precondition(KDPUploadService.draftBookID(from: "https://kdp.amazon.com/de_DE/title-setup/kindle/A123/details") == "A123")
        precondition(KDPUploadService.draftBookID(from: "https://kdp.amazon.com/de_DE/bookshelf") == nil)
        precondition(KDPUploadService.draftBookID(from: "https://kdp.amazon.com/de_DE/title-setup/kindle/new/details") == nil)
        precondition(KDPUploadService.draftBookID(from: "https://kdp.amazon.com.evil.test/de_DE/title-setup/kindle/A123/details") == nil)
        for bad in [
            #"{"stage":"done","saveConfirmed":true,"ok":true,"draftUrl":"https://kdp.amazon.com/de_DE/bookshelf"}"#,
            #"{"stage":"done","saveConfirmed":true,"ok":true,"draftUrl":"https://kdp.amazon.com/de_DE/title-setup/kindle/new/details"}"#,
            #"{"stage":"content","saveConfirmed":true,"ok":true,"draftUrl":"https://kdp.amazon.com/de_DE/title-setup/kindle/123/details"}"#,
            #"{"stage":"done","ok":true,"draftUrl":"https://kdp.amazon.com/de_DE/title-setup/kindle/123/details"}"#,
        ] {
            precondition(throwsError {
                _ = try KDPUploadService.interpretStatus(data: Data(bad.utf8), exitCode: 0, dryRun: false)
            }, "Unbestaetigter Entwurf darf nicht als Upload-Erfolg gelten")
        }
        let complete = Data(#"{"stage":"done","saveConfirmed":true,"ok":true,"draftUrl":"https://kdp.amazon.com/de_DE/title-setup/kindle/123/details","probleme":[]}"#.utf8)
        let completeResult = try KDPUploadService.interpretStatus(
            data: complete, exitCode: 0, dryRun: false
        )
        precondition(completeResult.isComplete && !completeResult.isDryRun)

        let incomplete = Data(#"{"stage":"done","saveConfirmed":true,"ok":false,"draftUrl":"https://kdp.amazon.com/de_DE/title-setup/kindle/123/details","probleme":["Cover fehlt"]}"#.utf8)
        let incompleteResult = try KDPUploadService.interpretStatus(
            data: incomplete, exitCode: 0, dryRun: false
        )
        precondition(!incompleteResult.isComplete)
        precondition(incompleteResult.offenePunkte == ["Cover fehlt"])

        let offline = Data(#"{"stage":"done","ok":true,"offline":true,"draftUrl":null,"probleme":[]}"#.utf8)
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
