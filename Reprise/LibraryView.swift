import SwiftUI

struct LibraryView: View {
    @ObservedObject var store: RepriseStore
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 224)
            Rectangle().fill(Atelier.ink.opacity(0.1)).frame(width: 0.5)
            detail.frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 820, height: 550)
        .background(LinearGradient(colors: [Atelier.paper, Atelier.beige.opacity(0.74)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .foregroundStyle(Atelier.ink).preferredColorScheme(.light)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                RepriseMark(color: Atelier.ink).frame(width: 20, height: 20)
                Text("REPRISE").font(.system(size: 12, weight: .semibold)).tracking(1.6)
            }.frame(height: 32)
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Atelier.ink.opacity(0.5))
                TextField("Retrouver un fil", text: $store.query).textFieldStyle(.plain).accessibilityLabel("Rechercher un fil")
            }.font(.system(size: 12)).padding(12)
                .background(.white.opacity(0.15), in: Capsule())
                .overlay(Capsule().strokeBorder(Atelier.ink.opacity(0.15), lineWidth: 0.5))
            HStack(spacing: 0) {
                filter("Tous", parked: false)
                filter("De côté", parked: true)
            }.padding(4).background(Atelier.ink.opacity(0.045), in: Capsule())
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(store.visibleNotes) { note in
                        Button { store.selectedID = note.id } label: {
                            HStack(alignment: .center, spacing: 12) {
                                SourceGlyph(note: note)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title).font(.system(size: 12, weight: .medium)).lineLimit(2)
                                    HStack(spacing: 4) {
                                        if note.id == store.note?.id { Circle().fill(Atelier.royal).frame(width: 4, height: 4) }
                                        Text(note.id == store.note?.id ? "Au bord" : note.sourceLabel)
                                            .font(.system(size: 11)).foregroundStyle(Atelier.ink.opacity(0.5)).lineLimit(1)
                                    }
                                }
                                Spacer(minLength: 0)
                            }.padding(12).frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                                .background(store.selected?.id == note.id ? Atelier.soft.opacity(0.85) : .clear, in: RoundedRectangle(cornerRadius: 8))
                        }.buttonStyle(.plain).accessibilityLabel(note.title + ", " + (note.id == store.note?.id ? "Au bord" : note.sourceLabel))
                    }
                    if store.visibleNotes.isEmpty {
                        Text("Aucun fil ici.").font(.system(size: 12)).foregroundStyle(Atelier.ink.opacity(0.55)).padding(.vertical, 16)
                    }
                }
            }
            Rectangle().fill(Atelier.ink.opacity(0.1)).frame(height: 0.5)
            HStack {
                Button { store.edit() } label: {
                    Label("Nouveau fil", systemImage: "plus").font(.system(size: 12)).padding(.vertical, 8)
                }.buttonStyle(.plain).keyboardShortcut("n")
                Spacer()
                Button { store.paste() } label: { Image(systemName: "doc.on.clipboard").frame(width: 24, height: 24) }
                    .buttonStyle(SurfaceButton()).help("Coller un lien ou un extrait").accessibilityLabel("Coller un lien ou un extrait")
            }
            HStack {
                Text("Capturer une page"); Spacer(); Text("⌃⇧R")
            }.font(.system(size: 11)).foregroundStyle(Atelier.ink.opacity(0.5))
        }.padding(16).padding(.top, 8).padding(.bottom, 8)
            .background(.white.opacity(0.12))
    }

    private func filter(_ title: String, parked: Bool) -> some View {
        Button { store.onlyParked = parked } label: {
            Text(title).font(.system(size: 12)).frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(store.onlyParked == parked ? Atelier.paper : .clear, in: Capsule())
                .shadow(color: .black.opacity(store.onlyParked == parked ? 0.08 : 0), radius: 3, y: 2)
        }.buttonStyle(.plain).accessibilityAddTraits(store.onlyParked == parked ? [.isSelected] : [])
    }

    @ViewBuilder private var detail: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Mes fils").font(.system(size: 24, weight: .semibold)).tracking(-0.6)
                Text("\(store.archive.saved.count)").font(.system(size: 12)).foregroundStyle(Atelier.ink.opacity(0.45))
                Spacer()
                if let note = store.selected {
                    Button(note.id == store.note?.id ? "Au bord ↗" : "Mettre au bord ↗") {
                        if note.id != store.note?.id { store.pin(note) }
                        store.onShapeChange?()
                    }.font(.system(size: 12)).padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white.opacity(0.1), in: Capsule())
                        .overlay(Capsule().strokeBorder(Atelier.ink.opacity(0.18), lineWidth: 0.5)).buttonStyle(.plain)
                        .accessibilityLabel(note.id == store.note?.id ? "Voir au bord" : "Mettre au bord")
                }
                Menu {
                    Button("Bord droit") { store.side = .right }
                    Button("Bord gauche") { store.side = .left }
                } label: { Image(systemName: "sidebar.right") }.menuStyle(.borderlessButton).menuIndicator(.hidden)
                    .frame(width: 20).help("Placement du signet").accessibilityLabel("Placement du signet")
            }
            if let note = store.selected {
                readingPane(note)
                Button { store.edit(chosen: note) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "pencil").font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 8) {
                            Text(note.context == nil && !note.intention.isEmpty ? "Modifier ce fil" : "Un mot pour la suite").font(.system(size: 14, weight: .medium))
                            Text(note.context == nil && !note.intention.isEmpty ? "Retrouver le texte et sa référence." : note.intention.isEmpty ? "Ajouter une note, si elle t’aide…" : note.intention)
                                .font(.system(size: 12)).foregroundStyle(Atelier.ink.opacity(0.55)).lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }.padding(16).frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Atelier.ink.opacity(0.16), lineWidth: 0.5))
                }.buttonStyle(.plain).accessibilityLabel("Modifier la note")
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text(store.query.isEmpty && !store.onlyParked ? "Garde l’endroit\noù reprendre." : "Aucun fil ici.")
                        .font(.system(size: 28, weight: .medium)).tracking(-0.6)
                    Text(store.query.isEmpty && !store.onlyParked ? "Une page, une vidéo, quelques mots. La suite reste à portée de main." : "Essaie un autre mot ou retrouve tous tes fils.")
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.7))
                    Button(store.query.isEmpty && !store.onlyParked ? "Créer un fil ↗" : "Voir tous les fils ↗") {
                        if !store.query.isEmpty || store.onlyParked { store.query = ""; store.onlyParked = false }
                        else { store.edit() }
                    }.font(.system(size: 14)).buttonStyle(.plain)
                    Spacer(minLength: 0)
                }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .foregroundStyle(.white).background(blueSurface).clipShape(RoundedRectangle(cornerRadius: 24))
            }
            HStack(spacing: 8) {
                Image(systemName: store.error.isEmpty ? "laptopcomputer" : "exclamationmark.circle")
                Text(store.error.isEmpty ? (store.notice.isEmpty ? "Gardé sur ce Mac" : store.notice) : store.error).lineLimit(2)
                Spacer(minLength: 0)
                if store.archive.previous != nil { Button("Annuler", action: store.undo).buttonStyle(.plain) }
            }.font(.system(size: 11)).foregroundStyle(Atelier.ink.opacity(0.5)).frame(minHeight: 16)
        }.padding(24).padding(.top, 8)
    }

    private func readingPane(_ note: ThreadNote) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(note.kindLabel).tracking(1.2)
                if let time = note.timeLabel { Text(time).monospacedDigit() }
                Spacer()
                if note.id == store.note?.id { Text("AU BORD").foregroundStyle(.white.opacity(0.6)) }
            }.font(.system(size: 11, weight: .medium))
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(note.context == nil && !note.intention.isEmpty && note.intention.hasPrefix(note.title) ? "Note personnelle" : note.title).font(.system(size: 28, weight: .medium)).tracking(-0.6)
                        .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 400, alignment: .leading).textSelection(.enabled)
                    if let text = capturedText(note) {
                        Text(text).font(.system(size: 14)).lineSpacing(4).foregroundStyle(.white.opacity(0.8)).textSelection(.enabled)
                    }
                    HStack(spacing: 8) {
                        SourceGlyph(note: note)
                        Text(note.context?.author?.isEmpty == false ? note.context!.author! : note.sourceLabel)
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.85)).lineLimit(2)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Rectangle().fill(.white.opacity(0.25)).frame(height: 0.5)
            HStack(spacing: 12) {
                if note.url != nil {
                    Button { store.openSource(note) } label: {
                        HStack(spacing: 8) { Text(note.actionLabel); Image(systemName: "arrow.up.right") }
                    }.buttonStyle(.plain).help(note.source).accessibilityLabel("Ouvrir la source")
                } else {
                    Text("Note personnelle").foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Button { store.copyIntention(note) } label: { Image(systemName: "doc.on.doc").frame(width: 28, height: 28) }
                    .buttonStyle(SurfaceButton(dark: true)).help("Copier avec la source").accessibilityLabel("Copier avec la source")
                if note.id == store.note?.id {
                    Button { store.release() } label: { Image(systemName: "archivebox").frame(width: 28, height: 28) }
                        .buttonStyle(SurfaceButton(dark: true)).help("Ranger le fil").accessibilityLabel("Ranger")
                }
            }.font(.system(size: 14))
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .foregroundStyle(.white).background(blueSurface)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
    }

    private func capturedText(_ note: ThreadNote) -> String? {
        // A plain-text capture is the content itself, not a second annotation.
        if note.context == nil, !note.intention.isEmpty { return note.intention }
        // Keep source text and the user's optional note in separate places.
        let text = [note.context?.excerpt, note.context?.description].compactMap { $0 }
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.trimmingCharacters(in: .whitespacesAndNewlines) != note.title.trimmingCharacters(in: .whitespacesAndNewlines) }
        return text
    }

    private var blueSurface: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(colors: [Atelier.royal, Color(red: 0.08, green: 0.17, blue: 0.55)], startPoint: .topTrailing, endPoint: .bottomLeading)
                Ellipse().fill(LinearGradient(colors: [.white.opacity(0.02), Atelier.soft.opacity(0.22), .white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: proxy.size.width * 0.55, height: proxy.size.height * 1.7)
                    .rotationEffect(.degrees(32)).offset(x: proxy.size.width * 0.4, y: proxy.size.height * 0.2)
                    .blur(radius: 10)
            }
        }.allowsHitTesting(false)
    }
}
