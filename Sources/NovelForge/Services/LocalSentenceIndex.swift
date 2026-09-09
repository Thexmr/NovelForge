import Foundation

/// Inverted trigram index. Only sentences sharing a word group need a comparison.
struct LocalSentenceIndex {
    private var sizes: [Int] = []
    private var postings: [[String]: [Int]] = [:]

    init(_ sentences: [Set<[String]>] = []) {
        for sentence in sentences { insert(sentence) }
    }

    mutating func insert(_ trigrams: Set<[String]>) {
        guard !trigrams.isEmpty else { return }
        let identifier = sizes.count
        sizes.append(trigrams.count)
        for trigram in trigrams {
            postings[trigram, default: []].append(identifier)
        }
    }

    func containsNearMatch(_ candidate: Set<[String]>, threshold: Double) -> Bool {
        guard !candidate.isEmpty, !sizes.isEmpty else { return false }
        if threshold <= 0 { return true }
        var shared: [Int: Int] = [:]
        for trigram in candidate {
            for identifier in postings[trigram] ?? [] {
                let count = (shared[identifier] ?? 0) + 1
                shared[identifier] = count
                if Double(count) / Double(min(candidate.count, sizes[identifier])) >= threshold {
                    return true
                }
            }
        }
        return false
    }
}
