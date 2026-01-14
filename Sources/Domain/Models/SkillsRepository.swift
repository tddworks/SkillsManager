import Foundation

// SkillsCatalog has been moved to its own file: SkillsCatalog.swift

/// Default catalog data for persistence
public extension SkillsCatalog.Data {
    /// Anthropic's official skills catalog data
    static let anthropicSkills = SkillsCatalog.Data(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        url: "https://github.com/anthropics/skills",
        name: "Anthropic Skills",
        addedAt: Date(timeIntervalSince1970: 0)
    )
}
