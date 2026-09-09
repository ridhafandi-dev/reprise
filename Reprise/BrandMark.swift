import SwiftUI
import AppKit

struct RepriseMark: View {
    var color: Color = .primary
    var tail: Color? = nil
    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            let stroke = StrokeStyle(lineWidth: proxy.size.width * 0.1125, lineCap: .round, lineJoin: .round)
            ZStack {
                Path(RepriseMarkGeometry.loop(in: rect)).stroke(color, style: stroke)
                Path(RepriseMarkGeometry.tail(in: rect)).stroke(tail ?? color, style: stroke)
            }
        }.accessibilityHidden(true)
    }
}

enum RepriseBrand {
    static func menuIcon() -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            guard let c = NSGraphicsContext.current?.cgContext else { return false }
            c.setStrokeColor(NSColor.black.cgColor); c.setLineWidth(2)
            c.setLineCap(.round); c.setLineJoin(.round)
            c.addPath(RepriseMarkGeometry.loop(in: rect.insetBy(dx: 1, dy: 1))); c.strokePath()
            c.addPath(RepriseMarkGeometry.tail(in: rect.insetBy(dx: 1, dy: 1))); c.strokePath()
            return true
        }
        image.isTemplate = true; image.accessibilityDescription = "Reprise"
        return image
    }
}
