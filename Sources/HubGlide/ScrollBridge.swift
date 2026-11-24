import AppKit
import CoreGraphics
import os

final class ScrollBridge {
    var enabled = true {
        didSet { if !enabled { finish() } }
    }
    var gain: CGFloat = 1
    var selection: ScreenSelection? {
        didSet { finish() }
    }

    private struct Gesture {
        let window: HubWindow
        var motion: Motion
        var receivedAt: TimeInterval
    }

    private var monitor: Any?
    private var timer: Timer?
    private var gesture: Gesture?
    private var pending: CGFloat = 0
    private var pendingAt: TimeInterval = 0
    private var tickAt: TimeInterval = 0
    private var lastWindowCheck: TimeInterval = 0
    private var cachedWindow: HubWindow?
    private let diagnostics = CommandLine.arguments.contains("--diagnose")
    private let log = Logger(subsystem: "io.github.naksilaclina.hubglide", category: "input")
    private var lastDiagnostic = ""

    var isListening: Bool { monitor != nil && AXIsProcessTrusted() }

    func connect() {
        guard AXIsProcessTrusted() else {
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
                finish()
            }
            return
        }
        guard monitor == nil else { return }

        // Observe AppKit's interpreted wheel events without intercepting Device Hub's other input.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.receive(event)
        }
        trace(monitor == nil ? "Monitor unavailable" : "Wheel monitor connected")
    }

    private func trace(_ message: String) {
        guard diagnostics, lastDiagnostic != message else { return }
        lastDiagnostic = message
        log.notice("\(message, privacy: .public)")
    }

    private func receive(_ scroll: NSEvent) {
        guard enabled,
              let foreground = NSWorkspace.shared.frontmostApplication,
              foreground.bundleIdentifier == DeviceHub.bundleID,
              scroll.modifierFlags.intersection([.command, .control, .option]).isEmpty else {
            cachedWindow = nil
            finish()
            return
        }
        guard let point = CGEvent(source: nil)?.location else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if gesture == nil || cachedWindow?.frame.contains(point) != true || now - lastWindowCheck > 0.075 {
            cachedWindow = DeviceHub.window(at: point)
            lastWindowCheck = now
        }
        guard let window = cachedWindow, window.pid == foreground.processIdentifier else {
            trace("Wheel event outside the Device Hub window")
            finish()
            return
        }
        guard let screen = selection?.screen(in: window.frame), screen.contains(point) else {
            trace("Wheel event outside the selected display or layout")
            finish()
            return
        }
        let vertical = scroll.scrollingDeltaY
        guard vertical != 0 else { return }
        trace("Vertical scroll received in simulator")
        let delta = vertical * (scroll.hasPreciseScrollingDeltas ? 1 : 10) * gain

        if let active = gesture, active.window != window || abs(active.motion.origin.x - point.x) > 36 {
            finish()
        }

        if var active = gesture {
            active.motion.receive(delta)
            active.receivedAt = now
            gesture = active
            return
        }

        guard NSEvent.pressedMouseButtons == 0 else { return }
        if now - pendingAt > 0.16 { pending = 0 }
        pending += delta
        pendingAt = now
        guard abs(pending) >= 10 else { return }

        // Leave room for the initial drag without starting on the status or home indicator.
        let start = CGPoint(x: point.x, y: min(screen.maxY - 22, max(screen.minY + 22, point.y)))
        var motion = Motion(origin: start, screen: screen)
        motion.receive(pending)
        pending = 0
        gesture = Gesture(window: window, motion: motion, receivedAt: now)
        trace("Simulator drag started")
        post(.leftMouseDown, point: start, window: window)

        tickAt = now
        let next = Timer(timeInterval: 1 / 120, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(next, forMode: .common)
        timer = next
        return
    }

    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        timer?.invalidate()
    }

    private func tick() {
        guard var active = gesture else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == active.window.pid,
              now - active.receivedAt < 0.18 else {
            finish()
            return
        }
        if let point = active.motion.next(elapsed: now - tickAt) {
            post(.leftMouseDragged, point: point, window: active.window)
            gesture = active
        }
        tickAt = now
    }

    func finish() {
        timer?.invalidate()
        timer = nil
        pending = 0
        if let active = gesture {
            gesture = nil
            post(.leftMouseUp, point: active.motion.point, window: active.window)
        }
    }

    private func post(_ type: CGEventType, point: CGPoint, window: HubWindow) {
        let source = CGEventSource(stateID: .privateState)
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
        else { return }
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.postToPid(window.pid)
    }
}
