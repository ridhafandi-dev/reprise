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
        VStack(alignment: .leading, spacing: 12) {
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
                Text("Ajoute ensuite où reprendre.").font(.system(size: 12)).foregroundStyle(Ink.muted)
                Spacer(minLength: 0)
            } else if let note = store.note {
                Text(note.intention).font(.system(size: 17, weight: .regular, design: .serif))
                    .lineSpacing(2).lineLimit(4).frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
                Button { store.openSource(note) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: note.url?.isFileURL == true ? "doc" : "link").foregroundStyle(Ink.amber)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(note.title).font(.system(size: 11, weight: .medium)).lineLimit(1)
                            Text(note.sourceLabel).font(.system(size: 10)).foregroundStyle(Ink.muted).lineLimit(1)
                        }; Spacer(minLength: 0)
                    }.padding(10).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 8))
                }.buttonStyle(.plain)
                HStack {
                    Button { store.resume() } label: { Label("Reprendre", systemImage: "arrow.up.right") }
                        .buttonStyle(CompactAction())
                    Spacer()
                    Button("Modifier") { store.edit(existing: true) }.buttonStyle(.plain).foregroundStyle(Ink.muted)
                }.font(.system(size: 11))
            } else {
                Spacer(minLength: 0)
                Text("Une place pour\nla suite.").font(.system(size: 22, weight: .regular, design: .serif))
                Text("Un lien, un fichier, une phrase.").font(.system(size: 12)).foregroundStyle(Ink.muted)
                Spacer(minLength: 0)
                Button("Déposer un fil") { store.edit() }.buttonStyle(CompactAction())
            }
            if !store.error.isEmpty {
                Text(store.error).font(.system(size: 10)).foregroundStyle(.orange).lineLimit(2)
            } else {
                HStack {
                    Text(store.notice.isEmpty ? "À ton rythme." : store.notice).lineLimit(1)
                    Spacer(minLength: 4)
                    if store.note != nil { Button("Ranger", action: store.release).buttonStyle(.plain) }
                }.font(.system(size: 10)).foregroundStyle(Ink.muted)
            }
        }.padding(.vertical, 22).padding(.horizontal, 20).foregroundStyle(Ink.paper)
    }
    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        let types = [UTType.fileURL.identifier, UTType.url.identifier, UTType.utf8PlainText.identifier]
        guard let type = types.first(where: provider.hasItemConformingToTypeIdentifier) else { return false }
        provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
            let value = (item as? URL)?.absoluteString ?? (item as? String) ?? (item as? Data).flatMap { String(data: $0, encoding: .utf8) }
            if let value { Task { @MainActor in store.edit(dropped: value.trimmingCharacters(in: .controlCharacters)) } }
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
