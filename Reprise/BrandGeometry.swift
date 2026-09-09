import CoreGraphics

/// The same open-R outline is used in SwiftUI, the menu bar and exported icons.
enum RepriseMarkGeometry {
    static func loop(in rect: CGRect) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 5, y: 27))
        p.addLine(to: CGPoint(x: 5, y: 11))
        p.addCurve(to: CGPoint(x: 13, y: 3), control1: CGPoint(x: 5, y: 6.6), control2: CGPoint(x: 8.6, y: 3))
        p.addLine(to: CGPoint(x: 17, y: 3))
        p.addCurve(to: CGPoint(x: 27, y: 13), control1: CGPoint(x: 23.6, y: 3), control2: CGPoint(x: 27, y: 7.6))
        p.addCurve(to: CGPoint(x: 18, y: 22), control1: CGPoint(x: 27, y: 18.4), control2: CGPoint(x: 23.4, y: 22))
        p.addLine(to: CGPoint(x: 12, y: 22))
        var t = CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: rect.width / 32, y: rect.height / 32)
        return p.copy(using: &t)!
    }
    static func tail(in rect: CGRect) -> CGPath {
        let p = CGMutablePath(); p.move(to: CGPoint(x: 18, y: 22)); p.addLine(to: CGPoint(x: 27, y: 29))
        var t = CGAffineTransform(translationX: rect.minX, y: rect.minY).scaledBy(x: rect.width / 32, y: rect.height / 32)
        return p.copy(using: &t)!
    }
}
