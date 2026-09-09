import AppKit

@main struct GenerateBrand {
    static let blue = CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [35.0/255, 92.0/255, 214.0/255, 1])!
    static let light = CGColor(colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!, components: [137.0/255, 167.0/255, 234.0/255, 1])!
    static func png(size: Int, app: Bool, to path: String) throws {
        let c = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let s = CGFloat(size)
        c.translateBy(x: 0, y: s); c.scaleBy(x: 1, y: -1)
        let inset = app ? s * 0.078125 : s * 0.03125
        let tile = CGRect(x: inset, y: inset, width: s - 2*inset, height: s - 2*inset)
        c.setFillColor(blue)
        c.addPath(CGPath(roundedRect: tile, cornerWidth: s * (app ? 0.19 : 0.20), cornerHeight: s * (app ? 0.19 : 0.20), transform: nil)); c.fillPath()
        let mark = CGRect(x: s * 0.23, y: s * 0.21, width: s * 0.54, height: s * 0.54)
        c.setLineWidth(mark.width * 0.1125); c.setLineCap(.round); c.setLineJoin(.round)
        c.setStrokeColor(CGColor(gray: 1, alpha: 1)); c.addPath(RepriseMarkGeometry.loop(in: mark)); c.strokePath()
        c.setStrokeColor(light); c.addPath(RepriseMarkGeometry.tail(in: mark)); c.strokePath()
        let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
    }
    static func main() throws {
        let root = CommandLine.arguments[1]
        let manager = FileManager.default
        let iconset = root + "/Brand/Reprise.iconset"
        try manager.createDirectory(atPath: iconset, withIntermediateDirectories: true)
        for n in [16, 32, 128, 256, 512] {
            try png(size: n, app: true, to: iconset + "/icon_\(n)x\(n).png")
            try png(size: n*2, app: true, to: iconset + "/icon_\(n)x\(n)@2x.png")
        }
        for n in [16, 32, 48, 128] { try png(size: n, app: false, to: root + "/Extension/icons/reprise-\(n).png") }
        try png(size: 1024, app: true, to: root + "/Brand/Reprise-icon.png")
    }
}
