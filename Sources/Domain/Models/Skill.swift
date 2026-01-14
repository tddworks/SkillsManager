import Foundation

/// Rich domain model representing an installable skill for AI coding assistants
public struct Skill: Sendable, Equatable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let description: String
    public let version: String
    public let content: String
    public let source: SkillSource
    public var installedProviders: Set<Provider>
    public var referenceCount: Int
    public var scriptCount: Int

    public init(
        id: String,
        name: String,
        description: String,
        version: String,
        content: String,
        source: SkillSource,
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
        self.installedProviders = installedProviders
        self.referenceCount = referenceCount
        self.scriptCount = scriptCount
    }

    // MARK: - Computed Properties (Domain Behavior)

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
            installedProviders: installedProviders,
            referenceCount: referenceCount,
            scriptCount: scriptCount
        )
    }
}
