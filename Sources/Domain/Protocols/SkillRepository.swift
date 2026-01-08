import Foundation
import Mockable

/// Protocol for fetching skills from various sources
@Mockable
public protocol SkillRepository: Sendable {
    /// Fetch all skills from this repository
    func fetchAll() async throws -> [Skill]

    /// Fetch a specific skill by ID
    func fetch(id: String) async throws -> Skill?
}

/// Protocol for installing skills to a provider
@Mockable
public protocol SkillInstaller: Sendable {
    /// Install a skill to the specified providers
    /// - Parameters:
    ///   - skill: The skill to install
    ///   - providers: The providers to install to
    /// - Returns: The updated skill with installation status
    func install(_ skill: Skill, to providers: Set<Provider>) async throws -> Skill

    /// Uninstall a skill from the specified provider
    func uninstall(_ skill: Skill, from provider: Provider) async throws -> Skill
}
