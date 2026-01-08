import Foundation
import Domain

/// Result of a process execution
public struct ProcessResult: Sendable {
    public let exitCode: Int32
    public let output: String
    public let error: String

    public init(exitCode: Int32, output: String, error: String) {
        self.exitCode = exitCode
        self.output = output
        self.error = error
    }

    public var isSuccess: Bool { exitCode == 0 }
}

/// Protocol for running shell processes (for testability)
public protocol ProcessRunnerProtocol: Sendable {
    func run(executable: String, arguments: [String], workingDirectory: String?) async throws -> ProcessResult
}

/// Real process runner using Foundation's Process
public final class RealProcessRunner: ProcessRunnerProtocol, @unchecked Sendable {
    public static let shared = RealProcessRunner()

    private init() {}

    public func run(executable: String, arguments: [String], workingDirectory: String?) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable] + arguments

        if let workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
        }

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()
        process.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let error = String(data: errorData, encoding: .utf8) ?? ""

        return ProcessResult(exitCode: process.terminationStatus, output: output, error: error)
    }
}

/// Git CLI client for cloning and pulling repositories
public final class GitCLIClient: GitCLIClientProtocol, @unchecked Sendable {
    private let processRunner: ProcessRunnerProtocol
    private let fileManager: FileManagerProtocol

    public init(
        processRunner: ProcessRunnerProtocol = RealProcessRunner.shared,
        fileManager: FileManagerProtocol = RealFileManager.shared
    ) {
        self.processRunner = processRunner
        self.fileManager = fileManager
    }

    public func clone(url: String, to localPath: String) async throws {
        // Ensure URL ends with .git
        let cloneUrl = url.hasSuffix(".git") ? url : "\(url).git"

        let result = try await processRunner.run(
            executable: "git",
            arguments: ["clone", "--depth", "1", cloneUrl, localPath],
            workingDirectory: nil
        )

        if !result.isSuccess {
            throw GitCLIError.cloneFailed(result.error)
        }
    }

    public func pull(at localPath: String) async throws {
        let result = try await processRunner.run(
            executable: "git",
            arguments: ["-C", localPath, "pull", "--ff-only"],
            workingDirectory: nil
        )

        if !result.isSuccess {
            throw GitCLIError.pullFailed(result.error)
        }
    }

    public func isGitRepository(at path: String) -> Bool {
        let gitPath = (path as NSString).appendingPathComponent(".git")
        return fileManager.isDirectory(atPath: gitPath)
    }
}
