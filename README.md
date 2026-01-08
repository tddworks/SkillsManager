# Skills Manager

[![Build](https://github.com/tddworks/SkillsManager/actions/workflows/build.yml/badge.svg)](https://github.com/tddworks/SkillsManager/actions/workflows/build.yml)
[![Tests](https://github.com/tddworks/SkillsManager/actions/workflows/tests.yml/badge.svg)](https://github.com/tddworks/SkillsManager/actions/workflows/tests.yml)
[![codecov](https://codecov.io/gh/tddworks/SkillsManager/graph/badge.svg)](https://codecov.io/gh/tddworks/SkillsManager)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2015-blue.svg)](https://developer.apple.com)

A macOS application for discovering, browsing, and installing skills for AI coding assistants. Manage skills for Claude Code and Codex from GitHub repositories or your local filesystem.

## Features

- **Browse Remote Skills** - Discover skills from GitHub repositories like [anthropics/skills](https://github.com/anthropics/skills)
- **View Local Skills** - See skills already installed on your system
- **Multi-Repository Support** - Add and manage multiple GitHub skill repositories
- **Install to Multiple Providers** - Install skills to Claude Code (`~/.claude/skills`) and/or Codex (`~/.codex/skills/public`)
- **Provider Badges** - Visual indicators showing where each skill is installed
- **Markdown Rendering** - View skill documentation with full markdown support
- **Search & Filter** - Quickly find skills by name or description
- **Uninstall Support** - Remove skills from individual providers

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

Launch the app to browse available skills. Use the source dropdown to switch between:

- **Local** - Skills installed on your system
- **Remote repositories** - Skills from configured GitHub repos

Select a skill to view its details and documentation. Click "Install" to install a skill to your chosen providers.

### Adding Repositories

1. Click the source dropdown
2. Select "Add Repository..."
3. Enter a GitHub URL (e.g., `https://github.com/anthropics/skills`)
4. Click "Add"

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

Skills Manager uses a **layered architecture** following rich domain model patterns:

| Layer | Location | Purpose |
|-------|----------|---------|
| **Domain** | `Sources/Domain/` | Rich models, protocols, actors (single source of truth) |
| **Infrastructure** | `Sources/Infrastructure/` | Repositories, clients, parsers, installers |
| **App** | `Sources/App/` | SwiftUI views consuming domain directly (no ViewModel) |

### Key Design Decisions

- **Rich Domain Models** - Behavior encapsulated in models (not anemic data)
- **Protocol-Based DI** - `@Mockable` protocols for testability
- **Chicago School TDD** - Test state changes, not interactions
- **No ViewModel Layer** - Views consume domain models directly
- **Actors for Thread Safety** - Concurrent operations handled safely

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

The script will:
1. Generate a public/private EdDSA key pair
2. Optionally update `Info.plist` with the public key
3. Display the private key to add as a GitHub secret

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

## Project Structure

```
SkillsManager/
├── Sources/
│   ├── Domain/
│   │   ├── Models/          # Skill, Provider, SkillSource, SkillsRepo
│   │   └── Protocols/       # SkillRepository, SkillInstaller
│   ├── Infrastructure/
│   │   ├── GitHub/          # GitHubClient, GitHubSkillRepository
│   │   ├── Local/           # LocalSkillRepository
│   │   ├── Parser/          # SkillParser (YAML frontmatter)
│   │   └── Installer/       # FileSystemSkillInstaller
│   └── App/
│       ├── Views/           # SwiftUI views
│       └── AppState.swift   # Observable app state
├── Tests/
│   ├── DomainTests/
│   └── InfrastructureTests/
├── Project.swift            # Tuist configuration
└── Package.swift            # SPM configuration
```

## License

MIT License - see [LICENSE](LICENSE) for details.
