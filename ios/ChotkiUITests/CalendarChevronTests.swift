import XCTest

/// The chevron under the calendar opens and closes the month, whichever day is selected.
///
/// It once stopped working on days whose picture happened to be positioned so that its (larger than
/// the card, invisible) touch area covered the chevron: XCUITest reported the chevron as present but
/// not hittable, and neither a finger nor an accessibility tap reached it.
final class CalendarChevronTests: XCTestCase {

    private func tap(_ app: XCUIApplication, _ x: CGFloat, _ y: CGFloat) {
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: x, dy: y)).tap()
    }

    func testChevronClosesTheMonthWhenAnotherDayIsSelected() throws {
        let app = XCUIApplication()
        app.launch()
        let open = app.buttons["Show the whole month"]
        XCTAssertTrue(open.waitForExistence(timeout: 15), "the week strip's chevron is there")
        // The opening mark plays over the app for a few seconds; wait for it to leave.
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == true"), object: open)
        XCTAssertEqual(XCTWaiter().wait(for: [ready], timeout: 15), .completed, "the opening finished")

        // Tomorrow's chip, then open the month.
        tap(app, 251, 200)
        XCTAssertTrue(open.isHittable)
        open.tap()
        let close = app.buttons["Show one week"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "the month opened")

        // The chevron must be reachable, not merely present.
        XCTAssertTrue(close.isHittable, "something covers the chevron")
        close.tap()
        XCTAssertTrue(app.buttons["Show the whole month"].waitForExistence(timeout: 5), "the month closed again")
    }
}
