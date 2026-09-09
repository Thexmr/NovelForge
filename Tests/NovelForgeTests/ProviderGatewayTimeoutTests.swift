import XCTest
@testable import NovelForge

final class ProviderGatewayTimeoutTests: XCTestCase {
    func testLongFormGenerationsReceiveSufficientRequestBudget() {
        XCTAssertEqual(ProviderGateway.longFormRequestTimeout, 15 * 60)
        XCTAssertEqual(ProviderGateway.longFormResourceTimeout, 30 * 60)
        XCTAssertGreaterThan(
            ProviderGateway.longFormRequestTimeout,
            5 * 60,
            "Langform-Anfragen dürfen nicht nach der früheren Fünf-Minuten-Grenze abbrechen."
        )
        XCTAssertGreaterThanOrEqual(
            ProviderGateway.longFormResourceTimeout,
            ProviderGateway.longFormRequestTimeout,
            "Die Ressourcenfrist muss mindestens die Anfragefrist abdecken."
        )
    }
}
