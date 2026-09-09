import SwiftUI

struct LibraryView: View {
    @ObservedObject var store: RepriseStore
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 260)
            Rectangle().fill(Color.black.opacity(0.09)).frame(width: 1)
            detail.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.frame(width: 820, height: 550).background(Ink.paper).preferredColorScheme(.light)
    }
    var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("REPRISE", systemImage: "bookmark.fill").font(.system(size: 11, weight: .semibold)).tracking(2)
            HStack(alignment: .firstTextBaseline) {
                Text("Mes fils").font(.system(size: 26, weight: .regular, design: .serif))
                Spacer()
                Text("\(store.archive.saved.count)").font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
            }
            TextField("Retrouver un fil…", text: $store.query).textFieldStyle(.roundedBorder).accessibilityLabel("Rechercher un fil")
            Picker("Afficher", selection: $store.onlyParked) {
                Text("Tous").tag(false); Text("De côté").tag(true)
            }.pickerStyle(.segmented).labelsHidden()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(store.visibleNotes) { note in
                        Button { store.selectedID = note.id } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: note.id == store.note?.id ? "bookmark.fill" : "text.alignleft")
                                    .font(.system(size: 11)).foregroundStyle(note.id == store.note?.id ? Color.brown : Color.secondary)
                                    .frame(width: 14).padding(.top, 3)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(note.title).font(.system(size: 13, weight: .medium)).lineLimit(2)
                                    Text(note.id == store.note?.id ? "Au bord de l’écran" : note.sourceLabel)
                                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
                                .background(store.selected?.id == note.id ? Color.white.opacity(0.8) : .clear, in: RoundedRectangle(cornerRadius: 10))
                        }.buttonStyle(.plain)
                    }
                    if store.visibleNotes.isEmpty {
                        Text(store.query.isEmpty ? "Les fils rangés apparaîtront ici." : "Aucun fil ne correspond.")
                            .font(.system(size: 12)).foregroundStyle(.secondary).padding(.vertical, 16)
                    }
                }
            }
            Button { store.edit() } label: {
                HStack { Image(systemName: "plus"); Text("Nouveau fil"); Spacer(); Text("⌘N").foregroundStyle(.secondary) }
                    .font(.system(size: 12, weight: .medium)).padding(12).background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
            }.buttonStyle(.plain).keyboardShortcut("n")
            Text("Capturer une page · ⌃⇧R").font(.system(size: 11)).foregroundStyle(.secondary)
            Button("Coller un lien ou un extrait", action: store.paste).buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.secondary)
        }.padding(24).padding(.top, 16).background(Color.black.opacity(0.025))
    }
    @ViewBuilder var detail: some View {
        if let note = store.selected {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Label(note.id == store.note?.id ? "AU BORD DE L’ÉCRAN" : "GARDÉ DE CÔTÉ", systemImage: note.id == store.note?.id ? "bookmark.fill" : "tray")
                        .font(.system(size: 10, weight: .medium)).tracking(1).foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        Button("Bord droit") { store.side = .right }
                        Button("Bord gauche") { store.side = .left }
                    } label: { Image(systemName: "sidebar.right") }.menuStyle(.borderlessButton).frame(width: 24).help("Placement du signet")
                }
                Text(note.title).font(.system(size: 24, weight: .regular, design: .serif)).lineLimit(2)
                ScrollView {
                    Text(note.preview).font(.system(size: 20, weight: .regular, design: .serif)).lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                }.frame(maxHeight: .infinity)
                HStack(spacing: 12) {
                    Image(systemName: note.url?.isFileURL == true ? "doc" : note.url == nil ? "text.alignleft" : "link")
                        .font(.system(size: 18, weight: .light)).foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text([note.context?.author, note.sourceLabel].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")).font(.system(size: 12, weight: .medium))
                        Text(note.source.isEmpty ? "Une phrase suffit." : note.source).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2).textSelection(.enabled)
                    }; Spacer()
                    if note.url != nil { Button { store.openSource(note) } label: { Image(systemName: "arrow.up.right") }.buttonStyle(.plain).help("Ouvrir la source").accessibilityLabel("Ouvrir la source") }
                }.padding(16).background(.white.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                HStack(spacing: 16) {
                    Button(note.id == store.note?.id ? "Voir au bord" : "Mettre au bord") {
                        if note.id != store.note?.id { store.pin(note) }
                        store.onShapeChange?()
                    }.buttonStyle(CompactAction())
                    Button("Modifier") { store.edit(chosen: note) }.buttonStyle(.plain)
                    Button { store.copyIntention(note) } label: { Image(systemName: "doc.on.doc") }.buttonStyle(.plain).help("Copier avec la source").accessibilityLabel("Copier avec la source")
                    Spacer()
                    if note.id == store.note?.id { Button("Ranger", action: store.release).buttonStyle(.plain).foregroundStyle(.secondary) }
                }.font(.system(size: 12))
                HStack {
                    Text(store.error.isEmpty ? (store.notice.isEmpty ? "Un seul fil au bord. Les autres restent ici." : store.notice) : store.error)
                    Spacer()
                    if store.archive.previous != nil { Button("Annuler", action: store.undo).buttonStyle(.plain) }
                }.font(.system(size: 10)).foregroundStyle(.secondary).frame(height: 16)
            }.padding(32).padding(.top, 16)
        } else if !store.query.isEmpty || store.onlyParked {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "magnifyingglass").font(.system(size: 24, weight: .light)).foregroundStyle(.secondary)
                Text("Aucun fil ici.").font(.system(size: 26, weight: .regular, design: .serif))
                Text(store.query.isEmpty ? "Les fils que tu ranges resteront disponibles ici." : "Essaie un autre mot dans le titre, la phrase ou la source.").font(.system(size: 13)).foregroundStyle(.secondary)
                Button("Voir tous les fils") { store.query = ""; store.onlyParked = false }.buttonStyle(.plain)
            }.padding(40).frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: "bookmark").font(.system(size: 28, weight: .ultraLight))
                Text("Garde l’endroit\noù reprendre.").font(.system(size: 30, weight: .regular, design: .serif))
                Text("Une phrase pour la suite, avec un lien ou un fichier si tu en as besoin. Les fils rangés restent disponibles ici.")
                    .font(.system(size: 14)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Button("Créer mon premier fil") { store.edit() }.buttonStyle(CompactAction())
                Text("Tout reste sur ce Mac.").font(.system(size: 11)).foregroundStyle(.secondary)
            }.padding(40).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
