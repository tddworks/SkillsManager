# Skills Manager Architecture

## Overview

Skills Manager is a macOS app that helps users discover, browse, and install skills for AI coding assistants (Claude Code and Codex).

## Features

- Browse skills from remote GitHub repositories (like anthropics/skills)
- View locally installed skills
- Toggle between Local/Remote sources
- Search and filter skills
- View skill details with rendered markdown
- Install skills to Codex (`~/.codex/skills/public`) and/or Claude Code (`~/.claude/skills`)
- Show provider badges indicating where a skill is installed

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        SKILLS MANAGER ARCHITECTURE                               │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  DOMAIN LAYER                                                                    │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │  SkillLibrary (@Observable)                                                │ │
│  │  ├── localCatalog: SkillsCatalog    ← Installed skills (claude + codex)   │ │
│  │  └── remoteCatalogs: [SkillsCatalog] ← GitHub skill repositories          │ │
│  │                                                                            │ │
│  │  SkillsCatalog (@Observable class)                                         │ │
│  │  ├── skills: [Skill]                ← Catalog OWNS its skills             │ │
│  │  ├── loadSkills() async             ← Tell-Don't-Ask behavior             │ │
│  │  ├── updateInstallationStatus()                                           │ │
│  │  ├── addSkill(), removeSkill()                                            │ │
│  │  └── syncInstallationStatus()                                             │ │
│  │                                                                            │ │
│  │  Skill (struct)                     ← Rich domain model with behavior     │ │
│  │  Provider (enum)                    ← .claude, .codex                     │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
│                                                                                  │
│  INFRASTRUCTURE LAYER                                                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ MergedSkillRepo │  │ClonedRepoSkill  │  │ FileSystemSkill │                  │
│  │ (claude+codex)  │  │Repository       │  │ Installer       │                  │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘                  │
│           │                    │                    │                            │
│           ▼                    ▼                    ▼                            │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                  │
│  │ LocalSkillRepo  │  │ GitCLIClient    │  │ProviderPath     │                  │
│  │ (FileSystem)    │  │ (git clone/pull)│  │Resolver         │                  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                  │
│                                                                                  │
│  APP LAYER (SwiftUI)                                                             │
│  ┌────────────────────────────────────────────────────────────────────────────┐ │
│  │  Views consume domain models directly (no ViewModel)                       │ │
│  │  ┌─────────────┐  ┌────────────────────────┐  ┌─────────────────────────┐  │ │
│  │  │ Sidebar     │  │ SkillDetailView        │  │ InstallSheet            │  │ │
│  │  │ - Search    │  │ - Rendered Markdown    │  │ - Provider checkboxes   │  │ │
│  │  │ - Source    │  │ - Install Button       │  │                         │  │ │
│  │  │ - SkillList │  │                        │  │                         │  │ │
│  │  └─────────────┘  └────────────────────────┘  └─────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Layers

| Layer | Location | Purpose |
|-------|----------|---------|
| **Domain** | `Sources/Domain/` | Rich models, protocols, actors (single source of truth) |
| **Infrastructure** | `Sources/Infrastructure/` | Repositories, clients, parsers |
| **App** | `Sources/App/` | SwiftUI views consuming domain directly (no ViewModel) |

## Domain Models

### Domain Model Hierarchy

```
SkillLibrary (@Observable)
├── localCatalog: SkillsCatalog     ← Installed skills (claude + codex)
└── remoteCatalogs: [SkillsCatalog] ← GitHub skill repositories
    └── skills: [Skill]              ← Each catalog OWNS its skills
```

### SkillsCatalog

Rich domain class that owns and manages its skills. Follows Tell-Don't-Ask principle.

```swift
@Observable
@MainActor
public final class SkillsCatalog: Identifiable {
    public let id: UUID
    public let url: String?           // nil for local catalog
    public let name: String
    public let addedAt: Date

    public var skills: [Skill] = []   // Catalog OWNS its skills
    public var isLoading: Bool = false
    public var errorMessage: String?

    private let loader: SkillRepository  // Injected dependency

    // Tell-Don't-Ask: catalog manages its own skills
    public func loadSkills() async { ... }
    public func addSkill(_ skill: Skill) { ... }
    public func removeSkill(uniqueKey: String) { ... }
    public func updateInstallationStatus(for uniqueKey: String, to providers: Set<Provider>) { ... }
    public func syncInstallationStatus(with installedSkills: [Skill]) { ... }

    // Computed
    public var isLocal: Bool { url == nil }
    public var isValid: Bool { ... }
}
```

### SkillLibrary

Coordinates catalogs. Views consume this directly.

```swift
@Observable
@MainActor
public final class SkillLibrary {
    public let localCatalog: SkillsCatalog      // Installed skills
    public var remoteCatalogs: [SkillsCatalog]  // GitHub repos

    public var catalogs: [SkillsCatalog] {
        [localCatalog] + remoteCatalogs
    }

    public var filteredSkills: [Skill] {
        selectedCatalog.skills.filter { $0.matches(query: searchQuery) }
    }

    // Tells catalogs what to do (Tell-Don't-Ask)
    public func install(to providers: Set<Provider>) async { ... }
    public func uninstall(from provider: Provider) async { ... }
}
```

### Skill

Rich domain model representing an installable skill.

```swift
public struct Skill: Sendable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let version: String
    public let content: String          // Full SKILL.md content
    public let source: SkillSource
    public var installedProviders: Set<Provider>

    // Computed behavior
    public var isInstalled: Bool { !installedProviders.isEmpty }
    public var displayName: String { ... }
    public var uniqueKey: String { ... }  // For matching across catalogs
    public func isInstalledFor(_ provider: Provider) -> Bool
    public func matches(query: String) -> Bool
}
```

