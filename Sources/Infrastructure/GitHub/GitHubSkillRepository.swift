import Foundation
import Domain

/// Repository for fetching skills from a GitHub repository
public final class GitHubSkillRepository: SkillRepository, @unchecked Sendable {
    private let repoUrl: String
    private let owner: String
    private let repo: String
    private let client: GitHubClientProtocol

    public init(repoUrl: String, client: GitHubClientProtocol = GitHubClient.shared) {
        self.repoUrl = repoUrl
        let (owner, repo) = Self.parseGitHubURL(repoUrl)
        self.owner = owner
        self.repo = repo
        self.client = client
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
        // First, check root directory for skills or a "skills" subdirectory
        let rootContents = try await client.getContents(owner: owner, repo: repo, path: "")

        // Check if there's a "skills" directory
        let skillsDir = rootContents.first { $0.name == "skills" && $0.type == "dir" }

        let searchPath: String
        let searchContents: [GitHubContent]

        if let _ = skillsDir {
            searchPath = "skills"
            searchContents = try await client.getContents(owner: owner, repo: repo, path: "skills")
        } else {
            searchPath = ""
            searchContents = rootContents
        }

        // Find all directories that might contain skills
        let potentialSkills = searchContents.filter { $0.type == "dir" }

        var skills: [Skill] = []

        for item in potentialSkills {
            let skillPath = searchPath.isEmpty ? item.name : "\(searchPath)/\(item.name)"
            let skillMdPath = "\(skillPath)/SKILL.md"

            do {
                let content = try await client.getFileContent(owner: owner, repo: repo, path: skillMdPath)
                let skill = try SkillParser.parse(
                    content: content,
                    id: item.name,
                    source: .remote(repoUrl: repoUrl)
                )
                skills.append(skill)
            } catch {
                // Skip directories without valid SKILL.md
                continue
            }
        }

        return skills.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public func fetch(id: String) async throws -> Skill? {
        // Try root first, then skills directory
        for basePath in ["", "skills"] {
            let skillPath = basePath.isEmpty ? id : "\(basePath)/\(id)"
            let skillMdPath = "\(skillPath)/SKILL.md"

            do {
                let content = try await client.getFileContent(owner: owner, repo: repo, path: skillMdPath)
                return try SkillParser.parse(
                    content: content,
                    id: id,
                    source: .remote(repoUrl: repoUrl)
                )
            } catch {
                continue
            }
        }
        return nil
    }
}
