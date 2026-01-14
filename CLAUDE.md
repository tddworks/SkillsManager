# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Test Commands

```bash
# Build the project
swift build

# Run all tests
swift test

# Run tests for a specific target
swift test --filter DomainTests
swift test --filter InfrastructureTests

# Run a specific test suite
swift test --filter "SkillTests"

# Run a specific test by name
swift test --filter "SkillTests/skill displays provider name when set"

# Run the app
swift run SkillsManager
```

## Architecture

Three-layer architecture with clean separation:

```
┌─────────────────────────────────────────────────────────────────────┐
│  Domain (Sources/Domain/)                                           │
│  - Rich domain models with behavior (Skill, Provider, SkillSource)  │
│  - Protocols with @Mockable for DI (SkillRepository, GitCLIClient)  │
│  - Pure business logic, no external dependencies                    │
├─────────────────────────────────────────────────────────────────────┤
│  Infrastructure (Sources/Infrastructure/)                           │
│  - Repository implementations (LocalSkillRepository, GitHub, Git)   │
│  - External integrations (GitHubClient, GitCLIClient, SkillParser)  │
│  - File system operations (FileSystemSkillInstaller)                │
├─────────────────────────────────────────────────────────────────────┤
│  App (Sources/App/)                                                 │
│  - SwiftUI views consuming domain models directly (no ViewModel)    │
│  - SkillLibrary (@Observable) for shared library state              │
│  - Dependency wiring in SkillsManagerApp                            │
└─────────────────────────────────────────────────────────────────────┘
```

**Key patterns:**
- Views consume domain models directly - no ViewModel layer
- `@Mockable` protocol annotation generates mocks for testing
- `MOCKING` compiler flag enabled for Domain, Infrastructure, and their tests

## TDD Approach (Chicago School)

This project follows **Chicago School TDD** (state-based testing):

- Test **state changes** and **return values**, not method call interactions
- Use `given().willReturn()` to stub mock data
- Avoid `verify().called()` for interaction testing
- Use Swift Testing framework (`@Test`, `@Suite`, `#expect`)

Example pattern:
```swift
@Test func `repository returns skills from directory`() async throws {
    // Given - stub dependencies
    given(mockFileManager).contentsOfDirectory(at: any()).willReturn([skillURL])

    // When
    let skills = try await repository.fetchSkills()

    // Then - assert state, not interactions
    #expect(skills.count == 1)
}
```

## Domain Model Design

Domain models encapsulate behavior matching user's mental model:

```swift
public struct Skill: Sendable, Equatable, Identifiable {
    public var displayName: String {  // Computed behavior
        provider?.name ?? name
    }
}
```

## Skill Sources

The app manages skills from multiple sources:
- **Local**: Skills from `~/.claude/skills/`
- **GitHub**: Skills fetched via GitHub API
- **Git CLI**: Skills from cloned repositories

Each source has a corresponding `SkillRepository` implementation in Infrastructure.
