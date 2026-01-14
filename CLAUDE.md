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
│  - Rich domain models with behavior (Skill, SkillsCatalog, Provider)│
│  - Protocols with @Mockable for DI (SkillRepository, GitCLIClient)  │
│  - Pure business logic, no external dependencies                    │
├─────────────────────────────────────────────────────────────────────┤
│  Infrastructure (Sources/Infrastructure/)                           │
│  - Repository implementations (LocalSkillRepository, GitHub, Git)   │
│  - MergedSkillRepository for combining multiple sources             │
│  - External integrations (GitHubClient, GitCLIClient, SkillParser)  │
│  - File system operations (FileSystemSkillInstaller)                │
├─────────────────────────────────────────────────────────────────────┤
│  App (Sources/App/)                                                 │
│  - SwiftUI views consuming domain models directly (no ViewModel)    │
│  - SkillLibrary (@Observable) coordinates catalogs                  │
│  - Dependency wiring in SkillsManagerApp                            │
└─────────────────────────────────────────────────────────────────────┘
```

**Key patterns:**
- Views consume domain models directly - no ViewModel layer
- `@Mockable` protocol annotation generates mocks for testing
- `MOCKING` compiler flag enabled for Domain, Infrastructure, and their tests
- Tell-Don't-Ask: objects encapsulate behavior with their data

## Domain Model Hierarchy

```
SkillLibrary (@Observable)
├── localCatalog: SkillsCatalog     ← Installed skills (claude + codex)
└── remoteCatalogs: [SkillsCatalog] ← GitHub skill repos
    └── skills: [Skill]              ← Each catalog owns its skills
```

### Key Domain Classes

**SkillsCatalog** - Rich domain class that owns skills:
```swift
@Observable
public final class SkillsCatalog {
    public var skills: [Skill] = []

    // Tell-Don't-Ask: catalog manages its own skills
    public func loadSkills() async { ... }
    public func addSkill(_ skill: Skill) { ... }
    public func removeSkill(uniqueKey: String) { ... }
    public func updateInstallationStatus(for uniqueKey: String, to providers: Set<Provider>) { ... }
    public func syncInstallationStatus(with installedSkills: [Skill]) { ... }
}
```

**SkillLibrary** - Coordinates catalogs:
```swift
@Observable
public final class SkillLibrary {
    public let localCatalog: SkillsCatalog      // Installed skills
    public var remoteCatalogs: [SkillsCatalog]  // Remote catalogs

    public var filteredSkills: [Skill] {
        selectedCatalog.skills.filtered(by: searchQuery)
    }
}
```

## TDD Approach (Chicago School)

This project follows **Chicago School TDD** (state-based testing):

- Test **state changes** and **return values**, not method call interactions
- Use `given().willReturn()` to stub mock data
- Avoid `verify().called()` for interaction testing
- Use Swift Testing framework (`@Test`, `@Suite`, `#expect`)

Example pattern:
```swift
@Test func `install adds skill to local catalog`() async {
    let remoteSkill = makeRemoteSkill(id: "test")
    let localCatalog = makeLocalCatalog()
    let mockInstaller = MockSkillInstaller()

    given(mockInstaller).install(.any, to: .any).willReturn(remoteSkill.installing(for: .claude))

    let library = SkillLibrary(localCatalog: localCatalog, installer: mockInstaller)
    library.selectedSkill = remoteSkill

    await library.install(to: [.claude])

    #expect(localCatalog.skills.count == 1)
}
```

## Domain Model Design

Domain models encapsulate behavior matching user's mental model:

```swift
public struct Skill: Sendable, Equatable, Identifiable {
    // User asks: "What name should I see?"
    public var displayName: String {
        repoPath != nil ? "\(name) (\(repoPath!))" : name
    }

    // User asks: "Is this skill installed?"
    public var isInstalled: Bool {
        !installedProviders.isEmpty
    }

    // User asks: "Can I edit this skill?"
    public var isEditable: Bool {
        source.isLocal
    }
}
```

## Tell-Don't-Ask Principle

Objects bundle data with behavior. Instead of:
```swift
// BAD: Asking for data and operating on it
for index in catalog.skills.indices {
    if catalog.skills[index].uniqueKey == uniqueKey {
        catalog.skills[index] = catalog.skills[index].withInstalledProviders(providers)
    }
}
```

Use:
```swift
// GOOD: Tell the object what to do
catalog.updateInstallationStatus(for: uniqueKey, to: providers)
```

## Skill Sources

The app manages skills from multiple sources:

- **Local Catalog**: Installed skills from `~/.claude/skills/` and `~/.codex/skills/`
  - Uses `MergedSkillRepository` to combine claude + codex providers
- **Remote Catalogs**: GitHub repositories containing skills
  - Uses `ClonedRepoSkillRepository` to clone and parse skills
  - Cache cleaning handled by `SkillLibrary` (infrastructure concern)

### Source Filter
```swift
public enum SourceFilter: Hashable {
    case local                    // Show localCatalog.skills
    case remote(repoId: UUID)     // Show remoteCatalog.skills
}
```

## Persistence

Remote catalogs are persisted using `SkillsCatalog.Data`:
```swift
public struct Data: Codable, Sendable {
    public let id: UUID
    public let url: String?  // nil for local
    public let name: String
    public let addedAt: Date
}
```

Local catalog is not persisted (rebuilt from filesystem on load).
