import Foundation

@main struct HoverDetailControllerTests {
    static func main() {
        final class TestScheduler {
            struct Entry { let delay: TimeInterval; let token: HoverDelayToken; let action: () -> Void }
            var entries: [Entry] = []

            func schedule(_ delay: TimeInterval, _ action: @escaping () -> Void) -> HoverDelayToken {
                let token = HoverDelayToken()
                entries.append(Entry(delay: delay, token: token, action: action))
                return token
            }
            func fireLast(after delay: TimeInterval) {
                guard let entry = entries.last(where: { $0.delay == delay }) else {
                    fatalError("missing scheduled callback for \(delay)")
                }
                entry.action()
            }
        }

        let scheduler = TestScheduler()
        var transitions: [HoverDetailState] = []
        let controller = HoverDetailController(schedule: scheduler.schedule) { transitions.append($0) }

        controller.pointerEnteredWidget()
        precondition(controller.state == .closed)
        scheduler.fireLast(after: 0.35)
        precondition(controller.state == .transient)

        controller.pointerExitedWidget()
        controller.pointerEnteredDetail()
        scheduler.fireLast(after: 0.25) // cancelled callbacks must not close a detail in transit.
        precondition(controller.state == .transient)
        controller.pointerExitedDetail()
        scheduler.fireLast(after: 0.25)
        precondition(controller.state == .closed)

        controller.pointerEnteredWidget()
        scheduler.fireLast(after: 0.35)
        controller.togglePinned()
        precondition(controller.state == .pinned)
        controller.pointerExitedWidget()
        scheduler.fireLast(after: 0.25)
        precondition(controller.state == .pinned, "pointer exit must not close pinned details")
        controller.togglePinned()
        precondition(controller.state == .closed)

        controller.pointerEnteredWidget()
        controller.dragStarted()
        scheduler.fireLast(after: 0.35)
        precondition(controller.state == .closed, "drag must cancel a pending hover open")

        controller.pointerEnteredWidget()
        scheduler.fireLast(after: 0.35)
        controller.dragStarted()
        precondition(controller.state == .closed, "drag must close a transient detail")

        controller.pointerEnteredWidget()
        scheduler.fireLast(after: 0.35)
        controller.close()
        precondition(controller.state == .closed, "layout changes and visibility cleanup must close details")
        precondition(transitions == [.transient, .closed, .transient, .pinned, .closed, .transient, .closed, .transient, .closed])
        print("PASS: hover open, transit, exit, pin, drag, and cleanup state transitions")
    }
}
