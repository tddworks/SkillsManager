# Changelog

All notable changes to Skills Manager will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - Unreleased

## [0.1.2] - 2026-01-18

### Added
- **Local Directory Skill Catalogs**: Browse and add skill catalogs directly from local folders on your Mac. Simply use the "Add Catalog" button and choose a local directory containing your skills. Perfect for developing and testing skills before publishing them.
- **Recursive Skill Discovery**: Skills Manager now finds skills in nested subdirectories. Whether your skills are organized in folders or deeply nested, they'll all be discovered and displayed with clear path labels.

### Improved
- **Better Skill Identification**: Skills are now identified by their unique path, preventing conflicts when multiple skills have the same name in different locations.
- **Clearer Display Names**: Skills from nested directories now show their relative path (e.g., "my-skill (tools/automation)") so you can easily distinguish between skills with similar names.

### Fixed
- **Skill Installation Sync**: Fixed an issue where installed skills weren't properly matched with their remote counterparts, ensuring accurate "installed" badges across all views.

## [0.1.1] - 2026-01-14

### Added
- **Settings View**: New settings panel for managing app preferences and manually checking for updates via Sparkle integration.
- **Local Skill Editing**: Edit skills directly in the app with a dedicated editor view. Changes are reflected in real-time with live preview support.
- **Skill Writer**: Save changes to local skills from within the app using the new `LocalSkillWriter` infrastructure component.

### Improved
- **Refined UI Design**: Improved layout and visual design across all views for a more polished user experience.

### Technical
- Added `SettingsView` in `Sources/App/Views/Settings/` with update check integration
- Created `SkillEditor` domain model in `Sources/Domain/Models/` for managing skill editing state
- Added `SkillEditorView` in `Sources/App/Views/Detail/` for the editing interface
- Created `LocalSkillWriter` in `Sources/Infrastructure/Local/` for persisting skill changes to disk
- Added comprehensive tests for `SkillEditor` and `LocalSkillWriter`

## [0.1.0] - 2026-01-08

### Added

- **Browse Remote Skills** - Discover skills from GitHub repositories like anthropics/skills
- **View Local Skills** - See skills installed in `~/.claude/skills` and `~/.codex/skills/public`
- **Multi-Repository Support** - Add and manage multiple GitHub skill repositories
- **Install to Multiple Providers** - Install skills to Claude Code and/or Codex
- **Provider Badges** - Visual indicators showing where each skill is installed
- **Markdown Rendering** - View skill documentation with full markdown support
- **Search & Filter** - Quickly find skills by name or description
- **Uninstall Support** - Remove skills from individual providers
- **Auto-Updates** - Sparkle integration for automatic app updates
