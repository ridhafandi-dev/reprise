import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum Ink {
    static let amber = Color(red: 0.94, green: 0.69, blue: 0.43)
    static let black = Color(red: 0.035, green: 0.037, blue: 0.04)
    static let muted = Color(white: 0.61)
    static let paper = Color(red: 0.94, green: 0.93, blue: 0.90)
}

struct QuietButton: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: primary ? .infinity : nil)
            .foregroundStyle(primary ? Ink.black : Color.white.opacity(0.8))
            .background(primary ? Ink.amber : Color.white.opacity(configuration.isPressed ? 0.13 : 0.06), in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

struct RepriseNotch: View {
    @ObservedObject var store: RepriseStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pointerInside = false
    var body: some View {
        let shape = SideNotchShape(edge: store.side)
        ZStack {
            shape.fill(Ink.black)
            if store.isOpen {
                content.padding(.vertical, 32)
                    .padding(.leading, store.side == .right ? 24 : 32)
                    .padding(.trailing, store.side == .right ? 32 : 24)
                    .transition(.opacity.combined(with: .offset(x: store.side == .right ? 16 : -16)))
            } else {
                Button { store.reveal() } label: { VStack(spacing: 16) {
                    Image(systemName: store.note == nil ? "plus" : "bookmark.fill")
                        .font(.system(size: 15, weight: .light))
                    if store.note != nil { Capsule().frame(width: 3, height: 24) }
                }
                .foregroundStyle(store.note == nil ? Ink.muted : Ink.amber)
                .padding(store.side == .right ? .trailing : .leading, 4)
                .frame(width: 40, height: 132) }.buttonStyle(.plain)
                .accessibilityLabel(store.note == nil ? "Reprise, déposer un fil" : "Reprise, un fil gardé")
                .accessibilityAction { store.reveal() }
            }
        }
        .frame(width: store.isOpen ? 382 : 40, height: store.isOpen ? 448 : 132)
        .contentShape(shape)
        .onHover { inside in
            guard inside != pointerInside else { return }
            pointerInside = inside
            store.hover(inside)
        }
        .onDrop(of: [UTType.fileURL.identifier, UTType.url.identifier, UTType.utf8PlainText.identifier], isTargeted: $store.targeted, perform: acceptDrop)
        .animation(NotchMotion.respectingReduceMotion(NotchMotion.unfold, reduceMotion), value: store.isOpen)
        .animation(NotchMotion.crossfade, value: store.note)
        .preferredColorScheme(.dark)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill").foregroundStyle(Ink.amber)
                    Text("Reprise").font(.system(size: 16, weight: .semibold))
                }
                Spacer()
                Button { store.fold() } label: { Image(systemName: store.side == .right ? "chevron.right" : "chevron.left") }
                    .buttonStyle(.plain).foregroundStyle(Ink.muted).help("Refermer")
                    .accessibilityLabel("Refermer le fil")
            }
            if store.targeted {
                Spacer()
                Image(systemName: "arrow.down.to.line.compact").font(.system(size: 32, weight: .light)).foregroundStyle(Ink.amber)
                Text("Pose-le ici.").font(.system(size: 28, weight: .regular, design: .serif))
                Text("Tu ajouteras juste où reprendre.").foregroundStyle(Ink.muted)
                Spacer()
            } else if let note = store.note {
                HStack(spacing: 8) {
                    Circle().fill(Ink.amber).frame(width: 5, height: 5)
                    Text(note.example ? "EXEMPLE À ESSAYER" : "UN FIL GARDÉ")
                        .tracking(1.6)
                    Spacer()
                }.font(.system(size: 10, weight: .medium)).foregroundStyle(Ink.muted)
                ScrollView {
                    Text(note.intention)
                        .font(.system(size: 23, weight: .regular, design: .serif))
                        .lineSpacing(4).foregroundStyle(Ink.paper)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }.frame(height: 112)
                HStack(spacing: 12) {
                    Image(systemName: note.url?.isFileURL == true ? "doc" : note.url == nil ? "text.alignleft" : "link")
                        .font(.system(size: 18, weight: .light)).foregroundStyle(Ink.amber)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(note.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        Text(note.sourceLabel).font(.system(size: 11)).foregroundStyle(Ink.muted).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }.padding(16).background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
                Button(action: store.resume) {
                    HStack { Text(note.url == nil ? "Je reprends ici" : "Reprendre le fil"); Spacer(); Image(systemName: "arrow.up.right") }
                }.buttonStyle(QuietButton(primary: true))
                HStack {
                    Button("Modifier") { store.edit(existing: true) }
                    Spacer()
                    Button("Libérer la place", action: store.release)
                }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(Ink.muted)
            } else {
                Spacer(minLength: 0)
                Image(systemName: "bookmark").font(.system(size: 32, weight: .ultraLight)).foregroundStyle(Ink.amber)
                Text("Tu peux\nlaisser le fil.").font(.system(size: 29, weight: .regular, design: .serif)).foregroundStyle(Ink.paper)
                Text("Un lien, un fichier, quelques mots.\nJuste assez pour revenir.")
                    .font(.system(size: 13)).lineSpacing(4).foregroundStyle(Ink.muted)
                Spacer(minLength: 0)
                Button("Déposer un fil") { store.edit() }.buttonStyle(QuietButton(primary: true))
                Button("Coller ce que j’ai copié", action: store.paste)
                    .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Ink.muted)
            }
            if !store.error.isEmpty {
                Text(store.error).font(.system(size: 11)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            } else {
                HStack {
                    Text(store.notice.isEmpty ? "Une place. Aucune urgence." : store.notice)
                    Spacer(minLength: 4)
                    if store.archive.previous != nil { Button("Annuler", action: store.undo).buttonStyle(.plain).foregroundStyle(Ink.amber) }
                }.font(.system(size: 10)).foregroundStyle(Ink.muted.opacity(0.8)).lineLimit(1)
            }
        }.foregroundStyle(.white)
    }

    private func acceptDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        let types = [UTType.fileURL.identifier, UTType.url.identifier, UTType.utf8PlainText.identifier]
        guard let type = types.first(where: provider.hasItemConformingToTypeIdentifier) else { return false }
        provider.loadItem(forTypeIdentifier: type, options: nil) { item, _ in
            var value: String?
            if let url = item as? URL { value = url.absoluteString }
            else if let text = item as? String { value = text }
            else if let data = item as? Data { value = String(data: data, encoding: .utf8) }
            if let value { Task { @MainActor in store.edit(dropped: value.trimmingCharacters(in: .controlCharacters)) } }
        }
        return true
    }
}

