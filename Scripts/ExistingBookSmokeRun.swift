import Foundation
import SwiftData

@main
@MainActor
struct ExistingBookSmokeRun {
    static func main() async {
        let env = ProcessInfo.processInfo.environment
        let storePath = env["NF_SMOKE_STORE"]
            ?? FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Application Support/default.store").path
        let outputPath = env["NF_SMOKE_OUTPUT"] ?? "/tmp/novelforge-smoke-export"
        let wantedTitle = env["NF_SMOKE_TITLE"]

        let schema = Schema([
            Project.self, BookProfile.self, StoryBible.self, CharacterProfile.self,
            LocationProfile.self, Chapter.self, StoryScene.self, PipelineJob.self,
            QualityReport.self, ChatMessage.self,
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            url: URL(fileURLWithPath: storePath)
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            let context = ModelContext(container)
            let projects = try context.fetch(FetchDescriptor<Project>())
            if env["NF_SMOKE_AUDIT_ALL"] == "1" {
                let manuscripts = projects
                    .filter { $0.chapters?.contains(where: { $0.bestText?.isEmpty == false }) == true }
                    .sorted { $0.updatedAt > $1.updatedAt }
                for candidate in manuscripts {
                    let issues = PublicationReadiness.completionBlockingIssues(project: candidate)
                    print("SMOKE_AUDIT: \(candidate.title) | \(candidate.recordedWordCount) Woerter | "
                          + (issues.isEmpty ? "PASS" : "BLOCKED: " + issues.joined(separator: " ")))
                }
                print("SMOKE_AUDIT_DONE: \(manuscripts.count) Manuskripte")
                exit(0)
            }
            let project = projects
                .filter { candidate in
                    candidate.chapters?.contains(where: { $0.bestText?.isEmpty == false }) == true
                        && (wantedTitle == nil || candidate.title == wantedTitle)
                }
                .max { $0.updatedAt < $1.updatedAt }
            guard let project else {
                print("SMOKE_FAIL: Kein Projekt mit Manuskript gefunden")
                exit(2)
            }

            if env["NF_SMOKE_PREPARE_FIXTURE"] == "1" {
                guard storePath.hasPrefix("/tmp/") else {
                    print("SMOKE_FAIL: Fixture-Korrektur ist ausschliesslich in /tmp erlaubt")
                    exit(6)
                }
                prepareIsolatedFixture(project: project, context: context)
            }

            if env["NF_SMOKE_SPELL_CONTEXT"] == "1" {
                let properNames = Set(
                    (project.storyBible?.characters ?? []).map(\.name)
                        + (project.storyBible?.locations ?? []).map(\.name)
                )
                for chapter in (project.chapters ?? []).sorted(by: {
                    $0.chapterNumber < $1.chapterNumber
                }) {
                    guard let text = chapter.bestText else { continue }
                    let findings = SpellCheckService.pruefe(text: text, eigennamen: properNames)
                    for (finding, sentence) in SpellCheckService.mitKontext(
                        findings, text: text, hoechstens: 40
                    ) {
                        print("SPELL_CONTEXT: K\(chapter.chapterNumber) | \(finding.wort) | \(sentence)")
                    }
                }
                exit(0)
            }

            UserDefaults.standard.set(outputPath, forKey: ExportEngine.exportRootDefaultsKey)
            print("SMOKE_PROJECT: \(project.title) | \(project.recordedWordCount) Woerter")

            if let expectedRaw = env["NF_SMOKE_EXPECT_MEMORY_NAMES"] {
                let expected = Set(expectedRaw.split(separator: ",").map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                })
                let memoryNames = StoryMemory.vergebeneNamensteile(
                    projects: projects, excluding: project.id
                )
                let missingMemory = expected.subtracting(memoryNames)
                guard missingMemory.isEmpty else {
                    print("SMOKE_FAIL: Namen fehlen im Kataloggedaechtnis: "
                          + missingMemory.sorted().joined(separator: ", "))
                    exit(5)
                }
                print("SMOKE_NAME_MEMORY_PASS: \(expected.count) erwartete Namen dauerhaft gesperrt")
            }

            let releaseIssues = PublicationReadiness.exportBlockingIssues(project: project)
            if releaseIssues.isEmpty {
                print("SMOKE_RELEASE_GATE: PASS")
            } else {
                print("SMOKE_RELEASE_GATE: BLOCKED | \(releaseIssues.joined(separator: " "))")
            }
            if env["NF_SMOKE_EXPECT_CANON_BLOCK"] == "1" {
                let canonBlocked = releaseIssues.contains {
                    $0.localizedCaseInsensitiveContains("Figurenbibel")
                        || $0.localizedCaseInsensitiveContains("Story Bible")
                }
                guard canonBlocked else {
                    print("SMOKE_FAIL: Erwarteter Kanonfehler wurde nicht erkannt")
                    exit(4)
                }
                print("SMOKE_CANON_BLOCK_PASS")
                exit(0)
            }

            if env["NF_SMOKE_GENERATE_COVER"] == "1",
               CoverArtService.coverURL(for: project) == nil {
                let result = try await CoverArtService.generateCover(for: project)
                print("SMOKE_COVER: \(result.url.lastPathComponent) | \(result.qualityNotes.count) Hinweise")
            }

            let epub = try ExportEngine.exportToEPUB(project: project)
            let pdf = try ExportEngine.exportToPDF(project: project)
            let docx = try ExportEngine.exportToDOCX(project: project)
            for file in [epub, pdf, docx] {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                print("SMOKE_FILE: \(file.lastPathComponent) | \(size) Bytes")
            }

            let proof = ProofService.prove(
                project: project,
                epubURL: epub,
                coverURL: CoverArtService.coverURL(for: project),
                wrapURL: nil,
                wrapDimensions: nil,
                targetPages: project.targetPageCount
            )
            print(proof.text)
            guard proof.passed else {
                print("SMOKE_PROOF_BLOCKED")
                exit(3)
            }

            if env["NF_SMOKE_KDP_DRY_RUN"] == "1" {
                let result = try await KDPUploadService.uploadDraft(
                    project: project,
                    priceEUR: 3.99,
                    aiDisclosure: "ai-generated",
                    dryRun: true,
                    progress: { print("KDP_DRY_RUN: \($0)") }
                )
                print("KDP_DRY_RUN_PASS: \(result.offenePunkte.count) offene Punkte")
            }
            print("SMOKE_PASS")
            exit(0)
        } catch {
            print("SMOKE_FAIL: \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func prepareIsolatedFixture(project: Project, context: ModelContext) {
        let chapterTexts = (project.chapters ?? []).compactMap(\.bestText)
        let canonText = [
            project.bookProfile?.premise ?? "",
            project.bookProfile?.logline ?? "",
            project.bookProfile?.synopsis ?? "",
            project.storyBible?.plotPoints ?? ""
        ].joined(separator: "\n")
        let requiredNames = CharacterCanonAudit.personNames(in: canonText)
        let actingParts = CharacterCanonAudit.actingCharacterNameParts(
            narrativeTexts: chapterTexts, minimumOccurrences: 2
        )
        if let bible = project.storyBible {
            var characters = bible.characters ?? []
            var knownParts = Set(characters.flatMap { CharacterCanonAudit.nameParts($0.name) })
            let candidates = requiredNames + actingParts.sorted()
            for name in candidates {
                let parts = Set(CharacterCanonAudit.nameParts(name))
                guard !parts.isEmpty, !parts.isSubset(of: knownParts) else { continue }
                let profile = CharacterProfile(name: name, role: "Testkanon aus Manuskript")
                profile.storyBible = bible
                context.insert(profile)
                characters.append(profile)
                knownParts.formUnion(parts)
            }
            bible.characters = characters
            bible.updatedAt = Date()
        }

        var corrections = 0
        for chapter in project.chapters ?? [] {
            guard let original = chapter.bestText else { continue }
            var corrected = original
            for (wrong, right) in SpellCheckService.haeufigeFalschschreibungen {
                let escaped = NSRegularExpression.escapedPattern(for: wrong)
                guard let regex = try? NSRegularExpression(
                    pattern: "(?<![\\p{L}])\(escaped)(?![\\p{L}])",
                    options: [.caseInsensitive]
                ) else { continue }
                let range = NSRange(corrected.startIndex..<corrected.endIndex, in: corrected)
                corrected = regex.stringByReplacingMatches(
                    in: corrected, range: range,
                    withTemplate: NSRegularExpression.escapedTemplate(for: right)
                )
            }
            for issue in SpellCheckService.tageszeitenFehler(in: corrected) {
                corrected = corrected.replacingOccurrences(
                    of: issue.fehler, with: issue.korrekt, options: [.caseInsensitive]
                )
            }
            guard corrected != original else { continue }
            if chapter.finalText != nil { chapter.finalText = corrected }
            else if chapter.revisedText != nil { chapter.revisedText = corrected }
            else { chapter.draftText = corrected }
            chapter.updatedAt = Date()
            corrections += 1
        }
        project.updatedAt = Date()
        try? context.save()
        print("SMOKE_FIXTURE_READY: \(requiredNames.count) Kanonnamen, \(corrections) Kapitel korrigiert")
    }
}