### Provider

Pure value object representing installation targets.

```swift
public enum Provider: String, CaseIterable, Sendable {
    case codex
    case claude

    public var displayName: String  // "Codex" or "Claude Code"
}
```

> **Note**: File system paths are resolved by `ProviderPathResolver` in the Infrastructure layer, not in the domain model.

### SkillSource

Enum representing where a skill comes from.

```swift
public enum SkillSource: Sendable, Equatable {
    case local(provider: Provider)
    case remote(repoUrl: String)

    public var isLocal: Bool
    public var isRemote: Bool
}
```

## Component Interactions

| Component | Purpose | Inputs | Outputs | Dependencies |
|-----------|---------|--------|---------|--------------|
| `Skill` | Rich domain model | name, desc, version, content | computed: isInstalled, displayName | None |
| `Provider` | Installation target enum | - | displayName | None |
| `SkillSource` | Local vs Remote enum | - | isLocal, isRemote | None |
| `SkillsCatalog` | Rich domain class owning skills | url, name, loader | skills, isLoading | SkillRepository |
| `SkillLibrary` | Coordinates catalogs | catalogs, installer | filteredSkills | SkillsCatalog, SkillInstaller |
| `SkillRepository` | Protocol for fetching skills | - | [Skill] | None |
| `MergedSkillRepository` | Combines multiple repos | repositories | merged [Skill] | SkillRepository[] |
| `LocalSkillRepository` | Read local skills | provider | [Skill] | FileSystem, PathResolver |
| `ClonedRepoSkillRepository` | Fetch from cloned GitHub repo | repo URL | [Skill] | GitCLI |
| `SkillParser` | Parse SKILL.md | fileContent | Skill metadata | None |
| `SkillInstaller` | Copy skills to provider paths | Skill, [Provider] | Skill | FileSystem, PathResolver |

## Data Flow

### Fetching Remote Skills

```
User selects remote catalog ──▶ SkillsCatalog.loadSkills()
                                          │
                                          ▼
                              ClonedRepoSkillRepository.fetchAll()
                                          │
                                          ▼
                              git clone/pull repo, parse SKILL.md files
                                          │
                                          ▼
                              catalog.skills = [Skill]
                                          │
                                          ▼
                              SwiftUI observes change, updates sidebar
```

### Installing a Skill

```
User clicks "Install" ──▶ InstallSheet shows ──▶ User selects providers
                                                          │
                                                          ▼
                              SkillLibrary.install(to: providers)
                                                          │
                                                          ▼
                              FileSystemSkillInstaller copies to paths
                                                          │
                                                          ▼
                              localCatalog.addSkill(installedSkill)
                                                          │
                                                          ▼
                              All catalogs update installation status
```

## Project Structure

```
SkillsManager/
├── Sources/
│   ├── Domain/
│   │   ├── Models/
│   │   │   ├── Skill.swift              # Rich domain model
│   │   │   ├── Provider.swift           # Value enum
│   │   │   ├── SkillSource.swift        # Local vs Remote enum
│   │   │   ├── SkillsCatalog.swift      # @Observable class owning skills
│   │   │   └── SkillEditor.swift        # Edit state
│   │   └── Protocols/
│   │       ├── SkillRepository.swift    # @Mockable protocol
│   │       ├── SkillInstaller.swift     # @Mockable protocol
│   │       └── GitCLIClient.swift       # @Mockable protocol
│   ├── Infrastructure/
│   │   ├── Repositories/
│   │   │   ├── LocalSkillRepository.swift
│   │   │   ├── ClonedRepoSkillRepository.swift
│   │   │   └── MergedSkillRepository.swift   # Combines claude + codex
│   │   ├── Local/
│   │   │   ├── LocalSkillWriter.swift
│   │   │   └── ProviderPathResolver.swift
│   │   ├── Parser/
│   │   │   └── SkillParser.swift
│   │   └── Installer/
│   │       └── FileSystemSkillInstaller.swift
│   └── App/
│       ├── SkillsManagerApp.swift       # Dependency wiring
│       ├── SkillLibrary.swift           # @Observable coordinator
│       └── Views/
│           ├── ContentView.swift
│           ├── Sidebar/
│           │   ├── SidebarView.swift
│           │   ├── SourceToggle.swift
│           │   └── SkillRowView.swift
│           ├── Detail/
│           │   └── SkillDetailView.swift
│           └── Sheets/
│               └── InstallSheet.swift
└── Tests/
    ├── DomainTests/
    │   ├── SkillTests.swift
    │   ├── SkillsCatalogTests.swift
    │   └── ProviderTests.swift
    ├── AppTests/
    │   └── SkillLibraryTests.swift
    └── InfrastructureTests/
        ├── SkillParserTests.swift
        ├── LocalSkillRepositoryTests.swift
        └── FileSystemSkillInstallerTests.swift
```

## Key Patterns

- **Rich Domain Models** - Behavior encapsulated in models (not anemic data)
- **Tell-Don't-Ask** - Objects manage their own state; callers tell objects what to do
- **Protocol-Based DI** - `@Mockable` protocols for testability
- **Chicago School TDD** - Test state changes, not interactions
- **No ViewModel Layer** - Views consume domain models directly
- **@Observable Classes** - SkillsCatalog owns skills, SkillLibrary coordinates
