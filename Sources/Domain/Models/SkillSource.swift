import Foundation

/// Represents where a skill comes from - local installation, remote repository, or local directory
public enum SkillSource: Sendable, Equatable, Hashable {
    /// Skill is installed locally for a specific provider
    case local(provider: Provider)

    /// Skill is from a remote GitHub repository
    case remote(repoUrl: String)

    /// Skill is from a local directory (not a provider installation)
    case localDirectory(path: String)

    /// Whether this skill is from a local installation (provider-based)
    public var isLocal: Bool {
        if case .local = self { return true }
        return false
    }

    /// Whether this skill is from a remote repository
    public var isRemote: Bool {
        if case .remote = self { return true }
        return false
    }

    /// Whether this skill is from a local directory catalog
    public var isLocalDirectory: Bool {
        if case .localDirectory = self { return true }
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
        case .localDirectory(let path):
            // Extract directory name from path (handle both file:// URLs and plain paths)
            let cleanPath = path.hasPrefix("file://") ? String(path.dropFirst(7)) : path
            if let lastComponent = URL(fileURLWithPath: cleanPath).lastPathComponent as String?,
               !lastComponent.isEmpty {
                return lastComponent
            }
            return "Local Directory"
        }
    }
}
