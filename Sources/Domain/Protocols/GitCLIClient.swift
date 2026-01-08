import Foundation
import Mockable

/// Errors from Git CLI operations
public enum GitCLIError: Error, Sendable, Equatable {
    case gitNotInstalled
    case cloneFailed(String)
    case pullFailed(String)
    case invalidURL
    case directoryNotFound
}

/// Protocol for Git CLI operations
@Mockable
public protocol GitCLIClientProtocol: Sendable {
    /// Clone a repository to the specified local path
    /// - Parameters:
    ///   - url: The repository URL to clone
    ///   - localPath: The local directory path to clone into
    /// - Throws: GitCLIError if the operation fails
    func clone(url: String, to localPath: String) async throws

    /// Pull latest changes in the specified repository
    /// - Parameter localPath: The local repository path
    /// - Throws: GitCLIError if the operation fails
    func pull(at localPath: String) async throws

    /// Check if a directory is a git repository
    /// - Parameter path: The directory path to check
    /// - Returns: true if the directory is a git repository
    func isGitRepository(at path: String) -> Bool
}
