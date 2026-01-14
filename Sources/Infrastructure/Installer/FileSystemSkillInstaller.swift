import Foundation
import Domain

/// Errors during skill installation
public enum SkillInstallerError: Error, Sendable {
    case directoryCreationFailed(String)
    case fileWriteFailed(String)
    case skillNotRemote
    case networkError(Error)
}

/// Installs skills by copying files to provider directories
public final class FileSystemSkillInstaller: SkillInstaller, @unchecked Sendable {

    private let fileManager: FileManager
    private let gitHubClient: GitHubClientProtocol

    public init(
        fileManager: FileManager = .default,
        gitHubClient: GitHubClientProtocol = GitHubClient.shared
    ) {
        self.fileManager = fileManager
        self.gitHubClient = gitHubClient
    }

    public func install(_ skill: Skill, to providers: Set<Provider>) async throws -> Skill {
        var updatedSkill = skill

        for provider in providers {
            // Skip if already installed
            guard !skill.isInstalledFor(provider) else { continue }

            // Use folderName for installation path (not the full id which may have prefixes)
            let targetPath = "\(provider.skillsPath)/\(skill.folderName)"

            // Create directory
            try createDirectory(at: targetPath)

            // Write SKILL.md
            let skillMdPath = "\(targetPath)/SKILL.md"
            try writeFile(content: skill.content, to: skillMdPath)

            // If remote, fetch additional files (references, scripts, assets)
            if case .remote(let repoUrl) = skill.source {
                try await fetchAdditionalFiles(
                    skillId: skill.folderName,
                    repoUrl: repoUrl,
                    targetPath: targetPath
                )
            }

            updatedSkill = updatedSkill.installing(for: provider)
        }

        return updatedSkill
    }

    public func uninstall(_ skill: Skill, from provider: Provider) async throws -> Skill {
        let targetPath = "\(provider.skillsPath)/\(skill.folderName)"

        if fileManager.fileExists(atPath: targetPath) {
            try fileManager.removeItem(atPath: targetPath)
        }

        return skill.uninstalling(from: provider)
    }

    // MARK: - Private Helpers

    private func createDirectory(at path: String) throws {
        do {
            try fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        } catch {
            throw SkillInstallerError.directoryCreationFailed(path)
        }
    }

    private func writeFile(content: String, to path: String) throws {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            throw SkillInstallerError.fileWriteFailed(path)
        }
    }

    private func fetchAdditionalFiles(
        skillId: String,
        repoUrl: String,
        targetPath: String
    ) async throws {
        let (owner, repo) = GitHubSkillRepository.parseGitHubURL(repoUrl)

        // Try to find skill in root or skills directory
        for basePath in ["", "skills"] {
            let skillPath = basePath.isEmpty ? skillId : "\(basePath)/\(skillId)"

            do {
                let contents = try await gitHubClient.getContents(owner: owner, repo: repo, path: skillPath)

                for item in contents {
                    // Skip SKILL.md (already written)
                    if item.name == "SKILL.md" { continue }

                    if item.type == "dir" {
                        // Create subdirectory and fetch its contents
                        let subDirPath = "\(targetPath)/\(item.name)"
                        try createDirectory(at: subDirPath)
                        try await fetchDirectoryContents(
                            owner: owner,
                            repo: repo,
                            remotePath: item.path,
                            localPath: subDirPath
                        )
                    } else if item.type == "file" {
                        // Fetch and write file
                        let fileContent = try await gitHubClient.getFileContent(
                            owner: owner,
                            repo: repo,
                            path: item.path
                        )
                        let localFilePath = "\(targetPath)/\(item.name)"
                        try writeFile(content: fileContent, to: localFilePath)
                    }
                }
                return // Success, exit the loop
            } catch {
                continue // Try next base path
            }
        }
    }

    private func fetchDirectoryContents(
        owner: String,
        repo: String,
        remotePath: String,
        localPath: String
    ) async throws {
        let contents = try await gitHubClient.getContents(owner: owner, repo: repo, path: remotePath)

        for item in contents {
            if item.type == "dir" {
                let subDirPath = "\(localPath)/\(item.name)"
                try createDirectory(at: subDirPath)
                try await fetchDirectoryContents(
                    owner: owner,
                    repo: repo,
                    remotePath: item.path,
                    localPath: subDirPath
                )
            } else if item.type == "file" {
                let fileContent = try await gitHubClient.getFileContent(
                    owner: owner,
                    repo: repo,
                    path: item.path
                )
                let localFilePath = "\(localPath)/\(item.name)"
                try writeFile(content: fileContent, to: localFilePath)
            }
        }
    }
}
