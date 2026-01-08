import Foundation
import Domain

/// Repository for reading locally installed skills
public final class LocalSkillRepository: SkillRepository, @unchecked Sendable {
    private let provider: Provider
    private let fileManager: FileManagerProtocol
    private let skillsPath: String

    public init(provider: Provider, fileManager: FileManagerProtocol = RealFileManager.shared) {
        self.provider = provider
        self.fileManager = fileManager
        self.skillsPath = provider.skillsPath
    }

    /// Fetch all skills from the local skills directory
    public func fetchAll() async throws -> [Skill] {
        guard fileManager.fileExists(atPath: skillsPath) else {
            return []
        }

        let contents = try fileManager.contentsOfDirectory(atPath: skillsPath)
        var skills: [Skill] = []

        for item in contents {
            let itemPath = (skillsPath as NSString).appendingPathComponent(item)

            // Skip non-directories
            guard fileManager.isDirectory(atPath: itemPath) else {
                continue
            }

            // Check for SKILL.md
            let skillFilePath = (itemPath as NSString).appendingPathComponent("SKILL.md")

            guard let data = fileManager.contents(atPath: skillFilePath),
                  let content = String(data: data, encoding: .utf8) else {
                continue
            }

            do {
                let skill = try SkillParser.parse(
                    content: content,
                    id: item,
                    source: .local(provider: provider)
                )
                skills.append(skill)
            } catch {
                // Skip invalid skills, log in production
                continue
            }
        }

        return skills.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Fetch a specific skill by ID
    public func fetch(id: String) async throws -> Skill? {
        let skillPath = (skillsPath as NSString).appendingPathComponent(id)
        let skillFilePath = (skillPath as NSString).appendingPathComponent("SKILL.md")

        guard let data = fileManager.contents(atPath: skillFilePath),
              let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        return try SkillParser.parse(
            content: content,
            id: id,
            source: .local(provider: provider)
        )
    }
}
