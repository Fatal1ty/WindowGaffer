import CoreGraphics
import XCTest
@testable import WindowGafferCore

final class SnapEngineTests: XCTestCase {
    func testSnapsMovingLeftEdgeToOtherRightEdge() {
        let moving = CGRect(x: 107, y: 10, width: 40, height: 30)
        let other = CGRect(x: 50, y: 10, width: 50, height: 30)

        let result = SnapEngine.snap(moving, to: [other], threshold: 10)

        XCTAssertEqual(result.frame.origin.x, 100)
        XCTAssertTrue(result.snappedHorizontally)
    }

    func testSnapsMovingBottomEdgeToOtherTopEdge() {
        let moving = CGRect(x: 20, y: 87, width: 40, height: 30)
        let other = CGRect(x: 20, y: 40, width: 40, height: 40)

        let result = SnapEngine.snap(moving, to: [other], threshold: 10)

        XCTAssertEqual(result.frame.origin.y, 80)
        XCTAssertTrue(result.snappedVertically)
    }

    func testDoesNotSnapOutsideThreshold() {
        let moving = CGRect(x: 120, y: 10, width: 40, height: 30)
        let other = CGRect(x: 50, y: 10, width: 50, height: 30)

        let result = SnapEngine.snap(moving, to: [other], threshold: 10)

        XCTAssertEqual(result.frame.origin.x, 120)
        XCTAssertFalse(result.snappedHorizontally)
    }

    func testSnapsToScreenRightEdge() {
        let moving = CGRect(x: 954, y: 100, width: 60, height: 30)
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)

        let result = SnapEngine.snap(
            moving,
            to: [],
            screenFrames: [screen],
            threshold: 15
        )

        XCTAssertEqual(result.frame.origin.x, 940)
        XCTAssertTrue(result.snappedHorizontally)
    }

    func testFarAwayOverlayDoesNotInfluencePerpendicularAxis() {
        let moving = CGRect(x: 130, y: 500, width: 40, height: 30)
        let other = CGRect(x: 50, y: 10, width: 50, height: 30)

        let result = SnapEngine.snap(moving, to: [other], threshold: 10)

        XCTAssertEqual(result.frame.origin.x, 130)
    }

    func testAlignsCentersInAHorizontalRowWithoutTouching() {
        let moving = CGRect(x: 300, y: 106, width: 40, height: 30)
        let other = CGRect(x: 50, y: 100, width: 80, height: 40)

        let result = SnapEngine.snap(moving, to: [other], threshold: 10)

        XCTAssertEqual(result.frame.midY, other.midY)
        XCTAssertTrue(result.snappedVertically)
    }

    func testAlignsCentersInAVerticalColumnWithoutTouching() {
        let moving = CGRect(x: 86, y: 300, width: 40, height: 30)
        let other = CGRect(x: 50, y: 40, width: 100, height: 50)

        let result = SnapEngine.snap(moving, to: [other], threshold: 10)

        XCTAssertEqual(result.frame.midX, other.midX)
        XCTAssertTrue(result.snappedHorizontally)
    }
}
