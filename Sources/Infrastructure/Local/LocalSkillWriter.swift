import Foundation
import Domain

/// Error thrown by LocalSkillWriter
public enum SkillWriterError: Error, Sendable, Equatable {
    case notLocalSkill
    case skillNotFound(String)
    case writeFailed(String)
}

/// Writes skill content to the local file system
public final class LocalSkillWriter: SkillWriter, @unchecked Sendable {
    private let fileManager: FileManager
    private let basePath: String?
    private let pathResolver: ProviderPathResolver

    /// Creates a writer with optional custom base path (for testing)
    /// - Parameter basePath: Custom base path, or nil to use provider's default path
    public init(
        basePath: String? = nil,
        fileManager: FileManager = .default,
        pathResolver: ProviderPathResolver = ProviderPathResolver()
    ) {
        self.basePath = basePath
        self.fileManager = fileManager
        self.pathResolver = pathResolver
    }

    /// Saves skill content to its local file
    /// - Parameter skill: The skill to save
    /// - Throws: SkillWriterError if skill is not local or write fails
    public func save(_ skill: Skill) async throws {
        // Validate skill is local
        guard case .local(let provider) = skill.source else {
            throw SkillWriterError.notLocalSkill
        }

        // Build path to SKILL.md
        let skillsPath = basePath ?? pathResolver.skillsPath(for: provider)
        let skillPath = "\(skillsPath)/\(skill.id)/SKILL.md"

        // Verify skill exists
        guard fileManager.fileExists(atPath: skillPath) else {
            throw SkillWriterError.skillNotFound(skill.id)
        }

        // Write content atomically
        do {
            try skill.content.write(toFile: skillPath, atomically: true, encoding: .utf8)
        } catch {
            throw SkillWriterError.writeFailed(skillPath)
        }
    }
}
