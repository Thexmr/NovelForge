import XCTest
@testable import NovelForge

/// Tests für den Kinder-/Minderjährigen-Schutzfilter (`ContentSafetyFilter`).
/// Stellt sicher, dass die harte Sperre nicht versehentlich kaputtgeht.
@MainActor
final class ContentSafetyTests: XCTestCase {

    // MARK: - Muss blockieren (sexueller Kontext + Minderjährigkeit)

    func testBlocksDigitAgeNearSexual() {
        XCTAssertFalse(ContentSafetyFilter.isSafe(
            "Sie war erst 15 Jahre alt, als es zur Penetration kam."))
    }

    func testBlocksMinorWordNearSexual() {
        XCTAssertFalse(ContentSafetyFilter.isSafe(
            "Das Kind lag nackt da, und er drang in sie ein."))
    }

    func testBlocksWrittenOutChildAge() {
        XCTAssertFalse(ContentSafetyFilter.isSafe(
            "Ein vierzehnjähriges Mädchen, und dann begann die Penetration."))
    }

    func testBlocksUnderageEnglish() {
        XCTAssertFalse(ContentSafetyFilter.isSafe(
            "The underage girl and the man had sex."))
    }

    // MARK: - Muss erlaubt sein (keine Fehlalarme)

    func testAllowsAdultErotica() {
        XCTAssertTrue(ContentSafetyFilter.isSafe(
            "Die beiden Erwachsenen, beide Mitte dreißig, erlebten einen intensiven Orgasmus bei der Penetration."))
    }

    func testAllowsChildInNonSexualScene() {
        XCTAssertTrue(ContentSafetyFilter.isSafe(
            "Das Kind spielte im Kindergarten und malte ein Bild für die Mutter."))
    }

    func testAllowsAdultAgeNearSexual() {
        XCTAssertTrue(ContentSafetyFilter.isSafe(
            "Die 19-jährige Studentin und ihr Freund hatten Sex."))
    }

    func testDoesNotFalseFlagChildhoodWord() {
        // "Kindheit" darf NICHT als Minderjährigkeits-Hinweis zählen, auch nahe
        // einem sexuellen Marker.
        XCTAssertTrue(ContentSafetyFilter.isSafe(
            "Er dachte an seine Kindheit, dann hatten die beiden Erwachsenen Sex mit viel Leidenschaft."))
    }

    // MARK: - violation() liefert Begründung bzw. nil

    func testViolationReturnsReasonWhenUnsafe() {
        XCTAssertNotNil(ContentSafetyFilter.violation(in: "Sie war 16 Jahre alt. Sein Penis war hart."))
    }

    func testViolationIsNilForHarmlessText() {
        XCTAssertNil(ContentSafetyFilter.violation(in: "Ein ganz normaler Spaziergang im Park bei Sonnenschein."))
    }

    // MARK: - Erweiterte Abdeckung (Kind-Substantive, ausgeschriebene Alter)

    func testBlocksChildNounMaedchen() {
        XCTAssertFalse(ContentSafetyFilter.isSafe(
            "Die Figur, das Mädchen, war beteiligt. Er hatte Sex mit ihr."))
    }

    func testBlocksChildRelationSohn() {
        XCTAssertFalse(ContentSafetyFilter.isSafe(
            "Er missbrauchte seinen Sohn beim Geschlechtsverkehr."))
    }

    func testBlocksWrittenAgeJahreAlt() {
        XCTAssertFalse(ContentSafetyFilter.isSafe(
            "Sie war acht Jahre alt, und es kam zum Orgasmus."))
    }

    // MARK: - Fehlalarme vermeiden (harmlose Erwachsenen-Kontexte)

    func testAllowsKinderwunschAfterSex() {
        XCTAssertTrue(ContentSafetyFilter.isSafe(
            "Nach dem leidenschaftlichen Sex sprachen sie über ein gemeinsames Kind."))
    }

    func testAllowsBabySimile() {
        XCTAssertTrue(ContentSafetyFilter.isSafe(
            "Sie hatten Sex, danach lag sein Kopf auf ihrer Brust wie ein Baby."))
    }

    func testAllowsJungeFrau() {
        XCTAssertTrue(ContentSafetyFilter.isSafe(
            "Die junge Frau stöhnte vor Lust, als sie sich liebten und Sex hatten."))
    }

    func testAllowsChildrenPlayingNearby() {
        XCTAssertTrue(ContentSafetyFilter.isSafe(
            "Sein Penis war hart. Draußen spielten die Kinder im Garten."))
    }

    /// Regression: Teiltreffer in längeren Zahlen dürfen NICHT als Minderjährigkeit
    /// gewertet werden („115 Jahre" ist nicht „15 Jahre").
    func testDoesNotFlagThreeDigitAgesAsUnderage() {
        XCTAssertTrue(ContentSafetyFilter.isSafe(
            "Der Vampir war 115 Jahre alt, als sie leidenschaftlichen Sex hatten."))
    }

    func testStillFlagsRealUnderageAgeNearSexualContent() {
        XCTAssertFalse(ContentSafetyFilter.isSafe(
            "Sie war 15 Jahre alt, als die Szene in expliziten Sex überging."))
    }
}
