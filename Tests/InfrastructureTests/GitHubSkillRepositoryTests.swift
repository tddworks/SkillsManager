import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite
struct GitHubSkillRepositoryTests {

    // MARK: - URL Parsing

    @Test func `extracts owner and repo from GitHub URL`() {
        let url = "https://github.com/anthropics/skills"

        let (owner, repo) = GitHubSkillRepository.parseGitHubURL(url)

        #expect(owner == "anthropics")
        #expect(repo == "skills")
    }

    @Test func `handles GitHub URL with trailing slash`() {
        let url = "https://github.com/owner/repo/"

        let (owner, repo) = GitHubSkillRepository.parseGitHubURL(url)

        #expect(owner == "owner")
        #expect(repo == "repo")
    }

    @Test func `handles GitHub URL with .git suffix`() {
        let url = "https://github.com/owner/repo.git"

        let (owner, repo) = GitHubSkillRepository.parseGitHubURL(url)

        #expect(owner == "owner")
        #expect(repo == "repo")
    }

    // MARK: - Skills Directory Detection

    @Test func `finds skills in skills subdirectory`() async throws {
        let mockClient = MockGitHubClient()
        mockClient.stubContents(for: "owner", repo: "skills-repo", path: "", items: [
            GitHubContent(name: "skills", type: "dir", path: "skills"),
            GitHubContent(name: "README.md", type: "file", path: "README.md")
        ])
        mockClient.stubContents(for: "owner", repo: "skills-repo", path: "skills", items: [
            GitHubContent(name: "skill-one", type: "dir", path: "skills/skill-one")
        ])
        mockClient.stubFileContent(
            for: "owner", repo: "skills-repo", path: "skills/skill-one/SKILL.md",
            content: """
            ---
            name: skill-one
            description: First skill
            ---
            # Skill One
            """
        )

        let repo = GitHubSkillRepository(
            repoUrl: "https://github.com/owner/skills-repo",
            client: mockClient
        )

        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
        #expect(skills.first?.name == "skill-one")
    }

    @Test func `finds skills in root directory`() async throws {
        let mockClient = MockGitHubClient()
        mockClient.stubContents(for: "owner", repo: "repo", path: "", items: [
            GitHubContent(name: "my-skill", type: "dir", path: "my-skill")
        ])
        mockClient.stubFileContent(
            for: "owner", repo: "repo", path: "my-skill/SKILL.md",
            content: """
            ---
            name: my-skill
            description: A root skill
            ---
            # My Skill
            """
        )

        let repo = GitHubSkillRepository(
            repoUrl: "https://github.com/owner/repo",
            client: mockClient
        )

        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
        #expect(skills.first?.name == "my-skill")
    }

    // MARK: - Source Assignment

    @Test func `assigns remote source with repo URL`() async throws {
        let mockClient = MockGitHubClient()
        mockClient.stubContents(for: "owner", repo: "repo", path: "", items: [
            GitHubContent(name: "test-skill", type: "dir", path: "test-skill")
        ])
        mockClient.stubFileContent(
            for: "owner", repo: "repo", path: "test-skill/SKILL.md",
            content: """
            ---
            name: test-skill
            description: Test
            ---
            # Test
            """
        )

        let repoUrl = "https://github.com/owner/repo"
        let repo = GitHubSkillRepository(repoUrl: repoUrl, client: mockClient)

        let skills = try await repo.fetchAll()

        #expect(skills.first?.source == .remote(repoUrl: repoUrl))
    }

    // MARK: - Error Handling

    @Test func `returns empty array when repo has no skills`() async throws {
        let mockClient = MockGitHubClient()
        mockClient.stubContents(for: "owner", repo: "empty", path: "", items: [
            GitHubContent(name: "README.md", type: "file", path: "README.md")
        ])

        let repo = GitHubSkillRepository(
            repoUrl: "https://github.com/owner/empty",
            client: mockClient
        )

        let skills = try await repo.fetchAll()

        #expect(skills.isEmpty)
    }

    @Test func `skips directories without SKILL.md`() async throws {
        let mockClient = MockGitHubClient()
        mockClient.stubContents(for: "owner", repo: "repo", path: "", items: [
            GitHubContent(name: "not-a-skill", type: "dir", path: "not-a-skill"),
            GitHubContent(name: "valid-skill", type: "dir", path: "valid-skill")
        ])
        // not-a-skill has no SKILL.md
        mockClient.stubFileContent(
            for: "owner", repo: "repo", path: "valid-skill/SKILL.md",
            content: """
            ---
            name: valid-skill
            description: Valid
            ---
            # Valid
            """
        )

        let repo = GitHubSkillRepository(
            repoUrl: "https://github.com/owner/repo",
            client: mockClient
        )

        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
        #expect(skills.first?.name == "valid-skill")
    }
}

// MARK: - Mock GitHub Client

final class MockGitHubClient: GitHubClientProtocol, @unchecked Sendable {
    private var contentsStubs: [String: [GitHubContent]] = [:]
    private var fileStubs: [String: String] = [:]

    func stubContents(for owner: String, repo: String, path: String, items: [GitHubContent]) {
        let key = "\(owner)/\(repo)/\(path)"
        contentsStubs[key] = items
    }

    func stubFileContent(for owner: String, repo: String, path: String, content: String) {
        let key = "\(owner)/\(repo)/\(path)"
        fileStubs[key] = content
    }

    func getContents(owner: String, repo: String, path: String) async throws -> [GitHubContent] {
        let key = "\(owner)/\(repo)/\(path)"
        return contentsStubs[key] ?? []
    }

    func getFileContent(owner: String, repo: String, path: String) async throws -> String {
        let key = "\(owner)/\(repo)/\(path)"
        guard let content = fileStubs[key] else {
            throw GitHubClientError.fileNotFound
        }
        return content
    }
}
