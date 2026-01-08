import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite
struct GitCLIClientTests {

    // MARK: - Clone Tests

    @Test func `clone executes git clone command`() async throws {
        let mockRunner = MockProcessRunner()
        mockRunner.stubSuccess(for: "git", arguments: ["clone", "--depth", "1", "https://github.com/owner/repo.git", "/tmp/cache/owner_repo"])

        let client = GitCLIClient(processRunner: mockRunner)

        try await client.clone(url: "https://github.com/owner/repo", to: "/tmp/cache/owner_repo")

        #expect(mockRunner.executedCommands.count == 1)
        let cmd = mockRunner.executedCommands[0]
        #expect(cmd.executable == "git")
        #expect(cmd.arguments.contains("clone"))
        #expect(cmd.arguments.contains("https://github.com/owner/repo.git"))
    }

    @Test func `clone appends .git suffix if missing`() async throws {
        let mockRunner = MockProcessRunner()
        mockRunner.stubSuccess(for: "git", arguments: ["clone", "--depth", "1", "https://github.com/owner/repo.git", "/tmp/test"])

        let client = GitCLIClient(processRunner: mockRunner)

        try await client.clone(url: "https://github.com/owner/repo", to: "/tmp/test")

        let cmd = mockRunner.executedCommands[0]
        #expect(cmd.arguments.contains("https://github.com/owner/repo.git"))
    }

    @Test func `clone preserves .git suffix if present`() async throws {
        let mockRunner = MockProcessRunner()
        mockRunner.stubSuccess(for: "git", arguments: ["clone", "--depth", "1", "https://github.com/owner/repo.git", "/tmp/test"])

        let client = GitCLIClient(processRunner: mockRunner)

        try await client.clone(url: "https://github.com/owner/repo.git", to: "/tmp/test")

        let cmd = mockRunner.executedCommands[0]
        #expect(cmd.arguments.contains("https://github.com/owner/repo.git"))
    }

    @Test func `clone throws error when git fails`() async throws {
        let mockRunner = MockProcessRunner()
        mockRunner.stubFailure(for: "git", errorMessage: "fatal: repository not found")

        let client = GitCLIClient(processRunner: mockRunner)

        await #expect(throws: GitCLIError.self) {
            try await client.clone(url: "https://github.com/owner/nonexistent", to: "/tmp/test")
        }
    }

    // MARK: - Pull Tests

    @Test func `pull executes git pull in directory`() async throws {
        let mockRunner = MockProcessRunner()
        mockRunner.stubSuccess(for: "git", arguments: ["-C", "/tmp/cache/owner_repo", "pull", "--ff-only"])

        let client = GitCLIClient(processRunner: mockRunner)

        try await client.pull(at: "/tmp/cache/owner_repo")

        #expect(mockRunner.executedCommands.count == 1)
        let cmd = mockRunner.executedCommands[0]
        #expect(cmd.executable == "git")
        #expect(cmd.arguments.contains("pull"))
        #expect(cmd.arguments.contains("-C"))
    }

    @Test func `pull throws error when git fails`() async throws {
        let mockRunner = MockProcessRunner()
        mockRunner.stubFailure(for: "git", errorMessage: "error: cannot pull with rebase")

        let client = GitCLIClient(processRunner: mockRunner)

        await #expect(throws: GitCLIError.self) {
            try await client.pull(at: "/tmp/cache/test")
        }
    }

    // MARK: - isGitRepository Tests

    @Test func `isGitRepository returns true when .git directory exists`() {
        let mockFileManager = StubFileManager()
        mockFileManager.stubIsDirectory(at: "/tmp/repo/.git", value: true)

        let client = GitCLIClient(fileManager: mockFileManager)

        #expect(client.isGitRepository(at: "/tmp/repo") == true)
    }

    @Test func `isGitRepository returns false when .git directory missing`() {
        let mockFileManager = StubFileManager()
        mockFileManager.stubIsDirectory(at: "/tmp/repo/.git", value: false)

        let client = GitCLIClient(fileManager: mockFileManager)

        #expect(client.isGitRepository(at: "/tmp/repo") == false)
    }
}

// MARK: - Mock Process Runner

struct ExecutedCommand: Sendable {
    let executable: String
    let arguments: [String]
}

final class MockProcessRunner: ProcessRunnerProtocol, @unchecked Sendable {
    var executedCommands: [ExecutedCommand] = []
    private var successStubs: Set<String> = []
    private var failureStubs: [String: String] = [:]

    func stubSuccess(for executable: String, arguments: [String]) {
        let key = "\(executable):\(arguments.joined(separator: ","))"
        successStubs.insert(key)
    }

    func stubFailure(for executable: String, errorMessage: String) {
        failureStubs[executable] = errorMessage
    }

    func run(executable: String, arguments: [String], workingDirectory: String?) async throws -> ProcessResult {
        executedCommands.append(ExecutedCommand(executable: executable, arguments: arguments))

        if let errorMessage = failureStubs[executable] {
            return ProcessResult(exitCode: 1, output: "", error: errorMessage)
        }

        return ProcessResult(exitCode: 0, output: "success", error: "")
    }
}

// MARK: - Stub File Manager for GitCLI Tests

final class StubFileManager: FileManagerProtocol, @unchecked Sendable {
    private var directoryStubs: [String: Bool] = [:]
    private var fileExistsStubs: [String: Bool] = [:]
    private var contentsStubs: [String: Data] = [:]
    private var directoryContentsStubs: [String: [String]] = [:]

    func stubIsDirectory(at path: String, value: Bool) {
        directoryStubs[path] = value
    }

    func stubFileExists(at path: String, value: Bool) {
        fileExistsStubs[path] = value
    }

    func isDirectory(atPath path: String) -> Bool {
        directoryStubs[path] ?? false
    }

    func fileExists(atPath path: String) -> Bool {
        fileExistsStubs[path] ?? directoryStubs[path] ?? false
    }

    func contentsOfDirectory(atPath path: String) throws -> [String] {
        directoryContentsStubs[path] ?? []
    }

    func contents(atPath path: String) -> Data? {
        contentsStubs[path]
    }

    func removeItem(atPath path: String) throws {
        // Not needed for these tests
    }
}
