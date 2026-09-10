import Foundation
import Darwin

// Every operation uses one cross-process lock. The immutable entry is the admission
// journal; the .request.json file is a disposable inbox projection, never authority.
final class GateStore {
    static let notification = "tools.pulsar.reprise.gate.requestAvailable"
    static let capacity = 8
    static let journalLimit = 1024 // Fail closed; no automatic anti-replay-history purge.
    let directory: URL
    private let fd: Int32
    private let mutex = NSLock()
    private struct Entry: Codable {
        let sequence: Int
        let admittedAt: Int64
        let request: GateRequest
    }

    static func defaultDirectory(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> URL {
        if let path = environment["REPRISE_GATE_PATH"] {
            guard path.hasPrefix("/"), path != "/" else { throw GateError.storage("REPRISE_GATE_PATH must be an absolute dedicated directory") }
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Reprise/GateInbox", isDirectory: true)
    }
    init(directory: URL) throws {
        self.directory = directory
        // Do not follow a symlink at the gate root. Parent directories are inside
        // the trusted user's environment; operations below stay relative to this fd.
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                              attributes: [.posixPermissions: 0o700])
        let handle = Darwin.open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard handle >= 0 else { throw GateError.storage("cannot open gate directory") }
        var info = stat()
        guard fstat(handle, &info) == 0, info.st_uid == getuid(), fchmod(handle, 0o700) == 0 else {
            close(handle); throw GateError.storage("unsafe directory owner or permissions")
        }
        fd = handle
    }
    deinit { close(fd) }
    private func name(_ id: UUID, _ suffix: String) -> String { id.uuidString.lowercased() + suffix }

    private func locked<T>(_ body: () throws -> T) throws -> T {
        mutex.lock(); defer { mutex.unlock() }
        let lockFD = openat(fd, ".gate.lock", O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard lockFD >= 0 else { throw GateError.storage("lock unavailable") }
        defer { close(lockFD) }
        var info = stat()
        guard fstat(lockFD, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_uid == getuid(), info.st_nlink == 1, fchmod(lockFD, 0o600) == 0,
              flock(lockFD, LOCK_EX) == 0 else { throw GateError.storage("unsafe lock") }
        defer { flock(lockFD, LOCK_UN) }
        return try body()
    }
    private func read(_ filename: String) throws -> Data? {
        let input = openat(fd, filename, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC)
        if input < 0 {
            if errno == ENOENT { return nil }
            throw GateError.storage("cannot read \(filename)")
        }
        defer { close(input) }
        var info = stat()
        guard fstat(input, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_uid == getuid(), info.st_nlink == 1, (info.st_mode & 0o077) == 0,
              info.st_size > 0, info.st_size <= GateWire.maxBytes else { throw GateError.storage("unsafe or oversized file \(filename)") }
        var bytes = [UInt8](repeating: 0, count: GateWire.maxBytes + 1)
        var total = 0
        while total < bytes.count {
            let count = bytes.withUnsafeMutableBytes { p in Darwin.read(input, p.baseAddress!.advanced(by: total), p.count - total) }
            if count < 0 { if errno == EINTR { continue }; throw GateError.storage("read failed") }
            if count == 0 { break }; total += count
        }
        guard total == info.st_size, total <= GateWire.maxBytes else { throw GateError.storage("file changed while reading") }
        return Data(bytes.prefix(total))
    }
    private func publish(_ data: Data, as filename: String) throws {
        guard !data.isEmpty, data.count <= GateWire.maxBytes else { throw GateError.storage("write size") }
        // RENAME_EXCL provides atomic visibility AND no overwrite (Data.atomic does not).
        let temporary = UUID().uuidString.lowercased() + ".tmp"
        let out = openat(fd, temporary, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard out >= 0 else { throw GateError.storage("temporary file unavailable") }
        defer { close(out); unlinkat(fd, temporary, 0) }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let n = Darwin.write(out, bytes.baseAddress!.advanced(by: offset), bytes.count - offset)
                if n < 0 && errno == EINTR { continue }
                guard n > 0 else { throw GateError.storage("write failed") }; offset += n
            }
        }
        guard fsync(out) == 0 else { throw GateError.storage("file synchronization failed") }
        guard renameatx_np(fd, temporary, fd, filename, UInt32(RENAME_EXCL)) == 0 else {
            throw GateError.storage("atomic publication refused for \(filename)")
        }
        guard fsync(fd) == 0, try read(filename) == data else { throw GateError.storage("publication not confirmed") }
    }
    private func entries() throws -> [Entry] {
        // Directory listing via fd: safe even if the original pathname is renamed.
        let copy = dup(fd)
        guard copy >= 0, let stream = fdopendir(copy) else { if copy >= 0 { close(copy) }; throw GateError.storage("list directory") }
        defer { closedir(stream) }
        rewinddir(stream)
        var result = [Entry]()
        var sequences = Set<Int>()
        while true {
            errno = 0
            guard let item = readdir(stream) else {
                guard errno == 0 else { throw GateError.storage("directory read failed") }
                break
            }
            let filename = withUnsafePointer(to: &item.pointee.d_name) {
                $0.withMemoryRebound(to: CChar.self, capacity: Int(item.pointee.d_namlen) + 1) { String(cString: $0) }
            }
            guard filename.hasSuffix(".entry.json") else { continue }
            guard result.count < Self.journalLimit, let data = try read(filename) else { throw GateError.storage("journal full or missing entry") }
            let entry = try GateWire.decode(Entry.self, data)
            guard filename == name(entry.request.id, ".entry.json"), (1...Self.journalLimit).contains(entry.sequence),
                  entry.admittedAt >= entry.request.createdAt, sequences.insert(entry.sequence).inserted else {
                throw GateError.storage("journal identity or sequence conflict")
            }
            result.append(entry)
        }
        return result.sorted { $0.sequence < $1.sequence }
    }
    private func requireEntry(_ request: GateRequest) throws {
        guard let data = try read(name(request.id, ".entry.json")) else { throw GateError.storage("request not admitted") }
        let entry = try GateWire.decode(Entry.self, data)
        guard entry.request == request else { throw GateError.invalid("request conflicts with journal") }
    }
    private func receipt(_ request: GateRequest, now: Int64) throws -> GateDecision? {
        guard let data = try read(name(request.id, ".decision.json")) else { return nil }
        return try GateWire.decode(GateDecision.self, data).verified(for: request, at: now)
    }
    private func terminalize(_ request: GateRequest, outcome: GateOutcome, now: Int64, live: Bool = false) throws -> GateDecision {
        if let existing = try receipt(request, now: now) { return existing }
        let decision = try GateDecision(request: request, outcome: outcome, now: live ? GateWire.now() : now)
        try publish(GateWire.encode(decision), as: name(request.id, ".decision.json"))
        guard let confirmed = try receipt(request, now: live ? GateWire.now() : now) else { throw GateError.storage("missing receipt after publication") }
        return confirmed
    }
    private func pending(_ all: [Entry], now: Int64) throws -> [GateRequest] {
        var result = [GateRequest]()
        for entry in all {
            guard now >= entry.admittedAt else { throw GateError.invalid("clock moved before admission") }
            let request = entry.request
            if try receipt(request, now: now) != nil { continue }
            if now >= request.expiresAt { _ = try terminalize(request, outcome: .expired, now: now); continue }
            let projection = name(request.id, ".request.json")
            if let data = try read(projection) {
                guard try GateWire.decode(GateRequest.self, data) == request else {
                    throw GateError.storage("corrupt inbox projection preserved")
                }
            } else { try publish(GateWire.encode(request), as: projection) }
            result.append(request)
        }
        return result
    }
    func enqueue(_ request: GateRequest, now: Int64 = GateWire.now()) throws {
        try request.validate(at: now)
        try locked {
            let all = try entries()
            if let prior = all.first(where: { $0.request.id == request.id }) {
                guard prior.request == request else { throw GateError.invalid("UUID reused with different request") }
                _ = try pending(all, now: now)
                return // Idempotent admission; never resurrect a cleaned terminal projection.
            }
            let active = try pending(all, now: now)
            guard (request.expiresAt <= now || active.count < Self.capacity), all.count < Self.journalLimit else {
                throw GateError.storage("queue or journal is full")
            }
            // Fail before admission on unexpected pre-existing files; preserve their bytes.
            guard try read(name(request.id, ".request.json")) == nil,
                  try read(name(request.id, ".decision.json")) == nil else { throw GateError.storage("orphan file conflicts with admission") }
            let entry = Entry(sequence: (all.last?.sequence ?? 0) + 1, admittedAt: now, request: request)
            try publish(GateWire.encode(entry), as: name(request.id, ".entry.json"))
            if now >= request.expiresAt { _ = try terminalize(request, outcome: .expired, now: now) }
            else { try publish(GateWire.encode(request), as: name(request.id, ".request.json")) }
        }
    }
    func pendingRequests(now: Int64 = GateWire.now()) throws -> [GateRequest] {
        try locked { try pending(entries(), now: now) }
    }
    // Future human-input adapter only: not exposed as an approval command by the CLI.
    func decide(_ request: GateRequest, outcome: GateOutcome, now: Int64? = nil) throws -> GateDecision {
        return try locked {
            let instant = now ?? GateWire.now()
            try request.validate(at: instant)
            try requireEntry(request)
            let active = try pending(entries(), now: instant)
            if let existing = try receipt(request, now: instant) { return existing }
            guard active.first?.id == request.id else { throw GateError.invalid("only the displayed FIFO head may be decided") }
            return try terminalize(request, outcome: outcome, now: instant, live: now == nil)
        }
    }
    func readDecision(_ request: GateRequest, now: Int64 = GateWire.now()) throws -> GateDecision? {
        try locked {
            try requireEntry(request)
            guard let decision = try receipt(request, now: now) else {
                if now >= request.expiresAt { return try terminalize(request, outcome: .expired, now: now) }
                return nil
            }
            return decision
        }
    }
    func cleanup(_ request: GateRequest, now: Int64 = GateWire.now()) throws {
        try locked {
            try requireEntry(request)
            guard try receipt(request, now: now) != nil else { throw GateError.storage("cleanup requires a verified receipt") }
            let filename = name(request.id, ".request.json")
            if let data = try read(filename) {
                guard try GateWire.decode(GateRequest.self, data) == request else { throw GateError.storage("corrupt projection preserved") }
                guard unlinkat(fd, filename, 0) == 0, fsync(fd) == 0 else { throw GateError.storage("cleanup not confirmed") }
            }
            // Keep the admission journal and immutable receipt for anti-replay/recovery.
        }
    }
}
