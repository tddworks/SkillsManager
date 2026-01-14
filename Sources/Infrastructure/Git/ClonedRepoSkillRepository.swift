import Foundation
import Domain

/// Repository for fetching skills by cloning GitHub repositories locally.
/// Recursively searches the entire repository for any folder containing a SKILL.md file.
public final class ClonedRepoSkillRepository: SkillRepository, @unchecked Sendable {
    private let repoUrl: String
    private let owner: String
    private let repo: String
    private let cacheDirectory: String
    private let localPath: String
    private let gitClient: GitCLIClientProtocol
    private let fileManager: FileManagerProtocol

    /// Clean URL for git clone (strips browser paths like /tree/master/...)
    private var cloneUrl: String {
        "https://github.com/\(owner)/\(repo).git"
    }

    /// Default cache directory for cloned repositories
    public static var defaultCacheDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.skillsmanager/cache"
    }

    public init(
        repoUrl: String,
        cacheDirectory: String = ClonedRepoSkillRepository.defaultCacheDirectory,
        gitClient: GitCLIClientProtocol = GitCLIClient(),
        fileManager: FileManagerProtocol = RealFileManager.shared
    ) {
        self.repoUrl = repoUrl
        let (owner, repo) = Self.parseGitHubURL(repoUrl)
        self.owner = owner
        self.repo = repo
        self.cacheDirectory = cacheDirectory
        self.localPath = "\(cacheDirectory)/\(owner)_\(repo)"
        self.gitClient = gitClient
        self.fileManager = fileManager
    }

    /// Parse GitHub URL to extract owner and repo
    public static func parseGitHubURL(_ url: String) -> (owner: String, repo: String) {
        var cleanUrl = url
            .replacingOccurrences(of: "https://github.com/", with: "")
            .replacingOccurrences(of: "http://github.com/", with: "")

        // Remove trailing slash
        if cleanUrl.hasSuffix("/") {
            cleanUrl = String(cleanUrl.dropLast())
        }

        // Remove .git suffix
        if cleanUrl.hasSuffix(".git") {
            cleanUrl = String(cleanUrl.dropLast(4))
        }

        let parts = cleanUrl.split(separator: "/")
        guard parts.count >= 2 else {
            return ("", "")
        }

        return (String(parts[0]), String(parts[1]))
    }

    public func fetchAll() async throws -> [Skill] {
        // Ensure repository is cloned or updated
        do {
            try await ensureRepositoryCloned()
        } catch {
            // If clone/pull fails, return empty array instead of throwing
            return []
        }

        // First pass: collect all skills with their paths
        var skillInfos: [(folderName: String, parentPath: String, content: String)] = []
        collectSkillInfos(in: localPath, relativePath: "", infos: &skillInfos)

        // Second pass: detect duplicates and assign unique IDs
        var folderNameCounts: [String: Int] = [:]
        for info in skillInfos {
            folderNameCounts[info.folderName, default: 0] += 1
        }

        // Third pass: create skills with unique IDs
        var skills: [Skill] = []
        var usedIds: Set<String> = []

        for info in skillInfos {
            var skillId = info.folderName

            // If this ID is already used, make it unique by adding parent path
            if usedIds.contains(skillId) || folderNameCounts[info.folderName, default: 0] > 1 {
                if !info.parentPath.isEmpty {
                    // Use full parent path with dashes (e.g., "charts-skills-ui-ux-pro-max")
                    let parentPrefix = info.parentPath.replacingOccurrences(of: "/", with: "-")
                    skillId = "\(parentPrefix)-\(info.folderName)"
                }
            }

            // If still duplicate (edge case), add a counter
            var finalId = skillId
            var counter = 2
            while usedIds.contains(finalId) {
                finalId = "\(skillId)-\(counter)"
                counter += 1
            }
            usedIds.insert(finalId)

            do {
                let skill = try SkillParser.parse(
                    content: info.content,
                    id: finalId,
                    source: .remote(repoUrl: repoUrl),
                    folderName: info.folderName  // Use original folder name for installation
                )
                skills.append(skill)
            } catch {
                // Skip invalid skills
            }
        }

        return skills.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Collect skill info (folder name, parent path, content) for all skills
    private func collectSkillInfos(in path: String, relativePath: String, infos: inout [(folderName: String, parentPath: String, content: String)], maxDepth: Int = 5, currentDepth: Int = 0) {
        guard currentDepth < maxDepth else { return }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return
        }

        for item in contents {
            if item == ".git" { continue }

            let itemPath = (path as NSString).appendingPathComponent(item)
            let itemRelativePath = relativePath.isEmpty ? item : "\(relativePath)/\(item)"

            guard fileManager.isDirectory(atPath: itemPath) else { continue }

            let skillFilePath = (itemPath as NSString).appendingPathComponent("SKILL.md")

            if let data = fileManager.contents(atPath: skillFilePath),
               let content = String(data: data, encoding: .utf8) {
                infos.append((folderName: item, parentPath: relativePath, content: content))
            } else {
                collectSkillInfos(in: itemPath, relativePath: itemRelativePath, infos: &infos, maxDepth: maxDepth, currentDepth: currentDepth + 1)
            }
        }
    }

    public func fetch(id: String) async throws -> Skill? {
        // Ensure repository is cloned or updated
        do {
            try await ensureRepositoryCloned()
        } catch {
            return nil
        }

        // Recursively search for the skill by id
        return findSkillById(id, in: localPath)
    }

    /// Recursively search for a skill by its id (directory name)
    private func findSkillById(_ id: String, in path: String, maxDepth: Int = 5, currentDepth: Int = 0) -> Skill? {
        guard currentDepth < maxDepth else { return nil }

        guard let contents = try? fileManager.contentsOfDirectory(atPath: path) else {
            return nil
        }

        for item in contents {
            // Skip .git directory
            if item == ".git" {
                continue
            }

            let itemPath = (path as NSString).appendingPathComponent(item)

            // Skip non-directories
            guard fileManager.isDirectory(atPath: itemPath) else {
                continue
            }

            // Check if this directory matches the id and has SKILL.md
            if item == id {
                let skillFilePath = (itemPath as NSString).appendingPathComponent("SKILL.md")
                if let data = fileManager.contents(atPath: skillFilePath),
                   let content = String(data: data, encoding: .utf8) {
                    return try? SkillParser.parse(
                        content: content,
                        id: id,
                        source: .remote(repoUrl: repoUrl)
                    )
                }
            }

            // Recurse into subdirectories
            if let found = findSkillById(id, in: itemPath, maxDepth: maxDepth, currentDepth: currentDepth + 1) {
                return found
            }
        }

        return nil
    }

    // MARK: - Cache Management

    /// Delete the cloned repository from cache
    public func deleteClone() throws {
        if fileManager.isDirectory(atPath: localPath) {
            try fileManager.removeItem(atPath: localPath)
        }
    }

    /// Delete a cloned repository by URL (static helper)
    public static func deleteClone(
        forRepoUrl url: String,
        cacheDirectory: String = ClonedRepoSkillRepository.defaultCacheDirectory,
        fileManager: FileManagerProtocol = RealFileManager.shared
    ) throws {
        let (owner, repo) = parseGitHubURL(url)
        let localPath = "\(cacheDirectory)/\(owner)_\(repo)"

        if fileManager.isDirectory(atPath: localPath) {
            try fileManager.removeItem(atPath: localPath)
        }
    }

    // MARK: - Private Helpers

    private func ensureRepositoryCloned() async throws {
        if gitClient.isGitRepository(at: localPath) {
            // Repository exists, pull latest changes
            try await gitClient.pull(at: localPath)
        } else {
            // Clone the repository using clean URL (strips browser paths)
            try await gitClient.clone(url: cloneUrl, to: localPath)
        }
    }
}
