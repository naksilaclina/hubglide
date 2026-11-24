import Foundation

struct ScreenSelection: Codable {
    let windowSize: CGSize
    let relativeRect: CGRect

    func screen(in window: CGRect) -> CGRect? {
        guard abs(window.width - windowSize.width) <= 2,
              abs(window.height - windowSize.height) <= 2,
              relativeRect.width >= 80, relativeRect.height >= 100 else { return nil }
        let rect = relativeRect.offsetBy(dx: window.minX, dy: window.minY)
        return window.contains(rect) ? rect.insetBy(dx: 4, dy: 8) : nil
    }
}

struct Motion {
    let origin: CGPoint
    let screen: CGRect
    private(set) var targetY: CGFloat
    private(set) var point: CGPoint

    init(origin: CGPoint, screen: CGRect) {
        self.origin = origin
        self.screen = screen
        targetY = origin.y
        point = origin
    }

    mutating func receive(_ delta: CGFloat) {
        guard delta.isFinite else { return }
        targetY = max(screen.minY, min(screen.maxY - 1, targetY + delta))
    }

    mutating func next(elapsed: TimeInterval) -> CGPoint? {
        let remaining = targetY - point.y
        guard remaining != 0 else { return nil }
        let response = CGFloat(1 - exp(-max(0, min(elapsed, 0.032)) / 0.028))
        point.y = abs(remaining) < 1 ? targetY : point.y + remaining * response
        return point
    }
}
