import Foundation

struct UsageWindow {
    let utilization: Double?
    let resetsAt: Date?

    var remainingPercent: Double? {
        guard let utilization else { return nil }
        return max(0, min(100, 100 - utilization))
    }
}

struct UsageSnapshot {
    let session: UsageWindow
    let week: UsageWindow
    let weekOpus: UsageWindow?
    let fetchedAt: Date
}

enum UsageError: Error, LocalizedError {
    case notAuthenticated
    case http(Int)
    case decoding
    case noOrganization

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: return "Not logged in — set your session cookie."
        case .http(let code): return "Request failed (HTTP \(code))."
        case .decoding: return "Unexpected response from claude.ai."
        case .noOrganization: return "No Claude organization found for this account."
        }
    }
}

// Raw wire format from https://claude.ai/api/organizations/{id}/usage
private struct RawWindow: Decodable {
    let utilization: Double?
    let resets_at: String?
}

private struct RawUsage: Decodable {
    let five_hour: RawWindow?
    let seven_day: RawWindow?
    let seven_day_opus: RawWindow?
}

private struct RawOrg: Decodable {
    let uuid: String
    let name: String?
    let capabilities: [String]?
}

enum UsageParser {
    static nonisolated(unsafe) let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static nonisolated(unsafe) let isoFormatterNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }
        return isoFormatter.date(from: s) ?? isoFormatterNoFraction.date(from: s)
    }

    static func parseOrgId(from data: Data) throws -> String {
        let orgs = try JSONDecoder().decode([RawOrg].self, from: data)
        guard !orgs.isEmpty else { throw UsageError.noOrganization }
        let chatOrg = orgs.first { $0.capabilities?.contains("chat") == true } ?? orgs[0]
        return chatOrg.uuid
    }

    static func parseUsage(from data: Data) throws -> UsageSnapshot {
        let raw: RawUsage
        do {
            raw = try JSONDecoder().decode(RawUsage.self, from: data)
        } catch {
            throw UsageError.decoding
        }
        func window(_ r: RawWindow?) -> UsageWindow {
            UsageWindow(utilization: r?.utilization, resetsAt: parseDate(r?.resets_at))
        }
        return UsageSnapshot(
            session: window(raw.five_hour),
            week: window(raw.seven_day),
            weekOpus: raw.seven_day_opus.map(window),
            fetchedAt: Date()
        )
    }
}
