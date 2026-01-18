import Testing
import Foundation
import Mockable
@testable import Infrastructure
@testable import Domain

@Suite
struct LocalDirectorySkillRepositoryTests {

    // MARK: - Basic Fetch

    @Test func `finds skills in directory`() async throws {
        let mockFileManager = MockFileManagerProtocol()

        // Directory has one skill
        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn(["my-skill"])
        given(mockFileManager).isDirectory(atPath: .any).willReturn(true)
        given(mockFileManager).contents(atPath: .any).willReturn(
            """
            ---
            name: My Skill
            description: A skill from local directory
            ---
            # My Skill Content
            """.data(using: .utf8)
        )

        let repo = LocalDirectorySkillRepository(
            directoryPath: "/Users/test/projects/.agent/skills",
            fileManager: mockFileManager
        )

        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
        #expect(skills.first?.name == "My Skill")
        #expect(skills.first?.id == "my-skill")
    }

    @Test func `skill has localDirectory source`() async throws {
        let mockFileManager = MockFileManagerProtocol()

        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn(["test-skill"])
        given(mockFileManager).isDirectory(atPath: .any).willReturn(true)
        given(mockFileManager).contents(atPath: .any).willReturn(
            """
            ---
            name: Test Skill
            description: Testing
            ---
            # Test
            """.data(using: .utf8)
        )

        let repo = LocalDirectorySkillRepository(
            directoryPath: "/path/to/skills",
            fileManager: mockFileManager
        )

        let skills = try await repo.fetchAll()

        #expect(skills.first?.source == .localDirectory(path: "/path/to/skills"))
    }

    @Test func `handles file URL scheme`() async throws {
        let mockFileManager = MockFileManagerProtocol()

        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn(["skill"])
        given(mockFileManager).isDirectory(atPath: .any).willReturn(true)
        given(mockFileManager).contents(atPath: .any).willReturn(
            """
            ---
            name: File URL Skill
            description: From file URL
            ---
            # Content
            """.data(using: .utf8)
        )

        // Using file:// URL
        let repo = LocalDirectorySkillRepository(
            directoryPath: "file:///Users/test/skills",
            fileManager: mockFileManager
        )

        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
    }

    @Test func `returns empty array when directory does not exist`() async throws {
        let mockFileManager = MockFileManagerProtocol()

        // Directory does not exist
        given(mockFileManager).contentsOfDirectory(atPath: .any).willThrow(
            NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError)
        )

        let repo = LocalDirectorySkillRepository(
            directoryPath: "/nonexistent/path",
            fileManager: mockFileManager
        )

        let skills = try await repo.fetchAll()

        #expect(skills.isEmpty)
    }

    @Test func `skips directories without SKILL.md`() async throws {
        let mockFileManager = MockFileManagerProtocol()

        // Directory has items but no SKILL.md
        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn(["folder-without-skill"])
        given(mockFileManager).isDirectory(atPath: .any).willReturn(true)
        given(mockFileManager).contents(atPath: .any).willReturn(nil)

        let repo = LocalDirectorySkillRepository(
            directoryPath: "/path/to/skills",
            fileManager: mockFileManager
        )

        let skills = try await repo.fetchAll()

        #expect(skills.isEmpty)
    }

    @Test func `finds skills in nested directories`() async throws {
        // Use real file manager with temp directory for this test
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create nested structure: root/.claude/skills/my-skill/SKILL.md
        let skillDir = tempDir.appendingPathComponent(".claude/skills/my-skill")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let skillContent = """
        ---
        name: Nested Skill
        description: Found in nested directory
        ---
        # Nested Content
        """
        try skillContent.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let repo = LocalDirectorySkillRepository(
            directoryPath: tempDir.path,
            fileManager: RealFileManager.shared
        )

        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
        #expect(skills.first?.name == "Nested Skill")
        #expect(skills.first?.repoPath == ".claude/skills")
    }

    @Test func `fetch by id returns skill`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let skillDir = tempDir.appendingPathComponent("target-skill")
        try FileManager.default.createDirectory(at: skillDir, withIntermediateDirectories: true)
        let skillContent = """
        ---
        name: Target Skill
        description: The skill we want
        ---
        # Target
        """
        try skillContent.write(to: skillDir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)

        let repo = LocalDirectorySkillRepository(
            directoryPath: tempDir.path,
            fileManager: RealFileManager.shared
        )

        let skill = try await repo.fetch(id: "target-skill")

        #expect(skill != nil)
        #expect(skill?.name == "Target Skill")
    }

    @Test func `fetch by id returns nil for non-existent skill`() async throws {
        let mockFileManager = MockFileManagerProtocol()

        given(mockFileManager).contentsOfDirectory(atPath: .any).willReturn([])

        let repo = LocalDirectorySkillRepository(
            directoryPath: "/path/to/skills",
            fileManager: mockFileManager
        )

        let skill = try await repo.fetch(id: "nonexistent")

        #expect(skill == nil)
    }
}
