import Foundation

/// Represents where a skill comes from - local installation or remote repository
public enum SkillSource: Sendable, Equatable, Hashable {
    /// Skill is installed locally for a specific provider
    case local(provider: Provider)

    /// Skill is from a remote GitHub repository
    case remote(repoUrl: String)

    /// Whether this skill is from a local installation
    public var isLocal: Bool {
        if case .local = self { return true }
        return false
    }

    /// Whether this skill is from a remote repository
    public var isRemote: Bool {
        if case .remote = self { return true }
        return false
    }

    /// Display name for the source
    public var displayName: String {
        switch self {
        case .local(let provider):
            return provider.displayName
        case .remote(let repoUrl):
            // Extract repo name from URL
            if let lastComponent = URL(string: repoUrl)?.lastPathComponent {
                return lastComponent
            }
            return "Remote"
        }
    }
}
