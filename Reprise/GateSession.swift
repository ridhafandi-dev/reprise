import Foundation
import Combine

struct GateVisualReceipt: Equatable {
    let request: GateRequest
    let decision: GateDecision
}

// Presentation state is independent of SwiftUI and of the bookmark store.
// Every click carries the displayed immutable request, never merely "queue head".
@MainActor final class GateSession: ObservableObject {
    @Published private(set) var request: GateRequest?
    @Published private(set) var receipt: GateVisualReceipt?
    @Published private(set) var isOpen = false
    @Published private(set) var otherCount = 0
    @Published private(set) var confirming = false
    @Published private(set) var remaining = 0
    @Published private(set) var error = ""
    private let backend: GateStore
    private let wall: () -> Int64
    private let steady: () -> Double
    private let testTime: (() -> Int64)?
    private var lastWall: Int64
    private var confirmIdentity: String?
    private var confirmWall: Int64 = 0
    private var confirmUntil: Double = 0
    private var receiptUntil: Double = 0
    private var announceUntil: Double = 0
    private var enterAt: Double?
    private var leaveAt: Double?
    private var inside = false
    private var closedUntilExit = false
    private var queuedReceipts: [GateVisualReceipt] = []

    init(backend: GateStore, wall: (() -> Int64)? = nil, steady: (() -> Double)? = nil) {
        self.backend = backend; self.wall = wall ?? GateWire.now; testTime = wall
        let origin = ContinuousClock.now
        self.steady = steady ?? {
            let duration = origin.duration(to: .now).components
            return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        }
        lastWall = (wall ?? GateWire.now)()
    }
    var canDecide: Bool { request != nil && receipt == nil && error.isEmpty && remaining > 0 }
    private func identity(_ r: GateRequest) -> String { r.id.uuidString + ":" + r.requestDigest }
    private func cancelConfirmation() { confirming = false; confirmIdentity = nil }
    private func fail(_ failure: Error) {
        cancelConfirmation()
        error = "Décision suspendue. Le stockage ou la requête ne peut pas être vérifié."
        // Do not replace data or announce a receipt when persistence is uncertain.
    }
    func tick() {
        let now = wall(); let instant = steady()
        guard now >= lastWall else { fail(GateError.invalid("clock rollback")); return }
        lastWall = now
        if confirming && (now >= confirmWall || instant >= confirmUntil) { cancelConfirmation() }
        do {
            // Read the displayed request's terminal result before advancing FIFO,
            // including expiration produced by the waiting CLI.
            if let current = request, receipt == nil,
               let decision = try backend.readDecision(current, now: now) {
                present(GateVisualReceipt(request: current, decision: decision))
            }
            let pending = try backend.pendingRequests(now: now)
            error = ""
            if receipt != nil {
                otherCount = pending.count
                if instant < receiptUntil { return }
                receipt = nil
                if !queuedReceipts.isEmpty { present(queuedReceipts.removeFirst()); return }
            }
            if request != pending.first {
                cancelConfirmation(); request = pending.first
                remaining = pending.first.map { max(0, Int(($0.expiresAt - now + 999) / 1000)) } ?? 0
                if request != nil {
                    closedUntilExit = false; isOpen = true; announceUntil = instant + 2
                } else { isOpen = false }
            }
            otherCount = max(0, pending.count - (request == nil ? 0 : 1))
            remaining = request.map { max(0, Int(($0.expiresAt - now + 999) / 1000)) } ?? 0
            if request == nil { isOpen = false; return }
            if !closedUntilExit, inside, let entered = enterAt, instant - entered >= 0.1 { isOpen = true }
            if !inside && instant >= announceUntil && !confirming,
               leaveAt.map({ instant - $0 >= 0.3 }) ?? true { isOpen = false }
        } catch { fail(error) }
    }
    func hover(_ value: Bool) {
        guard inside != value else { return }
        inside = value
        if value { enterAt = steady(); leaveAt = nil }
        else { enterAt = nil; leaveAt = steady(); closedUntilExit = false }
    }
    func reveal() {
        tick()
        guard request != nil || receipt != nil || !error.isEmpty else { return }
        isOpen = true; announceUntil = steady() + 2; closedUntilExit = false
    }
    func close() {
        isOpen = false; cancelConfirmation(); announceUntil = 0; closedUntilExit = inside
        // Closing is never a business decision.
    }
    func approve(_ displayed: GateRequest) {
        tick()
        guard canDecide, request == displayed else { cancelConfirmation(); return }
        if displayed.effect != .reversible {
            if !confirming || confirmIdentity != identity(displayed) {
                confirmIdentity = identity(displayed); confirming = true
                confirmWall = wall() + 5_000; confirmUntil = steady() + 5; isOpen = true
                return
            }
        }
        commit(displayed, outcome: .approveOnce)
    }
    func deny(_ displayed: GateRequest) {
        tick()
        guard canDecide, request == displayed else { cancelConfirmation(); return }
        commit(displayed, outcome: .deny)
    }
    private func commit(_ displayed: GateRequest, outcome: GateOutcome) {
        cancelConfirmation()
        do {
            let decision = try backend.decide(displayed, outcome: outcome, now: testTime?())
            present(GateVisualReceipt(request: displayed, decision: decision))
            otherCount = try backend.pendingRequests(now: wall()).count
        } catch { fail(error) }
    }
    private func present(_ value: GateVisualReceipt) {
        cancelConfirmation(); request = nil; remaining = 0
        receipt = value; receiptUntil = steady() + 5; isOpen = true
        closedUntilExit = false; error = ""
    }
    func sendDemo() {
        do {
            let demo = try GateRequest(requester: "DÉMONSTRATION", action: "Valider un passage de relais fictif",
                target: "Espace de démonstration local", scope: "Cette demande synthétique uniquement. Aucun effet en dehors de Reprise.",
                effect: .difficult, evidence: ["Scénario synthétique — aucune action ne sera exécutée."], ttl: 120, now: wall())
            try backend.enqueue(demo, now: wall()); tick()
        } catch { fail(error); isOpen = true }
    }
    func denyAll() {
        cancelConfirmation()
        do {
            // Snapshot only: a request admitted after this gesture is not covered.
            let pending = try backend.pendingRequests(now: wall())
            for item in pending {
                let decision = try backend.decide(item, outcome: .deny, now: testTime?())
                let visual = GateVisualReceipt(request: item, decision: decision)
                if receipt == nil { present(visual) } else { queuedReceipts.append(visual) }
            }
            otherCount = try backend.pendingRequests(now: wall()).count
        } catch { fail(error) }
    }
}
