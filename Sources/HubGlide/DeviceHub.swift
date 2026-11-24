import AppKit
import CoreGraphics

struct HubWindow: Equatable {
    let pid: pid_t
    let id: CGWindowID
    let frame: CGRect

    var appKitFrame: CGRect? {
        guard let screen = NSScreen.screens.first else { return nil }
        return CGRect(x: frame.minX, y: screen.frame.maxY - frame.maxY, width: frame.width, height: frame.height)
    }
}

enum DeviceHub {
    static let bundleID = "com.apple.dt.Devices"

    static var application: NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    }

    static func window(at point: CGPoint? = nil) -> HubWindow? {
        guard let app = application,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                  as? [[String: Any]] else { return nil }

        for window in windows {
            guard window[kCGWindowLayer as String] as? Int == 0,
                  let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  let id = window[kCGWindowNumber as String] as? CGWindowID,
                  let bounds = window[kCGWindowBounds as String] as? [String: Any],
                  let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary) else { continue }

            if let point {
                guard frame.contains(point) else { continue }
                if pid != app.processIdentifier { return nil }
            }
            guard pid == app.processIdentifier, frame.width >= 220, frame.height >= 320 else { continue }
            return HubWindow(pid: pid, id: id, frame: frame)
        }
        return nil
    }
}
