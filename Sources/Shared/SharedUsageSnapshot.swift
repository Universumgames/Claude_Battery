import Foundation

/// Small, codable slice of `UsageSnapshot` written by the main app into the shared
/// App Group container so the widget extension (a separate, sandboxed process) can
/// read the latest fetch without duplicating the claude.ai auth/network logic.
struct SharedUsageSnapshot: Codable {
    let sessionRemainingPercent: Double?
    let sessionResetsAt: Date?
    let weekRemainingPercent: Double?
    let weekResetsAt: Date?
    let fetchedAt: Date
}

enum SharedUsageStore {
    static let appGroupID = "group.de.universegame.ClaudeBattery"
    private static let key = "latestSnapshot"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func save(_ snapshot: SharedUsageSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: key)
    }

    static func load() -> SharedUsageSnapshot? {
        guard let data = defaults?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedUsageSnapshot.self, from: data)
    }

    static func clear() {
        defaults?.removeObject(forKey: key)
    }
}
