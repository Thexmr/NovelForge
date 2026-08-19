import Foundation
import SwiftData

@main
@MainActor
enum ManuscriptQualityAudit {
    static func main() {
        let env = ProcessInfo.processInfo.environment
        guard let storePath = env["NF_AUDIT_STORE"], !storePath.isEmpty else {
            print("AUDIT_FAIL: NF_AUDIT_STORE fehlt")
            exit(2)
        }
        let limit = Int(env["NF_AUDIT_LIMIT"] ?? "8") ?? 8
        let schema = Schema([
            Project.self, BookProfile.self, StoryBible.self, CharacterProfile.self,
            LocationProfile.self, Chapter.self, StoryScene.self, PipelineJob.self,
            QualityReport.self, ChatMessage.self,
        ])

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: URL(fileURLWithPath: storePath))]
            )
            let context = ModelContext(container)
            let projects = try context.fetch(FetchDescriptor<Project>())
                .filter { project in
                    project.chapters?.contains(where: { $0.bestText?.isEmpty == false }) == true
                }
                .sorted { $0.updatedAt > $1.updatedAt }
            let selected = Array(projects.prefix(limit))

            print("AUDIT_BOOKS: \(selected.count)")
            auditNameReuse(projects: selected)
            auditBooks(selected)
        } catch {
            print("AUDIT_FAIL: \(error.localizedDescription)")
            exit(1)
        }
    }

    private static func auditNameReuse(projects: [Project]) {
        var owners: [String: Set<String>] = [:]
        var display: [String: String] = [:]
        for project in projects {
            for character in project.storyBible?.characters ?? [] {
                for part in CharacterCanonAudit.nameParts(character.name) where part.count >= 3 {
                    let key = part.folding(
                        options: [.caseInsensitive, .diacriticInsensitive], locale: .current
                    ).lowercased()
                    owners[key, default: []].insert(project.title)
                    display[key] = part
                }
            }
        }
        let reused = owners
            .filter { $0.value.count > 1 }
            .sorted { lhs, rhs in
                if lhs.value.count != rhs.value.count { return lhs.value.count > rhs.value.count }
                return lhs.key < rhs.key
            }
        if reused.isEmpty {
            print("NAME_REUSE: PASS")
        } else {
            for item in reused {
                print("NAME_REUSE: \(display[item.key] ?? item.key) | \(item.value.sorted().joined(separator: " | "))")
            }
        }
    }

    private static func auditBooks(_ projects: [Project]) {
        for project in projects {
            let chapters = (project.chapters ?? []).sorted { $0.chapterNumber < $1.chapterNumber }
            let texts = chapters.compactMap(\.bestText).filter { !$0.isEmpty }
            guard !texts.isEmpty else { continue }
            let fullText = texts.joined(separator: "\n")
            let names = (project.storyBible?.characters ?? []).map(\.name)
            let explicitProtagonists = (project.storyBible?.characters ?? []).filter {
                let role = $0.role.folding(
                    options: [.caseInsensitive, .diacriticInsensitive], locale: .current
                ).lowercased()
                return role.contains("protagon") || role.contains("hauptfigur")
            }.map(\.name)
            let protagonistNames = explicitProtagonists.isEmpty
                ? Array(names.prefix(1)) : explicitProtagonists
            let opening = String(texts[0].prefix(5_000))
            let openingIssues = AutonomousContentQuality.finalOpeningIssues(
                in: opening, protagonistNames: protagonistNames
            )
            let planIssues = AutonomousContentQuality.kapitelplanMaengel(
                ziele: chapters.map(\.goal), schritte: chapters.map(\.conflict)
            )
            let repeatedPhrases = AutonomousContentQuality.wiederholteWortgruppen(
                in: texts, abHaeufigkeit: 4
            )
            let crossChapterPhrases = AutonomousContentQuality.overusedPhrases(
                inChapters: texts, minChapters: 3, maxResults: 12
            )
            let blockingPhrases = AutonomousContentQuality.blockingRepeatedPhrases(
                inChapters: texts
            )
            let nameOveruse = AutonomousContentQuality.characterNameOveruseFindings(
                inChapters: texts, characterNames: names
            )
            let aiLikeChapters = texts.enumerated().compactMap { index, text in
                AutonomousContentQuality.soundsLikeAI(text)
                    ? chapters[index].chapterNumber : nil
            }
            let expectedTense = project.bookProfile?.tense ?? ""
            let tenseIssues = expectedTense.isEmpty ? [] : texts.enumerated().compactMap { index, text in
                AutonomousContentQuality.narrativeTenseIssuesAcrossSections(
                    in: text, expectedTense: expectedTense
                ).isEmpty ? nil : chapters[index].chapterNumber
            }
            let plannedScenes: [(kapitel: Int, szenen: [PlannedScene])] = chapters.map { chapter in
                let scenes = (chapter.scenes ?? []).sorted { $0.sceneNumber < $1.sceneNumber }.map { scene in
                    var planned = PlannedScene(
                        number: scene.sceneNumber, perspective: scene.perspective,
                        location: scene.location, time: scene.time, goal: scene.goal,
                        obstacle: scene.obstacle, turn: scene.cliffhanger
                    )
                    planned.takt = scene.emotionalChange
                    return planned
                }
                return (chapter.chapterNumber, scenes)
            }
            let planStagnation = EreignisRegister.stagnierendeSequenzen(
                imBuchplan: plannedScenes
            )
            let spellIssues = SpellCheckService.eindeutigeFehler(in: fullText)
            let ticks = AutonomousContentQuality.saetzeMitTicks(in: fullText)
            let oldPhrases = AutonomousContentQuality.altmodischeWendungen(in: fullText)
            let foreignWords = AutonomousContentQuality.schwereFremdwoerter(in: fullText)
            let dialogue = AutonomousContentQuality.dialoganteil(in: fullText)
            let sentenceIssue = AutonomousContentQuality.fehlendeSatzvarianz(in: fullText)
            let wordCount = fullText.split(whereSeparator: \.isWhitespace).count

            print("BOOK: \(project.title) | \(wordCount) Woerter | \(chapters.count) Kapitel | Dialog \(Int(dialogue * 100)) %")
            print("  OPENING: \(openingIssues.isEmpty ? "PASS" : openingIssues.joined(separator: " || "))")
            print("  OPENING_RHYTHM: long=\(AutonomousContentQuality.schwerLesbareSaetze(in: opening).count) | staccato=\(AutonomousContentQuality.stakkatoKetten(in: opening))")
            print("  ARC: \(planIssues.isEmpty ? "PASS" : planIssues.joined(separator: " || "))")
            print("  SPELLING: \(spellIssues.isEmpty ? "PASS" : spellIssues.prefix(8).joined(separator: " | "))")
            print("  SENTENCE_RHYTHM: \(sentenceIssue ?? "PASS")")
            print("  TICKS: \(ticks.count) | OLD_PHRASES: \(oldPhrases.count) | HARD_WORDS: \(foreignWords.count)")
            if repeatedPhrases.isEmpty {
                print("  REPEATED_PHRASES: PASS")
            } else {
                let summary = repeatedPhrases.prefix(8).map { "\($0.gruppe) (\($0.anzahl)x)" }
                print("  REPEATED_PHRASES: \(summary.joined(separator: " | "))")
            }
            print("  CROSS_CHAPTER_PHRASES: "
                  + (crossChapterPhrases.isEmpty
                     ? "PASS"
                     : crossChapterPhrases.joined(separator: " | ")))
            print("  BLOCKING_PHRASES: "
                  + (blockingPhrases.isEmpty
                     ? "PASS"
                     : blockingPhrases.joined(separator: " | ")))
            print("  NAME_OVERUSE: " + (nameOveruse.isEmpty
                  ? "PASS"
                  : nameOveruse.prefix(8).map {
                      "\($0.characterName) K\(chapters[$0.chapterIndex].chapterNumber) (\($0.maximumMentions)x)"
                  }.joined(separator: " | ")))
            print("  TENSE: " + (tenseIssues.isEmpty
                  ? "PASS"
                  : "Bruch in K" + tenseIssues.map(String.init).joined(separator: ", K")))
            print("  PLAN_STAGNATION: " + (planStagnation.isEmpty
                  ? "PASS"
                  : planStagnation.joined(separator: " | ")))
            print("  AI_LIKE_CHAPTERS: "
                  + (aiLikeChapters.isEmpty
                     ? "PASS"
                     : aiLikeChapters.map(String.init).joined(separator: ", ")))
            for number in aiLikeChapters.prefix(4) {
                guard let index = chapters.firstIndex(where: { $0.chapterNumber == number }) else {
                    continue
                }
                let text = texts[index]
                print("  AI_DETAIL_K\(number): words=\(text.wordCount) | tells=\(AutonomousContentQuality.aiTellCount(text)) | archaic=\(AutonomousContentQuality.archaicTellCount(text)) | jargon=\(AutonomousContentQuality.jargonTellCount(text)) | circumlocution=\(AutonomousContentQuality.circumlocutionCount(text))")
            }
        }
    }
}
