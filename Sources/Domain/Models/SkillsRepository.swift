import Foundation

/// Represents a remote skills catalog (GitHub repo containing skills)
/// Named "Catalog" to distinguish from the SkillRepository protocol (repository pattern)
public struct SkillsCatalog: Sendable, Equatable, Identifiable, Hashable, Codable {
    public let id: UUID
    public let url: String
    public let name: String
    public let addedAt: Date

    public init(id: UUID = UUID(), url: String, name: String? = nil, addedAt: Date = Date()) {
        self.id = id
        self.url = url
        self.name = name ?? Self.extractName(from: url)
        self.addedAt = addedAt
    }

    /// Extract repo name from GitHub URL
    public static func extractName(from url: String) -> String {
        var cleanUrl = url
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: "http://github.com/", with: "")

        if cleanUrl.hasSuffix("/") {
            cleanUrl = String(cleanUrl.dropLast())
        }
        if cleanUrl.hasSuffix(".git") {
            cleanUrl = String(cleanUrl.dropLast(4))
        }

        let parts = cleanUrl.split(separator: "/")
        if parts.count >= 2 {
            // Return "owner/repo" format or just repo name
            return String(parts[1]).capitalized
        }
        return cleanUrl.isEmpty ? "Unknown" : cleanUrl
    }

    /// Validate that URL is a valid GitHub URL
    public var isValid: Bool {
        url.contains("github.com") && url.contains("/")
    }
}

/// Default catalogs
public extension SkillsCatalog {
    /// Anthropic's official skills catalog
    static let anthropicSkills = SkillsCatalog(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        url: "https://github.com/anthropics/skills",
        name: "Anthropic Skills"
    )
}
