import XCTest
@testable import Babel

final class TranscriptAccumulatorTests: XCTestCase {

    func testEmptyAccumulatorSnapshotsToEmptyString() {
        XCTAssertEqual(TranscriptAccumulator().snapshot(), "")
    }

    func testAppendFinalConcatenatesWithSpaces() {
        let acc = TranscriptAccumulator()
        acc.appendFinal("Hi my name is Matt")
        acc.appendFinal("what about yours")
        XCTAssertEqual(acc.snapshot(), "Hi my name is Matt what about yours")
    }

    func testSetPartialAppearsAfterFinals() {
        let acc = TranscriptAccumulator()
        acc.appendFinal("First sentence.")
        acc.setPartial("second sentence still being typed")
        XCTAssertEqual(
            acc.snapshot(),
            "First sentence. second sentence still being typed"
        )
    }

    func testAppendFinalClearsThePartial() {
        let acc = TranscriptAccumulator()
        acc.setPartial("typing in progress")
        acc.appendFinal("typing in progress committed")
        // Partial is wiped by appendFinal — the engine has finalized that segment.
        XCTAssertEqual(acc.snapshot(), "typing in progress committed")
    }

    func testAppendFinalIgnoresWhitespaceOnlySegments() {
        let acc = TranscriptAccumulator()
        acc.appendFinal("hello")
        acc.appendFinal("   ")
        acc.appendFinal("\n\t  ")
        acc.appendFinal("world")
        XCTAssertEqual(acc.snapshot(), "hello world")
    }

    func testWhitespaceIsStrippedFromPartial() {
        let acc = TranscriptAccumulator()
        acc.setPartial("  spaced out  ")
        XCTAssertEqual(acc.snapshot(), "spaced out")
    }

    func testEmptyPartialDoesNotIntroduceTrailingSpace() {
        let acc = TranscriptAccumulator()
        acc.appendFinal("done")
        acc.setPartial("")
        XCTAssertEqual(acc.snapshot(), "done")
    }
}
