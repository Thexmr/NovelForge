import XCTest
@testable import NovelForge

/// Tests für die Parser, die KI-Antworten in Strukturen übersetzen –
/// die kritischste Stelle der Pipeline: Wenn hier etwas bricht,
/// produziert die Pipeline leere Bücher.
final class ParserTests: XCTestCase {

    // MARK: - ConceptParser

    func testConceptParserParsesAllSections() {
        let text = """
        PRÄMISSE: Eine Frau entdeckt ein Geheimnis.
        LOGLINE: Ein Satz, der alles zusammenfasst.
        EXPOSÉ: Satz eins.
        Satz zwei.
        HAUPTKONFLIKT: Der zentrale Konflikt.
        THEMA: Verrat
        ZIELGRUPPE: Erwachsene Krimileser
        """
        let result = ConceptParser.parse(text)
        XCTAssertEqual(result.premise, "Eine Frau entdeckt ein Geheimnis.")
        XCTAssertEqual(result.logline, "Ein Satz, der alles zusammenfasst.")
        XCTAssertTrue(result.synopsis.contains("Satz eins."))
        XCTAssertTrue(result.synopsis.contains("Satz zwei."))
        XCTAssertEqual(result.mainConflict, "Der zentrale Konflikt.")
        XCTAssertEqual(result.theme, "Verrat")
        XCTAssertEqual(result.audience, "Erwachsene Krimileser")
    }

    func testConceptParserToleratesMarkdownNoise() {
        let result = ConceptParser.parse("**PRÄMISSE:** Test-Prämisse")
        XCTAssertEqual(result.premise, "Test-Prämisse")
    }

    func testConceptParserAcceptsAsciiLabels() {
        let result = ConceptParser.parse("PRAEMISSE: A\nEXPOSE: B")
        XCTAssertEqual(result.premise, "A")
        XCTAssertEqual(result.synopsis, "B")
    }

    // MARK: - StructureParser (Kapitel)

    func testChapterParserParsesAndRenumbers() {
        let text = """
        Hier ist der Kapitelplan:
        KAPITEL|1|Der Anfang|Held einführen|Innerer Zweifel
        - KAPITEL|2|Die Reise|Aufbruch wagen|Der Sturm
        KAPITEL|9|Lückenhafte Nummer|Wird renummeriert|Egal
        """
        let chapters = StructureParser.parseChapters(text)
        XCTAssertEqual(chapters.count, 3)
        XCTAssertEqual(chapters[0].title, "Der Anfang")
        XCTAssertEqual(chapters[0].goal, "Held einführen")
        XCTAssertEqual(chapters[1].conflict, "Der Sturm")
        // Modell-Nummern können lückenhaft sein – der Parser nummeriert fortlaufend.
        XCTAssertEqual(chapters[2].number, 3)
    }

    func testChapterParserIgnoresGarbage() {
        let chapters = StructureParser.parseChapters("Kein gültiges Format.\nKAPITEL ohne Pipe")
        XCTAssertTrue(chapters.isEmpty)
    }

    // MARK: - StructureParser (Szenen)

    func testSceneParserParsesAllFields() {
        let scenes = StructureParser.parseScenes("SZENE|1|Ich-Erzähler|Hafen|Nacht|Fliehen|Wachen|Verrat")
        XCTAssertEqual(scenes.count, 1)
        XCTAssertEqual(scenes[0].perspective, "Ich-Erzähler")
        XCTAssertEqual(scenes[0].location, "Hafen")
        XCTAssertEqual(scenes[0].time, "Nacht")
        XCTAssertEqual(scenes[0].goal, "Fliehen")
        XCTAssertEqual(scenes[0].obstacle, "Wachen")
        XCTAssertEqual(scenes[0].turn, "Verrat")
    }

    // MARK: - StructureParser (Figuren)

