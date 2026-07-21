import Foundation

struct LongFormProductionPlan {
    let pageCount: Int
    let wordsPerChapterGoal: Int
    let chapterVariation: Int

    init(pageCount: Int, wordsPerChapterGoal: Int = 2_500, chapterVariation: Int = 0) {
        self.pageCount = pageCount
        self.wordsPerChapterGoal = min(max(wordsPerChapterGoal, 1_800), 4_500)
        self.chapterVariation = min(max(chapterVariation, -4), 4)
    }

    var targetWordCount: Int {
        normalizedPageCount * AppConstants.wordsPerPage
    }

    var chapterCount: Int {
        let base = Int(ceil(Double(targetWordCount) / Double(wordsPerChapterGoal)))
        return max(12, min(80, base + chapterVariation))
    }

    var targetWordsPerChapter: Int {
        max(1, targetWordCount / chapterCount)
    }

    var scenesPerChapter: Int {
        max(4, min(7, Int(ceil(Double(targetWordsPerChapter) / 750.0))))
    }

    var targetWordsPerScene: Int {
        max(1, targetWordsPerChapter / scenesPerChapter)
    }

    var totalPlannedScenes: Int {
        chapterCount * scenesPerChapter
    }

    static func draftMaxTokens(forTargetWords words: Int) -> Int {
        min(8000, max(1800, words * 4))
    }

    private var normalizedPageCount: Int {
        min(max(pageCount, AppConstants.minPageCount), AppConstants.maxPageCount)
    }
}

/// Eine gemeinsame Umfangsentscheidung für Revisionsprompt, Tokenbudget und
/// Antwortabnahme. So kann der Prompt nicht mehr „Länge behalten" verlangen,
/// während die Abnahme gleichzeitig eine starke Kürzung erwartet.
enum ChapterRevisionSizing {
    static let maximumTargetRatio = 1.35
    static let minimumTargetRatio = 0.75

    static func isOversized(sourceWords: Int, targetWords: Int) -> Bool {
        guard targetWords > 0 else { return false }
        return Double(sourceWords) > Double(targetWords) * maximumTargetRatio
    }

    static func desiredOutputWords(sourceWords: Int, targetWords: Int) -> Int {
        isOversized(sourceWords: sourceWords, targetWords: targetWords)
            ? max(1, targetWords)
            : max(1, sourceWords)
    }

    static func minimumSourceRatio(sourceWords: Int, targetWords: Int) -> Double {
        guard isOversized(sourceWords: sourceWords, targetWords: targetWords) else {
            return 0.80
        }
        let ratioNeededForTargetFloor = Double(targetWords) * minimumTargetRatio
            / Double(max(1, sourceWords))
        return max(0.20, ratioNeededForTargetFloor)
    }

    static func maxOutputTokens(sourceWords: Int, targetWords: Int) -> Int {
        let desiredWords = desiredOutputWords(sourceWords: sourceWords, targetWords: targetWords)
        return min(12_000, max(3_000, desiredWords * 3))
    }
}

struct ProductionTiming {
    let currentBookStartedAt: Date?
    let now: Date
    let completedBookDurations: [TimeInterval]
    let completedScenes: Int
    let totalScenes: Int
    let recentSceneDurations: [TimeInterval]

    var elapsed: TimeInterval? {
        currentBookStartedAt.map { max(0, now.timeIntervalSince($0)) }
    }

    var remaining: TimeInterval? {
        guard completedScenes < totalScenes, !recentSceneDurations.isEmpty else { return nil }
        let avg = recentSceneDurations.reduce(0, +) / Double(recentSceneDurations.count)
        return avg * Double(totalScenes - completedScenes)
    }

    var estimatedTotal: TimeInterval? {
        guard let elapsed else { return nil }
        return elapsed + (remaining ?? 0)
    }

    var averageBookDuration: TimeInterval? {
        guard !completedBookDurations.isEmpty else { return nil }
        return completedBookDurations.reduce(0, +) / Double(completedBookDurations.count)
    }

    var elapsedText: String {
        elapsed.map(Self.formatHumanDuration) ?? ""
    }

    var remainingText: String {
        remaining.map(Self.formatHumanDuration) ?? ""
    }

    var estimatedTotalText: String {
        estimatedTotal.map(Self.formatHumanDuration) ?? ""
    }

    var averageBookText: String {
        averageBookDuration.map(Self.formatHumanDuration) ?? ""
    }

    static func formatHumanDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(1, Int(ceil(seconds / 60.0)))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 && minutes > 0 { return "\(hours) h \(minutes) min" }
        if hours > 0 { return "\(hours) h" }
        return "\(minutes) min"
    }
}
