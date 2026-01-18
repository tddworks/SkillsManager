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
    private let pathResolver: ProviderPathResolver
    private let cacheDirectory: String

    public init(
        fileManager: FileManager = .default,
        gitHubClient: GitHubClientProtocol = GitHubClient.shared,
        pathResolver: ProviderPathResolver = ProviderPathResolver(),
        cacheDirectory: String = ClonedRepoSkillRepository.defaultCacheDirectory
    ) {
        self.fileManager = fileManager
        self.gitHubClient = gitHubClient
        self.pathResolver = pathResolver
        self.cacheDirectory = cacheDirectory
    }

    public func install(_ skill: Skill, to providers: Set<Provider>) async throws -> Skill {
        var updatedSkill = skill

        for provider in providers {
            // Skip if already installed
            guard !skill.isInstalledFor(provider) else { continue }

            // skill.id is the folder name used for installation path
            let targetPath = "\(pathResolver.skillsPath(for: provider))/\(skill.id)"

            // Create directory
            try createDirectory(at: targetPath)

            // Write SKILL.md
            let skillMdPath = "\(targetPath)/SKILL.md"
            try writeFile(content: skill.content, to: skillMdPath)

            // Write .skill-id metadata to track which variant was installed
            // Store uniqueKey (repoPath/id) to distinguish variants
            let metadataPath = "\(targetPath)/.skill-id"
            try writeFile(content: skill.uniqueKey, to: metadataPath)

            // If remote, copy additional files (references, scripts, assets)
            if case .remote(let repoUrl) = skill.source {
                try await copyAdditionalFiles(
                    skillId: skill.id,
                    repoUrl: repoUrl,
                    repoPath: skill.repoPath,
                    targetPath: targetPath
                )
            }

            updatedSkill = updatedSkill.installing(for: provider)
        }

        return updatedSkill
    }

    public func uninstall(_ skill: Skill, from provider: Provider) async throws -> Skill {
        let targetPath = "\(pathResolver.skillsPath(for: provider))/\(skill.id)"

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

    /// Copy additional files from local clone or fetch from GitHub API
    private func copyAdditionalFiles(
        skillId: String,
        repoUrl: String,
        repoPath: String?,
        targetPath: String
    ) async throws {
        let (owner, repo) = ClonedRepoSkillRepository.parseGitHubURL(repoUrl)

        // First, try to copy from local clone if it exists
        let clonedRepoPath = "\(cacheDirectory)/\(owner)_\(repo)"
        if fileManager.fileExists(atPath: clonedRepoPath) {
            // Use repoPath if available, otherwise search common locations
            let skillSourcePath: String
            if let repoPath = repoPath {
                skillSourcePath = "\(clonedRepoPath)/\(repoPath)/\(skillId)"
            } else {
                // Fall back to searching common locations
                let possiblePaths = [
                    "\(clonedRepoPath)/\(skillId)",
                    "\(clonedRepoPath)/skills/\(skillId)"
                ]
                skillSourcePath = possiblePaths.first { fileManager.fileExists(atPath: $0) } ?? ""
            }

            if !skillSourcePath.isEmpty && fileManager.fileExists(atPath: skillSourcePath) {
                try copyDirectoryContents(from: skillSourcePath, to: targetPath)
                return
            }
        }

        // Fall back to GitHub API
        try await fetchAdditionalFilesFromGitHub(
            skillId: skillId,
            repoUrl: repoUrl,
            targetPath: targetPath
        )
    }

    /// Copy directory contents from local clone (excluding SKILL.md)
    private func copyDirectoryContents(from sourcePath: String, to targetPath: String) throws {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: sourcePath) else {
            return
        }

        for item in contents {
            // Skip SKILL.md (already written) and .skill-id (we write our own)
            if item == "SKILL.md" || item == ".skill-id" { continue }

            let sourceItemPath = "\(sourcePath)/\(item)"
            let targetItemPath = "\(targetPath)/\(item)"

            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: sourceItemPath, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                try createDirectory(at: targetItemPath)
                try copyDirectoryContents(from: sourceItemPath, to: targetItemPath)
            } else {
                try fileManager.copyItem(atPath: sourceItemPath, toPath: targetItemPath)
            }
        }
    }

    /// Fetch additional files from GitHub API (fallback when no local clone)
    private func fetchAdditionalFilesFromGitHub(
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
