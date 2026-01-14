import Foundation

/// A skills catalog - a collection of skills from a source
/// User thinks: "This catalog has these skills I can browse and install"
/// Can be local (installed skills) or remote (GitHub repo)
@Observable
@MainActor
public final class SkillsCatalog: Identifiable {

    // MARK: - Identity

    public let id: UUID
    public let url: String?  // nil for local catalog
    public let name: String
    public let addedAt: Date

    // MARK: - State

    /// Skills owned by this catalog
    public var skills: [Skill] = []

    /// Loading state
    public var isLoading: Bool = false

    /// Error message if loading failed
    public var errorMessage: String?

    // MARK: - Dependencies

    private let loader: SkillRepository

    // MARK: - Init

    /// Init for remote catalog (with URL)
    public init(
        id: UUID = UUID(),
        url: String,
        name: String? = nil,
        addedAt: Date = Date(),
        loader: SkillRepository
    ) {
        self.id = id
        self.url = url
        self.name = name ?? Self.extractName(from: url)
        self.addedAt = addedAt
        self.loader = loader
    }

    /// Init for local catalog (no URL)
    public init(
        id: UUID = UUID(),
        name: String,
        addedAt: Date = Date(),
        loader: SkillRepository
    ) {
        self.id = id
        self.url = nil
        self.name = name
        self.addedAt = addedAt
        self.loader = loader
    }

    // MARK: - Actions

    /// Load skills from the catalog source
    public func loadSkills() async {
        isLoading = true
        errorMessage = nil

        do {
            skills = try await loader.fetchAll()
        } catch {
            errorMessage = formatError(error)
        }

        isLoading = false
    }

    /// Update installation status for skills matching the uniqueKey
    public func updateInstallationStatus(for uniqueKey: String, to providers: Set<Provider>) {
        for index in skills.indices {
            if skills[index].uniqueKey == uniqueKey {
                skills[index] = skills[index].withInstalledProviders(providers)
            }
        }
    }

    /// Sync installation status with installed skills
    public func syncInstallationStatus(with installedSkills: [Skill]) {
        skills = skills.map { skill in
            if let installed = installedSkills.first(where: { $0.uniqueKey == skill.uniqueKey }) {
                return skill.withInstalledProviders(installed.installedProviders)
            }
            return skill
        }
    }

    /// Add a skill to the catalog (for local catalog)
    public func addSkill(_ skill: Skill) {
        guard !skills.contains(where: { $0.uniqueKey == skill.uniqueKey }) else { return }
        skills.append(skill)
        skills.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Remove a skill from the catalog (for local catalog)
    public func removeSkill(uniqueKey: String) {
        skills.removeAll { $0.uniqueKey == uniqueKey }
    }

    /// Update an existing skill in the catalog
    public func updateSkill(_ skill: Skill) {
        if let index = skills.firstIndex(where: { $0.id == skill.id }) {
            skills[index] = skill
        }
    }

    // MARK: - Computed Properties

    /// Whether this is a local catalog
    public var isLocal: Bool {
        url == nil
    }

    /// Whether this URL is valid (always true for local)
    public var isValid: Bool {
        guard let url = url else { return true }
        return url.contains("github.com") && url.contains("/")
    }

    /// Whether this is the official Anthropic catalog
    public var isOfficial: Bool {
        id == Self.officialAnthropicId
    }

    /// Skill count
    public var skillCount: Int {
        skills.count
    }

    // MARK: - Helpers

    private func formatError(_ error: Error) -> String {
        if let gitError = error as? GitCLIError {
            switch gitError {
            case .cloneFailed(let message):
                return "Clone failed: \(message)"
            case .pullFailed(let message):
                return "Pull failed: \(message)"
            case .gitNotInstalled:
                return "Git is not installed"
            default:
                return "Git error: \(error.localizedDescription)"
            }
        }
        return error.localizedDescription
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
            return String(parts[1]).capitalized
        }
        return cleanUrl.isEmpty ? "Unknown" : cleanUrl
    }

    // MARK: - Well-known Catalog IDs

    public static let localCatalogId = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    public static let officialAnthropicId = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}

// MARK: - Persistence Data

public extension SkillsCatalog {

    /// Data for persistence (Codable struct)
    struct Data: Codable, Sendable {
        public let id: UUID
        public let url: String?
        public let name: String
        public let addedAt: Date

        public init(id: UUID, url: String?, name: String, addedAt: Date) {
            self.id = id
            self.url = url
            self.name = name
            self.addedAt = addedAt
        }
    }

    /// Convert to persistable data
    var persistableData: Data {
        Data(id: id, url: url, name: name, addedAt: addedAt)
    }

    /// Create remote catalog from persisted data
    convenience init(
        from data: Data,
        loader: SkillRepository
    ) {
        guard let url = data.url else {
            fatalError("Cannot create remote catalog from data without URL")
        }
        self.init(
            id: data.id,
            url: url,
            name: data.name,
            addedAt: data.addedAt,
            loader: loader
        )
    }
}

// MARK: - Hashable (for SwiftUI)

extension SkillsCatalog: Hashable {
    nonisolated public static func == (lhs: SkillsCatalog, rhs: SkillsCatalog) -> Bool {
        lhs.id == rhs.id
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
