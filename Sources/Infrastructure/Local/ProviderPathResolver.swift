import Foundation
import Domain

/// Resolves file system paths for providers
/// This is infrastructure knowledge - the domain model (Provider) shouldn't know about file paths
public struct ProviderPathResolver: Sendable {

    private let homePath: String

    public init() {
        self.homePath = FileManager.default.homeDirectoryForCurrentUser.path
    }

    /// Returns the path where skills are installed for the given provider
    public func skillsPath(for provider: Provider) -> String {
        switch provider {
        case .codex:
            return "\(homePath)/.codex/skills/public"
        case .claude:
            return "\(homePath)/.claude/skills"
        }
    }
}
