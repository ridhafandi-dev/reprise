import SwiftUI
import UniformTypeIdentifiers

enum RepriseMetrics {
    static let closed = CGSize(width: 22, height: 76)
    static let open = CGSize(width: 288, height: 280)
    static let canvas = CGSize(width: 288, height: 304)
    static let motion = Animation.spring(response: 0.30, dampingFraction: 0.91)
}

struct RepriseNotch: View {
    @ObservedObject var store: RepriseStore
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    var body: some View {
        let size = store.isOpen ? RepriseMetrics.open : RepriseMetrics.closed
        let alignment: Alignment = store.side == .right ? .trailing : .leading
        let shape = SideNotchShape(edge: store.side, curlRadius: 9, cornerRadius: 16)
        ZStack(alignment: alignment) {
            shape.fill(Ink.black).frame(width: size.width, height: size.height)
            if store.isOpen {
                content.frame(width: 288, height: 280)
                    .transition(.opacity.combined(with: .offset(x: store.side == .right ? 8 : -8)))
            } else {
                Button { store.reveal() } label: {
                    Image(systemName: store.note == nil ? "plus" : "bookmark.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(store.note == nil ? Ink.muted : Ink.amber)
                        .frame(width: 22, height: 76)
                }.buttonStyle(.plain).accessibilityLabel("Ouvrir le fil")
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(shape)
        .onDrop(of: [UTType.fileURL.identifier, UTType.url.identifier, UTType.utf8PlainText.identifier], isTargeted: $store.targeted, perform: acceptDrop)
        .animation(reduceMotion ? nil : RepriseMetrics.motion, value: store.isOpen)
        .frame(width: RepriseMetrics.canvas.width, height: RepriseMetrics.canvas.height, alignment: alignment)
        .preferredColorScheme(.dark)
    }
    var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("REPRISE", systemImage: "bookmark.fill").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(Ink.amber)
                Spacer()
                Button { store.showWelcome?() } label: { Image(systemName: "tray").font(.system(size: 12)) }
                    .help("Ouvrir Mes fils").accessibilityLabel("Ouvrir Mes fils")
                Button { store.fold() } label: { Image(systemName: "chevron.right").font(.system(size: 10)) }
                    .help("Refermer").accessibilityLabel("Refermer le fil")
            }.buttonStyle(.plain).foregroundStyle(Ink.muted)
            if store.targeted {
                Spacer(minLength: 0)
                Label("Dépose ici", systemImage: "arrow.down.to.line").font(.system(size: 21, weight: .regular, design: .serif))
                Text("La référence sera gardée aussitôt.").font(.system(size: 12)).foregroundStyle(Ink.muted)
                Spacer(minLength: 0)
            } else if let note = store.note {
                HStack(spacing: 6) {
                    Image(systemName: note.symbol)
                    Text(note.kindLabel)
                    if let time = note.timeLabel { Text("· " + time).monospacedDigit() }
                    Spacer()
                }.font(.system(size: 9, weight: .medium)).tracking(0.8).foregroundStyle(Ink.muted)
                Text(note.title).font(.system(size: 17, weight: .regular, design: .serif))
                    .lineSpacing(1).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                if note.preview != note.title {
                    Text(note.preview).font(.system(size: 12)).foregroundStyle(Ink.paper.opacity(0.78))
                        .lineSpacing(2).lineLimit(3).frame(maxWidth: .infinity, alignment: .leading)
                }
                Text([note.context?.author, note.sourceLabel].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 10)).foregroundStyle(Ink.muted).lineLimit(1)
                Spacer(minLength: 0)
                HStack(spacing: 12) {
                    Button { store.resume() } label: { Text(note.actionLabel) }.buttonStyle(CompactAction())
                    Spacer(minLength: 0)
                    Button { store.copyIntention(note) } label: { Image(systemName: "doc.on.doc") }
                        .buttonStyle(.plain).help("Copier avec la source").accessibilityLabel("Copier avec la source")
                    Button { store.edit(existing: true) } label: { Image(systemName: "square.and.pencil") }
                        .buttonStyle(.plain).help("Ajouter une note").accessibilityLabel("Ajouter une note")
                }.font(.system(size: 12)).foregroundStyle(Ink.muted)
            } else {
                Spacer(minLength: 0)
                Text("Une place pour\nla suite.").font(.system(size: 22, weight: .regular, design: .serif))
                Text("Sur ta page, clique sur Reprise\nou utilise ⌘⇧S.").font(.system(size: 12)).foregroundStyle(Ink.muted)
                Spacer(minLength: 0)
                Button("Coller une référence") { store.paste() }.buttonStyle(CompactAction())
            }
            if !store.error.isEmpty {
                Text(store.error).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(2)
            } else {
                HStack {
                    Text(store.notice.isEmpty ? "À portée de main." : store.notice).lineLimit(1)
                    Spacer(minLength: 4)
                    if store.note != nil { Button("Ranger", action: store.release).buttonStyle(.plain) }
                }.font(.system(size: 10)).foregroundStyle(Ink.muted)
            }
        }.padding(.vertical, 18).padding(.horizontal, 20).foregroundStyle(Ink.paper)
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
            .foregroundStyle(Ink.black)
            .background(Ink.amber.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 9))
    }
}
