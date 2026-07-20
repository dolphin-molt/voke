import AppKit
import ApplicationServices
import Foundation

@MainActor
final class ScrollOutputService {
    private var tasks: [String: Task<Void, Never>] = [:]

    func press(direction: ScrollDirection, id: String) {
        guard tasks[id] == nil else { return }
        post(direction)
        tasks[id] = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(110))
            while !Task.isCancelled {
                self?.post(direction)
                try? await Task.sleep(for: .milliseconds(24))
            }
        }
    }

    func release(id: String) {
        tasks.removeValue(forKey: id)?.cancel()
    }

    func releaseAll() {
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
    }

    private func post(_ direction: ScrollDirection) {
        let vertical: Int32
        let horizontal: Int32
        switch direction {
        case .up: (vertical, horizontal) = (5, 0)
        case .down: (vertical, horizontal) = (-5, 0)
        case .left: (vertical, horizontal) = (0, 5)
        case .right: (vertical, horizontal) = (0, -5)
        }
        guard let event = CGEvent(
            scrollWheelEvent2Source: CGEventSource(stateID: .combinedSessionState),
            units: .pixel,
            wheelCount: 2,
            wheel1: vertical,
            wheel2: horizontal,
            wheel3: 0
        ) else { return }
        event.post(tap: .cghidEventTap)
    }
}
