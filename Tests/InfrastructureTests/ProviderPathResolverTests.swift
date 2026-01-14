import Testing
import Foundation
@testable import Domain
@testable import Infrastructure

@Suite
struct ProviderPathResolverTests {

    // MARK: - Path Resolution

    @Test func `codex provider path is in codex skills directory`() {
        let resolver = ProviderPathResolver()

        let path = resolver.skillsPath(for: .codex)

        #expect(path.contains(".codex/skills/public"))
    }

    @Test func `claude provider path is in claude skills directory`() {
        let resolver = ProviderPathResolver()

        let path = resolver.skillsPath(for: .claude)

        #expect(path.contains(".claude/skills"))
    }

    @Test func `paths are absolute paths starting from home`() {
        let resolver = ProviderPathResolver()
        let home = FileManager.default.homeDirectoryForCurrentUser.path

        let codexPath = resolver.skillsPath(for: .codex)
        let claudePath = resolver.skillsPath(for: .claude)

        #expect(codexPath.hasPrefix(home))
        #expect(claudePath.hasPrefix(home))
    }

    @Test func `codex path ends with correct suffix`() {
        let resolver = ProviderPathResolver()

        let path = resolver.skillsPath(for: .codex)

        #expect(path.hasSuffix(".codex/skills/public"))
    }

    @Test func `claude path ends with correct suffix`() {
        let resolver = ProviderPathResolver()

        let path = resolver.skillsPath(for: .claude)

        #expect(path.hasSuffix(".claude/skills"))
    }
}
