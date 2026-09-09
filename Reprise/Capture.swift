import Foundation

struct PageCapture: Codable, Equatable {
    var version: Int
    var id: String
    var url: String
    var title: String
    var author: String?
    var excerpt: String?
    var description: String?
    var kind: String
    var seconds: Double?

    func validated() throws -> PageCapture {
        guard version == 1, UUID(uuidString: id) != nil,
              let address = ThreadNote.sourceURL(url), !address.isFileURL,
              url.utf8.count < 12_000 else { throw CaptureError.invalid }
        var value = self
        value.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240))
        if value.title.isEmpty { value.title = address.host ?? "Référence" }
        value.author = author.map { String($0.prefix(160)) }
        value.excerpt = excerpt.map { String($0.prefix(2000)) }
        value.description = description.map { String($0.prefix(600)) }
        value.kind = ["page", "post", "video"].contains(kind) ? kind : "page"
        let host = address.host?.lowercased() ?? ""
        let youtube = host == "youtu.be" || host == "youtube.com" || host.hasSuffix(".youtube.com")
        if let seconds, youtube, seconds.isFinite, seconds >= 0, seconds < 604800 {
            value.seconds = floor(seconds)
        } else { value.seconds = nil }
        return value
    }
}
enum CaptureError: LocalizedError {
    case invalid
    var errorDescription: String? { "Cette référence n’est pas valide." }
}

struct CaptureReceipt: Codable { var ok: Bool; var error: String? }

enum CaptureInbox {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Reprise/CaptureInbox")
    }
    static let notification = "tools.pulsar.reprise.capture"
    static func prepare() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
}
