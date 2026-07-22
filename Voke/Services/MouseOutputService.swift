import ApplicationServices
import Foundation

struct MouseMotionPlanner {
    static func delta(
        x: CGFloat,
        y: CGFloat,
        deadZone: CGFloat = 0.14,
        maximumSpeed: CGFloat = 18
    ) -> CGPoint {
        let magnitude = min(1, hypot(x, y))
        guard magnitude > deadZone else { return .zero }

        let normalized = (magnitude - deadZone) / (1 - deadZone)
        let speed = 1.2 + pow(normalized, 1.65) * (maximumSpeed - 1.2)
        return CGPoint(
            x: x / magnitude * speed,
            y: -y / magnitude * speed
        )
    }
}

enum MouseClickEventFactory {
    static func leftClick(at position: CGPoint) -> (down: CGEvent, up: CGEvent)? {
        // A Control-modified left click is a secondary click on macOS. Use a
        // private source and clear flags so a Voke "left click" stays a plain
        // primary click even while another mapped modifier is being released.
        guard let source = CGEventSource(stateID: .privateState),
              let down = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseDown,
                mouseCursorPosition: position,
                mouseButton: .left
              ),
              let up = CGEvent(
                mouseEventSource: source,
                mouseType: .leftMouseUp,
                mouseCursorPosition: position,
                mouseButton: .left
              )
        else { return nil }

        for event in [down, up] {
            event.flags = []
            event.setIntegerValueField(.mouseEventButtonNumber, value: 0)
            event.setIntegerValueField(.mouseEventClickState, value: 1)
        }
        return (down, up)
    }
}

@MainActor
final class MouseOutputService {
    private var delta = CGPoint.zero
    private var movementTask: Task<Void, Never>?

    func updateStick(x: Float, y: Float, enabled: Bool) {
        guard enabled else {
            stopMoving()
            return
        }

        delta = MouseMotionPlanner.delta(x: CGFloat(x), y: CGFloat(y))
        guard delta != .zero else {
            stopMoving()
            return
        }
        startMovingIfNeeded()
    }

    func clickLeft() {
        guard let position = CGEvent(source: nil)?.location,
              let events = MouseClickEventFactory.leftClick(at: position)
        else { return }
        events.down.post(tap: .cghidEventTap)
        events.up.post(tap: .cghidEventTap)
    }

    func stopMoving() {
        delta = .zero
        movementTask?.cancel()
        movementTask = nil
    }

    private func startMovingIfNeeded() {
        guard movementTask == nil else { return }
        movementTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.postMovement()
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    private func postMovement() {
        guard delta != .zero,
              let current = CGEvent(source: nil)?.location,
              let source = CGEventSource(stateID: .combinedSessionState),
              let event = CGEvent(
                mouseEventSource: source,
                mouseType: .mouseMoved,
                mouseCursorPosition: CGPoint(x: current.x + delta.x, y: current.y + delta.y),
                mouseButton: .left
              )
        else { return }
        event.post(tap: .cghidEventTap)
    }
}
