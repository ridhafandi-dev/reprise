import Foundation
import Darwin

@main struct GateTests {
    static var passed = 0
    static let time: Int64 = 1_800_000_000_000
    static func check(_ name: String, _ body: () throws -> Void) throws {
        try body(); passed += 1; print("PASS Gate: \(name)")
    }
    static func expectError(_ body: () throws -> Void) throws {
        do { try body() } catch { return }
        throw GateError.invalid("test expected rejection")
    }
    static func require(_ value: Bool) throws {
        guard value else { throw GateError.invalid("test assertion failed") }
    }
    static func request(id: UUID = UUID(), action: String = "Publier la branche", now: Int64 = time, ttl: Int = 300) throws -> GateRequest {
        try GateRequest(id: id, requester: "Codex", action: action, target: "ridhafandi-dev/reprise",
            scope: "feature/aegis-gate-v0 uniquement", effect: .difficult,
            evidence: ["Tests locaux réussis"], ttl: ttl, now: now)
    }
    static func altered<T: Encodable>(_ value: T, _ change: (inout [String: Any]) -> Void) throws -> Data {
        var object = try JSONSerialization.jsonObject(with: GateWire.encode(value)) as! [String: Any]
        change(&object)
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    }
    static func withStore(_ body: (GateStore, URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gate-tests-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try body(GateStore(directory: root), root)
    }
    static func path(_ root: URL, _ request: GateRequest, _ suffix: String) -> URL {
        root.appendingPathComponent(request.id.uuidString.lowercased() + suffix)
    }
    static func rawWrite(_ data: Data, _ url: URL) throws {
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    static func main() throws {
        let r = try request()
        try check("valid request Codable and digest roundtrip") {
            try require(GateWire.decode(GateRequest.self, GateWire.encode(r)) == r)
            try require(r.requestDigest == r.digest())
        }
        try check("NFC and edge whitespace normalization before signing") {
            let q = try request(action: "  Cafe\u{301}  ")
            try require(q.action == "Café"); try q.validate()
            try expectError { _ = try GateWire.decode(GateRequest.self, altered(q) { $0["action"] = " Cafe\u{301} " }) }
        }
        try check("canonical hash independent of JSON key order and UUID casing") {
            let data = try altered(r) { $0["id"] = r.id.uuidString.lowercased() }
            try require(GateWire.decode(GateRequest.self, data) == r)
        }
        try check("excessive text and multibyte text rejected, never truncated") {
            try expectError { _ = try request(action: String(repeating: "a", count: 257)) }
            try expectError { _ = try request(action: String(repeating: "é", count: 129)) }
            try expectError { _ = try request(action: String(repeating: " ", count: 300)) }
        }
        try check("empty, control and bidi text rejected") {
            for value in [" ", "foo\nbar", "\u{202E}target", "foo\0bar"] {
                try expectError { _ = try request(action: value) }
            }
        }
        try check("evidence bounded by count and UTF-8 bytes") {
            for evidence in [Array(repeating: "proof", count: 9), [String(repeating: "a", count: 513)]] {
                try expectError { _ = try GateRequest(requester: "X", action: "A", target: "T", scope: "S", effect: .unknown, evidence: evidence, ttl: 30, now: time) }
            }
        }
        try check("invalid UUID and path traversal rejected before filesystem") {
            for value in ["../../escape", "", "foo", r.id.uuidString + "/../../x"] {
                try expectError { _ = try GateWire.decode(GateRequest.self, altered(r) { $0["id"] = value }) }
            }
        }
        try check("TTL 29 and 901 rejected; 30 and 900 accepted") {
            for ttl in [-1, 0, 29, 901, Int.max] { try expectError { _ = try request(ttl: ttl) } }
            try request(ttl: 30).validate(); try request(ttl: 900).validate()
        }
        try check("incoherent and future dates rejected") {
            try expectError { try request(now: time + 1).validate(at: time) }
            for date: Int64 in [-1, r.createdAt, r.createdAt + 29_000, Int64.max] {
                try expectError { _ = try GateWire.decode(GateRequest.self, altered(r) { $0["expiresAt"] = date }) }
            }
        }
        try check("unknown fields, version, enums and wrong types rejected") {
            for (key, value) in [("extra", "x"), ("effect", "safe"), ("version", "1"), ("createdAt", "now")] {
                try expectError { _ = try GateWire.decode(GateRequest.self, altered(r) { $0[key] = value }) }
            }
            try expectError { _ = try GateWire.decode(GateRequest.self, altered(r) { $0["version"] = 2 }) }
            try expectError { _ = try GateWire.decode(GateRequest.self, altered(r) { $0.removeValue(forKey: "scope") }) }
        }
        try check("fractional and exponent timestamp encodings rejected") {
            let original = String(data: try GateWire.encode(r), encoding: .utf8)!
            for token in ["1800000000000.0", "1.8e12"] {
                let data = Data(original.replacingOccurrences(of: "\"createdAt\":1800000000000", with: "\"createdAt\":\(token)").utf8)
                try expectError { _ = try GateWire.decode(GateRequest.self, data) }
            }
        }
        try check("duplicate JSON keys including escaped aliases rejected") {
            let original = String(data: try GateWire.encode(r), encoding: .utf8)!
            for key in ["id", "\\u0069d"] {
                let data = Data(("{\"\(key)\":\"\(r.id.uuidString)\"," + original.dropFirst()).utf8)
                try expectError { _ = try GateWire.decode(GateRequest.self, data) }
            }
        }
        try check("64 KiB maximum, invalid UTF-8 and nesting rejected") {
            var bytes = try GateWire.encode(r)
            bytes.append(Data(repeating: 32, count: GateWire.maxBytes - bytes.count))
            try require(GateWire.decode(GateRequest.self, bytes) == r)
            bytes.append(32); try expectError { _ = try GateWire.decode(GateRequest.self, bytes) }
            try expectError { _ = try GateWire.decode(GateRequest.self, Data([0xff])) }
            try expectError { _ = try GateWire.decode(GateRequest.self, Data((String(repeating: "[", count: 20) + "0" + String(repeating: "]", count: 20)).utf8)) }
        }
        try check("tampered request digest and action rejected") {
            try expectError { _ = try GateWire.decode(GateRequest.self, altered(r) { $0["requestDigest"] = String(repeating: "0", count: 64) }) }
            try expectError { _ = try GateWire.decode(GateRequest.self, altered(r) { $0["scope"] = "toutes les branches" }) }
        }
        let approval = try GateDecision(request: r, outcome: .approveOnce, now: time + 1)
        try check("valid decision Codable and exact six fields") {
            try require(GateWire.decode(GateDecision.self, GateWire.encode(approval)) == approval)
            try require(approval.verified(for: r, at: time + 2).outcome == .approveOnce)
            let fields = try JSONSerialization.jsonObject(with: GateWire.encode(approval)) as! [String:Any]
            try require(Set(fields.keys) == ["version","requestID","requestDigest","outcome","decidedAt","expiresAt"])
        }
        try check("decision from another request rejected") {
            try expectError { _ = try approval.verified(for: request(), at: time + 2) }
        }
        try check("decision digest, expiry and UUID tampering rejected") {
            for (key,value) in [("requestDigest",String(repeating: "f",count:64)),("requestID",UUID().uuidString)] {
                let changed = try GateWire.decode(GateDecision.self, altered(approval) { $0[key] = value })
                try expectError { _ = try changed.verified(for: r, at: time + 2) }
            }
            let changed = try GateWire.decode(GateDecision.self, altered(approval) { $0["expiresAt"] = r.expiresAt + 1 })
            try expectError { _ = try changed.verified(for: r, at: time + 2) }
        }
        try check("unknown outcome and decision fields rejected") {
            try expectError { _ = try GateWire.decode(GateDecision.self, altered(approval) { $0["outcome"] = "approve_forever" }) }
            try expectError { _ = try GateWire.decode(GateDecision.self, altered(approval) { $0["requester"] = "X" }) }
        }
        try check("late approval and exact expiration boundary become expired") {
            try require(approval.verified(for: r, at: r.expiresAt - 1).outcome == .approveOnce)
            try require(approval.verified(for: r, at: r.expiresAt).outcome == .expired)
            try require(approval.verified(for: r, at: r.expiresAt + 1).outcome == .expired)
            let late = try GateWire.decode(GateDecision.self, altered(approval) { $0["decidedAt"] = r.expiresAt + 1 })
            try require(late.verified(for: r, at: r.expiresAt + 2).outcome == .expired)
        }
        try check("future decisions, premature expiry and late deny rejected") {
            try expectError { _ = try approval.verified(for: r, at: time) }
            try expectError { _ = try GateDecision(request: r, outcome: .expired, now: time + 1) }
            let lateDeny = try GateWire.decode(GateDecision.self, altered(approval) { $0["outcome"] = "deny"; $0["decidedAt"] = r.expiresAt })
            try expectError { _ = try lateDeny.verified(for: r, at: r.expiresAt) }
        }
        try check("directory 0700 and protocol files 0600") {
            try withStore { store, root in
                try store.enqueue(r, now: time)
                let mode = try FileManager.default.attributesOfItem(atPath: root.path)[.posixPermissions] as! NSNumber
                try require(mode.intValue == 0o700)
                for file in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
                    let permissions = try FileManager.default.attributesOfItem(atPath: file.path)[.posixPermissions] as! NSNumber
                    try require(permissions.intValue == 0o600)
                }
            }
        }
        try check("FIFO independent requests, capacity, duplicate and conflict") {
            try withStore { store, root in
                var list = [GateRequest]()
                for index in 0..<8 { let q = try request(action: "Action \(index)"); try store.enqueue(q, now: time); list.append(q) }
                try require(store.pendingRequests(now: time).map(\.id) == list.map(\.id))
                try store.enqueue(list[0], now: time)
                try expectError { try store.enqueue(request(), now: time) }
                try expectError { try store.enqueue(request(id: list[0].id, action: "Different"), now: time) }
                try require(store.pendingRequests(now: time).count == 8)
                try require(FileManager.default.contentsOfDirectory(atPath: root.path).filter { $0.hasSuffix(".entry.json") }.count == 8)
            }
        }
        try check("decision only for FIFO head; duplicate decision immutable") {
            try withStore { store, _ in
                let second = try request(); try store.enqueue(r, now: time); try store.enqueue(second, now: time)
                try expectError { _ = try store.decide(second, outcome: .approveOnce, now: time + 1) }
                let first = try store.decide(r, outcome: .deny, now: time + 1)
                try require(store.decide(r, outcome: .approveOnce, now: time + 2) == first)
                try require(store.pendingRequests(now: time + 2).first == second)
            }
        }
        try check("expired queued requests terminalized without approval") {
            try withStore { store, _ in
                let short = try request(ttl: 30); try store.enqueue(r, now: time); try store.enqueue(short, now: time)
                try require(store.pendingRequests(now: time + 30_000) == [r])
                try require(store.readDecision(short, now: time + 30_000)?.outcome == .expired)
                try require(store.decide(r, outcome: .approveOnce, now: r.expiresAt).outcome == .expired)
            }
        }
        try check("expired arrival and restart preserve journal FIFO") {
            try withStore { store, root in
                let expired = try request(ttl: 30)
                try store.enqueue(expired, now: time + 30_000)
                try require(store.readDecision(expired, now: time + 30_000)?.outcome == .expired)
                try store.enqueue(r, now: time + 30_000)
                let reopened = try GateStore(directory: root)
                try require(reopened.pendingRequests(now: time + 30_000) == [r])
            }
        }
        try check("cleanup requires verified receipt; journal and receipt retained") {
            try withStore { store, root in
                try store.enqueue(r, now: time)
                try expectError { try store.cleanup(r, now: time) }
                _ = try store.decide(r, outcome: .deny, now: time + 1)
                try store.cleanup(r, now: time + 2)
                try require(!FileManager.default.fileExists(atPath: path(root,r,".request.json").path))
                try require(FileManager.default.fileExists(atPath: path(root,r,".entry.json").path))
                try require(FileManager.default.fileExists(atPath: path(root,r,".decision.json").path))
                try store.enqueue(r, now: time + 3)
                try require(store.pendingRequests(now: time + 3).isEmpty)
            }
        }
        try check("corrupt request projection preserved and never approved") {
            try withStore { store, root in
                try store.enqueue(r, now: time); let file = path(root,r,".request.json")
                try rawWrite(Data("broken".utf8), file)
                try expectError { _ = try store.decide(r, outcome: .approveOnce, now: time + 1) }
                try require(Data(contentsOf: file) == Data("broken".utf8))
                try require(!FileManager.default.fileExists(atPath: path(root,r,".decision.json").path))
            }
        }
        try check("corrupt receipt preserved, no cleanup or replacement") {
            try withStore { store, root in
                try store.enqueue(r, now: time); let file = path(root,r,".decision.json")
                try rawWrite(Data("broken".utf8), file)
                try expectError { _ = try store.readDecision(r, now: time + 1) }
                try expectError { try store.cleanup(r, now: time + 1) }
                try require(Data(contentsOf: file) == Data("broken".utf8))
                try require(FileManager.default.fileExists(atPath: path(root,r,".request.json").path))
            }
        }
        try check("corrupt journal blocks admission without deleting evidence") {
            try withStore { store, root in
                try store.enqueue(r, now: time); let file = path(root,r,".entry.json")
                try rawWrite(Data("broken".utf8), file)
                try expectError { try store.enqueue(request(), now: time) }
                try require(Data(contentsOf: file) == Data("broken".utf8))
            }
        }
        try check("corrupt sequence cannot overflow FIFO allocation") {
            try withStore { store, root in
                try store.enqueue(r, now: time)
                let file = path(root,r,".entry.json")
                var object = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String:Any]
                object["sequence"] = Int.max
                let corrupt = try JSONSerialization.data(withJSONObject: object)
                try rawWrite(corrupt, file)
                try expectError { try store.enqueue(request(), now: time) }
                try require(Data(contentsOf: file) == corrupt)
            }
        }
        try check("crash recovery reconstructs missing projection from journal") {
            try withStore { store, root in
                try store.enqueue(r, now: time)
                try FileManager.default.removeItem(at: path(root,r,".request.json"))
                try require(store.pendingRequests(now: time) == [r])
                try require(GateWire.decode(GateRequest.self, Data(contentsOf: path(root,r,".request.json"))) == r)
            }
        }
        try check("symlink and unsafe file refusal, external target unchanged") {
            try withStore { store, root in
                let outside = root.appendingPathComponent("sentinel")
                try rawWrite(Data("unchanged".utf8), outside)
                try FileManager.default.createSymbolicLink(at: path(root,r,".request.json"), withDestinationURL: outside)
                try expectError { try store.enqueue(r, now: time) }
                try require(Data(contentsOf: outside) == Data("unchanged".utf8))
                let linkedRoot = root.appendingPathComponent("link")
                try FileManager.default.createSymbolicLink(at: linkedRoot, withDestinationURL: root)
                try expectError { _ = try GateStore(directory: linkedRoot) }
            }
        }
        try check("atomic publication: no temporary files after commit, no overwrite") {
            try withStore { store, root in
                try store.enqueue(r, now: time)
                let file = path(root,r,".entry.json"); let before = try Data(contentsOf: file)
                try expectError { try store.enqueue(request(id: r.id, action: "Other"), now: time) }
                try require(Data(contentsOf: file) == before)
                let decision = try store.decide(r, outcome: .approveOnce, now: time + 1)
                try require(GateWire.decode(GateDecision.self, Data(contentsOf: path(root,r,".decision.json"))) == decision)
                try require(!FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasSuffix(".tmp") })
            }
        }
        try check("request action never executed, even shell-like malicious text") {
            try withStore { store, root in
                let marker = root.appendingPathComponent("MUST-NOT-EXIST")
                let q = try request(action: "touch \(marker.path)")
                try store.enqueue(q, now: time)
                _ = try store.decide(q, outcome: .approveOnce, now: time + 1)
                try store.cleanup(q, now: time + 2)
                try require(!FileManager.default.fileExists(atPath: marker.path))
            }
        }
        try check("clock rollback after admission fails closed") {
            try withStore { store, _ in
                try store.enqueue(r, now: time + 10)
                try expectError { _ = try store.pendingRequests(now: time + 9) }
            }
        }
        try check("environment override and default path") {
            try require(GateStore.defaultDirectory(environment: [:]).path.hasSuffix("/Library/Application Support/Reprise/GateInbox"))
            try require(GateStore.defaultDirectory(environment: ["REPRISE_GATE_PATH":"/tmp/gate-isolated"]).path == "/tmp/gate-isolated")
            try expectError { _ = try GateStore.defaultDirectory(environment: ["REPRISE_GATE_PATH":"../escape"]) }
        }
        print("Gate unit tests: \(passed) passed, 0 failed")
    }
}
