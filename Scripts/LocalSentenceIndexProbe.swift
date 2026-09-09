import Foundation

@main
enum LocalSentenceIndexProbe {
    static func main() {
        func grams(_ seed: Int) -> Set<[String]> {
            Set((0..<8).map { ["wort\(seed)", "gruppe\($0)", "ende\(seed + $0)"] })
        }
        let corpus = (0..<10_000).map(grams)
        var cases = (0..<160).map { grams(20_000 + $0) }
        cases += [corpus[1], [], Set(corpus[91].prefix(4)), Set(corpus[300].prefix(1))]
        var overlap = Set(corpus[55].prefix(4))
        overlap.formUnion(grams(30_000).prefix(4))
        cases.append(overlap)

        let start = Date()
        let expected = cases.map { candidate in
            corpus.contains { prior in
                !candidate.isEmpty && !prior.isEmpty
                    && Double(candidate.intersection(prior).count)
                        / Double(min(candidate.count, prior.count)) >= 0.5
            }
        }
        let baseline = Date().timeIntervalSince(start)
        let indexStart = Date()
        let index = LocalSentenceIndex(corpus)
        let actual = cases.map { index.containsNearMatch($0, threshold: 0.5) }
        let indexed = Date().timeIntervalSince(indexStart)
        precondition(actual == expected, "Index must preserve every legacy match")

        var incremental = LocalSentenceIndex()
        precondition(!incremental.containsNearMatch(corpus[0], threshold: 0.5))
        incremental.insert(corpus[0])
        precondition(incremental.containsNearMatch(corpus[0], threshold: 0.5))
        precondition(!incremental.containsNearMatch(grams(40_000), threshold: 0.5))
        precondition(!index.containsNearMatch([], threshold: 0.5))
        print("LOCAL_INDEX_PASS: \(cases.count) identical results against 10000 sentences; incremental and empty cases pass")
        print(String(format: "BENCHMARK_SECONDS: baseline=%.3f indexed_including_build=%.3f speedup=%.2fx",
                     baseline, indexed, baseline / max(indexed, 0.000001)))
    }
}
