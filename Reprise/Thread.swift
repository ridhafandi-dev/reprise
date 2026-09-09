import Foundation

struct ThreadNote: Codable, Equatable, Identifiable {
    var identity: UUID? = UUID()
    var id: String { identity?.uuidString ?? "\(createdAt.timeIntervalSince1970)-\(title)" }
    var title: String
    var intention: String
    var source: String
    var createdAt: Date
    var example: Bool

    static let example = ThreadNote(title: "Un geste à garder", intention: "Reprendre ici : le mouvement du volet, avant de penser aux fonctionnalités.", source: "https://github.com/vinzdg/codenotch", createdAt: Date(), example: true)

    var url: URL? { Self.sourceURL(source) }
    static func sourceURL(_ text: String) -> URL? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("/") { return URL(fileURLWithPath: value) }
        guard let url = URL(string: value), let scheme = url.scheme?.lowercased() else { return nil }
        if scheme == "file" { return url }
        guard ["https", "http"].contains(scheme), let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
    var sourceLabel: String {
        guard let url else { return "Note sans pièce jointe" }
        return url.isFileURL ? url.lastPathComponent : (url.host ?? source)
    }
}

/// One current thread and one recoverable previous thread. No background reads,
/// network requests, credentials, or copied file content.
struct ThreadArchive: Codable {
    var current: ThreadNote?
    var previous: ThreadNote?
    var history: [ThreadNote]? = nil
    var saved: [ThreadNote] {
        var seen = Set<String>()
        return ([current, previous].compactMap { $0 } + (history ?? []))
            .filter { seen.insert($0.id).inserted }.sorted { $0.createdAt > $1.createdAt }
    }
    mutating func keep(_ note: ThreadNote) {
        let all = saved.filter { $0.id != note.id }
        previous = current; current = note; history = [note] + all
    }
    mutating func release() { history = saved; previous = current; current = nil }
    mutating func undo() { history = saved; swap(&current, &previous) }
}

enum ThreadPersistence {
    static func load(from url: URL) throws -> ThreadArchive {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return ThreadArchive(current: .example)
        }
        return try JSONDecoder().decode(ThreadArchive.self, from: Data(contentsOf: url))
    }
    static func save(_ archive: ThreadArchive, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(archive).write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    }
}
