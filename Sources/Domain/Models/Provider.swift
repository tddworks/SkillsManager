import Foundation

/// Installation target for skills - either Codex or Claude Code
public enum Provider: String, CaseIterable, Sendable, Identifiable, Hashable {
    case codex
    case claude

    public var id: String { rawValue }

    /// Human-readable display name
    public var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claude: return "Claude Code"
        }
    }

    /// Path where skills are installed for this provider
    public var skillsPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        switch self {
        case .codex:
            return "\(home)/.codex/skills/public"
        case .claude:
            return "\(home)/.claude/skills"
        }
    }
}
