import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite
struct LocalSkillRepositoryTests {

    // MARK: - Scanning Skills Directory

    @Test func `returns empty array when skills directory does not exist`() async throws {
        let repo = LocalSkillRepository(
            provider: .claude,
            fileManager: MockFileManager(directoryExists: false)
        )

        let skills = try await repo.fetchAll()

        #expect(skills.isEmpty)
    }

    @Test func `returns empty array when skills directory is empty`() async throws {
        let repo = LocalSkillRepository(
            provider: .codex,
            fileManager: MockFileManager(directoryExists: true, contents: [])
        )

        let skills = try await repo.fetchAll()

        #expect(skills.isEmpty)
    }

    @Test func `finds skill with SKILL.md file`() async throws {
        let skillContent = """
        ---
        name: test-skill
        description: A test skill
        ---
        # Test Skill
        """

        let repo = LocalSkillRepository(
            provider: .claude,
            fileManager: MockFileManager(
                directoryExists: true,
                contents: ["test-skill"],
                skillFiles: ["test-skill/SKILL.md": skillContent]
            )
        )

        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
        #expect(skills.first?.name == "test-skill")
        #expect(skills.first?.source.isLocal == true)
    }

    @Test func `ignores directories without SKILL.md`() async throws {
        let repo = LocalSkillRepository(
            provider: .codex,
            fileManager: MockFileManager(
                directoryExists: true,
                contents: ["not-a-skill", "also-not-a-skill"],
                skillFiles: [:]
            )
        )

        let skills = try await repo.fetchAll()

        #expect(skills.isEmpty)
    }

    @Test func `finds multiple skills`() async throws {
        let skill1 = """
        ---
        name: skill-one
        description: First skill
        ---
        # One
        """
        let skill2 = """
        ---
        name: skill-two
        description: Second skill
        ---
        # Two
        """

        let repo = LocalSkillRepository(
            provider: .claude,
            fileManager: MockFileManager(
                directoryExists: true,
                contents: ["skill-one", "skill-two"],
                skillFiles: [
                    "skill-one/SKILL.md": skill1,
                    "skill-two/SKILL.md": skill2
                ]
            )
        )

        let skills = try await repo.fetchAll()

        #expect(skills.count == 2)
        #expect(skills.map(\.name).contains("skill-one"))
        #expect(skills.map(\.name).contains("skill-two"))
    }

    // MARK: - Provider Assignment

    @Test func `assigns correct provider to local skills`() async throws {
        let skillContent = """
        ---
        name: provider-test
        description: Test provider
        ---
        # Test
        """

        let claudeRepo = LocalSkillRepository(
            provider: .claude,
            fileManager: MockFileManager(
                directoryExists: true,
                contents: ["provider-test"],
                skillFiles: ["provider-test/SKILL.md": skillContent]
            )
        )

        let skills = try await claudeRepo.fetchAll()

        #expect(skills.first?.source == .local(provider: .claude))
    }

    // MARK: - Fetch by ID

    @Test func `fetches specific skill by id`() async throws {
        let skillContent = """
        ---
        name: specific-skill
        description: A specific skill
        ---
        # Specific
        """

        let repo = LocalSkillRepository(
            provider: .claude,
            fileManager: MockFileManager(
                directoryExists: true,
                contents: ["specific-skill"],
                skillFiles: ["specific-skill/SKILL.md": skillContent]
            )
        )

        let skill = try await repo.fetch(id: "specific-skill")

        #expect(skill?.name == "specific-skill")
    }

    @Test func `returns nil for non-existent skill id`() async throws {
        let repo = LocalSkillRepository(
            provider: .claude,
            fileManager: MockFileManager(
                directoryExists: true,
                contents: [],
                skillFiles: [:]
            )
        )

        let skill = try await repo.fetch(id: "non-existent")

        #expect(skill == nil)
    }
}

// MARK: - Mock File Manager

/// Mock FileManager for testing
final class MockFileManager: FileManagerProtocol, @unchecked Sendable {
    private let directoryExists: Bool
    private let contents: [String]
    private let skillFiles: [String: String]

    init(directoryExists: Bool, contents: [String] = [], skillFiles: [String: String] = [:]) {
        self.directoryExists = directoryExists
        self.contents = contents
        self.skillFiles = skillFiles
    }

    func fileExists(atPath path: String) -> Bool {
        directoryExists
    }

    func contentsOfDirectory(atPath path: String) throws -> [String] {
        contents
    }

    func contents(atPath path: String) -> Data? {
        // Extract relative path for skill files
        for (key, value) in skillFiles {
            if path.hasSuffix(key) {
                return value.data(using: .utf8)
            }
        }
        return nil
    }

    func isDirectory(atPath path: String) -> Bool {
        // Check if this is a skill directory
        for dir in contents {
            if path.hasSuffix(dir) {
                return true
            }
        }
        return false
    }
}
