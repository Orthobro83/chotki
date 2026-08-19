import Foundation
#if canImport(FoundationNetworking)
// swift-corelibs-foundation splits networking out on Linux and Windows.
import FoundationNetworking
#endif

/// The single seam between this app and the network.
///
/// Everything above it is testable offline, which is why the whole liturgical
/// suite runs against recorded fixtures and CI never makes a request.
public protocol HTTPFetching: Sendable {
    func data(from url: URL) async throws -> Data
}

public enum HTTPError: Error, Sendable {
    case status(Int)
    case transport(String)
}

public struct URLSessionFetcher: HTTPFetching {
    private let timeout: TimeInterval

    public init(timeout: TimeInterval = 20) {
        self.timeout = timeout
    }

    public func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("chotki", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw HTTPError.status(http.statusCode)
        }
        return data
    }
}
