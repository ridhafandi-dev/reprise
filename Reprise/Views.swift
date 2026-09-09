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
            Text("Ce fil sera au bord. Les autres restent dans Mes fils.")
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
