import Foundation
import XCTest
@testable import EnglishPlus

final class Store0EnvironmentIsolationTests: XCTestCase {
    private let competitionAI = URL(
        string: "https://englishplus-ai-proxy.englishplus-ray.workers.dev/ai"
    )
    private let competitionEvidence = URL(
        string: "https://englishplus-ai-proxy.englishplus-ray.workers.dev"
    )
    private let productionAI = URL(
        string: "https://englishplus-ai-proxy-production.englishplus-ray.workers.dev/ai"
    )
    private let productionEvidence = URL(
        string: "https://englishplus-ai-proxy-production.englishplus-ray.workers.dev"
    )

    func testCompetitionAllowsIntentionalLocalMockWithoutBundledFirebase() {
        XCTAssertTrue(
            EnglishPlusEnvironmentBoundary.isValid(
                environment: .competition,
                expectedProjectID: "englishplus-testflight",
                aiEndpoint: competitionAI,
                evidenceEndpoint: competitionEvidence,
                bundledProjectID: nil
            )
        )
    }

    func testProductionRequiresMatchingBundledFirebaseProject() {
        XCTAssertFalse(
            EnglishPlusEnvironmentBoundary.isValid(
                environment: .production,
                expectedProjectID: "englishplus-production",
                aiEndpoint: productionAI,
                evidenceEndpoint: productionEvidence,
                bundledProjectID: nil
            )
        )
        XCTAssertTrue(
            EnglishPlusEnvironmentBoundary.isValid(
                environment: .production,
                expectedProjectID: "englishplus-production",
                aiEndpoint: productionAI,
                evidenceEndpoint: productionEvidence,
                bundledProjectID: "englishplus-production"
            )
        )
    }

    func testCrossEnvironmentFirebaseAndWorkerValuesAreRejected() {
        XCTAssertFalse(
            EnglishPlusEnvironmentBoundary.isValid(
                environment: .production,
                expectedProjectID: "englishplus-production",
                aiEndpoint: competitionAI,
                evidenceEndpoint: competitionEvidence,
                bundledProjectID: "englishplus-production"
            )
        )
        XCTAssertFalse(
            EnglishPlusEnvironmentBoundary.isValid(
                environment: .competition,
                expectedProjectID: "englishplus-testflight",
                aiEndpoint: competitionAI,
                evidenceEndpoint: competitionEvidence,
                bundledProjectID: "englishplus-production"
            )
        )
    }
}