struct EditorView: View {
    @ObservedObject var store: RepriseStore
    var close: () -> Void
    @FocusState private var focus: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("REPRISE", systemImage: "bookmark.fill").tracking(2).foregroundStyle(Ink.amber)
                Spacer()
                Text("UNE SEULE PLACE").foregroundStyle(Ink.muted).tracking(1.5)
            }.font(.system(size: 10, weight: .medium))
            Text("Où reprendre ?").font(.system(size: 30, weight: .regular, design: .serif)).foregroundStyle(Ink.paper)
            Text("Laisse une phrase à ton toi de tout à l’heure.").foregroundStyle(Ink.muted).font(.system(size: 13))
            VStack(alignment: .leading, spacing: 8) {
                Text("LE POINT DE REPRISE").font(.system(size: 10)).tracking(1.2).foregroundStyle(Ink.muted)
                TextEditor(text: $store.intention).font(.system(size: 17)).scrollContentBackground(.hidden)
                    .padding(12).frame(height: 108).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                    .focused($focus).accessibilityLabel("Le point de reprise")
                TextField("Un nom pour ce fil · facultatif", text: $store.title).textFieldStyle(.roundedBorder).accessibilityLabel("Nom du fil")
                HStack {
                    TextField("Lien ou chemin de fichier · facultatif", text: $store.source).textFieldStyle(.roundedBorder).accessibilityLabel("Source du fil")
                    Button { chooseFile() } label: { Image(systemName: "folder") }.help("Choisir un fichier")
                }
            }
            if !store.error.isEmpty { Text(store.error).font(.system(size: 12)).foregroundStyle(.orange) }
            Text(store.note == nil ? "Le fil reste sur ce Mac." : "Ce fil prendra la place du précédent. Tu pourras annuler.")
                .font(.system(size: 11)).foregroundStyle(Ink.muted)
            HStack {
                Button("Annuler") { store.editing = false; close() }.keyboardShortcut(.cancelAction).buttonStyle(QuietButton())
                Button("Garder ce fil") { store.save(); if !store.editing { close() } }
                    .keyboardShortcut(.return, modifiers: .command).buttonStyle(QuietButton(primary: true)).disabled(!store.canSave)
            }
        }.padding(32).frame(width: 480).background(Ink.black).preferredColorScheme(.dark)
            .onAppear { focus = true }
    }
    private func chooseFile() {
        let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.allowsMultipleSelection = false
        panel.begin { result in
            if result == .OK, let url = panel.url {
                store.source = url.path
                if store.title.isEmpty { store.title = url.deletingPathExtension().lastPathComponent }
            }
        }
    }
}

