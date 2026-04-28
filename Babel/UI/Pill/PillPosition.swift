import AppKit
import Foundation

enum PillPosition: String, CaseIterable, Identifiable, Sendable {
    case bottomCenter = "bottom_center"
    case topCenter = "top_center"
    case bottomLeft = "bottom_left"
    case bottomRight = "bottom_right"
    case topLeft = "top_left"
    case topRight = "top_right"

    static let userDefaultsKey = "babel.pillPosition"
    static let `default`: PillPosition = .bottomCenter

    static var current: PillPosition {
        guard
            let raw = UserDefaults.standard.string(forKey: userDefaultsKey),
            let value = PillPosition(rawValue: raw)
        else { return .default }
        return value
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bottomCenter: "Bottom (center)"
        case .topCenter: "Top (center)"
        case .bottomLeft: "Bottom left"
        case .bottomRight: "Bottom right"
        case .topLeft: "Top left"
        case .topRight: "Top right"
        }
    }

    /// Distance to keep from the relevant screen edge.
    private static let edgeInset: CGFloat = 80
    /// Side inset for left/right anchored positions.
    private static let sideInset: CGFloat = 40

    /// Top-left origin (Cocoa Y-up coordinates) for a pill of `size` on
    /// `screen`'s `visibleFrame`.
    func origin(for size: CGSize, on screen: NSScreen) -> NSPoint {
        let v = screen.visibleFrame
        let inset = Self.edgeInset
        let side = Self.sideInset

        let x: CGFloat
        switch self {
        case .bottomCenter, .topCenter:
            x = v.midX - size.width / 2
        case .bottomLeft, .topLeft:
            x = v.minX + side
        case .bottomRight, .topRight:
            x = v.maxX - size.width - side
        }

        let y: CGFloat
        switch self {
        case .bottomCenter, .bottomLeft, .bottomRight:
            y = v.minY + inset
        case .topCenter, .topLeft, .topRight:
            y = v.maxY - size.height - inset
        }

        return NSPoint(x: x, y: y)
    }
}
