import Foundation
@main struct CaptureTests {
    @MainActor static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = RepriseStore(storageURL: root.appendingPathComponent("thread.json"))
        let initial = store.archive.saved.count
        var capture = PageCapture(version: 1, id: UUID().uuidString, url: "https://www.youtube.com/watch?v=test&t=10", title: "Une vidéo", author: "Auteur", excerpt: "", description: "Description", kind: "video", seconds: 763)
        precondition(store.receive(capture)); precondition(!store.editing)
        precondition(store.note?.timeLabel == "12:43")
        precondition(store.note?.resumeURL?.absoluteString.contains("t=763") == true)
        let count=store.archive.saved.count
        precondition(count == initial + 1)
        capture.id = UUID().uuidString; capture.seconds = 800
        precondition(store.receive(capture)); precondition(store.archive.saved.count == count)
        precondition(store.note?.timeLabel == "13:20")
        store.edit(existing: true); store.intention = ""; precondition(store.canSave); store.save()
        precondition(store.note?.context?.author == "Auteur")
        let restored = try ThreadPersistence.load(from: root.appendingPathComponent("thread.json"))
        precondition(restored.current?.timeLabel == "13:20")
        precondition(restored.current?.citation.contains("Auteur") == true)
        capture.url = "file:///etc/passwd"; precondition(!store.receive(capture)); precondition(store.archive.saved.count == count)
        capture.url = "https://example.com/"; capture.seconds = 25
        let checked = try capture.validated(); precondition(checked.seconds == nil)
        capture.id = "../../invalid"; precondition(!store.receive(capture))
        store.captureText("https://example.com/a"); precondition(!store.editing && store.note?.url?.host == "example.com")
        store.release(); precondition(store.note == nil); store.undo(); precondition(store.note?.url?.host == "example.com")
        let inbox = root.appendingPathComponent("inbox")
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        capture.id = UUID().uuidString; capture.seconds = nil
        let incoming = inbox.appendingPathComponent(capture.id + ".json")
        try JSONEncoder().encode(capture).write(to: incoming)
        store.drainCaptures(in: inbox)
        let ackData = try Data(contentsOf: inbox.appendingPathComponent(capture.id + ".ack"))
        let ack = try JSONDecoder().decode(CaptureReceipt.self, from: ackData)
        precondition(ack.ok && !FileManager.default.fileExists(atPath: incoming.path))
        let inboxSaved = try ThreadPersistence.load(from: root.appendingPathComponent("thread.json")); precondition(inboxSaved.current?.source == capture.url)
        let badPath = root.appendingPathComponent("corrupt.json")
        try Data("broken".utf8).write(to: badPath)
        let brokenStore = RepriseStore(storageURL: badPath)
        precondition(!brokenStore.receive(capture))
        let untouched = try String(contentsOf: badPath, encoding: .utf8); precondition(untouched == "broken")
        print("PASS: immediate capture, timestamp URL, repeat capture dedup, optional note, context persistence, unsafe payloads, paste/release/undo")
    }
}
