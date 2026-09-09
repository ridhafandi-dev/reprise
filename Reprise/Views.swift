import AppKit
import SwiftUI
import UniformTypeIdentifiers

enum Ink {
    static let blue = Color(red: 35.0/255, green: 92.0/255, blue: 214.0/255)
    static let sky = Color(red: 137.0/255, green: 167.0/255, blue: 234.0/255)
    static let black = Color(red: 0.035, green: 0.037, blue: 0.04)
    static let muted = Color(white: 0.61)
    static let paper = Color.white
}

struct QuietButton: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: primary ? .infinity : nil)
            .foregroundStyle(primary ? Color.white : Color.white.opacity(0.8))
            .background(primary ? Ink.blue : Color.white.opacity(configuration.isPressed ? 0.13 : 0.06), in: RoundedRectangle(cornerRadius: 12))
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
                HStack(spacing: 8) { RepriseMark(color: Ink.sky).frame(width: 13, height: 13); Text("REPRISE").tracking(2) }.foregroundStyle(Ink.sky)
                Spacer()
                Text("UNE SEULE PLACE").foregroundStyle(Ink.muted).tracking(1.5)
            }.font(.system(size: 10, weight: .medium))
            Text("Un mot pour la suite ?").font(.system(size: 30, weight: .regular, design: .serif)).foregroundStyle(Ink.paper)
            Text("Ta référence suffit. Ajoute une note si elle t’aide.").foregroundStyle(Ink.muted).font(.system(size: 13))
            VStack(alignment: .leading, spacing: 8) {
                Text("TA NOTE · FACULTATIVE").font(.system(size: 10)).tracking(1.2).foregroundStyle(Ink.muted)
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
