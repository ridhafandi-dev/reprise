import Foundation
import CryptoKit

enum GateError: Error, CustomStringConvertible {
    case invalid(String), storage(String)
    var description: String {
        switch self { case .invalid(let s): return "Invalid Gate message: \(s)"
        case .storage(let s): return "Gate storage: \(s)" }
    }
}

enum GateEffect: String, Codable, CaseIterable { case reversible, difficult, irreversible, unknown }
enum GateOutcome: String, Codable { case approveOnce = "approve_once", deny, expired }

// Milliseconds since Unix epoch, never floating point dates on the wire.
enum GateWire {
    static let maxBytes = 65_536
    static func now() -> Int64 { Int64((Date().timeIntervalSince1970 * 1000).rounded(.down)) }
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(value)
        guard data.count <= maxBytes else { throw GateError.invalid("message exceeds 64 KiB") }
        return data
    }
    static func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        guard !data.isEmpty, data.count <= maxBytes, String(data: data, encoding: .utf8) != nil else {
            throw GateError.invalid("invalid UTF-8 or message size")
        }
        var scanner = GateJSONScanner(bytes: Array(data))
        try scanner.validate()
        return try JSONDecoder().decode(type, from: data)
    }
    static func text(_ raw: String, limit: Int, normalize: Bool) throws -> String {
        guard raw.utf8.count <= limit else { throw GateError.invalid("text exceeds \(limit) UTF-8 bytes") }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).precomposedStringWithCanonicalMapping
        guard !value.isEmpty, value.utf8.count <= limit, normalize || raw == value,
              !value.unicodeScalars.contains(where: {
                  CharacterSet.controlCharacters.contains($0) || (0x202A...0x202E).contains($0.value)
                  || (0x2066...0x2069).contains($0.value)
              }) else { throw GateError.invalid("empty, non-normalized or control text") }
        return value
    }
}

private struct GateKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}
private func closed(_ decoder: Decoder, _ fields: Set<String>) throws {
    let keys = try decoder.container(keyedBy: GateKey.self).allKeys.map(\.stringValue)
    guard Set(keys) == fields else { throw GateError.invalid("unknown or missing fields") }
}

