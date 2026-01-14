import Foundation

/// Installation target for skills - either Codex or Claude Code
/// This is a pure domain value object - file system paths are resolved in Infrastructure layer
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
}
