import Foundation

struct ThreadNote: Codable, Equatable {
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
    mutating func keep(_ note: ThreadNote) { previous = current; current = note }
    mutating func release() { previous = current; current = nil }
    mutating func undo() { swap(&current, &previous) }
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