struct WelcomeView: View {
    @ObservedObject var store: RepriseStore
    var reveal: () -> Void
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Label("REPRISE", systemImage: "bookmark.fill").font(.system(size: 11, weight: .semibold)).tracking(3)
                Spacer()
                Text("Laisse le fil.\nRetrouve l’élan.").font(.system(size: 36, weight: .regular, design: .serif)).tracking(-1.2).fixedSize(horizontal: false, vertical: true)
                Text("Un petit endroit au bord de l’écran\npour garder où tu en étais.").font(.system(size: 15)).lineSpacing(5).foregroundStyle(.black.opacity(0.58)).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 12) {
                    step("01", "Dépose un lien, un fichier ou un extrait.")
                    step("02", "Laisse quelques mots pour la suite.")
                    step("03", "Reviens quand tu veux.")
                }.padding(.top, 8)
                Spacer()
                Button(action: reveal) { HStack { Text("Essayer au bord de l’écran"); Image(systemName: "arrow.right") }.font(.system(size: 13, weight: .medium)).padding(.vertical, 14).padding(.horizontal, 20).background(Ink.black, in: Capsule()).foregroundStyle(.white) }.buttonStyle(.plain)
                Text("ÉTUDE 01  /  NATIVE MACOS  /  ISSUE DE CODENOTCH").font(.system(size: 8, weight: .medium)).tracking(1).foregroundStyle(.black.opacity(0.42))
            }.padding(32).frame(width: 440)
            ZStack(alignment: .trailing) {
                Color(red: 0.82, green: 0.81, blue: 0.77)
                if !store.isOpen { VStack(alignment: .leading, spacing: 16) {
                    Text("LE FIL T’ATTEND.").font(.system(size: 9, weight: .medium)).tracking(2).foregroundStyle(.black.opacity(0.4))
                    Text("Rien à rattraper.\nJuste un endroit\noù revenir.").font(.system(size: 25, weight: .regular, design: .serif)).foregroundStyle(.black.opacity(0.58))
                    Text("Survole le signet →").font(.system(size: 11)).foregroundStyle(.black.opacity(0.45))
                }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 32).padding(.trailing, 48) }
                RepriseNotch(store: store)
            }.frame(width: 430)
        }.frame(width: 870, height: 532).background(Ink.paper).preferredColorScheme(.light)
    }
    func step(_ number: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(number).font(.system(size: 10, design: .monospaced)).foregroundStyle(.black.opacity(0.4))
            Text(text).font(.system(size: 12)).foregroundStyle(.black.opacity(0.7))
        }
    }
}
