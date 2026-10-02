import XCTest
@testable import Fleet

/// Guards the "Starting Claude…" progress banner logic: a session enters the
/// initializing set on spawn and leaves as soon as its state moves past idle.
final class InitializingSessionTests: XCTestCase {
    private func session(_ name: String, _ state: AgentSession.State) -> AgentSession {
        AgentSession(name: name, state: state)
    }

    func testIdleSessionStaysInitializing() {
        let result = FleetStore.pendingInitializing(
            current: ["proj/task"],
            sessions: [session("proj/task", .idle)])
        XCTAssertEqual(result, ["proj/task"])
    }

    func testDoneSessionClearsInitializing() {
        let result = FleetStore.pendingInitializing(
            current: ["proj/task"],
            sessions: [session("proj/task", .done)])
        XCTAssertTrue(result.isEmpty)
    }

    func testBusySessionClearsInitializing() {
        let result = FleetStore.pendingInitializing(
            current: ["proj/task"],
            sessions: [session("proj/task", .busy)])
        XCTAssertTrue(result.isEmpty)
    }

    func testInputSessionClearsInitializing() {
        let result = FleetStore.pendingInitializing(
            current: ["proj/task"],
            sessions: [session("proj/task", .input)])
        XCTAssertTrue(result.isEmpty)
    }

    func testDeletedSessionClearsInitializing() {
        // Session killed externally — don't leave it in the initializing set forever.
        let result = FleetStore.pendingInitializing(current: ["proj/task"], sessions: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testOtherSessionsUnaffected() {
        let result = FleetStore.pendingInitializing(
            current: ["proj/task"],
            sessions: [session("proj/task", .idle), session("other/task", .done)])
        XCTAssertEqual(result, ["proj/task"])
    }
}
