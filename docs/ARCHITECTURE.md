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
│  EXTERNAL                    INFRASTRUCTURE                 DOMAIN               │
│  ┌─────────────────┐        ┌─────────────────┐           ┌─────────────────┐   │
│  │  GitHub API     │───────▶│ GitHubSkillRepo │──────────▶│  Skill          │   │
│  │  (REST/Clone)   │        │ (implements     │           │  (name, desc,   │   │
│  └─────────────────┘        │  SkillRepository)│           │   version, etc) │   │
│                             └─────────────────┘           └─────────────────┘   │
│  ┌─────────────────┐        ┌─────────────────┐                   │             │
│  │  FileSystem     │───────▶│ LocalSkillRepo  │──────────────────▶│             │
│  │  (~/.claude,    │        │ (implements     │                   │             │
│  │   ~/.codex)     │        │  SkillRepository)│                   ▼             │
│  └─────────────────┘        └─────────────────┘           ┌─────────────────┐   │
│                                     │                     │  SkillManager   │   │
│                                     │                     │  (actor)        │   │
│                                     └────────────────────▶│  - fetch        │   │
│                                                           │  - install      │   │
│  ┌─────────────────┐        ┌─────────────────┐           │  - uninstall    │   │
│  │  SKILL.md       │───────▶│ SkillParser     │──────────▶│                 │   │
│  │  (YAML+Markdown)│        │                 │           └─────────────────┘   │
│  └─────────────────┘        └─────────────────┘                   │             │
│                                                                   │             │
│                                                                   ▼             │
│                             ┌───────────────────────────────────────────────┐  │
│                             │  APP LAYER (SwiftUI)                           │  │
│                             │  ┌─────────────┐  ┌────────────────────────┐   │  │
│                             │  │ Sidebar     │  │ SkillDetailView        │   │  │
│                             │  │ - Search    │  │ - Rendered Markdown    │   │  │
│                             │  │ - Source    │  │ - Install Button       │   │  │
│                             │  │ - SkillList │  │                        │   │  │
│                             │  └─────────────┘  └────────────────────────┘   │  │
│                             │                                                │  │
│                             │  ┌────────────────────────────────────────┐    │  │
│                             │  │ InstallSheet (modal)                   │    │  │
│                             │  │ - Provider checkboxes                  │    │  │
│                             │  └────────────────────────────────────────┘    │  │
│                             └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Layers

| Layer | Location | Purpose |
|-------|----------|---------|
| **Domain** | `Sources/Domain/` | Rich models, protocols, actors (single source of truth) |
| **Infrastructure** | `Sources/Infrastructure/` | Repositories, clients, parsers |
| **App** | `Sources/App/` | SwiftUI views consuming domain directly (no ViewModel) |

## Domain Models

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
    public var referenceCount: Int
    public var scriptCount: Int

    // Computed behavior
    public var isInstalled: Bool
    public var hasReferences: Bool
    public var hasScripts: Bool
    public func isInstalledFor(_ provider: Provider) -> Bool
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

### SkillsCatalog

Represents a remote skills catalog (GitHub repository containing skills).

```swift
public struct SkillsCatalog: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let url: String
    public let name: String
    public let addedAt: Date

    public var isValid: Bool  // Validates GitHub URL format
}
```

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
| `Skill` | Rich domain model | name, desc, version, content | computed: isInstalled, providers | None |
| `Provider` | Installation target enum | - | displayName | None |
| `SkillSource` | Local vs Remote enum | - | displayName | None |
| `SkillsCatalog` | Remote skills catalog | url, name | isValid | None |
| `SkillRepository` | Protocol for fetching skills | source, query | [Skill] | None |
| `ProviderPathResolver` | Resolve provider paths | Provider | path string | FileSystem |
| `GitHubSkillRepository` | Fetch from GitHub | repo URL | [Skill] | NetworkClient |
| `LocalSkillRepository` | Read local skills | provider | [Skill] | FileSystem, PathResolver |
| `SkillParser` | Parse SKILL.md | fileContent | Skill metadata | None |
| `SkillInstaller` | Copy skills to provider paths | Skill, [Provider] | Result | FileSystem, PathResolver |
| `SkillLibrary` | Orchestrates all operations | - | skills state | Repositories, Installer |

## Data Flow

### Fetching Remote Skills

```
User selects "Remote" ──▶ SkillManager.fetchRemote() ──▶ GitHubSkillRepository
                                       │
                                       ▼
                              Parse SKILL.md files
                                       │
                                       ▼
                              Return [Skill] to SkillLibrary
                                       │
                                       ▼
                              SwiftUI updates sidebar
```

### Installing a Skill

```
User clicks "Install" ──▶ InstallSheet shows ──▶ User selects providers
                                                          │
                                                          ▼
                              SkillManager.install(skill, providers)
                                                          │
                                                          ▼
                              FileSystemSkillInstaller copies to paths
                                                          │
                                                          ▼
                              Refresh local skills, update badges
```

## Project Structure

```
SkillsManager/
├── Sources/
│   ├── Domain/
│   │   ├── Models/
│   │   │   ├── Skill.swift
│   │   │   ├── Provider.swift
│   │   │   ├── SkillSource.swift
│   │   │   ├── SkillsCatalog.swift
│   │   │   └── SkillEditor.swift
│   │   └── Protocols/
│   │       ├── SkillRepository.swift
│   │       └── GitCLIClient.swift
│   ├── Infrastructure/
│   │   ├── GitHub/
│   │   │   └── GitHubSkillRepository.swift
│   │   ├── Local/
│   │   │   ├── LocalSkillRepository.swift
│   │   │   ├── LocalSkillWriter.swift
│   │   │   └── ProviderPathResolver.swift
│   │   ├── Parser/
│   │   │   └── SkillParser.swift
│   │   └── Installer/
│   │       └── FileSystemSkillInstaller.swift
│   └── App/
│       ├── SkillsManagerApp.swift
│       ├── Views/
│       │   ├── ContentView.swift
│       │   ├── Sidebar/
│       │   │   ├── SidebarView.swift
│       │   │   ├── SourceToggle.swift
│       │   │   └── SkillRowView.swift
│       │   ├── Detail/
│       │   │   └── SkillDetailView.swift
│       │   └── Sheets/
│       │       └── InstallSheet.swift
│       └── SkillLibrary.swift
└── Tests/
    ├── DomainTests/
    │   ├── SkillTests.swift
    │   ├── ProviderTests.swift
    │   └── SkillEditorTests.swift
    └── InfrastructureTests/
        ├── SkillParserTests.swift
        ├── LocalSkillRepositoryTests.swift
        ├── ProviderPathResolverTests.swift
        └── FileSystemSkillInstallerTests.swift
```

## Key Patterns

- **Rich Domain Models** - Behavior encapsulated in models (not anemic data)
- **Protocol-Based DI** - `@Mockable` protocols for testability
- **Chicago School TDD** - Test state changes, not interactions
- **No ViewModel Layer** - Views consume domain models directly
- **Actors for Thread Safety** - SkillManager as actor for concurrent operations
