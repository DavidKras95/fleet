import XCTest
@testable import Fleet

/// A notification should fire only when a session *transitions into* needing
/// input — not every poll while it sits there, and not for other states.
final class NotificationTriggerTests: XCTestCase {
    typealias S = AgentSession.State

    func testFiresWhenSessionEntersInput() {
        let fire = NotificationTrigger.newlyNeedingInput(
            previous: ["a": S.busy], current: ["a": S.input])
        XCTAssertEqual(fire, ["a"])
    }

    func testDoesNotRefireWhileAlreadyInput() {
        let fire = NotificationTrigger.newlyNeedingInput(
            previous: ["a": S.input], current: ["a": S.input])
        XCTAssertTrue(fire.isEmpty)
    }

    func testFiresForBrandNewSessionAlreadyNeedingInput() {
        let fire = NotificationTrigger.newlyNeedingInput(
            previous: [:], current: ["a": S.input])
        XCTAssertEqual(fire, ["a"])
    }

    func testIgnoresNonInputTransitions() {
        let fire = NotificationTrigger.newlyNeedingInput(
            previous: ["a": S.done], current: ["a": S.busy])
        XCTAssertTrue(fire.isEmpty)
    }
}
