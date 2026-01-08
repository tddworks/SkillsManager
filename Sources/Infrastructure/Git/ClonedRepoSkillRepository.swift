import Foundation
import Domain

/// Repository for fetching skills by cloning GitHub repositories locally
public final class ClonedRepoSkillRepository: SkillRepository, @unchecked Sendable {
    private let repoUrl: String
    private let owner: String
    private let repo: String
    private let cacheDirectory: String
    private let localPath: String
    private let gitClient: GitCLIClientProtocol
    private let fileManager: FileManagerProtocol

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

        // Determine where skills are located
        let searchPath = findSkillsDirectory()

        // Get all directories in the search path
        let contents = try fileManager.contentsOfDirectory(atPath: searchPath)

        var skills: [Skill] = []

        for item in contents {
            // Skip hidden directories
            if item.hasPrefix(".") {
                continue
            }

            let itemPath = (searchPath as NSString).appendingPathComponent(item)

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
                    source: .remote(repoUrl: repoUrl)
                )
                skills.append(skill)
            } catch {
                // Skip invalid skills
                continue
            }
        }

        return skills.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func fetch(id: String) async throws -> Skill? {
        // Ensure repository is cloned or updated
        do {
            try await ensureRepositoryCloned()
        } catch {
            return nil
        }

        // Try root first, then skills directory
        for basePath in [localPath, "\(localPath)/skills"] {
            let skillPath = (basePath as NSString).appendingPathComponent(id)
            let skillFilePath = (skillPath as NSString).appendingPathComponent("SKILL.md")

            guard let data = fileManager.contents(atPath: skillFilePath),
                  let content = String(data: data, encoding: .utf8) else {
                continue
            }

            return try SkillParser.parse(
                content: content,
                id: id,
                source: .remote(repoUrl: repoUrl)
            )
        }

        return nil
    }

    // MARK: - Private Helpers

    private func ensureRepositoryCloned() async throws {
        if gitClient.isGitRepository(at: localPath) {
            // Repository exists, pull latest changes
            try await gitClient.pull(at: localPath)
        } else {
            // Clone the repository
            try await gitClient.clone(url: repoUrl, to: localPath)
        }
    }

    private func findSkillsDirectory() -> String {
        // Check if there's a "skills" subdirectory
        let skillsSubdir = (localPath as NSString).appendingPathComponent("skills")

        if fileManager.isDirectory(atPath: skillsSubdir) {
            return skillsSubdir
        }

        // Otherwise, use root directory
        return localPath
    }
}
