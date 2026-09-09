import Foundation

@main struct HoverTests {
    @MainActor static func main() async throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("thread.json")
        let store = RepriseStore(storageURL: path)
        store.hover(true)
        try await Task.sleep(for: .milliseconds(40))
        store.hover(false)
        try await Task.sleep(for: .milliseconds(120))
        precondition(!store.isOpen, "A brief pass should not open the notch")
        store.hover(true)
        try await Task.sleep(for: .milliseconds(140))
        precondition(store.isOpen)
        store.hover(false)
        try await Task.sleep(for: .milliseconds(150))
        precondition(store.isOpen, "Crossing the edge should not snap it shut")
        store.hover(true)
        try await Task.sleep(for: .milliseconds(200))
        precondition(store.isOpen, "Returning cancels the pending close")
        store.hover(false)
        // The fallback poll must not continually postpone closing.
        for _ in 0..<5 { store.hover(false); try await Task.sleep(for: .milliseconds(80)) }
        precondition(!store.isOpen)
        store.reveal(); store.fold()
        try await Task.sleep(for: .milliseconds(150))
        precondition(!store.isOpen)
        print("PASS: hover dwell, exit grace, interrupted close, repeated polls, explicit fold")
    }
}
