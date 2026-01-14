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

    // MARK: - Recursive Skill Discovery

    @Test func `finds skills in root directory`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn(["my-skill", "README.md"])
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("my-skill") }).willReturn(true)
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("README.md") }).willReturn(false)
        given(mockFileManager).contents(atPath: .matching { $0.hasSuffix("SKILL.md") }).willReturn(
            """
            ---
            name: my-skill
            description: A skill
            ---
            # My Skill
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
        #expect(skills.first?.name == "my-skill")
    }

    @Test func `finds skills in nested directories`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        // Root contains "skills" directory
        given(mockFileManager).contentsOfDirectory(atPath: .matching { $0.hasSuffix("owner_repo") }).willReturn(["skills"])
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("/skills") }).willReturn(true)

        // skills/ itself has no SKILL.md (it's just a container)
        given(mockFileManager).contents(atPath: .matching { $0.hasSuffix("/skills/SKILL.md") }).willReturn(nil)

        // skills/ contains the actual skill
        given(mockFileManager).contentsOfDirectory(atPath: .matching { $0.hasSuffix("/skills") }).willReturn(["nested-skill"])
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("nested-skill") }).willReturn(true)
        given(mockFileManager).contents(atPath: .matching { $0.contains("nested-skill/SKILL.md") }).willReturn(
            """
            ---
            name: nested-skill
            description: A nested skill
            ---
            # Nested
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
        #expect(skills.first?.name == "nested-skill")
    }

    @Test func `finds skills in hidden directories like .claude`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        // Root contains ".claude" hidden directory
        given(mockFileManager).contentsOfDirectory(atPath: .matching { $0.hasSuffix("owner_repo") }).willReturn([".claude", "README.md"])
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix(".claude") }).willReturn(true)
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("README.md") }).willReturn(false)

        // .claude/ itself has no SKILL.md
        given(mockFileManager).contents(atPath: .matching { $0.hasSuffix(".claude/SKILL.md") }).willReturn(nil)

        // .claude/ contains "skills" directory
        given(mockFileManager).contentsOfDirectory(atPath: .matching { $0.hasSuffix(".claude") }).willReturn(["skills"])
        given(mockFileManager).isDirectory(atPath: .matching { $0.contains(".claude/skills") }).willReturn(true)

        // .claude/skills/ itself has no SKILL.md
        given(mockFileManager).contents(atPath: .matching { $0.hasSuffix(".claude/skills/SKILL.md") }).willReturn(nil)

        // .claude/skills/ contains the skill
        given(mockFileManager).contentsOfDirectory(atPath: .matching { $0.contains(".claude/skills") }).willReturn(["ui-ux-pro-max"])
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("ui-ux-pro-max") }).willReturn(true)
        given(mockFileManager).contents(atPath: .matching { $0.contains("ui-ux-pro-max/SKILL.md") }).willReturn(
            """
            ---
            name: ui-ux-pro-max
            description: UI/UX design intelligence
            ---
            # UI/UX Pro Max
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
        #expect(skills.first?.name == "ui-ux-pro-max")
    }

    @Test func `skips .git directory`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        // Root contains .git and a skill
        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn([".git", "my-skill"])
        given(mockFileManager).isDirectory(atPath: .matching { $0.hasSuffix("my-skill") }).willReturn(true)
        // .git should not be checked for isDirectory (it's skipped)
        given(mockFileManager).contents(atPath: .matching { $0.hasSuffix("SKILL.md") }).willReturn(
            """
            ---
            name: my-skill
            description: Test
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
        #expect(skills.first?.name == "my-skill")
    }

    @Test func `skips directories without SKILL.md`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        // Root directory has two subdirectories
        given(mockFileManager).contentsOfDirectory(atPath: .matching { $0.hasSuffix("owner_repo") }).willReturn(["not-a-skill", "valid-skill"])
        // Subdirectories have no children (to prevent infinite recursion)
        given(mockFileManager).contentsOfDirectory(atPath: .matching { !$0.hasSuffix("owner_repo") }).willReturn([])
        given(mockFileManager).isDirectory(atPath: .any).willReturn(true)
        // not-a-skill has no SKILL.md
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
            repoUrl: "https://github.com/owner/repo",
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
        #expect(skills.first?.name == "valid-skill")
    }

    // MARK: - Source Assignment

    @Test func `assigns remote source with repo URL`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn(["test-skill"])
        given(mockFileManager).isDirectory(atPath: .any).willReturn(true)
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

    // MARK: - Fetch by ID

    @Test func `fetches specific skill by id`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn(["target-skill", "other-skill"])
        given(mockFileManager).isDirectory(atPath: .any).willReturn(true)
        given(mockFileManager).contents(atPath: .matching { $0.contains("target-skill/SKILL.md") }).willReturn(
            """
            ---
            name: target-skill
            description: The target
            ---
            # Target
            """.data(using: .utf8)
        )
        given(mockFileManager).contents(atPath: .matching { $0.contains("other-skill") }).willReturn(nil)

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/repo",
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        let skill = try await repo.fetch(id: "target-skill")

        #expect(skill != nil)
        #expect(skill?.name == "target-skill")
    }

    @Test func `returns nil for non-existent skill id`() async throws {
        let mockGit = MockGitCLIClientProtocol()
        let mockFileManager = MockFileManagerProtocol()

        given(mockGit).isGitRepository(at: .any).willReturn(true)
        given(mockGit).pull(at: .any).willReturn()

        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn(["other-skill"])
        given(mockFileManager).isDirectory(atPath: .any).willReturn(true)
        given(mockFileManager).contents(atPath: .any).willReturn(nil)

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/repo",
            cacheDirectory: "/tmp/cache",
            gitClient: mockGit,
            fileManager: mockFileManager
        )

        let skill = try await repo.fetch(id: "nonexistent")

        #expect(skill == nil)
    }

    // MARK: - Cache Deletion

    @Test func `deleteClone removes cloned directory`() throws {
        let mockFileManager = MockFileManagerProtocol()

        given(mockFileManager).isDirectory(atPath: .any).willReturn(true)
        given(mockFileManager).removeItem(atPath: .any).willReturn()

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/repo",
            cacheDirectory: "/tmp/cache",
            gitClient: MockGitCLIClientProtocol(),
            fileManager: mockFileManager
        )

        try repo.deleteClone()

        verify(mockFileManager).removeItem(atPath: .any).called(1)
    }

    @Test func `deleteClone does nothing if directory does not exist`() throws {
        let mockFileManager = MockFileManagerProtocol()

        given(mockFileManager).isDirectory(atPath: .any).willReturn(false)

        let repo = ClonedRepoSkillRepository(
            repoUrl: "https://github.com/owner/repo",
            cacheDirectory: "/tmp/cache",
            gitClient: MockGitCLIClientProtocol(),
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
