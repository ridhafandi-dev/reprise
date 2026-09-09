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
    private var storageReadable = true
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
        catch { storageReadable = false; self.error = "Le fil enregistré ne peut pas être lu. Le fichier est conservé." }
        side = UserDefaults.standard.string(forKey: "reprise.edge") == "left" ? .left : .right
    }
    var note: ThreadNote? { archive.current }
    var isOpen: Bool { expanded || targeted }
    var canSave: Bool { !intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ThreadNote.sourceURL(source) != nil }
    var visibleNotes: [ThreadNote] {
        archive.saved.filter { note in
            (!onlyParked || note.id != archive.current?.id) &&
            (query.isEmpty || [note.title, note.intention, note.source, note.context?.excerpt ?? "", note.context?.author ?? ""].joined(separator: " ").localizedStandardContains(query))
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
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(note.citation, forType: .string)
        flash("Extrait et source copiés.")
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
        updated.title = String((heading.isEmpty ? (ThreadNote.sourceURL(trimmedSource)?.host ?? "Mon point de reprise") : heading).prefix(120))
        updated.intention = String(intention.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1200))
        if updated.source != trimmedSource { updated.context = nil }
        updated.source = trimmedSource; updated.example = false
        next.keep(updated); selectedID = updated.id
        guard persist(next) else { return }
        editing = false; flash("Le fil est gardé."); fold()
    }
    @discardableResult private func persist(_ next: ThreadArchive) -> Bool {
        guard storageReadable else { error = "Le fichier existant ne peut pas être lu. Capture non enregistrée pour le préserver."; return false }
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
        guard let url = note.resumeURL else {
            flash("Ton point de reprise est ici."); return
        }
        if url.isFileURL && !FileManager.default.fileExists(atPath: url.path) {
            error = "Ce fichier a été déplacé. Modifie le fil pour le retrouver."; return
        }
        guard NSWorkspace.shared.open(url) else { error = "Cette source n’a pas pu être ouverte."; return }
        fold()
    }
    // Used by paste/drop. Browser capture provides richer metadata through receive().
    func captureText(_ text: String) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        let url = ThreadNote.sourceURL(value)
        let note = ThreadNote(title: url.map { $0.isFileURL ? $0.lastPathComponent : ($0.host ?? "Référence") } ?? String(value.prefix(100)), intention: url == nil ? String(value.prefix(2000)) : "", source: url?.absoluteString ?? "", createdAt: Date(), example: false)
        var next = archive; next.keep(note)
        if persist(next) { selectedID = note.id; flash("Gardé au bord."); reveal() }
    }
    @discardableResult func receive(_ payload: PageCapture) -> Bool {
        do {
            let capture = try payload.validated()
            var note = archive.saved.first { $0.source == capture.url && $0.context?.excerpt == capture.excerpt }
                ?? ThreadNote(title: capture.title, intention: "", source: capture.url, createdAt: Date(), example: false)
            note.title = capture.title; note.context = capture; note.createdAt = Date(); note.example = false
            var next = archive; next.keep(note)
            guard persist(next) else { return false }
            selectedID = note.id; flash("Gardé au bord."); reveal(); return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func drainCaptures(in directory: URL = CaptureInbox.directory) {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        for file in files.filter({ $0.pathExtension == "json" }).sorted(by: {
            let first = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let second = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return first < second
        }) {
            guard UUID(uuidString: file.deletingPathExtension().lastPathComponent) != nil else { continue }
            do {
                let data = try Data(contentsOf: file)
                guard data.count <= 65536 else { throw CaptureError.invalid }
                let capture = try JSONDecoder().decode(PageCapture.self, from: data).validated()
                guard capture.id == file.deletingPathExtension().lastPathComponent else { throw CaptureError.invalid }
                let ok = receive(capture)
                let ack = CaptureReceipt(ok: ok, error: ok ? nil : error)
                try JSONEncoder().encode(ack).write(to: file.deletingPathExtension().appendingPathExtension("ack"), options: .atomic)
                try FileManager.default.removeItem(at: file)
            } catch {
                let ack = CaptureReceipt(ok: false, error: error.localizedDescription)
                try? JSONEncoder().encode(ack).write(to: file.deletingPathExtension().appendingPathExtension("ack"), options: .atomic)
                // Preserve rejected data, without repeatedly attempting it.
                try? FileManager.default.moveItem(at: file, to: file.appendingPathExtension("rejected"))
            }
        }
    }
    func paste() {
        let board = NSPasteboard.general
        if let files = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL], let file = files.first {
            captureText(file.absoluteString)
        } else if let text = board.string(forType: .string), !text.isEmpty { captureText(text) }
        else { error = "Copie d’abord un lien, un fichier ou un extrait." }
    }
}
