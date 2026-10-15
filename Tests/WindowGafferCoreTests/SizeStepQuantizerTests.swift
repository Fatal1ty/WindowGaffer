import CoreGraphics
import XCTest
@testable import WindowGafferCore

final class SizeStepQuantizerTests: XCTestCase {
    private let minimum = CGSize(width: 44, height: 38)
    private let maximum = CGSize(width: 244, height: 110)

    func testRoundsBothDimensionsToSharedSteps() {
        let result = SizeStepQuantizer.quantize(
            CGSize(width: 91, height: 57),
            minimum: minimum,
            maximum: maximum,
            widthStep: 20,
            heightStep: 12
        )

        XCTAssertEqual(result, CGSize(width: 84, height: 62))
    }

    func testClampsToMinimumSize() {
        let result = SizeStepQuantizer.quantize(
            CGSize(width: 1, height: 1),
            minimum: minimum,
            maximum: maximum,
            widthStep: 20,
            heightStep: 12
        )

        XCTAssertEqual(result, minimum)
    }

    func testClampsToMaximumSize() {
        let result = SizeStepQuantizer.quantize(
            CGSize(width: 1_000, height: 1_000),
            minimum: minimum,
            maximum: maximum,
            widthStep: 20,
            heightStep: 12
        )

        XCTAssertEqual(result, maximum)
    }
}
