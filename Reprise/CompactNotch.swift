import SwiftUI
import UniformTypeIdentifiers

enum RepriseMetrics {
    static let closed = CGSize(width: 22, height: 76)
    static let open = CGSize(width: 288, height: 264)
    static func expandedSize(note: ThreadNote?, targeted: Bool) -> CGSize {
        CGSize(width: 288, height: targeted ? 196 : note == nil || note?.preview == note?.title ? 224 : 264)
    }
    static let canvas = CGSize(width: 288, height: 304)
    static let motion = Animation.spring(response: 0.30, dampingFraction: 0.91)
}

struct RepriseNotch: View {
    @ObservedObject var store: RepriseStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var body: some View {
        let size = store.isOpen ? RepriseMetrics.expandedSize(note: store.note, targeted: store.targeted) : RepriseMetrics.closed
        let alignment: Alignment = store.side == .right ? .trailing : .leading
        let shape = SideNotchShape(edge: store.side, curlRadius: 9, cornerRadius: 16)
        ZStack(alignment: alignment) {
            shape.fill(store.isOpen ? Color.clear : Ink.black).frame(width: size.width, height: size.height)
            if store.isOpen {
                content.frame(width: size.width, height: size.height)
                    .transition(.opacity.combined(with: .offset(x: store.side == .right ? 8 : -8)))
            } else {
                Button { store.reveal() } label: {
                    RepriseMark(color: store.note == nil ? Ink.muted : Ink.sky)
                        .frame(width: 13, height: 13)
                        .frame(width: 22, height: 76)
                }.buttonStyle(.plain).accessibilityLabel("Ouvrir le fil")
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .onDrop(of: [UTType.fileURL.identifier, UTType.url.identifier, UTType.utf8PlainText.identifier], isTargeted: $store.targeted, perform: acceptDrop)
        .animation(reduceMotion ? nil : RepriseMetrics.motion, value: size)
        .frame(width: RepriseMetrics.canvas.width, height: RepriseMetrics.canvas.height, alignment: alignment)
        .preferredColorScheme(.dark)
    }
    var content: some View {
        ZStack {
            RepriseGlass()
            Color(red: 0.04, green: 0.055, blue: 0.08).opacity(0.48)
            LinearGradient(colors: [Color.white.opacity(0.07), Ink.sky.opacity(0.06), Color.black.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing)
            SurfaceFold(left: store.side == .left)
                .stroke(Color.white.opacity(0.2), lineWidth: 8).blur(radius: 6)
                .accessibilityHidden(true)
            SurfaceFold(left: store.side == .left)
                .stroke(LinearGradient(colors: [.white.opacity(0.6), .white.opacity(0.12), .white.opacity(0.35)], startPoint: .top, endPoint: .bottom), lineWidth: 0.7)
                .accessibilityHidden(true)
            readingContent
                .padding(.leading, store.side == .left ? 40 : 16)
                .padding(.trailing, store.side == .right ? 40 : 16)
                .padding(.vertical, 24)
            VStack {
                Button { store.fold() } label: {
                    Image(systemName: store.side == .right ? "chevron.right" : "chevron.left")
                        .font(.system(size: 12)).frame(width: 28, height: 28)
                }.buttonStyle(SurfaceButton(dark: true, filled: true))
                    .accessibilityLabel("Refermer le fil").help("Refermer")
                Spacer()
                Menu {
                    Button("Mes fils") { store.showWelcome?() }
                    if store.note != nil { Button("Ranger le fil", action: store.release) }
                    if store.archive.previous != nil { Button("Annuler le dernier rangement", action: store.undo) }
                    Divider()
                    Button("Changer de bord") { store.side = store.side == .right ? .left : .right }
                } label: {
                    Image(systemName: "ellipsis").font(.system(size: 12)).frame(width: 28, height: 28)
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                    .accessibilityLabel("Actions du fil").help("Mes fils et rangement")
            }
            .padding(.vertical, 24).padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: store.side == .right ? .trailing : .leading)
        }
        .overlay {
            SideNotchShape(edge: store.side, curlRadius: 9, cornerRadius: 16)
                .stroke(.white.opacity(0.28), lineWidth: 0.7).allowsHitTesting(false)
        }
    }

    private var readingContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if store.targeted {
                Text("DÉPOSER ICI").font(.system(size: 11, weight: .medium)).tracking(1)
                Text("Garde la suite.").font(.system(size: 18, weight: .medium))
                Text("Un lien, un fichier ou un passage.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                Spacer(minLength: 8)
                Image(systemName: "arrow.down.to.line").font(.system(size: 18)).foregroundStyle(Ink.sky)
            } else if let note = store.note {
                HStack(spacing: 8) {
                    SourceGlyph(note: note, size: 18)
                    Text(store.notice.isEmpty ? note.kindLabel : store.notice)
                        .font(.system(size: 11, weight: .medium)).lineLimit(1)
                    Spacer(minLength: 0)
                    if let time = note.timeLabel { Text(time).font(.system(size: 11)).monospacedDigit() }
                }.foregroundStyle(.white.opacity(0.64))
                Text(note.title).font(.system(size: 18, weight: .medium)).tracking(-0.3)
                    .lineLimit(2).frame(maxWidth: .infinity, alignment: .leading).help(note.title)
                if !store.error.isEmpty {
                    Text(store.error).font(.system(size: 12)).foregroundStyle(Color(red: 1, green: 0.72, blue: 0.66)).lineLimit(3)
                } else if note.preview != note.title {
                    Text(note.preview).font(.system(size: 12)).foregroundStyle(.white.opacity(0.72)).lineLimit(2)
                }
                Text(note.context?.author?.isEmpty == false ? note.context!.author! : note.sourceLabel)
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                Spacer(minLength: 8)
                Rectangle().fill(.white.opacity(0.18)).frame(height: 0.5)
                Button {
                    if note.url == nil { store.selectedID = note.id; store.showWelcome?() }
                    else { store.resume() }
                } label: {
                    HStack(spacing: 8) {
                        Text(note.url == nil ? "Relire le fil" : note.actionLabel)
                        Image(systemName: "arrow.up.right")
                    }.font(.system(size: 12, weight: .medium)).foregroundStyle(Atelier.soft).frame(height: 28)
                }.buttonStyle(.plain).accessibilityLabel(note.url == nil ? "Relire le fil" : note.actionLabel)
                HStack(spacing: 0) {
                    Button { store.copyIntention(note) } label: {
                        Label(store.notice == "Extrait et source copiés." ? "Copié" : "Copier", systemImage: store.notice == "Extrait et source copiés." ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity).frame(height: 32)
                    }.accessibilityLabel("Copier avec la source")
                    Rectangle().fill(.white.opacity(0.16)).frame(width: 0.5, height: 16)
                    Button { store.edit(existing: true) } label: {
                        Label("Annoter", systemImage: "pencil").frame(maxWidth: .infinity).frame(height: 32)
                    }.accessibilityLabel("Ajouter une note")
                }.font(.system(size: 11)).buttonStyle(SurfaceButton(dark: true))
                    .background(.white.opacity(0.055), in: Capsule())
                    .overlay(Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 0.5))
            } else {
                RepriseMark(color: Ink.sky).frame(width: 16, height: 16)
                Text("Une place pour\nla suite.").font(.system(size: 18, weight: .medium))
                Text("Sur ta page, clique sur Reprise ou utilise ⌃⇧R.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.65))
                Spacer(minLength: 8)
                if !store.error.isEmpty { Text(store.error).font(.system(size: 11)).foregroundStyle(.white).lineLimit(2) }
                if !store.notice.isEmpty { Text(store.notice).font(.system(size: 11)).foregroundStyle(Ink.sky).lineLimit(1) }
                Button { store.paste() } label: {
                    Label("Coller une référence", systemImage: "plus").font(.system(size: 12)).padding(12).frame(maxWidth: .infinity)
                }.buttonStyle(SurfaceButton(dark: true, filled: true))
            }
        }.foregroundStyle(.white.opacity(0.9)).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        let types = [UTType.fileURL.identifier, UTType.url.identifier, UTType.utf8PlainText.identifier]
        guard let type = types.first(where: provider.hasItemConformingToTypeIdentifier) else { return false }
        provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
            let value = (item as? URL)?.absoluteString ?? (item as? String) ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
            if let value { Task { @MainActor in store.captureText(value.trimmingCharacters(in: .controlCharacters)) } }
        }
        return true
    }
}

struct CompactAction: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 14).padding(.vertical, 9)
            .foregroundStyle(Color.white)
            .background(Ink.blue.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 9))
    }
}
