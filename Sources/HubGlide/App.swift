import AppKit
import ApplicationServices

@main
final class HubGlideApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let bridge = ScrollBridge()
    private let defaults = UserDefaults.standard
    private var item: NSStatusItem!
    private var permissionTimer: Timer?
    private var selectionPanel: SelectionPanel?
    private var calibratedWindow: HubWindow?

    static func main() {
        let app = NSApplication.shared
        let delegate = HubGlideApp()
        app.setActivationPolicy(.accessory)
        app.delegate = delegate
        app.run()
        withExtendedLifetime(delegate) {}
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "arrow.up.and.down", accessibilityDescription: "HubGlide")
        item.button?.toolTip = "HubGlide"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        bridge.enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        bridge.gain = defaults.object(forKey: "gain") as? CGFloat ?? 1
        if let bytes = defaults.data(forKey: "screen") {
            bridge.selection = try? JSONDecoder().decode(ScreenSelection.self, from: bytes)
        }
        bridge.connect()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.bridge.connect()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        permissionTimer?.invalidate()
        bridge.finish()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let status: String
        if !AXIsProcessTrusted() { status = "Accessibility access required" }
        else if !bridge.isListening { status = "Scroll input unavailable" }
        else if bridge.selection == nil { status = "Select the simulator screen" }
        else { status = bridge.enabled ? "Ready for Device Hub" : "Paused" }
        let heading = NSMenuItem(title: status, action: nil, keyEquivalent: "")
        heading.isEnabled = false
        menu.addItem(heading)
        menu.addItem(.separator())
        let enabled = add("Enable scrolling", #selector(toggle), to: menu)
        enabled.state = bridge.enabled ? .on : .off
        add("Select simulator screen…", #selector(pickScreen), to: menu)
        if !bridge.isListening {
            add("Open Accessibility settings…", #selector(showPermission), to: menu)
        }
        let speed = NSMenuItem(title: "Sensitivity", action: nil, keyEquivalent: "")
        let choices = NSMenu()
        for (index, entry) in [("Gentle", 0.65), ("Standard", 1.0), ("Fast", 1.45)].enumerated() {
            let choice = add(entry.0, #selector(changeGain(_:)), to: choices)
            choice.tag = index
            choice.state = bridge.gain == entry.1 ? .on : .off
        }
        speed.submenu = choices
        menu.addItem(speed)
        menu.addItem(.separator())
        add("Quit HubGlide", #selector(quit), to: menu)
    }

    @discardableResult
    private func add(_ title: String, _ selector: Selector, to menu: NSMenu) -> NSMenuItem {
        let row = menu.addItem(withTitle: title, action: selector, keyEquivalent: "")
        row.target = self
        return row
    }

    @objc private func toggle() {
        bridge.enabled.toggle()
        defaults.set(bridge.enabled, forKey: "enabled")
    }

    @objc private func changeGain(_ sender: NSMenuItem) {
        bridge.gain = [0.65, 1.0, 1.45][sender.tag]
        defaults.set(Double(bridge.gain), forKey: "gain")
    }

    @objc private func showPermission() {
        let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func pickScreen() {
        guard selectionPanel == nil else { return }
        guard let app = DeviceHub.application else {
            let alert = NSAlert()
            alert.messageText = "Open a simulator in Device Hub first"
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        bridge.finish()
        app.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            self?.showPicker()
        }
    }

    private func showPicker() {
        guard selectionPanel == nil,
              let window = DeviceHub.window(), let frame = window.appKitFrame else { return }
        let panel = SelectionPanel(contentRect: frame, styleMask: [.borderless],
                                   backing: .buffered, defer: false)
        let view = SelectionView(frame: CGRect(origin: .zero, size: frame.size))
        calibratedWindow = window
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.contentView = view
        panel.onCancel = { [weak self] in self?.closePicker() }
        view.onSelect = { [weak self] rect in self?.saveSelection(rect) }
        selectionPanel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    private func saveSelection(_ rect: CGRect) {
        guard let window = calibratedWindow else { return }
        let selection = ScreenSelection(windowSize: window.frame.size, relativeRect: rect)
        guard selection.screen(in: window.frame) != nil,
              let bytes = try? JSONEncoder().encode(selection) else { return }
        bridge.selection = selection
        defaults.set(bytes, forKey: "screen")
        closePicker()
    }

    private func closePicker() {
        selectionPanel?.close()
        selectionPanel = nil
        calibratedWindow = nil
        DeviceHub.application?.activate()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
