import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite
struct SkillParserTests {

    // MARK: - Basic Parsing

    @Test func `parses skill name from frontmatter`() throws {
        let content = """
        ---
        name: apple-calendar
        description: Interact with Apple Calendar
        ---
        # Apple Calendar
        """

        let result = try SkillParser.parse(content: content, id: "apple-calendar", source: .local(provider: .claude))

        #expect(result.name == "apple-calendar")
    }

    @Test func `parses skill description from frontmatter`() throws {
        let content = """
        ---
        name: test-skill
        description: This is a test skill for testing
        ---
        # Test Skill
        """

        let result = try SkillParser.parse(content: content, id: "test-skill", source: .local(provider: .claude))

        #expect(result.description == "This is a test skill for testing")
    }

    @Test func `parses multiline description from frontmatter`() throws {
        let content = """
        ---
        name: calendar-cli
        description: |
          This skill should be used when interacting with
          Apple Calendar on macOS. Use it for listing calendars.
        ---
        # Calendar CLI
        """

        let result = try SkillParser.parse(content: content, id: "calendar-cli", source: .local(provider: .claude))

        #expect(result.description.contains("Apple Calendar"))
        #expect(result.description.contains("listing calendars"))
    }

    // MARK: - Version Parsing

    @Test func `parses version from frontmatter when present`() throws {
        let content = """
        ---
        name: versioned-skill
        description: A versioned skill
        version: 1.2.3
        ---
        # Versioned Skill
        """

        let result = try SkillParser.parse(content: content, id: "versioned-skill", source: .local(provider: .codex))

        #expect(result.version == "1.2.3")
    }

    @Test func `uses default version when not in frontmatter`() throws {
        let content = """
        ---
        name: no-version-skill
        description: Skill without version
        ---
        # No Version
        """

        let result = try SkillParser.parse(content: content, id: "no-version-skill", source: .local(provider: .claude))

        #expect(result.version == "1.0.0")
    }

    // MARK: - Content Preservation

    @Test func `preserves full markdown content`() throws {
        let content = """
        ---
        name: content-skill
        description: Test content
        ---
        # Main Heading

        This is the body content.

        ## Features

        - Feature 1
        - Feature 2
        """

        let result = try SkillParser.parse(content: content, id: "content-skill", source: .remote(repoUrl: "https://github.com/test"))

        #expect(result.content.contains("# Main Heading"))
        #expect(result.content.contains("## Features"))
        #expect(result.content.contains("Feature 1"))
    }

    // MARK: - Source Assignment

    @Test func `assigns local source correctly`() throws {
        let content = """
        ---
        name: local-skill
        description: Local skill
        ---
        # Local
        """

        let result = try SkillParser.parse(content: content, id: "local-skill", source: .local(provider: .codex))

        #expect(result.source.isLocal)
    }

    @Test func `assigns remote source correctly`() throws {
        let content = """
        ---
        name: remote-skill
        description: Remote skill
        ---
        # Remote
        """

        let result = try SkillParser.parse(content: content, id: "remote-skill", source: .remote(repoUrl: "https://github.com/example/skills"))

        #expect(result.source.isRemote)
    }

    // MARK: - Error Cases

    @Test func `throws error for missing frontmatter`() {
        let content = """
        # No Frontmatter
        Just markdown content
        """

        #expect(throws: SkillParserError.self) {
            _ = try SkillParser.parse(content: content, id: "bad-skill", source: .local(provider: .claude))
        }
    }

    @Test func `throws error for missing name in frontmatter`() {
        let content = """
        ---
        description: Missing name
        ---
        # Content
        """

        #expect(throws: SkillParserError.self) {
            _ = try SkillParser.parse(content: content, id: "bad-skill", source: .local(provider: .claude))
        }
    }

    @Test func `throws error for missing description in frontmatter`() {
        let content = """
        ---
        name: missing-desc
        ---
        # Content
        """

        #expect(throws: SkillParserError.self) {
            _ = try SkillParser.parse(content: content, id: "bad-skill", source: .local(provider: .claude))
        }
    }
}
