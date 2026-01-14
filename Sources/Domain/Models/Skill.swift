import Foundation

/// Rich domain model representing an installable skill for AI coding assistants
public struct Skill: Sendable, Equatable, Identifiable, Hashable {

    // MARK: - Identity (simple, one purpose each)

    /// Folder name - used for installation path (e.g., "ui-ux-pro-max")
    public let id: String

    /// Skill name from frontmatter
    public let name: String

    /// Skill description from frontmatter
    public let description: String

    /// Skill version from frontmatter
    public let version: String

    /// Full SKILL.md content
    public let content: String

    // MARK: - Source & Location

    /// Where the skill comes from (local or remote)
    public let source: SkillSource

    /// Path within repo where skill was found (e.g., ".claude/skills")
    /// Only set for remote skills; nil for local skills
    public let repoPath: String?

    // MARK: - Installation Status

    /// Which providers this skill is installed for
    public var installedProviders: Set<Provider>

    // MARK: - Metadata

    public var referenceCount: Int
    public var scriptCount: Int

    // MARK: - Init

    public init(
        id: String,
        name: String,
        description: String,
        version: String,
        content: String,
        source: SkillSource,
        repoPath: String? = nil,
        installedProviders: Set<Provider> = [],
        referenceCount: Int = 0,
        scriptCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.version = version
        self.content = content
        self.source = source
        self.repoPath = repoPath
        self.installedProviders = installedProviders
        self.referenceCount = referenceCount
        self.scriptCount = scriptCount
    }

    // MARK: - Computed Properties (Domain Behavior)

    /// Unique key for deduplication (combines repoPath + id for remote skills)
    public var uniqueKey: String {
        if let path = repoPath {
            return "\(path)/\(id)"
        }
        return id
    }

    /// Display name for the skill
    /// - Local skills: just the name
    /// - Remote skills without repoPath: just the name
    /// - Remote skills with repoPath: "name (repoPath)" to distinguish variants
    public var displayName: String {
        if source.isLocal {
            return name
        }
        if let path = repoPath, !path.isEmpty {
            return "\(name) (\(path))"
        }
        return name
    }

    /// Whether this skill is installed for any provider
    public var isInstalled: Bool {
        !installedProviders.isEmpty
    }

    /// Whether this skill has reference files
    public var hasReferences: Bool {
        referenceCount > 0
    }

    /// Whether this skill has script files
    public var hasScripts: Bool {
        scriptCount > 0
    }

    /// Whether this skill can be edited (only local skills are editable)
    public var isEditable: Bool {
        source.isLocal
    }

    /// Check if skill is installed for a specific provider
    public func isInstalledFor(_ provider: Provider) -> Bool {
        installedProviders.contains(provider)
    }

    // MARK: - Rich Installation Status (User Mental Model)

    /// Providers where this skill can still be installed
    /// User thinks: "Where else can I install this?"
    public var availableProviders: Set<Provider> {
        Set(Provider.allCases).subtracting(installedProviders)
    }

    /// Whether this skill is installed in all available providers
    /// User thinks: "Is this installed everywhere?"
    public var isFullyInstalled: Bool {
        installedProviders.count == Provider.allCases.count
    }

    /// Whether this skill can be installed to at least one more provider
    /// User thinks: "Can I install this somewhere?"
    public var canBeInstalled: Bool {
        !availableProviders.isEmpty
    }

    // MARK: - Search (User Mental Model)

    /// Check if skill matches a search query
    /// User thinks: "Does this skill match my search?"
    public func matches(query: String) -> Bool {
        guard !query.isEmpty else { return true }
        return name.localizedCaseInsensitiveContains(query) ||
               description.localizedCaseInsensitiveContains(query)
    }

    // MARK: - Mutation Methods

    /// Returns a copy with the provider added to installed providers
    public func installing(for provider: Provider) -> Skill {
        var updated = self
        updated.installedProviders.insert(provider)
        return updated
    }

    /// Returns a copy with the provider removed from installed providers
    public func uninstalling(from provider: Provider) -> Skill {
        var updated = self
        updated.installedProviders.remove(provider)
        return updated
    }

    /// Returns a copy with updated content
    public func updating(content newContent: String) -> Skill {
        Skill(
            id: id,
            name: name,
            description: description,
            version: version,
            content: newContent,
            source: source,
            repoPath: repoPath,
            installedProviders: installedProviders,
            referenceCount: referenceCount,
            scriptCount: scriptCount
        )
    }

    /// Returns a copy with the specified installed providers
    /// User thinks: "This remote skill is actually installed locally"
    public func withInstalledProviders(_ providers: Set<Provider>) -> Skill {
        Skill(
            id: id,
            name: name,
            description: description,
            version: version,
            content: content,
            source: source,
            repoPath: repoPath,
            installedProviders: providers,
            referenceCount: referenceCount,
            scriptCount: scriptCount
        )
    }
}
