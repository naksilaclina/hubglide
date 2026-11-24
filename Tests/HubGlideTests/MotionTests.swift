import XCTest
@testable import HubGlide

final class MotionTests: XCTestCase {
    func testSelectionMovesWithWindowAndRejectsResize() {
        let selection = ScreenSelection(windowSize: CGSize(width: 610, height: 800),
                                        relativeRect: CGRect(x: 150, y: 70, width: 300, height: 670))
        XCTAssertEqual(selection.screen(in: CGRect(x: 20, y: 30, width: 610, height: 800)),
                       CGRect(x: 174, y: 108, width: 292, height: 654))
        XCTAssertNil(selection.screen(in: CGRect(x: 20, y: 30, width: 635, height: 800)))
    }

    func testMotionAccumulatesAndReversesWithoutOvershoot() {
        var motion = Motion(origin: CGPoint(x: 25, y: 100), screen: CGRect(x: 0, y: 0, width: 200, height: 400))
        motion.receive(20)
        motion.receive(30)
        let first = motion.next(elapsed: 0.01)!
        XCTAssertGreaterThan(first.y, 100)
        XCTAssertLessThan(first.y, 150)
        for _ in 0..<30 { _ = motion.next(elapsed: 0.016) }
        XCTAssertEqual(motion.point.y, 150)
        motion.receive(-5)
        for _ in 0..<30 { _ = motion.next(elapsed: 0.016) }
        XCTAssertEqual(motion.point.y, 145)
    }

    func testTouchStaysInsideSelection() {
        var motion = Motion(origin: CGPoint(x: 25, y: 100), screen: CGRect(x: 0, y: 40, width: 200, height: 400))
        motion.receive(1000)
        for _ in 0..<30 { _ = motion.next(elapsed: 0.016) }
        XCTAssertEqual(motion.point.y, 439)
        motion.receive(-1000)
        for _ in 0..<30 { _ = motion.next(elapsed: 0.016) }
        XCTAssertEqual(motion.point.y, 40)
    }
}