    func testCharacterParserParsesAllFields() {
        let characters = StructureParser.parseCharacters(
            "FIGUR|Anna Berg|Protagonistin|34|Ärztin|Wahrheit finden|Verlust|Stolz"
        )
        XCTAssertEqual(characters.count, 1)
        XCTAssertEqual(characters[0].name, "Anna Berg")
        XCTAssertEqual(characters[0].role, "Protagonistin")
        XCTAssertEqual(characters[0].age, "34")
        XCTAssertEqual(characters[0].occupation, "Ärztin")
        XCTAssertEqual(characters[0].goal, "Wahrheit finden")
        XCTAssertEqual(characters[0].fear, "Verlust")
        XCTAssertEqual(characters[0].weakness, "Stolz")
    }

    // MARK: - StructureParser (Konsistenzprobleme)

    func testIssueParserMapsSeverities() {
        let text = """
        PROBLEM|Kritisch|Zeitlinie|Widerspruch A|Fix A
        PROBLEM|Fehler|Logik|Widerspruch B|Fix B
        PROBLEM|Warnung|Figur|Widerspruch C|Fix C
        PROBLEM|Info|Stil|Hinweis D|Fix D
        KEINE PROBLEME
        """
        let issues = StructureParser.parseIssues(text)
        XCTAssertEqual(issues.count, 4)
        XCTAssertEqual(issues[0].severity, .critical)
        XCTAssertEqual(issues[1].severity, .error)
        XCTAssertEqual(issues[2].severity, .warning)
        XCTAssertEqual(issues[3].severity, .info)
    }

    // MARK: - KDPMetadataParser

    func testKDPMetadataParser() {
        let text = """
        VERKAUFSTEXT: Ein packender Roman.
        Zweite Zeile des Verkaufstexts.
        KEYWORDS: krimi hafen, ermittlerin, dunkles geheimnis
        KATEGORIEN: Belletristik > Krimis & Thriller
        Belletristik > Spannung
        """
        let result = KDPMetadataParser.parse(text)
        XCTAssertTrue(result.salesDescription.contains("Ein packender Roman."))
        XCTAssertTrue(result.salesDescription.contains("Zweite Zeile"))
        XCTAssertEqual(result.keywords, "krimi hafen, ermittlerin, dunkles geheimnis")
        XCTAssertTrue(result.categories.contains("Belletristik > Spannung"))
    }

    func testKDPMetadataParserExtractsSalesTitleAndSubtitle() {
        let text = """
        VERKAUFSTITEL: Sag, dass du bleibst
        UNTERTITEL: Ein Liebesroman über zweite Chancen
        VERKAUFSTEXT: Packender Roman.
        KEYWORDS: liebe, drama
        KATEGORIEN: Belletristik > Liebesroman
        """
        let result = KDPMetadataParser.parse(text)
        XCTAssertEqual(result.salesTitle, "Sag, dass du bleibst")
        XCTAssertEqual(result.subtitle, "Ein Liebesroman über zweite Chancen")
        XCTAssertTrue(result.salesDescription.contains("Packender Roman"))
        XCTAssertEqual(result.keywords, "liebe, drama")
    }

    func testParseTitleLinesStripsPrefixesAndDedupes() {
        let text = """
        TITEL: Sag, dass du bleibst
        2. „Die letzte Nacht“
        - Sag, dass du bleibst
        TITEL: Vergiss mich nicht
        """
        let titles = StructureParser.parseTitleLines(text)
        XCTAssertEqual(titles, ["Sag, dass du bleibst", "Die letzte Nacht", "Vergiss mich nicht"])
    }

    // MARK: - RepairIssueParser

    func testRepairIssueParserTargetsAffectedChapters() {
        let text = """
        REPAIR|Kritisch|Kapitel 3|Zeitlinie|Mara liest den Brief, bevor er gefunden wird.|Schreibe die Brief-Entdeckung so um, dass sie erst nach dem Fund passiert.
        REPAIR|Warnung|Gesamtmanuskript|Figurenlogik|Die Motivation des Antagonisten kippt.|Glätte die Motivationslinie in den betroffenen Kapiteln.
        Das hier ist Kommentar.
        """

        let issues = RepairIssueParser.parse(text)

        XCTAssertEqual(issues.count, 2)
        XCTAssertEqual(issues[0].severity, .critical)
        XCTAssertEqual(issues[0].chapterNumber, 3)
        XCTAssertEqual(issues[0].area, "Zeitlinie")
        XCTAssertTrue(issues[0].problem.contains("bevor er gefunden"))
        XCTAssertTrue(issues[0].instruction.contains("nach dem Fund"))
        XCTAssertNil(issues[1].chapterNumber)
        XCTAssertEqual(issues[1].severity, .warning)
    }