struct GateRequest: Codable, Equatable {
    let version: Int
    let id: UUID
    let requester: String
    let action: String
    let target: String
    let scope: String
    let effect: GateEffect
    let evidence: [String]
    let createdAt: Int64
    let expiresAt: Int64
    let requestDigest: String

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case version, id, requester, action, target, scope, effect, evidence, createdAt, expiresAt, requestDigest
    }
    // Canonical V1: sorted ASCII keys, compact JSON, NFC text, lowercase UUID,
    // integer milliseconds, ordered evidence, UTF-8, unescaped slash; no digest field.
    private struct Unsigned: Encodable {
        let version: Int; let id: String; let requester: String; let action: String
        let target: String; let scope: String; let effect: GateEffect; let evidence: [String]
        let createdAt: Int64; let expiresAt: Int64
    }
    func canonicalData() throws -> Data {
        return try GateWire.encode(Unsigned(version: version, id: id.uuidString.lowercased(), requester: requester,
            action: action, target: target, scope: scope, effect: effect, evidence: evidence,
            createdAt: createdAt, expiresAt: expiresAt))
    }
    func digest() throws -> String { SHA256.hash(data: try canonicalData()).map { String(format: "%02x", $0) }.joined() }

    init(id: UUID = UUID(), requester: String, action: String, target: String, scope: String,
         effect: GateEffect, evidence: [String], ttl: Int, now: Int64 = GateWire.now()) throws {
        guard (30...900).contains(ttl), now >= 0, now <= 253_402_300_799_000 - 900_000,
              evidence.count <= 8 else { throw GateError.invalid("TTL, dates or evidence count") }
        self.version = 1; self.id = id
        self.requester = try GateWire.text(requester, limit: 128, normalize: true)
        self.action = try GateWire.text(action, limit: 256, normalize: true)
        self.target = try GateWire.text(target, limit: 1024, normalize: true)
        self.scope = try GateWire.text(scope, limit: 2048, normalize: true)
        self.effect = effect
        self.evidence = try evidence.map { try GateWire.text($0, limit: 512, normalize: true) }
        createdAt = now; expiresAt = now + Int64(ttl) * 1000
        // Initialize through a private value to avoid ever hashing the digest itself.
        requestDigest = try Self.hash(version: 1, id: id, requester: self.requester, action: self.action,
            target: self.target, scope: self.scope, effect: effect, evidence: self.evidence,
            createdAt: createdAt, expiresAt: expiresAt)
    }
    private static func hash(version: Int, id: UUID, requester: String, action: String, target: String,
                             scope: String, effect: GateEffect, evidence: [String], createdAt: Int64, expiresAt: Int64) throws -> String {
        let unsigned = try GateWire.encode(Unsigned(version: version, id: id.uuidString.lowercased(),
            requester: requester, action: action, target: target, scope: scope, effect: effect,
            evidence: evidence, createdAt: createdAt, expiresAt: expiresAt))
        return SHA256.hash(data: unsigned).map { String(format: "%02x", $0) }.joined()
    }
    init(from decoder: Decoder) throws {
        try closed(decoder, Set(CodingKeys.allCases.map(\.rawValue)))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        let rawID = try c.decode(String.self, forKey: .id)
        guard let uuid = UUID(uuidString: rawID), rawID.lowercased() == uuid.uuidString.lowercased() else {
            throw GateError.invalid("UUID")
        }
        id = uuid; requester = try c.decode(String.self, forKey: .requester)
        action = try c.decode(String.self, forKey: .action); target = try c.decode(String.self, forKey: .target)
        scope = try c.decode(String.self, forKey: .scope); effect = try c.decode(GateEffect.self, forKey: .effect)
        evidence = try c.decode([String].self, forKey: .evidence)
        createdAt = try c.decode(Int64.self, forKey: .createdAt); expiresAt = try c.decode(Int64.self, forKey: .expiresAt)
        requestDigest = try c.decode(String.self, forKey: .requestDigest)
        try validate()
    }
    func validate(at now: Int64? = nil) throws {
        guard version == 1, createdAt >= 0, expiresAt <= 253_402_300_799_000,
              expiresAt >= createdAt, (30_000...900_000).contains(expiresAt - createdAt),
              now.map({ createdAt <= $0 }) ?? true, evidence.count <= 8 else { throw GateError.invalid("version, dates or evidence") }
        for (text, limit) in [(requester,128),(action,256),(target,1024),(scope,2048)] {
            _ = try GateWire.text(text, limit: limit, normalize: false)
        }
        for text in evidence { _ = try GateWire.text(text, limit: 512, normalize: false) }
        guard requestDigest == (try digest()) else { throw GateError.invalid("request digest mismatch") }
        _ = try GateWire.encode(self)
    }
}

