import AppKit

// A separate executable using Chrome's length-prefixed native messaging protocol.
// The only accepted operation is a bounded, validated web-reference capture.
@main struct NativeHost {
    static func send(_ receipt: CaptureReceipt) {
        guard let data = try? JSONEncoder().encode(receipt) else { return }
        var size = UInt32(data.count).littleEndian
        FileHandle.standardOutput.write(Data(bytes: &size, count: 4))
        FileHandle.standardOutput.write(data)
    }
    static func readExact(_ count: Int) -> Data {
        var result = Data()
        while result.count < count {
            let part = FileHandle.standardInput.readData(ofLength: count - result.count)
            if part.isEmpty { break }; result.append(part)
        }
        return result
    }
    static func main() {
        guard CommandLine.arguments.dropFirst().first == BridgeIdentity.origin else {
            send(.init(ok: false, error: "Extension non reconnue.")); return
        }
        let header = readExact(4)
        guard header.count == 4 else { return }
        let size = header.enumerated().reduce(UInt32(0)) { $0 | (UInt32($1.element) << ($1.offset * 8)) }
        guard size > 0, size <= 65536 else { send(.init(ok: false, error: "Référence trop volumineuse.")); return }
        do {
            let capture = try JSONDecoder().decode(PageCapture.self, from: readExact(Int(size))).validated()
            try CaptureInbox.prepare()
            let file = CaptureInbox.directory.appendingPathComponent(capture.id + ".json")
            let receipt = CaptureInbox.directory.appendingPathComponent(capture.id + ".ack")
            try? FileManager.default.removeItem(at: receipt)
            try JSONEncoder().encode(capture).write(to: file, options: .atomic)
            if NSRunningApplication.runningApplications(withBundleIdentifier: "tools.pulsar.reprise.study").isEmpty {
                let executable = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath()
                let app = executable.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                let config = NSWorkspace.OpenConfiguration(); config.activates = false; config.arguments = ["--quiet"]
                NSWorkspace.shared.openApplication(at: app, configuration: config) { _, _ in }
            }
            DistributedNotificationCenter.default().postNotificationName(NSNotification.Name(CaptureInbox.notification), object: nil, userInfo: nil, deliverImmediately: true)
            let deadline = Date().addingTimeInterval(8)
            while Date() < deadline {
                if let data = try? Data(contentsOf: receipt), let ack = try? JSONDecoder().decode(CaptureReceipt.self, from: data) {
                    try? FileManager.default.removeItem(at: receipt); send(ack); return
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.05))
            }
            // Leave the pending capture for the next app launch; do not claim success.
            send(.init(ok: false, error: "Reprise n’a pas encore confirmé. Ouvre l’app : la capture est en attente."))
        } catch { send(.init(ok: false, error: error.localizedDescription)) }
    }
}
