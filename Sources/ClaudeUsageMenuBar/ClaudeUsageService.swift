import Foundation

@MainActor
final class ClaudeUsageService {
    private var cachedOrgId: String?
    private let session = URLSession(configuration: .ephemeral)

    // Mimics a real browser request; claude.ai's edge rejects requests that
    // look like bare scripted clients.
    private static let userAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    private func request(_ url: URL, cookie: String) -> URLRequest {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("sessionKey=\(cookie)", forHTTPHeaderField: "Cookie")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        return req
    }

    private func fetch(_ url: URL, cookie: String) async throws -> Data {
        let (data, response) = try await session.data(for: request(url, cookie: cookie))
        guard let http = response as? HTTPURLResponse else { throw UsageError.decoding }
        if http.statusCode == 401 || http.statusCode == 403 {
            throw UsageError.notAuthenticated
        }
        guard (200..<300).contains(http.statusCode) else {
            throw UsageError.http(http.statusCode)
        }
        return data
    }

    private func resolveOrgId(cookie: String, forceRefresh: Bool) async throws -> String {
        if !forceRefresh, let cachedOrgId { return cachedOrgId }
        let data = try await fetch(URL(string: "https://claude.ai/api/organizations")!, cookie: cookie)
        let orgId = try UsageParser.parseOrgId(from: data)
        cachedOrgId = orgId
        return orgId
    }

    func fetchUsage() async throws -> UsageSnapshot {
        guard let cookie = KeychainStore.load(), !cookie.isEmpty else {
            throw UsageError.notAuthenticated
        }

        do {
            let orgId = try await resolveOrgId(cookie: cookie, forceRefresh: false)
            let data = try await fetch(
                URL(string: "https://claude.ai/api/organizations/\(orgId)/usage")!,
                cookie: cookie
            )
            return try UsageParser.parseUsage(from: data)
        } catch UsageError.http, UsageError.decoding {
            // Org may have gone stale (e.g. switched teams); retry once with a fresh lookup.
            let orgId = try await resolveOrgId(cookie: cookie, forceRefresh: true)
            let data = try await fetch(
                URL(string: "https://claude.ai/api/organizations/\(orgId)/usage")!,
                cookie: cookie
            )
            return try UsageParser.parseUsage(from: data)
        }
    }
}
