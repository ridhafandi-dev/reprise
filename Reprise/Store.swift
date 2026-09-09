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
    @Published var side: NotchEdge = .right
    var openEditor: (() -> Void)?
    var onShapeChange: (() -> Void)?
    var showWelcome: (() -> Void)?
    private var closeWork: DispatchWorkItem?
    private var noticeWork: DispatchWorkItem?
    private var manualOpenUntil = Date.distantPast
    private let storage: URL

    init() {
        if let value = ProcessInfo.processInfo.environment["REPRISE_STATE_PATH"] {
            storage = URL(fileURLWithPath: value)
        } else {
            storage = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Reprise/thread.json")
        }
        do { archive = try ThreadPersistence.load(from: storage) }
        catch { self.error = "Le fil enregistré ne peut pas être lu. Le fichier est conservé." }
    }
    var note: ThreadNote? { archive.current }
    var isOpen: Bool { expanded || targeted }
    var canSave: Bool { !intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    func reveal() {
        closeWork?.cancel()
        manualOpenUntil = Date().addingTimeInterval(3)
        expanded = true
    }
    func hover(_ inside: Bool) {
        closeWork?.cancel()
        if inside { expanded = true }
        else if !editing {
            let work = DispatchWorkItem { [weak self] in self?.expanded = false }
            closeWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0.65, manualOpenUntil.timeIntervalSinceNow), execute: work)
        }
    }
    func fold() { closeWork?.cancel(); expanded = false; targeted = false }
    func flash(_ text: String) {
        noticeWork?.cancel(); notice = text
        let work = DispatchWorkItem { [weak self] in self?.notice = "" }
        noticeWork = work; DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
    }
    func edit(existing: Bool = false, dropped: String? = nil) {
        closeWork?.cancel(); error = ""
        title = existing ? note?.title ?? "" : ""
        intention = existing ? note?.intention ?? "" : ""
        source = existing ? note?.source ?? "" : ""
        if let dropped {
            if let url = ThreadNote.sourceURL(dropped) {
                source = url.isFileURL ? url.path : url.absoluteString
                title = url.isFileURL ? url.deletingPathExtension().lastPathComponent : url.host ?? ""
            } else { intention = String(dropped.prefix(1200)) }
        }
        editing = true; expanded = true; openEditor?()
    }
    func save() {
        guard canSave else { return }
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedSource.isEmpty || ThreadNote.sourceURL(trimmedSource) != nil else {
            error = "Utilise un lien https:// ou le chemin d’un fichier."; return
        }
        var next = archive
        let heading = title.trimmingCharacters(in: .whitespacesAndNewlines)
        next.keep(ThreadNote(title: String((heading.isEmpty ? "Mon point de reprise" : heading).prefix(120)), intention: String(intention.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1200)), source: trimmedSource, createdAt: Date(), example: false))
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
