import XCTest
@testable import Babel

final class SessionPhaseTests: XCTestCase {

    func testAllPhasesHaveLabels() {
        let phases: [SessionPhase] = [
            .idle, .listening, .processing, .inserting,
            .clipboardFallback, .error("something broke"),
        ]
        for phase in phases {
            XCTAssertFalse(phase.label.isEmpty, "\(phase) has empty label")
        }
    }

    func testErrorLabelIncludesMessage() {
        XCTAssertEqual(SessionPhase.error("boom").label, "Error: boom")
    }

    func testEqualityRespectsErrorPayload() {
        XCTAssertEqual(SessionPhase.error("a"), SessionPhase.error("a"))
        XCTAssertNotEqual(SessionPhase.error("a"), SessionPhase.error("b"))
        XCTAssertNotEqual(SessionPhase.idle, SessionPhase.processing)
    }

    func testBabelModeMetadata() {
        for mode in BabelMode.allCases {
            XCTAssertFalse(mode.displayName.isEmpty)
            XCTAssertFalse(mode.tagline.isEmpty)
            XCTAssertFalse(mode.sfSymbol.isEmpty)
        }
    }
}