    func testRepairChapterPromptRepairsOnlyAffectedText() {
        let audit = PromptFactory.repairAudit(
            bookTitle: "Nacht über dem Hafen",
            summaries: "Kapitel 1: Test",
            characters: "Mara",
            qualityReports: "Warnung | Zeitlinie"
        )
        let prompt = PromptFactory.repairChapter(
            language: "Deutsch",
            bookTitle: "Nacht über dem Hafen",
            chapterNumber: 4,
            chapterTitle: "Die Schleuse",
            issue: RepairIssue(severity: .error,
                               chapterNumber: 4,
                               area: "Zeitlinie",
                               problem: "Die Figur kennt ein Geheimnis zu früh.",
                               instruction: "Setze die Erkenntnis erst in die zweite Hälfte des Kapitels."),
            chapterText: "Romantext"
        )

        XCTAssertTrue(audit.contains("Fehlerquelle"))
        XCTAssertTrue(audit.contains("automatisch behoben"))
        XCTAssertTrue(prompt.contains("NUR die betroffene Stelle"))
        XCTAssertTrue(prompt.contains("nicht das ganze Kapitel neu"))
        XCTAssertTrue(prompt.contains("Proofreader-Qualität"))
        XCTAssertTrue(prompt.contains("Fehlerquelle"))
        XCTAssertTrue(prompt.contains("Setze die Erkenntnis"))
    }
}

/// Tests für Preislogik, Wortzählung und KDP-Druckmaße.
final class HelperTests: XCTestCase {

    func testModelPricingPrefixMatching() {
        // Längere Präfixe müssen gewinnen: gpt-4o-mini darf nicht als gpt-4o zählen.
        XCTAssertEqual(ModelPricing.ratePer1K(model: "gpt-4o-mini"), 0.0003)
        XCTAssertEqual(ModelPricing.ratePer1K(model: "gpt-4o"), 0.0075)
        XCTAssertEqual(ModelPricing.ratePer1K(model: "claude-opus-4-8"), 0.015)
        XCTAssertEqual(ModelPricing.ratePer1K(model: "voellig-unbekannt"), 0)
    }

    func testModelPricingCostEstimate() {
        // 1000 Tokens gpt-4o ≈ 0,0075 USD
        XCTAssertEqual(ModelPricing.estimatedCost(model: "gpt-4o", tokens: 1000), 0.0075, accuracy: 0.000001)
    }

    func testWordCount() {
        XCTAssertEqual("Ein Test mit genau fünf".wordCount, 5)
        XCTAssertEqual("".wordCount, 0)
        XCTAssertEqual("  \n\t ".wordCount, 0)
    }

    func testTrimSizeGutterFollowsKDPTable() {
        XCTAssertEqual(TrimSize.gutterPoints(forPageCount: 100), 0.375 * 72)
        XCTAssertEqual(TrimSize.gutterPoints(forPageCount: 150), 0.375 * 72)
        XCTAssertEqual(TrimSize.gutterPoints(forPageCount: 151), 0.5 * 72)
        XCTAssertEqual(TrimSize.gutterPoints(forPageCount: 300), 0.5 * 72)
        XCTAssertEqual(TrimSize.gutterPoints(forPageCount: 500), 0.625 * 72)
        XCTAssertEqual(TrimSize.gutterPoints(forPageCount: 700), 0.75 * 72)
        XCTAssertEqual(TrimSize.gutterPoints(forPageCount: 800), 0.875 * 72)
    }

    func testTrimSizeDimensions() {
        XCTAssertEqual(TrimSize.sixByNine.pageWidth, 432)   // 6 Zoll
        XCTAssertEqual(TrimSize.sixByNine.pageHeight, 648)  // 9 Zoll
    }
}
