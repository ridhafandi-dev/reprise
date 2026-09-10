import Foundation
import AppKit

@main struct RepriseGate {
    static let usage = """
    RepriseGate ask --requester TEXT --action TEXT --target TEXT --scope TEXT
      --effect reversible|difficult|irreversible|unknown [--evidence TEXT ...] --ttl 30..900 [--no-wait]
    --no-wait: test/diagnostic admission only; outputs the request, exits 4, never approval.
    Exit codes: 0 approve_once, 2 deny, 3 expired, 4 pending (--no-wait), 1 error.
    REPRISE_GATE_PATH: absolute isolated inbox path (tests/diagnostics).
    """
    static func run(_ args: [String]) throws -> Int32 {
        guard args.first == "ask" else { throw GateError.invalid(usage) }
        let required: Set<String> = ["--requester", "--action", "--target", "--scope", "--effect", "--ttl"]
        var options = [String:String](); var evidence = [String](); var noWait = false; var i = 1
        while i < args.count {
            let key = args[i]; i += 1
            if key == "--no-wait" {
                guard !noWait else { throw GateError.invalid("duplicate --no-wait") }; noWait = true; continue
            }
            guard required.contains(key) || key == "--evidence", i < args.count else { throw GateError.invalid("unknown or missing option: \(key)") }
            let value = args[i]; i += 1
            if key == "--evidence" { evidence.append(value) }
            else { guard options[key] == nil else { throw GateError.invalid("duplicate option: \(key)") }; options[key] = value }
        }
        guard Set(options.keys) == required, let effect = GateEffect(rawValue: options["--effect"]!),
              let ttl = Int(options["--ttl"]!) else { throw GateError.invalid(usage) }
        let request = try GateRequest(requester: options["--requester"]!, action: options["--action"]!,
            target: options["--target"]!, scope: options["--scope"]!, effect: effect, evidence: evidence, ttl: ttl)
        let clock = ContinuousClock(); let deadline = clock.now.advanced(by: .seconds(ttl))
        let store = try GateStore(directory: GateStore.defaultDirectory())
        try store.enqueue(request)
        // Only a wake-up hint, never launch an app, pass action text, or contact the network.
        if !NSRunningApplication.runningApplications(withBundleIdentifier: "tools.pulsar.reprise.study").isEmpty {
            DistributedNotificationCenter.default().postNotificationName(
                NSNotification.Name(GateStore.notification), object: nil, userInfo: nil, deliverImmediately: true)
        }
        if noWait { try output(request); return 4 }
        var previousWall = request.createdAt
        while true {
            let wall = GateWire.now()
            guard wall >= previousWall else { throw GateError.invalid("clock moved backwards; request preserved, no authorization") }
            previousWall = wall
            let effectiveNow = clock.now >= deadline ? max(wall, request.expiresAt) : wall
            if let decision = try store.readDecision(request, now: effectiveNow) {
                // Verify again at delivery, including expiration during disk I/O.
                let delivered = try decision.verified(for: request, at: max(effectiveNow, GateWire.now()))
                try store.cleanup(request, now: max(effectiveNow, GateWire.now()))
                // Cleanup may span the deadline too. Never output a stale approval.
                let final = try delivered.verified(for: request, at: max(effectiveNow, GateWire.now()))
                try output(final)
                switch final.outcome { case .approveOnce: return 0; case .deny: return 2; case .expired: return 3 }
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
    }
    static func output<T: Encodable>(_ value: T) throws {
        var data = try GateWire.encode(value); data.append(10)
        try FileHandle.standardOutput.write(contentsOf: data)
    }
    static func main() {
        if CommandLine.arguments.dropFirst().elementsEqual(["--help"]) { print(usage); return }
        do { exit(try run(Array(CommandLine.arguments.dropFirst()))) }
        catch {
            try? FileHandle.standardError.write(contentsOf: Data("\(error)\n".utf8))
            exit(1)
        }
    }
}
