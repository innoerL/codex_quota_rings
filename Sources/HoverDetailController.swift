import Foundation

enum HoverDetailState: Equatable {
    case closed
    case transient
    case pinned
}

final class HoverDelayToken {
    fileprivate(set) var isCancelled = false
    func cancel() { isCancelled = true }
}

final class HoverDetailController {
    typealias Schedule = (_ delay: TimeInterval, _ action: @escaping () -> Void) -> HoverDelayToken

    private let schedule: Schedule
    private let onStateChange: (HoverDetailState) -> Void
    private var openToken: HoverDelayToken?
    private var exitToken: HoverDelayToken?
    private var pointerInWidget = false
    private var pointerInDetail = false
    private(set) var state: HoverDetailState = .closed

    init(schedule: @escaping Schedule = HoverDetailController.mainQueueSchedule,
         onStateChange: @escaping (HoverDetailState) -> Void) {
        self.schedule = schedule
        self.onStateChange = onStateChange
    }

    func pointerEnteredWidget() {
        pointerInWidget = true
        cancelExit()
        guard state == .closed else { return }
        scheduleOpen()
    }

    func pointerExitedWidget() {
        pointerInWidget = false
        if state == .closed { cancelOpen() }
        scheduleExitIfNeeded()
    }

    func pointerEnteredDetail() {
        pointerInDetail = true
        cancelExit()
    }

    func pointerExitedDetail() {
        pointerInDetail = false
        scheduleExitIfNeeded()
    }

    func dragStarted() {
        pointerInWidget = false
        cancelOpen()
        cancelExit()
        if state == .transient { setState(.closed) }
    }

    func togglePinned() {
        cancelOpen()
        cancelExit()
        setState(state == .pinned ? .closed : .pinned)
    }

    func close() {
        pointerInWidget = false
        pointerInDetail = false
        cancelOpen()
        cancelExit()
        setState(.closed)
    }

    private func scheduleOpen() {
        cancelOpen()
        openToken = schedule(0.35) { [weak self] in
            guard let self, self.state == .closed, self.pointerInWidget else { return }
            self.openToken = nil
            self.setState(.transient)
        }
    }

    private func scheduleExitIfNeeded() {
        guard state == .transient, !pointerInWidget, !pointerInDetail else { return }
        cancelExit()
        exitToken = schedule(0.25) { [weak self] in
            guard let self, self.state == .transient,
                  !self.pointerInWidget, !self.pointerInDetail else { return }
            self.exitToken = nil
            self.setState(.closed)
        }
    }

    private func cancelOpen() { openToken?.cancel(); openToken = nil }
    private func cancelExit() { exitToken?.cancel(); exitToken = nil }
    private func setState(_ newState: HoverDetailState) {
        guard state != newState else { return }
        state = newState
        onStateChange(newState)
    }

    private static func mainQueueSchedule(_ delay: TimeInterval, _ action: @escaping () -> Void) -> HoverDelayToken {
        let token = HoverDelayToken()
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard !token.isCancelled else { return }
            action()
        }
        return token
    }
}
