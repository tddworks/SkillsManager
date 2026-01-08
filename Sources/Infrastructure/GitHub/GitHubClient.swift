import Foundation

/// Errors from GitHub API
public enum GitHubClientError: Error, Sendable {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case fileNotFound
    case rateLimited
}

/// Content item from GitHub API
public struct GitHubContent: Sendable, Decodable {
    public let name: String
    public let type: String  // "file" or "dir"
    public let path: String
    public let downloadUrl: String?

    enum CodingKeys: String, CodingKey {
        case name, type, path
        case downloadUrl = "download_url"
    }

    public init(name: String, type: String, path: String, downloadUrl: String? = nil) {
        self.name = name
        self.type = type
        self.path = path
        self.downloadUrl = downloadUrl
    }
}

/// Protocol for GitHub API client
public protocol GitHubClientProtocol: Sendable {
    /// Get contents of a directory
    func getContents(owner: String, repo: String, path: String) async throws -> [GitHubContent]

    /// Get content of a file as string
    func getFileContent(owner: String, repo: String, path: String) async throws -> String
}

/// Real GitHub API client
public final class GitHubClient: GitHubClientProtocol, @unchecked Sendable {
    public static let shared = GitHubClient()

    private let session: URLSession
    private let baseURL = "https://api.github.com"

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func getContents(owner: String, repo: String, path: String) async throws -> [GitHubContent] {
        let urlString = "\(baseURL)/repos/\(owner)/\(repo)/contents/\(path)"
        guard let url = URL(string: urlString) else {
            throw GitHubClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 404 {
                    return []
                }
                if httpResponse.statusCode == 403 {
                    throw GitHubClientError.rateLimited
                }
            }

            // GitHub returns array for directories, single object for files
            if let contents = try? JSONDecoder().decode([GitHubContent].self, from: data) {
                return contents
            } else if let single = try? JSONDecoder().decode(GitHubContent.self, from: data) {
                return [single]
            }
            return []
        } catch let error as GitHubClientError {
            throw error
        } catch {
            throw GitHubClientError.networkError(error)
        }
    }

    public func getFileContent(owner: String, repo: String, path: String) async throws -> String {
        // Use raw.githubusercontent.com for direct file content
        let urlString = "https://raw.githubusercontent.com/\(owner)/\(repo)/main/\(path)"
        guard let url = URL(string: urlString) else {
            throw GitHubClientError.invalidURL
        }

        do {
            let (data, response) = try await session.data(from: url)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                // Try master branch as fallback
                let masterURL = URL(string: "https://raw.githubusercontent.com/\(owner)/\(repo)/master/\(path)")!
                let (masterData, masterResponse) = try await session.data(from: masterURL)

                if let masterHTTP = masterResponse as? HTTPURLResponse, masterHTTP.statusCode == 404 {
                    throw GitHubClientError.fileNotFound
                }

                guard let content = String(data: masterData, encoding: .utf8) else {
                    throw GitHubClientError.decodingError(NSError(domain: "UTF8", code: 0))
                }
                return content
            }

            guard let content = String(data: data, encoding: .utf8) else {
                throw GitHubClientError.decodingError(NSError(domain: "UTF8", code: 0))
            }
            return content
        } catch let error as GitHubClientError {
            throw error
        } catch {
            throw GitHubClientError.networkError(error)
        }
    }
}
