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
                    RepriseMark(color: store.note == nil ? Ink.muted : Ink.sky)
                        .frame(width: 13, height: 13)
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
    // The reading surface and the controls are separate physical zones.
    // Keeping both within the existing canvas preserves edge hit-testing.
    var content: some View {
        HStack(spacing: 0) {
            if store.side == .left { controlSpine }
            readingSurface
            if store.side == .right { controlSpine }
        }
        .padding(.vertical, 12)
    }

    private var readingSurface: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle().fill(store.targeted ? Ink.blue : Ink.sky).frame(width: 4, height: 4)
                Text(store.targeted ? "DÉPOSER" : (store.notice.isEmpty ? store.note?.kindLabel ?? "PLACE LIBRE" : store.notice))
                    .font(.system(size: 12, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
                if store.notice.isEmpty, let time = store.note?.timeLabel {
                    Text(time).font(.system(size: 12)).monospacedDigit()
                }
            }.foregroundStyle(Ink.blue)

            if store.targeted {
                Text("Dépose.\nC’est gardé.").font(.system(size: 24, weight: .semibold))
                Text("Un lien, un fichier ou quelques mots.")
                    .font(.system(size: 16)).foregroundStyle(Color.black.opacity(0.62))
                Spacer(minLength: 8)
                Image(systemName: "arrow.down.to.line").font(.system(size: 24, weight: .medium))
                    .foregroundStyle(Ink.blue).frame(maxWidth: .infinity, alignment: .leading)
            } else if let note = store.note {
                Text(note.title).font(.system(size: 24, weight: .semibold))
                    .tracking(-0.6).lineLimit(2).frame(maxWidth: .infinity, alignment: .leading)
                    .help(note.title)
                if !store.error.isEmpty {
                    Text(store.error).font(.system(size: 12)).foregroundStyle(Color(red: 0.65, green: 0.12, blue: 0.16)).lineLimit(3)
                } else if note.preview != note.title {
                    Text(note.preview).font(.system(size: 16)).lineLimit(2)
                        .foregroundStyle(Color.black.opacity(0.66))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 8)
                if let author = note.context?.author, !author.isEmpty {
                    Text(author).font(.system(size: 12)).foregroundStyle(Color.black.opacity(0.6)).lineLimit(1)
                }
                Button {
                    if note.url == nil { store.selectedID = note.id; store.showWelcome?() }
                    else { store.resume() }
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.url == nil ? "Relire le fil" : note.timeLabel.map { "Reprendre à " + $0 } ?? "Reprendre")
                                .font(.system(size: 16, weight: .semibold)).lineLimit(1)
                            Text(note.url == nil ? "Dans Mes fils" : note.sourceLabel)
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: note.context?.kind == "video" ? "play.fill" : "arrow.up.right")
                            .font(.system(size: 16, weight: .medium))
                    }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                }.buttonStyle(RepriseSurfaceAction())
                    .accessibilityLabel(note.url == nil ? "Relire le fil dans Mes fils" : note.actionLabel)
            } else {
                Text("La suite\nreste ici.").font(.system(size: 24, weight: .semibold)).tracking(-0.6)
                Text("Sur ta page, clique sur Reprise ou utilise ⌃⇧R.")
                    .font(.system(size: 16)).foregroundStyle(Color.black.opacity(0.66))
                Spacer(minLength: 8)
                if !store.error.isEmpty {
                    Text(store.error).font(.system(size: 12)).foregroundStyle(Color(red: 0.65, green: 0.12, blue: 0.16)).lineLimit(2)
                }
                Button { store.paste() } label: {
                    HStack(spacing: 8) {
                        Text("Coller ici").font(.system(size: 16, weight: .semibold))
                        Spacer(minLength: 0)
                        Image(systemName: "plus").font(.system(size: 16))
                    }.padding(12)
                }.buttonStyle(RepriseSurfaceAction()).accessibilityLabel("Coller une référence")
            }
        }
        .padding(16)
        .frame(width: 232, height: 256, alignment: .topLeading)
        .foregroundStyle(Color(red: 0.07, green: 0.09, blue: 0.14))
        .background {
            ZStack(alignment: .bottomTrailing) {
                LinearGradient(colors: [.white, Color(red: 0.92, green: 0.95, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                if store.note?.preview == store.note?.title && !store.targeted {
                    RepriseMark(color: Ink.sky.opacity(0.16)).frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-12)).offset(x: 24, y: -32)
                        .accessibilityHidden(true)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.8), lineWidth: 1))
    }

    private var controlSpine: some View {
        VStack(spacing: 8) {
            RepriseMark(color: Ink.sky).frame(width: 20, height: 20)
                .frame(width: 32, height: 32).accessibilityHidden(true)
            VStack(spacing: 4) {
                if let note = store.note {
                    spineButton(store.notice == "Extrait et source copiés." ? "checkmark" : "doc.on.doc", "Copier avec la source") { store.copyIntention(note) }
                    spineButton("square.and.pencil", "Ajouter une note") { store.edit(existing: true) }
                    spineButton("archivebox", "Ranger le fil") { store.release() }
                } else if store.archive.previous != nil {
                    spineButton("arrow.uturn.backward", "Annuler le rangement") { store.undo() }
                }
            }
            Spacer(minLength: 0)
            spineButton("tray", "Ouvrir Mes fils") { store.showWelcome?() }
            spineButton(store.side == .right ? "chevron.right" : "chevron.left", "Refermer le fil") { store.fold() }
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .frame(width: 56, height: 256)
        .background {
            LinearGradient(stops: [.init(color: .white.opacity(0.18), location: 0), .init(color: .white.opacity(0.04), location: 0.16), .init(color: .clear, location: 0.55)],
                           startPoint: store.side == .right ? .leading : .trailing,
                           endPoint: store.side == .right ? .trailing : .leading)
        }
    }

    private func spineButton(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 16, weight: .regular))
                .frame(width: 32, height: 32)
        }.buttonStyle(RepriseSpineAction()).help(label).accessibilityLabel(label)
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

/// Local hover feedback does not change the panel bounds or its hover region.
struct RepriseSpineAction: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        SpineBody(configuration: configuration)
    }
    private struct SpineBody: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovered = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        var body: some View {
            configuration.label
                .foregroundStyle(hovered ? Color.white : Color.white.opacity(0.68))
                .background(.white.opacity(configuration.isPressed ? 0.20 : hovered ? 0.12 : 0.035), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(hovered ? 0.2 : 0.07), lineWidth: 0.5))
                .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.93 : 1)
                .onHover { hovered = $0 }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hovered)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}

struct RepriseSurfaceAction: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ActionBody(configuration: configuration)
    }
    private struct ActionBody: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovered = false
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        var body: some View {
            configuration.label.foregroundStyle(.white)
                .background(LinearGradient(colors: [hovered ? Ink.blue : Ink.blue.opacity(0.94), Ink.blue], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                .shadow(color: Ink.blue.opacity(hovered ? 0.28 : 0.12), radius: hovered ? 8 : 4, y: 4)
                .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.97 : 1)
                .onHover { hovered = $0 }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovered)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
        }
    }
}
