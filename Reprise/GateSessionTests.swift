import Foundation

@MainActor @main struct GateSessionTests {
    final class Clock {
        var now: Int64 = 1_800_000_000_000
        var elapsed: Double = 0
        func advance(_ seconds: Double) { now += Int64(seconds * 1000); elapsed += seconds }
    }
    static var passed = 0
    static func require(_ condition: Bool) throws { if !condition { throw GateError.invalid("UI state assertion") } }
    static func check(_ name: String, _ body: (GateStore, GateSession, Clock, URL) throws -> Void) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("gate-session-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = try GateStore(directory: root); let clock = Clock()
        let session = GateSession(backend: store, wall: { clock.now }, steady: { clock.elapsed })
        try body(store, session, clock, root)
        passed += 1; print("PASS Gate session: \(name)")
    }
    static func request(_ clock: Clock, effect: GateEffect = .difficult, ttl: Int = 300) throws -> GateRequest {
        try GateRequest(requester: "TEST", action: "Valider une simulation", target: "Banc local",
            scope: "Cette simulation uniquement", effect: effect, evidence: ["Déclaration non vérifiée"], ttl: ttl, now: clock.now)
    }
    static func main() throws {
        try check("idle stays closed, no bookmark model") { _, session, _, _ in
            session.tick(); session.reveal()
            try require(!session.isOpen && session.request == nil && session.receipt == nil)
        }
        try check("FIFO selection and count; brief signal then closed but accessible") { store, session, clock, _ in
            let a = try request(clock); let b = try request(clock)
            try store.enqueue(a, now: clock.now); try store.enqueue(b, now: clock.now)
            session.tick(); try require(session.request == a && session.otherCount == 1 && session.isOpen)
            clock.advance(2.1); session.tick(); try require(!session.isOpen)
            session.hover(true); clock.advance(0.11); session.tick(); try require(session.isOpen)
        }
        try check("reversible: one click, immutable digest and persisted receipt") { store, session, clock, _ in
            let a = try request(clock, effect: .reversible); try store.enqueue(a, now: clock.now)
            session.tick(); session.approve(a)
            try require(session.receipt?.decision.outcome == .approveOnce)
            try require(session.receipt?.decision.requestDigest == a.requestDigest)
            try require(store.readDecision(a, now: clock.now) == session.receipt?.decision)
        }
        for effect in [GateEffect.difficult, .irreversible, .unknown] {
            try check("\(effect.rawValue): second click required") { store, session, clock, _ in
                let a = try request(clock, effect: effect); try store.enqueue(a, now: clock.now)
                session.tick(); session.approve(a)
                try require(session.confirming && session.receipt == nil && store.readDecision(a, now: clock.now) == nil)
                clock.advance(1); session.approve(a)
                try require(session.receipt?.decision.outcome == .approveOnce && !session.confirming)
            }
        }
        try check("confirmation expires after exactly five seconds") { store, session, clock, _ in
            let a = try request(clock); try store.enqueue(a, now: clock.now)
            session.tick(); session.approve(a); clock.advance(5); session.tick()
            try require(!session.confirming && store.readDecision(a, now: clock.now) == nil)
            session.approve(a); try require(session.confirming && session.receipt == nil)
        }
        try check("close cancels confirmation without producing any decision") { store, session, clock, _ in
            let a = try request(clock); try store.enqueue(a, now: clock.now)
            session.tick(); session.approve(a); session.hover(true); session.close(); session.tick()
            try require(!session.isOpen && !session.confirming && store.readDecision(a, now: clock.now) == nil)
            session.hover(false); session.reveal(); session.approve(a)
            try require(session.confirming && session.receipt == nil)
        }
        try check("changed request between clicks cancels and fails closed") { store, session, clock, root in
            let a = try request(clock); try store.enqueue(a, now: clock.now)
            session.tick(); session.approve(a)
            let file = root.appendingPathComponent(a.id.uuidString.lowercased() + ".request.json")
            var object = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as! [String:Any]
            object["scope"] = "Autre portée"
            try JSONSerialization.data(withJSONObject: object).write(to: file)
            session.approve(a)
            try require(!session.confirming && !session.canDecide && session.receipt == nil)
            try require(store.readDecision(a, now: clock.now) == nil)
        }
        try check("visible expiration, impossible approval at deadline") { store, session, clock, _ in
            let a = try request(clock, ttl: 30); try store.enqueue(a, now: clock.now)
            session.tick(); session.approve(a); clock.advance(30); session.approve(a)
            try require(session.isOpen && session.receipt?.decision.outcome == .expired && !session.confirming)
        }
        try check("receipt holds five seconds before next head; stale click cannot decide next") { store, session, clock, _ in
            let a = try request(clock); let b = try request(clock)
            try store.enqueue(a, now: clock.now); try store.enqueue(b, now: clock.now)
            session.tick(); session.deny(a); clock.advance(4.99); session.tick()
            try require(session.receipt?.request == a && session.request == nil)
            clock.advance(0.01); session.tick()
            try require(session.receipt == nil && session.request == b)
            session.approve(a)
            try require(!session.confirming && store.readDecision(b, now: clock.now) == nil)
        }
        try check("last receipt folds into silent idle") { store, session, clock, _ in
            let a = try request(clock); try store.enqueue(a, now: clock.now)
            session.tick(); session.deny(a); clock.advance(5); session.tick()
            try require(!session.isOpen && session.request == nil && session.receipt == nil)
        }
        try check("external CLI expiration is displayed before moving on") { store, session, clock, _ in
            let a = try request(clock, ttl: 30); let b = try request(clock)
            try store.enqueue(a, now: clock.now); try store.enqueue(b, now: clock.now); session.tick()
            clock.advance(30); _ = try store.readDecision(a, now: clock.now); try store.cleanup(a, now: clock.now)
            session.tick(); try require(session.receipt?.decision.outcome == .expired && session.request == nil)
            clock.advance(5); session.tick(); try require(session.request == b)
        }
        try check("bulk refusal persists each exact receipt, later arrivals excluded") { store, session, clock, _ in
            let a = try request(clock); let b = try request(clock)
            try store.enqueue(a, now: clock.now); try store.enqueue(b, now: clock.now); session.tick(); session.denyAll()
            try require(store.readDecision(a, now: clock.now)?.outcome == .deny)
            try require(store.readDecision(b, now: clock.now)?.requestDigest == b.requestDigest)
            let later = try request(clock); try store.enqueue(later, now: clock.now)
            clock.advance(5); session.tick(); try require(session.receipt?.request == b)
            clock.advance(5); session.tick(); try require(session.request == later)
            try require(store.readDecision(later, now: clock.now) == nil)
        }
        try check("demo is explicitly marked and synthetic") { store, session, clock, _ in
            session.sendDemo()
            try require(session.request?.requester == "DÉMONSTRATION")
            try require(session.request?.scope.contains("Aucun effet") == true)
            try require(store.pendingRequests(now: clock.now).count == 1)
        }
        try check("clock rollback cancels confirmation") { store, session, clock, _ in
            let a = try request(clock); try store.enqueue(a, now: clock.now); session.tick(); session.approve(a)
            clock.now -= 1; session.tick()
            try require(!session.confirming && !session.canDecide && session.receipt == nil)
        }
        print("Gate session tests: \(passed) passed, 0 failed")
    }
}
