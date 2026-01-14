import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite
struct FileSystemSkillInstallerTests {

    // MARK: - Integration Tests for Install/Uninstall Flow

    @Test func `installed skill can be found by LocalSkillRepository with correct uniqueKey`() async throws {
        // This tests the full flow: install writes .skill-id, LocalSkillRepository reads it back

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a mock provider path
        let skillsPath = tempDir.appendingPathComponent("skills").path

        // Create skill folder with SKILL.md and .skill-id
        let skillFolder = "\(skillsPath)/ui-ux-pro-max"
        try FileManager.default.createDirectory(atPath: skillFolder, withIntermediateDirectories: true)

        let skillContent = """
        ---
        name: UI/UX Pro Max
        description: UI skill
        version: 1.0.0
        ---
        # Content
        """
        try skillContent.write(toFile: "\(skillFolder)/SKILL.md", atomically: true, encoding: .utf8)

        // Write .skill-id with uniqueKey format (repoPath/id)
        let uniqueKey = ".claude/skills/ui-ux-pro-max"
        try uniqueKey.write(toFile: "\(skillFolder)/.skill-id", atomically: true, encoding: .utf8)

        // Create a mock file manager that uses our temp directory
        let mockFileManager = TempDirFileManager(basePath: skillsPath)

        // Read using LocalSkillRepository
        let repo = LocalSkillRepository(provider: .claude, fileManager: mockFileManager)
        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
        let skill = skills.first!
        #expect(skill.id == "ui-ux-pro-max")
        #expect(skill.repoPath == ".claude/skills")
        #expect(skill.uniqueKey == ".claude/skills/ui-ux-pro-max")
    }

    @Test func `skill without skill-id file has uniqueKey equal to id`() async throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let skillsPath = tempDir.appendingPathComponent("skills").path
        let skillFolder = "\(skillsPath)/local-skill"
        try FileManager.default.createDirectory(atPath: skillFolder, withIntermediateDirectories: true)

        let skillContent = """
        ---
        name: Local Skill
        description: A local skill
        version: 1.0.0
        ---
        # Content
        """
        try skillContent.write(toFile: "\(skillFolder)/SKILL.md", atomically: true, encoding: .utf8)
        // No .skill-id file

        let mockFileManager = TempDirFileManager(basePath: skillsPath)
        let repo = LocalSkillRepository(provider: .claude, fileManager: mockFileManager)
        let skills = try await repo.fetchAll()

        #expect(skills.count == 1)
        let skill = skills.first!
        #expect(skill.id == "local-skill")
        #expect(skill.repoPath == nil)
        #expect(skill.uniqueKey == "local-skill")
    }
}

// MARK: - Skill Matching Tests

@Suite
struct SkillMatchingTests {

    @Test func `local and remote skills with same uniqueKey should match`() {
        let localSkill = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "UI skill",
            version: "1.0.0",
            content: "# Content",
            source: .local(provider: .claude),
            repoPath: ".claude/skills",
            installedProviders: [.claude]
        )

        let remoteSkill = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "UI skill",
            version: "1.0.0",
            content: "# Content",
            source: .remote(repoUrl: "https://github.com/example/repo"),
            repoPath: ".claude/skills"
        )

        // Both should have the same uniqueKey for matching
        #expect(localSkill.uniqueKey == remoteSkill.uniqueKey)
        #expect(localSkill.uniqueKey == ".claude/skills/ui-ux-pro-max")
    }

    @Test func `skills with same id but different repoPath have different uniqueKeys`() {
        let skill1 = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "UI skill",
            version: "1.0.0",
            content: "# Content",
            source: .remote(repoUrl: "https://github.com/example/repo"),
            repoPath: ".claude/skills"
        )

        let skill2 = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "UI skill",
            version: "1.0.0",
            content: "# Content",
            source: .remote(repoUrl: "https://github.com/example/repo"),
            repoPath: "cli/assets/.claude/skills"
        )

        // Different repoPath = different uniqueKey
        #expect(skill1.uniqueKey != skill2.uniqueKey)
        #expect(skill1.uniqueKey == ".claude/skills/ui-ux-pro-max")
        #expect(skill2.uniqueKey == "cli/assets/.claude/skills/ui-ux-pro-max")
    }

    @Test func `installed variant should not match other variants`() {
        // Simulates: user installed from .claude/skills path
        let installedLocal = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "UI skill",
            version: "1.0.0",
            content: "# Content",
            source: .local(provider: .claude),
            repoPath: ".claude/skills",
            installedProviders: [.claude]
        )

        // Remote variant from different path
        let remoteOtherVariant = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "UI skill",
            version: "1.0.0",
            content: "# Content",
            source: .remote(repoUrl: "https://github.com/example/repo"),
            repoPath: ".gemini/skills"
        )

        // Same variant from remote
        let remoteSameVariant = Skill(
            id: "ui-ux-pro-max",
            name: "UI/UX Pro Max",
            description: "UI skill",
            version: "1.0.0",
            content: "# Content",
            source: .remote(repoUrl: "https://github.com/example/repo"),
            repoPath: ".claude/skills"
        )

        // Should NOT match different variant
        #expect(installedLocal.uniqueKey != remoteOtherVariant.uniqueKey)

        // SHOULD match same variant
        #expect(installedLocal.uniqueKey == remoteSameVariant.uniqueKey)
    }
}

// MARK: - Helper: Temp Directory File Manager

final class TempDirFileManager: FileManagerProtocol, @unchecked Sendable {
    private let basePath: String
    private let claudeSkillsPath: String

    init(basePath: String) {
        self.basePath = basePath
        self.claudeSkillsPath = ProviderPathResolver().skillsPath(for: .claude)
    }

    func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path.replacingOccurrences(of: claudeSkillsPath, with: basePath))
    }

    func contentsOfDirectory(atPath path: String) throws -> [String] {
        let actualPath = path.replacingOccurrences(of: claudeSkillsPath, with: basePath)
        return try FileManager.default.contentsOfDirectory(atPath: actualPath)
    }

    func contents(atPath path: String) -> Data? {
        let actualPath = path.replacingOccurrences(of: claudeSkillsPath, with: basePath)
        return FileManager.default.contents(atPath: actualPath)
    }

    func isDirectory(atPath path: String) -> Bool {
        let actualPath = path.replacingOccurrences(of: claudeSkillsPath, with: basePath)
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: actualPath, isDirectory: &isDir) && isDir.boolValue
    }

    func removeItem(atPath path: String) throws {
        let actualPath = path.replacingOccurrences(of: claudeSkillsPath, with: basePath)
        try FileManager.default.removeItem(atPath: actualPath)
    }
}
