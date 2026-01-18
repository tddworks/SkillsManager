import Foundation
import Domain

/// Repository that reads skills from a local directory
/// Unlike LocalSkillRepository (which reads from provider-specific paths),
/// this can read from any arbitrary directory path
public final class LocalDirectorySkillRepository: SkillRepository, Sendable {

    private let directoryPath: String
    private let fileManager: FileManagerProtocol

    public init(
        directoryPath: String,
        fileManager: FileManagerProtocol = RealFileManager.shared
    ) {
        // Handle file:// URL scheme
        if directoryPath.hasPrefix("file://") {
            self.directoryPath = String(directoryPath.dropFirst(7))
        } else {
            self.directoryPath = directoryPath
        }
        self.fileManager = fileManager
    }

    public func fetchAll() async throws -> [Skill] {
        // Collect all skills with their paths
        var skillInfos: [(folderName: String, parentPath: String, content: String)] = []
        collectSkillInfos(in: directoryPath, relativePath: "", infos: &skillInfos)

        // Create skills - id is folder name, repoPath is parent path
        var skills: [Skill] = []

        for info in skillInfos {
            do {
                let skill = try SkillParser.parse(
                    content: info.content,
                    id: info.folderName,
                    source: .localDirectory(path: directoryPath),
                    repoPath: info.parentPath.isEmpty ? nil : info.parentPath
                )
                skills.append(skill)
            } catch {
                // Skip invalid skills
            }
        }

        return skills.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func fetch(id: String) async throws -> Skill? {
        let skills = try await fetchAll()
        return skills.first { $0.id == id }
    }

    // MARK: - Private Helpers

    /// Collect skill info (folder name, parent path, content) for all skills
    private func collectSkillInfos(
        in path: String,
        relativePath: String,
        infos: inout [(folderName: String, parentPath: String, content: String)],
        maxDepth: Int = 5,
        currentDepth: Int = 0
    ) {
        guard currentDepth < maxDepth else { return }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return
        }

        for item in contents {
            // Skip hidden files and .git directory
            if item.hasPrefix(".") && item != ".claude" && item != ".codex" && item != ".agent" && item != ".gemini" {
                continue
            }

            let itemPath = (path as NSString).appendingPathComponent(item)
            let itemRelativePath = relativePath.isEmpty ? item : "\(relativePath)/\(item)"

            guard fileManager.isDirectory(atPath: itemPath) else { continue }

            let skillFilePath = (itemPath as NSString).appendingPathComponent("SKILL.md")

            if let data = fileManager.contents(atPath: skillFilePath),
               let content = String(data: data, encoding: .utf8) {
                infos.append((folderName: item, parentPath: relativePath, content: content))
            } else {
                // Recurse into subdirectory
                collectSkillInfos(
                    in: itemPath,
                    relativePath: itemRelativePath,
                    infos: &infos,
                    maxDepth: maxDepth,
                    currentDepth: currentDepth + 1
                )
            }
        }
    }
}
