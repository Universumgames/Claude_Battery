import Foundation
import Combine
import WidgetKit

@MainActor
final class UsageStore: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var lastError: UsageError?
    @Published var isLoading = false
    @Published var hasCookie: Bool = KeychainStore.load() != nil

    private let service = ClaudeUsageService()
    private var timer: Timer?

    var refreshInterval: TimeInterval = 90

    func start() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func refresh() async {
        guard hasCookie else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            snapshot = try await service.fetchUsage()
            lastError = nil
            publishToWidget()
        } catch let err as UsageError {
            lastError = err
        } catch {
            lastError = .decoding
        }
    }

    func setCookie(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        KeychainStore.save(trimmed)
        hasCookie = true
        Task { await refresh() }
    }

    func clearCookie() {
        KeychainStore.clear()
        hasCookie = false
        snapshot = nil
        lastError = nil
        SharedUsageStore.clear()
        WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeBatteryWidget")
    }

    /// Mirrors the latest fetch into the shared App Group container and asks
    /// WidgetKit to redraw the desktop widget with it.
    private func publishToWidget() {
        guard let snapshot else { return }
        SharedUsageStore.save(SharedUsageSnapshot(
            sessionRemainingPercent: snapshot.session.remainingPercent,
            sessionResetsAt: snapshot.session.resetsAt,
            weekRemainingPercent: snapshot.week.remainingPercent,
            weekResetsAt: snapshot.week.resetsAt,
            fetchedAt: snapshot.fetchedAt
        ))
        WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeBatteryWidget")
    }

    /// Remaining fraction (0...1) of the most constrained active window — drives the menu bar icon.
    var menuBarRemainingFraction: Double? {
        guard let snapshot else { return nil }
        let candidates = [snapshot.session.remainingPercent, snapshot.week.remainingPercent].compactMap { $0 }
        guard let min = candidates.min() else { return nil }
        return min / 100
    }
}
