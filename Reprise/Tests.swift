import Foundation

@main struct RepriseTests {
    static func main() throws {
        precondition(ThreadNote.sourceURL("javascript:alert(1)") == nil)
        precondition(ThreadNote.sourceURL("https://user:secret@example.com") == nil)
        precondition(ThreadNote.sourceURL("https://example.com/test")?.host == "example.com")
        precondition(ThreadNote.sourceURL("/tmp/un fichier.txt")?.isFileURL == true)
        precondition(ThreadNote.sourceURL("ceci est une note") == nil)
        var archive = ThreadArchive(current: .example)
        let mine = ThreadNote(title: "Essai", intention: "Reprendre le deuxième paragraphe", source: "", createdAt: Date(), example: false)
        archive.keep(mine)
        precondition(archive.current == mine && archive.previous == .example)
        archive.release(); precondition(archive.current == nil && archive.previous == mine)
        archive.undo(); precondition(archive.current == mine)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("thread.json")
        try ThreadPersistence.save(archive, to: url)
        let restored = try ThreadPersistence.load(from: url)
        precondition(restored.current == mine)
        precondition(restored.previous == nil)
        precondition(restored.saved.contains { $0.id == mine.id })
        // V1 archives have no history and notes have no identity. Decode them
        // without losing the previous thread, then persist as V2.
        let legacy = Data(#"{"current":null,"previous":{"title":"Ancien fil","intention":"Continuer ici","source":"","createdAt":12,"example":false}}"#.utf8)
        var migrated = try JSONDecoder().decode(ThreadArchive.self, from: legacy)
        precondition(migrated.saved.count == 1)
        let legacyID = migrated.saved[0].id
        migrated.keep(mine); migrated.release()
        precondition(migrated.saved.contains { $0.id == legacyID })
        precondition(migrated.saved.contains { $0.id == mine.id })
        var edited = mine; edited.intention = "Version modifiée"
        migrated.keep(edited)
        precondition(migrated.saved.filter { $0.id == mine.id }.count == 1)
        precondition(migrated.saved.first { $0.id == mine.id }?.intention == "Version modifiée")
        try Data("broken".utf8).write(to: url)
        do { _ = try ThreadPersistence.load(from: url); fatalError("Corrupt archive was silently replaced") }
        catch { /* Expected: the caller preserves the file and shows an error. */ }
        print("PASS: URL restrictions, file paths, replace/release/undo, persistence, V1 migration, saved history and identity, corrupt state")
    }
}
