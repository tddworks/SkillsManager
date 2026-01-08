import Testing
import Foundation
import Mockable
@testable import Infrastructure
@testable import Domain

@Suite
struct ClonedRepoSkillRepositoryTests {

    // MARK: - Clone Behavior

    @Test func `clones repository when not already cloned`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        // Repo is not cloned yet
        given(mockGit).isGitRepository(at: .any).willReturn(false)
        given(mockGit).clone(url: .any, to: .any).willReturn()

        // After clone, the directory has skills
        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn(["test-skill"])
        given(mockFileManager).isDirectory(atPath: .any).willReturn(true)
        given(mockFileManager).contents(atPath: .any).willReturn(
            """
            ---
            name: test-skill
            description: A test skill
            ---
            # Test
            """.data(using: .utf8)
        )

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/repo",
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
        #expect(skills.first?.name == "test-skill")
        verify(mockGit).clone(url: .any, to: .any).called(1)
    }

    @Test func `pulls when repository already cloned`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        // Repo is already cloned
        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn(["existing-skill"])
        given(mockFileManager).isDirectory(atPath: .any).willReturn(true)
        given(mockFileManager).contents(atPath: .any).willReturn(
            """
            ---
            name: existing-skill
            description: Existing
            ---
            # Existing
            """.data(using: .utf8)
        )

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/repo",
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        let skills = try await repo.fetchAll()

        verify(mockGit).pull(at: .any).called(1)
        verify(mockGit).clone(url: .any, to: .any).called(0)
        #expect(skills.count == 1)
    }

    // MARK: - Skills Directory Detection

    @Test func `finds skills in skills subdirectory`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        // Root has a "skills" directory - need to handle multiple calls
        given(mockFileManager).contentsOfDirectory(atPath: .matching { $0.hasSuffix("owner_skills-repo") })
            .willReturn(["skills", "README.md"])
        given(mockFileManager).contentsOfDirectory(atPath: .matching { $0.hasSuffix("skills") })
            .willReturn(["skill-one"])
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("skills") && !$0.hasSuffix("skill-one") })
            .willReturn(true)
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("skill-one") })
            .willReturn(true)
        given(mockFileManager).contents(atPath: .matching { $0.hasSuffix("SKILL.md") }).willReturn(
            """
            ---
            name: skill-one
            description: First skill
            ---
            # One
            """.data(using: .utf8)
        )

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/skills-repo",
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
        #expect(skills.first?.name == "skill-one")
    }

    @Test func `finds skills in root directory when no skills subdirectory`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        // Root has skill directories directly
        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn(["my-skill", ".git"])
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("skills") }).willReturn(false)
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("my-skill") }).willReturn(true)
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix(".git") }).willReturn(true)
        given(mockFileManager).contents(atPath: .matching { $0.hasSuffix("SKILL.md") }).willReturn(
            """
            ---
            name: my-skill
            description: Root skill
            ---
            # My Skill
            """.data(using: .utf8)
        )

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/root-skills",
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
        #expect(skills.first?.name == "my-skill")
    }

    // MARK: - Source Assignment

    @Test func `assigns remote source with repo URL`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn(["test-skill"])
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("skills") }).willReturn(false)
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("test-skill") }).willReturn(true)
        given(mockFileManager).contents(atPath: .any).willReturn(
            """
            ---
            name: test-skill
            description: Test
            ---
            # Test
            """.data(using: .utf8)
        )

        let repoUrl = "https://github.com/owner/repo"
        let repo = ClonedRepoSkillRepository(
            repoUrl: repoUrl,
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        let skills = try await repo.fetchAll()

        #expect(skills.first?.source == .remote(repoUrl: repoUrl))
    }

    // MARK: - Cache Directory Naming

    @Test func `creates cache directory name from owner and repo`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(false)
        given(mockGit).clone(url: .any, to: .matching { $0.hasSuffix("anthropics_skills") }).willReturn()

        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn([])
        given(mockFileManager).isDirectory(atPath: .any).willReturn(false)

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/anthropics/skills",
            cacheDirectory: "/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        _ = try await repo.fetchAll()

        verify(mockGit).clone(url: .any, to: .matching { $0.hasSuffix("anthropics_skills") }).called(1)
    }

    // MARK: - Error Handling

    @Test func `returns empty array when clone fails`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(false)
        given(mockGit).clone(url: .any, to: .any).willThrow(GitCLIError.cloneFailed("not found"))

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/nonexistent",
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        // Should not throw, but return empty
        let skills = try await repo.fetchAll()

        #expect(skills.isEmpty)
    }

    @Test func `skips directories without SKILL.md`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        // Root directory has two directories
        given(mockFileManager).contentsOfDirectory(atPath: .matching { $0.hasSuffix("owner_mixed") }).willReturn(["not-a-skill", "valid-skill"])
        // not-a-skill directory is empty (no subdirectories)
        given(mockFileManager).contentsOfDirectory(atPath: .matching { $0.hasSuffix("not-a-skill") }).willReturn([])
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("skills") }).willReturn(false)
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("not-a-skill") }).willReturn(true)
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("valid-skill") }).willReturn(true)
        // Only valid-skill has SKILL.md
        given(mockFileManager).contents(atPath: .matching { $0.contains("not-a-skill") }).willReturn(nil)
        given(mockFileManager).contents(atPath: .matching { $0.contains("valid-skill") }).willReturn(
            """
            ---
            name: valid-skill
            description: Valid
            ---
            # Valid
            """.data(using: .utf8)
        )

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/mixed",
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
        #expect(skills.first?.name == "valid-skill")
    }

    // MARK: - Fetch by ID

    @Test func `fetches specific skill by id`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        given(mockFileManager).contents(atPath: .matching { $0.contains("specific-skill") }).willReturn(
            """
            ---
            name: specific-skill
            description: Specific
            ---
            # Specific
            """.data(using: .utf8)
        )

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/repo",
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        let skill = try await repo.fetch(id: "specific-skill")

        #expect(skill?.name == "specific-skill")
    }

    @Test func `returns nil for non-existent skill id`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()
        given(mockFileManager).contents(atPath: .any).willReturn(nil)

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/repo",
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        let skill = try await repo.fetch(id: "non-existent")

        #expect(skill == nil)
    }

    // MARK: - Delete Clone Tests

    @Test func `deleteClone removes cloned directory`() throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("owner_repo") }).willReturn(true)
        given(mockFileManager).removeItem(atPath: .matching { $0.hasSuffix("owner_repo") }).willReturn()

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/repo",
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        try repo.deleteClone()

        verify(mockFileManager).removeItem(atPath: .matching { $0.hasSuffix("owner_repo") }).called(1)
    }

    @Test func `deleteClone does nothing if directory does not exist`() throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockFileManager).isDirectory(atPath: .any).willReturn(false)

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/repo",
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        try repo.deleteClone()

        verify(mockFileManager).removeItem(atPath: .any).called(0)
    }

    @Test func `static deleteClone removes directory by URL`() throws {
        let mockFileManager = MockFileManagerProtocol()

        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("anthropics_skills") }).willReturn(true)
        given(mockFileManager).removeItem(atPath: .matching { $0.hasSuffix("anthropics_skills") }).willReturn()

        try ClonedRepoSkillRepository.deleteClone(
            forRepoUrl: "https://github.com/anthropics/skills",
            cacheDirectory: "/cache",
            fileManager: mockFileManager
        )

        verify(mockFileManager).removeItem(atPath: .matching { $0.hasSuffix("anthropics_skills") }).called(1)
    }
}
