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

Enum representing installation targets.

```swift
public enum Provider: String, CaseIterable, Sendable {
    case codex
    case claude

    public var displayName: String
    public var skillsPath: String  // ~/.codex/skills/public or ~/.claude/skills
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
| `Provider` | Installation target enum | - | path, displayName | None |
| `SkillSource` | Local vs Remote enum | - | displayName | None |
| `SkillRepository` | Protocol for fetching skills | source, query | [Skill] | None |
| `GitHubSkillRepository` | Fetch from GitHub | repo URL | [Skill] | NetworkClient |
| `LocalSkillRepository` | Read local skills | provider paths | [Skill] | FileSystem |
| `SkillParser` | Parse SKILL.md | fileContent | Skill metadata | None |
| `SkillInstaller` | Copy skills to provider paths | Skill, [Provider] | Result | FileSystem |
| `SkillManager` | Orchestrates all operations | - | skills state | Repositories, Installer |

## Data Flow

### Fetching Remote Skills

```
User selects "Remote" ──▶ SkillManager.fetchRemote() ──▶ GitHubSkillRepository
                                       │
                                       ▼
                              Parse SKILL.md files
                                       │
                                       ▼
                              Return [Skill] to AppState
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
│   │   │   └── SkillSource.swift
│   │   ├── Protocols/
│   │   │   ├── SkillRepository.swift
│   │   │   └── SkillInstaller.swift
│   │   └── Services/
│   │       └── SkillManager.swift
│   ├── Infrastructure/
│   │   ├── GitHub/
│   │   │   └── GitHubSkillRepository.swift
│   │   ├── Local/
│   │   │   └── LocalSkillRepository.swift
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
│       └── AppState.swift
└── Tests/
    ├── DomainTests/
    │   ├── SkillTests.swift
    │   └── ProviderTests.swift
    └── InfrastructureTests/
        ├── SkillParserTests.swift
        └── LocalSkillRepositoryTests.swift
```

## Key Patterns

- **Rich Domain Models** - Behavior encapsulated in models (not anemic data)
- **Protocol-Based DI** - `@Mockable` protocols for testability
- **Chicago School TDD** - Test state changes, not interactions
- **No ViewModel Layer** - Views consume domain models directly
- **Actors for Thread Safety** - SkillManager as actor for concurrent operations
