import SwiftUI

// Minimal adapters for the original SideNotchShape. Its path and springs are
// compiled directly from ../Sources/Notch, not approximated here.
enum NotchEdge { case right, left, top, bottom
    var isVertical: Bool { self == .right || self == .left }
}
struct HardwareNotch { let width: CGFloat; let height: CGFloat }
enum NotchLayout {
    static let curlRadius: CGFloat = 16
    static let cornerRadius: CGFloat = 28
    static let bezelFillet: CGFloat = 8
}