struct GateDecision: Codable, Equatable {
    let version: Int
    let requestID: UUID
    let requestDigest: String
    let outcome: GateOutcome
    let decidedAt: Int64
    let expiresAt: Int64
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case version, requestID, requestDigest, outcome, decidedAt, expiresAt
    }
    init(request: GateRequest, outcome: GateOutcome, now: Int64) throws {
        try request.validate()
        guard now >= request.createdAt, now <= 253_402_300_799_000 else { throw GateError.invalid("decision precedes request") }
        if outcome == .expired && now < request.expiresAt { throw GateError.invalid("premature expiration") }
        version = 1; requestID = request.id; requestDigest = request.requestDigest
        self.outcome = now >= request.expiresAt ? .expired : outcome
        decidedAt = now; expiresAt = request.expiresAt
    }
    init(from decoder: Decoder) throws {
        try closed(decoder, Set(CodingKeys.allCases.map(\.rawValue)))
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(Int.self, forKey: .version)
        requestID = try c.decode(UUID.self, forKey: .requestID)
        requestDigest = try c.decode(String.self, forKey: .requestDigest)
        outcome = try c.decode(GateOutcome.self, forKey: .outcome)
        decidedAt = try c.decode(Int64.self, forKey: .decidedAt); expiresAt = try c.decode(Int64.self, forKey: .expiresAt)
        guard version == 1, requestDigest.count == 64,
              requestDigest.allSatisfy({ "0123456789abcdef".contains($0) }),
              decidedAt >= 0, expiresAt >= 0 else { throw GateError.invalid("decision fields") }
    }
    func verified(for request: GateRequest, at now: Int64) throws -> GateDecision {
        try request.validate()
        guard version == 1, requestID == request.id, requestDigest == request.requestDigest,
              expiresAt == request.expiresAt, decidedAt >= request.createdAt, decidedAt <= now,
              outcome != .expired || decidedAt >= expiresAt,
              outcome != .deny || decidedAt < expiresAt else { throw GateError.invalid("decision binding or dates") }
        // A late approval is reported as expired; the immutable original receipt is retained.
        if outcome == .approveOnce && (now >= expiresAt || decidedAt >= expiresAt) {
            return try GateDecision(request: request, outcome: .expired, now: max(now, expiresAt))
        }
        return self
    }
}

// JSONDecoder accepts duplicate keys. Scan structure first, including escaped-key
// aliases ("id" and "\u0069d"), then let JSONDecoder validate actual value types.
private struct GateJSONScanner {
    let bytes: [UInt8]; var i = 0
    mutating func whitespace() { while i < bytes.count && [9,10,13,32].contains(bytes[i]) { i += 1 } }
    mutating func string() throws -> String {
        let start = i
        guard i < bytes.count, bytes[i] == 34 else { throw GateError.invalid("JSON string") }
        i += 1
        while i < bytes.count {
            let b = bytes[i]; i += 1
            if b == 92 { i += 1 }
            else if b == 34 { return try JSONDecoder().decode(String.self, from: Data(bytes[start..<i])) }
        }
        throw GateError.invalid("unfinished JSON string")
    }
    mutating func value(depth: Int) throws {
        guard depth < 16 else { throw GateError.invalid("JSON nesting") }
        whitespace(); guard i < bytes.count else { throw GateError.invalid("unfinished JSON") }
        if bytes[i] == 34 { _ = try string(); return }
        if bytes[i] == 123 || bytes[i] == 91 {
            let object = bytes[i] == 123; let end: UInt8 = object ? 125 : 93
            i += 1; whitespace()
            if i < bytes.count && bytes[i] == end { i += 1; return }
            var keys = Set<String>()
            while true {
                if object {
                    whitespace(); let key = try string()
                    guard keys.insert(key).inserted else { throw GateError.invalid("duplicate JSON key") }
                    whitespace(); guard i < bytes.count, bytes[i] == 58 else { throw GateError.invalid("JSON colon") }; i += 1
                }
                try value(depth: depth + 1); whitespace()
                guard i < bytes.count else { throw GateError.invalid("unfinished JSON container") }
                if bytes[i] == end { i += 1; return }
                guard bytes[i] == 44 else { throw GateError.invalid("JSON separator") }; i += 1
            }
        }
        let start = i
        while i < bytes.count && ![9,10,13,32,44,93,125].contains(bytes[i]) { i += 1 }
        guard i > start else { throw GateError.invalid("JSON value") }
        let token = bytes[start..<i]
        if token.first == 45 || token.first.map({ (48...57).contains($0) }) == true {
            guard !token.contains(where: { [46, 69, 101].contains($0) }) else {
                throw GateError.invalid("integer JSON numbers required")
            }
        }
    }
    mutating func validate() throws {
        try value(depth: 0); whitespace()
        guard i == bytes.count else { throw GateError.invalid("trailing JSON") }
    }
}
