import AppKit
import SwiftUI

// Real backdrop sampling: the card takes its tint from the desktop behind it.
struct RepriseGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

enum Atelier {
    static let beige = Color(red: 240.0/255, green: 216.0/255, blue: 181.0/255)
    static let soft = Color(red: 189.0/255, green: 208.0/255, blue: 231.0/255)
    static let royal = Color(red: 50.0/255, green: 76.0/255, blue: 249.0/255)
    static let ink = Color(red: 0.055, green: 0.065, blue: 0.08)
    static let paper = Color(red: 0.97, green: 0.94, blue: 0.89)
}

// A fold, not a divider: the light bends into the same surface.
struct SurfaceFold: Shape {
    var left = false
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let x: CGFloat = left ? 34 : rect.width - 34
        let bend: CGFloat = left ? -12 : 12
        p.move(to: CGPoint(x: x, y: 0))
        p.addCurve(to: CGPoint(x: x + bend, y: rect.height), control1: CGPoint(x: x - bend, y: rect.height * 0.32), control2: CGPoint(x: x + bend, y: rect.height * 0.58))
        return p
    }
}

struct SourceGlyph: View {
    var note: ThreadNote
    var size: CGFloat = 24
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6).fill(Atelier.ink)
            if ["x.com", "twitter.com"].contains(note.url?.host ?? "") {
                Text("𝕏").font(.system(size: size * 0.6, weight: .regular))
            } else {
                Image(systemName: note.context?.kind == "video" ? "play.fill" : note.url == nil ? "text.alignleft" : note.url?.isFileURL == true ? "doc" : "globe")
                    .font(.system(size: size * 0.5))
            }
        }.foregroundStyle(.white).frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct SurfaceButton: ButtonStyle {
    var dark = false
    var filled = false
    func makeBody(configuration: Configuration) -> some View {
        ButtonSurfaceBody(configuration: configuration, dark: dark, filled: filled)
    }
    private struct ButtonSurfaceBody: View {
        let configuration: ButtonStyleConfiguration
        let dark: Bool
        let filled: Bool
        @State private var hover = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        var body: some View {
            configuration.label
                .foregroundStyle(dark ? Color.white.opacity(0.9) : Atelier.ink)
                .background((dark ? Color.white : Color.black).opacity(configuration.isPressed ? 0.16 : hover ? 0.1 : filled ? 0.045 : 0), in: Capsule())
                .overlay(Capsule().strokeBorder((dark ? Color.white : Color.black).opacity(filled ? 0.16 : hover ? 0.12 : 0), lineWidth: 0.5))
                .opacity(configuration.isPressed ? 0.7 : 1)
                .onHover { hover = $0 }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hover)
        }
    }
}
