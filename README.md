# Skills Manager

[![Build](https://github.com/tddworks/SkillsManager/actions/workflows/build.yml/badge.svg)](https://github.com/tddworks/SkillsManager/actions/workflows/build.yml)
[![Tests](https://github.com/tddworks/SkillsManager/actions/workflows/tests.yml/badge.svg)](https://github.com/tddworks/SkillsManager/actions/workflows/tests.yml)
[![codecov](https://codecov.io/gh/tddworks/SkillsManager/graph/badge.svg)](https://codecov.io/gh/tddworks/SkillsManager)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2015-blue.svg)](https://developer.apple.com)

A macOS application for discovering, browsing, installing, and tagging skills for AI coding assistants. Manage skills for Claude Code and Codex from GitHub repositories or your local filesystem.

<p align="center">
  <img src="docs/screenshots/skillmanager.png" alt="Skills Manager" width="700"/>
</p>
<p align="center">
  <em>Browse, install, and tag skills for Claude Code and Codex</em>
</p>

## Features

- **Browse Remote Skills** - Discover skills from GitHub repositories like [anthropics/skills](https://github.com/anthropics/skills)
- **Chinese Discovery** - Chinese users can also discover and install skills via [Skills宝](https://skilery.com)
- **Local Directory Support** - Add skills from any local directory via `file://` URLs
- **View Installed Skills** - Filter by provider (Claude Code, Codex, or all)
- **Multi-Repository Support** - Add and manage multiple GitHub skill catalogs
- **Install to Multiple Providers** - Install skills to Claude Code and/or Codex
- **Global Custom Tags** - Create tags to organize skills across all catalogs
- **Tag-Based Filtering** - Filter skills by SKILL.md tags or your custom tags
- **Markdown Rendering** - View skill documentation with full markdown support
- **Split-Pane Editor** - Edit local skills with live markdown preview
- **Uninstall / Unlink** - Unlink from a provider or fully uninstall
- **Search** - Find skills by name, description, or tags
- **Grid / List View** - Toggle between card grid and compact list views

## Providers

| Provider | Skills Path | Description |
|----------|-------------|-------------|
| Claude Code | `~/.claude/skills` | Anthropic's AI coding assistant |
| Codex | `~/.codex/skills/public` | OpenAI's code generation tool |

## Requirements

- macOS 15+
- Swift 6.0+

## Installation

### Download (Recommended)

Download the latest release from [GitHub Releases](https://github.com/tddworks/SkillsManager/releases/latest).

### Build from Source

```bash
git clone https://github.com/tddworks/SkillsManager.git
cd SkillsManager
swift build -c release
```

## Usage

Launch the app to browse available skills. The three-column layout shows:

- **Sidebar** - Navigate between installed skills, provider filters, and remote catalogs
- **Main Content** - Browse skills in grid or list view with tag-based filtering
- **Detail Panel** - View skill info, manage tags, install/uninstall

### Adding Catalogs

1. Click "+ Add Catalog" in the sidebar footer
2. Choose GitHub Repository or Local Directory
3. Enter a URL (e.g., `https://github.com/anthropics/skills`) or browse for a folder
4. Click "Add Catalog"

### Tagging Skills

1. Select a skill to open the detail panel
2. In the Tags section, click "+ add" to create a new tag
3. Tags are global labels - once created, they appear in the filter bar across all views
4. Purple tags come from SKILL.md frontmatter; cyan tags are your custom tags

## Development

### Command Line (Swift Package Manager)

```bash
# Build the project
swift build

# Run all tests
swift test

# Run the app
swift run SkillsManager
```

### Xcode (with SwiftUI Previews)

The project uses [Tuist](https://tuist.io) to generate Xcode projects with SwiftUI preview support.

```bash
# Install Tuist (if not installed)
brew install tuist

# Generate Xcode project
tuist generate

# Open in Xcode
open SkillsManager.xcworkspace

# Run tests via Tuist
tuist test
```

## Architecture

> **Full documentation:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)

Skills Manager uses a **layered architecture** with rich domain models and SwiftUI Atomic Design:

```
SkillLibrary (@Observable, coordinator)
├── localCatalog: SkillsCatalog     ← Installed skills (claude + codex)
├── remoteCatalogs: [SkillsCatalog] ← GitHub repos or local directories
│   └── skills: [Skill]             ← Each catalog OWNS its skills
└── skillTags: SkillTags            ← Global tag management aggregate
```

| Layer | Location | Purpose |
|-------|----------|---------|
| **Domain** | `Sources/Domain/` | Rich models (Skill, SkillsCatalog, SkillTags), protocols |
| **Infrastructure** | `Sources/Infrastructure/` | Repositories, parsers, persistence |
| **App** | `Sources/App/` | SwiftUI views (Atomic Design), coordinator, design tokens |

### Key Design Decisions

- **Rich Domain Models** - Behavior encapsulated in models (not anemic data)
- **Domain Aggregates** - SkillTags is an @Observable aggregate managing the tags feature
- **Tell-Don't-Ask** - Objects manage their own state; callers tell objects what to do
- **Protocol-Based DI** - `@Mockable` protocols for testability
- **Chicago School TDD** - Test state changes, not interactions
- **No ViewModel Layer** - Views consume domain models directly
- **SwiftUI Atomic Design** - Atoms, Molecules, Organisms, Pages
- **Design Tokens** - DS enum mirrors prototype CSS for consistent dark theme

## Project Structure

```
SkillsManager/
├── Sources/
│   ├── Domain/
│   │   ├── Models/          # Skill, SkillsCatalog, SkillTags, Provider, SkillEditor
│   │   └── Protocols/       # SkillRepository, UserTagRepository, SkillInstaller (@Mockable)
│   ├── Infrastructure/
│   │   ├── Repositories/    # MergedSkillRepository
│   │   ├── Local/           # LocalSkillRepository, LocalDirectorySkillRepository
│   │   ├── Git/             # ClonedRepoSkillRepository
│   │   ├── Parser/          # SkillParser (YAML frontmatter)
│   │   ├── Installer/       # FileSystemSkillInstaller
│   │   └── UserDefaultsUserTagRepository.swift
│   └── App/
│       ├── SkillLibrary.swift   # @Observable coordinator
│       ├── Theme/               # DesignTokens (DS enum)
│       └── Views/
│           ├── ContentView.swift     # 3-column root layout
│           ├── Sidebar/              # SidebarView, SkillCardView, SkillRowView
│           ├── Detail/               # SkillDetailView, SkillEditorView, MarkdownView
│           ├── Atoms/                # TagChip, EditableTagsView, FlowLayout, etc.
│           ├── Molecules/            # CategoryTabsBar, StatsBar, ProviderLinkCard
│           └── Sheets/               # AddCatalogSheet, InstallSheet, UninstallSheet
├── Tests/
│   ├── DomainTests/         # SkillTests, SkillTagsTests, SkillEditorTests
│   ├── AppTests/            # SkillLibraryTests, SkillLibraryUserTagTests
│   └── InfrastructureTests/ # Parser, repository, installer tests
├── Project.swift            # Tuist configuration
└── Package.swift            # SPM configuration
```

## Release & Auto-Updates

The project includes CI/CD workflows and Sparkle integration for automatic updates.

### Setup Sparkle Keys

Generate EdDSA keys for signing updates:

```bash
# Build first to get Sparkle tools
swift build

# Generate key pair
./scripts/sparkle-setup.sh
```

### Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `APPLE_CERTIFICATE_P12` | Base64-encoded Developer ID certificate |
| `APPLE_CERTIFICATE_PASSWORD` | Certificate password |
| `APP_STORE_CONNECT_API_KEY_P8` | Base64-encoded App Store Connect API key |
| `APP_STORE_CONNECT_KEY_ID` | API key ID |
| `APP_STORE_CONNECT_ISSUER_ID` | Team issuer ID |
| `SPARKLE_EDDSA_PRIVATE_KEY` | EdDSA private key for signing updates |
| `CODECOV_TOKEN` | (Optional) Codecov upload token |

### Creating a Release

Releases are triggered by:
- Pushing a version tag: `git tag v1.0.0 && git push --tags`
- Manual workflow dispatch with version input

The release workflow will:
1. Build universal binary (arm64 + x86_64)
2. Sign with Developer ID
3. Notarize with Apple
4. Create DMG and ZIP artifacts
5. Publish GitHub Release
6. Update Sparkle appcast for auto-updates

## License

MIT License - see [LICENSE](LICENSE) for details.
