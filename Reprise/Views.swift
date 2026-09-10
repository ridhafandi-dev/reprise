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
        configuration.label.font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(maxWidth: primary ? .infinity : nil)
            .foregroundStyle(primary ? Color.white : Atelier.ink)
            .background(primary ? Atelier.royal : Atelier.ink.opacity(0.045), in: Capsule())
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
                HStack(spacing: 8) { RepriseMark(color: Atelier.ink).frame(width: 13, height: 13); Text("REPRISE").tracking(2) }.foregroundStyle(Atelier.ink)
                Spacer()
                Text("NOTE FACULTATIVE").foregroundStyle(Atelier.ink.opacity(0.5)).tracking(1.5)
            }.font(.system(size: 11, weight: .medium))
            Text("Un mot pour la suite ?").font(.system(size: 24, weight: .medium)).foregroundStyle(Atelier.ink)
            Text("Ta référence suffit. Ajoute une note si elle t’aide.").foregroundStyle(Atelier.ink.opacity(0.5)).font(.system(size: 14))
            VStack(alignment: .leading, spacing: 8) {
                Text("TA NOTE · FACULTATIVE").font(.system(size: 11)).tracking(1.2).foregroundStyle(Atelier.ink.opacity(0.5))
                TextEditor(text: $store.intention).font(.system(size: 14)).scrollContentBackground(.hidden)
                    .padding(12).frame(height: 108).background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                    .focused($focus).accessibilityLabel("Le point de reprise")
                TextField("Un nom pour ce fil · facultatif", text: $store.title).textFieldStyle(.roundedBorder).accessibilityLabel("Nom du fil")
                HStack {
                    TextField("Lien ou chemin de fichier · facultatif", text: $store.source).textFieldStyle(.roundedBorder).accessibilityLabel("Source du fil")
                    Button { chooseFile() } label: { Image(systemName: "folder") }.help("Choisir un fichier")
                }
            }
            if !store.error.isEmpty { Text(store.error).font(.system(size: 12)).foregroundStyle(Color(red: 0.65, green: 0.12, blue: 0.16)) }
            Text("Ce fil sera au bord. Les autres restent dans Mes fils.")
                .font(.system(size: 11)).foregroundStyle(Atelier.ink.opacity(0.5))
            HStack {
                Button("Annuler") { store.editing = false; close() }.keyboardShortcut(.cancelAction).buttonStyle(QuietButton())
                Button("Garder ce fil") { store.save(); if !store.editing { close() } }
                    .keyboardShortcut(.return, modifiers: .command).buttonStyle(QuietButton(primary: true)).disabled(!store.canSave)
            }
        }.padding(32).frame(width: 480).background(Atelier.paper).foregroundStyle(Atelier.ink).preferredColorScheme(.light)
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
