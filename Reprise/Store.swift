import AppKit
import SwiftUI

@MainActor
final class RepriseStore: ObservableObject {
    @Published var archive = ThreadArchive()
    @Published var expanded = false
    @Published var editing = false
    @Published var targeted = false
    @Published var title = ""
    @Published var intention = ""
    @Published var source = ""
    @Published var notice = ""
    @Published var error = ""
    @Published var side: NotchEdge = .right {
        didSet { UserDefaults.standard.set(side == .left ? "left" : "right", forKey: "reprise.edge") }
    }
    @Published var selectedID: String?
    @Published var query = ""
    @Published var onlyParked = false
    var openEditor: (() -> Void)?
    var onShapeChange: (() -> Void)?
    var showWelcome: (() -> Void)?
    private var closeWork: DispatchWorkItem?
    private var noticeWork: DispatchWorkItem?
    private var manualOpenUntil = Date.distantPast
    private var openWork: DispatchWorkItem?
    private var hoverInside = false
    private var editingNote: ThreadNote?
    private let storage: URL

    init(storageURL: URL? = nil) {
        if let storageURL { storage = storageURL }
        else if let value = ProcessInfo.processInfo.environment["REPRISE_STATE_PATH"] {
            storage = URL(fileURLWithPath: value)
        } else {
            storage = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Reprise/thread.json")
        }
        do { archive = try ThreadPersistence.load(from: storage) }
        catch { self.error = "Le fil enregistré ne peut pas être lu. Le fichier est conservé." }
        side = UserDefaults.standard.string(forKey: "reprise.edge") == "left" ? .left : .right
    }
    var note: ThreadNote? { archive.current }
    var isOpen: Bool { expanded || targeted }
    var canSave: Bool { !intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var visibleNotes: [ThreadNote] {
        archive.saved.filter { note in
            (!onlyParked || note.id != archive.current?.id) &&
            (query.isEmpty || [note.title, note.intention, note.source].joined(separator: " ").localizedStandardContains(query))
        }
    }
    var selected: ThreadNote? {
        if let selectedID, let found = visibleNotes.first(where: { $0.id == selectedID }) { return found }
        if let current = archive.current, visibleNotes.contains(where: { $0.id == current.id }) { return current }
        return visibleNotes.first
    }
    func pin(_ note: ThreadNote) {
        var next = archive; next.keep(note)
        if persist(next) { selectedID = note.id; flash("Ce fil est au bord.") }
    }
    func copyIntention(_ note: ThreadNote) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(note.intention, forType: .string)
        flash("Phrase copiée.")
    }
    func reveal() {
        closeWork?.cancel(); closeWork = nil; openWork?.cancel(); openWork = nil
        manualOpenUntil = Date().addingTimeInterval(3)
        expanded = true
    }
    func hover(_ inside: Bool) {
        hoverInside = inside
        if inside {
            closeWork?.cancel(); closeWork = nil
            guard !expanded, openWork == nil else { return }
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }; self.openWork = nil
                if self.hoverInside { self.expanded = true }
            }
            openWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 0.10, execute: work)
        } else {
            openWork?.cancel(); openWork = nil
            guard expanded, !editing, !targeted, closeWork == nil else { return }
            let delay = max(0.30, manualOpenUntil.timeIntervalSinceNow)
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }; self.closeWork = nil
                if !self.hoverInside && !self.editing && !self.targeted { self.expanded = false }
            }
            closeWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
        }
    }
    func fold() { openWork?.cancel(); openWork = nil; closeWork?.cancel(); closeWork = nil; expanded = false; targeted = false }
    func flash(_ text: String) {
        noticeWork?.cancel(); notice = text
        let work = DispatchWorkItem { [weak self] in self?.notice = "" }
        noticeWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }
    func edit(existing: Bool = false, dropped: String? = nil, chosen: ThreadNote? = nil) {
        closeWork?.cancel(); error = ""
        editingNote = chosen ?? (existing ? note : nil)
        title = editingNote?.title ?? ""
        intention = editingNote?.intention ?? ""
        source = editingNote?.source ?? ""
        if let dropped {
            if let url = ThreadNote.sourceURL(dropped) {
                source = url.isFileURL ? url.path : url.absoluteString
                title = url.isFileURL ? url.deletingPathExtension().lastPathComponent : url.host ?? ""
            } else { intention = String(dropped.prefix(1200)) }
        }
        editing = true; fold(); openEditor?()
    }
    func save() {
        guard canSave else { return }
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSource.isEmpty || ThreadNote.sourceURL(trimmedSource) != nil else {
            error = "Utilise un lien https:// ou le chemin d’un fichier."; return
        }
        var next = archive
        let heading = title.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = editingNote ?? ThreadNote(title: "", intention: "", source: "", createdAt: Date(), example: false)
        updated.title = String((heading.isEmpty ? "Mon point de reprise" : heading).prefix(120))
        updated.intention = String(intention.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1200))
        updated.source = trimmedSource; updated.example = false
        next.keep(updated); selectedID = updated.id
        guard persist(next) else { return }
        editing = false; flash("Le fil est gardé."); fold()
    }
    @discardableResult private func persist(_ next: ThreadArchive) -> Bool {
        do { try ThreadPersistence.save(next, to: storage); archive = next; error = ""; return true }
        catch { self.error = "Enregistrement impossible. Ton texte reste ouvert."; return false }
    }
    func release() { var next = archive; next.release(); if persist(next) { flash("Place libre. Tu peux annuler.") } }
    func undo() { var next = archive; next.undo(); if persist(next) { flash("Le fil précédent est revenu.") } }
    func resume() {
        guard let note else { return }
        openSource(note)
    }
    func openSource(_ note: ThreadNote) {
        guard let url = note.url else {
            flash("Ton point de reprise est ici."); return
        }
        if url.isFileURL && !FileManager.default.fileExists(atPath: url.path) {
            error = "Ce fichier a été déplacé. Modifie le fil pour le retrouver."; return
        }
        guard NSWorkspace.shared.open(url) else { error = "Cette source n’a pas pu être ouverte."; return }
        fold()
    }
    func paste() {
        let board = NSPasteboard.general
        if let files = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let file = files.first {
            edit(dropped: file.absoluteString)
        } else if let text = board.string(forType: .string), !text.isEmpty { edit(dropped: text) }
        else { error = "Copie d’abord un lien, un fichier ou un extrait." }
    }
}
