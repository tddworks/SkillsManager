import Foundation
import Domain

/// Repository that merges skills from multiple sources
/// Used for local skills that come from both claude and codex providers
public final class MergedSkillRepository: SkillRepository {

    private let repositories: [SkillRepository]
    private let merger: @Sendable ([Skill], [Skill]) -> [Skill]

    public init(
        repositories: [SkillRepository],
        merger: @escaping @Sendable ([Skill], [Skill]) -> [Skill] = { a, b in a + b }
    ) {
        self.repositories = repositories
        self.merger = merger
    }

    /// Convenience init for two repositories (typical case)
    public convenience init(
        primary: SkillRepository,
        secondary: SkillRepository,
        merger: @escaping @Sendable ([Skill], [Skill]) -> [Skill]
    ) {
        self.init(repositories: [primary, secondary], merger: merger)
    }

    public func fetchAll() async throws -> [Skill] {
        var allSkills: [Skill] = []

        for repo in repositories {
            let skills = try await repo.fetchAll()
            if allSkills.isEmpty {
                allSkills = skills
            } else {
                allSkills = merger(allSkills, skills)
            }
        }

        return allSkills
    }

    public func fetch(id: String) async throws -> Skill? {
        for repo in repositories {
            if let skill = try await repo.fetch(id: id) {
                return skill
            }
        }
        return nil
    }
}

// MARK: - Default Merger for Local Skills

public extension MergedSkillRepository {

    /// Creates a merged repository for local skills
    /// Merges skills by uniqueKey, combining installedProviders
    static func forLocalSkills(
        claudeRepo: SkillRepository,
        codexRepo: SkillRepository
    ) -> MergedSkillRepository {
        MergedSkillRepository(
            primary: claudeRepo,
            secondary: codexRepo,
            merger: mergeByUniqueKey
        )
    }

    private static let mergeByUniqueKey: @Sendable ([Skill], [Skill]) -> [Skill] = { claude, codex in
        var byKey: [String: Skill] = [:]

        for skill in claude {
            byKey[skill.uniqueKey] = skill.installing(for: .claude)
        }

        for skill in codex {
            if var existing = byKey[skill.uniqueKey] {
                existing = existing.installing(for: .codex)
                byKey[skill.uniqueKey] = existing
            } else {
                byKey[skill.uniqueKey] = skill.installing(for: .codex)
            }
        }

        return Array(byKey.values)
    }
}
