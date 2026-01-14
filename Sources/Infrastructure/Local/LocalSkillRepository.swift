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

    /// Fetch all skills from the local skills directory (recursively)
    public func fetchAll() async throws -> [Skill] {
        guard fileManager.fileExists(atPath: skillsPath) else {
            return []
        }

        var skills: [Skill] = []
        findSkillsRecursively(in: skillsPath, relativePath: "", skills: &skills)

        return skills.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Recursively search for SKILL.md files in directories.
    /// Uses relative path as skill ID to match remote skill IDs.
    private func findSkillsRecursively(in path: String, relativePath: String, skills: inout [Skill], maxDepth: Int = 5, currentDepth: Int = 0) {
        guard currentDepth < maxDepth else { return }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return
        }

        for item in contents {
            let itemPath = (path as NSString).appendingPathComponent(item)
            let itemRelativePath = relativePath.isEmpty ? item : "\(relativePath)/\(item)"

            // Skip non-directories
            guard fileManager.isDirectory(atPath: itemPath) else {
                continue
            }

            // Check for SKILL.md in this directory
            let skillFilePath = (itemPath as NSString).appendingPathComponent("SKILL.md")

            if let data = fileManager.contents(atPath: skillFilePath),
               let content = String(data: data, encoding: .utf8) {
                // Found a skill! Use folder name as ID
                do {
                    let skill = try SkillParser.parse(
                        content: content,
                        id: item,
                        source: .local(provider: provider)
                    )
                    skills.append(skill)
                } catch {
                    // Skip invalid skills
                }
                // Don't recurse into skill directories (a skill folder is a leaf)
            } else {
                // No SKILL.md here, search subdirectories
                findSkillsRecursively(in: itemPath, relativePath: itemRelativePath, skills: &skills, maxDepth: maxDepth, currentDepth: currentDepth + 1)
            }
        }
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
