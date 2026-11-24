import AppKit
import CoreGraphics

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

    private var tap: CFMachPort?
    private var timer: Timer?
    private var gesture: Gesture?
    private var pending: CGFloat = 0
    private var pendingAt: TimeInterval = 0
    private var tickAt: TimeInterval = 0
    private let source = CGEventSource(stateID: .privateState)
    private var activePID: pid_t?
    private var observer: NSObjectProtocol?
    private var lastWindowCheck: TimeInterval = 0
    private var cachedWindow: HubWindow?
    private static let marker: Int64 = 0x485542474C494445

    var isListening: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

    func connect() {
        guard tap == nil, AXIsProcessTrusted() else { return }
        let types: [CGEventType] = [.scrollWheel, .leftMouseDown, .rightMouseDown, .otherMouseDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: mask,
            callback: { _, kind, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                let bridge = Unmanaged<ScrollBridge>.fromOpaque(context).takeUnretainedValue()
                return bridge.receive(kind, event: event) ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        guard let tap, let runLoopSource = CFMachPortCreateRunLoopSource(nil, tap, 0) else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        focusChanged(to: NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] notification in
            self?.focusChanged(to: notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func receive(_ kind: CGEventType, event: CGEvent) -> Bool {
        if kind == .tapDisabledByTimeout || kind == .tapDisabledByUserInput {
            finish()
            if let tap, AXIsProcessTrusted() { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        guard event.getIntegerValueField(.eventSourceUserData) != Self.marker else { return false }
        guard kind == .scrollWheel else {
            finish()
            return false
        }

        guard enabled,
              !event.flags.contains(.maskCommand),
              !event.flags.contains(.maskControl),
              !event.flags.contains(.maskAlternate),
              let activePID else {
            finish()
            return false
        }
        let point = CGEvent(source: nil)?.location ?? event.location
        let now = ProcessInfo.processInfo.systemUptime
        if cachedWindow?.frame.contains(point) != true || now - lastWindowCheck > 0.075 {
            cachedWindow = DeviceHub.window(at: point)
            lastWindowCheck = now
        }
        guard let window = cachedWindow, window.pid == activePID,
              let screen = selection?.screen(in: window.frame), screen.contains(point),
              let scroll = NSEvent(cgEvent: event) else {
            finish()
            return false
        }
        let vertical = scroll.scrollingDeltaY
        guard vertical != 0, abs(vertical) >= abs(scroll.scrollingDeltaX) else { return false }
        let delta = vertical * (scroll.hasPreciseScrollingDeltas ? 1 : 10) * gain

        if let active = gesture, active.window != window || abs(active.motion.origin.x - point.x) > 36 {
            finish()
        }

        if var active = gesture {
            active.motion.receive(delta)
            active.receivedAt = now
            gesture = active
            return true
        }

        guard NSEvent.pressedMouseButtons == 0 else { return false }
        if now - pendingAt > 0.16 { pending = 0 }
        pending += delta
        pendingAt = now
        guard abs(pending) >= 10 else { return true }

        // Leave room for the initial drag without starting on the status or home indicator.
        let start = CGPoint(x: point.x, y: min(screen.maxY - 22, max(screen.minY + 22, point.y)))
        var motion = Motion(origin: start, screen: screen)
        motion.receive(pending)
        pending = 0
        gesture = Gesture(window: window, motion: motion, receivedAt: now)
        post(.leftMouseDown, point: start, window: window)

        tickAt = now
        let next = Timer(timeInterval: 1 / 120, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(next, forMode: .common)
        timer = next
        return true
    }

    private func tick() {
        guard var active = gesture else { return }
        let now = ProcessInfo.processInfo.systemUptime
        guard activePID == active.window.pid,
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

    private func focusChanged(to app: NSRunningApplication?) {
        activePID = app?.bundleIdentifier == DeviceHub.bundleID ? app?.processIdentifier : nil
        cachedWindow = nil
        finish()
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
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
        else { return }
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        event.setIntegerValueField(.mouseEventClickState, value: 1)
        event.postToPid(window.pid)
    }
}
