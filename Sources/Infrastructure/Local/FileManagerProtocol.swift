import Foundation
import Mockable

/// Protocol abstracting FileManager for testing
@Mockable
public protocol FileManagerProtocol: Sendable {
    func fileExists(atPath path: String) -> Bool
    func contentsOfDirectory(atPath path: String) throws -> [String]
    func contents(atPath path: String) -> Data?
    func isDirectory(atPath path: String) -> Bool
    func removeItem(atPath path: String) throws
}

/// Default implementation using real FileManager
public final class RealFileManager: FileManagerProtocol, @unchecked Sendable {
    public static let shared = RealFileManager()

    private init() {}

    public func fileExists(atPath path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    public func contentsOfDirectory(atPath path: String) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: path)
    }

    public func contents(atPath path: String) -> Data? {
        FileManager.default.contents(atPath: path)
    }

    public func isDirectory(atPath path: String) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    public func removeItem(atPath path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }
}
