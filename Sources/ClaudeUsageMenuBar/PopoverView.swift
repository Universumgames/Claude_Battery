import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: UsageStore
    let onRequestSignIn: () -> Void
    let onRequestCookieEntry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if !store.hasCookie {
                signedOutView
            } else if let error = store.lastError {
                errorView(error)
            } else if let snapshot = store.snapshot {
                usageView(snapshot)
            } else {
                ProgressView().padding(.vertical, 12)
            }

            Divider()

            footer
        }
        .padding(16)
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            Text("Claude Usage")
                .font(.headline)
            Spacer()
            if store.isLoading {
                ProgressView().controlSize(.small)
            } else {
                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Refresh now")
            }
        }
    }

    private func usageView(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            usageRow(title: "Session limit", window: snapshot.session)
            usageRow(title: "Weekly limit", window: snapshot.week)
            if let opus = snapshot.weekOpus, opus.utilization != nil {
                usageRow(title: "Weekly Opus limit", window: opus)
            }
            TimelineView(.periodic(from: snapshot.fetchedAt, by: 1)) { context in
                Text("Updated \(relativeTime(snapshot.fetchedAt, now: context.date))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func usageRow(title: String, window: UsageWindow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                if let remaining = window.remainingPercent {
                    Text("\(remaining, specifier: "%.0f")% left")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(color(for: remaining))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            ProgressView(value: (window.remainingPercent ?? 0) / 100)
                .tint(color(for: window.remainingPercent ?? 0))
            if let resetsAt = window.resetsAt {
                Text("Resets \(resetLabel(resetsAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func errorView(_ error: UsageError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(error.errorDescription ?? "Error", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.orange)
                .font(.subheadline)
            if case .notAuthenticated = error {
                signInChoice
            } else {
                Button("Try again") { Task { await store.refresh() } }
            }
        }
    }

    private var signedOutView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Not signed in").font(.subheadline)
            signInChoice
        }
    }

    /// Two equally-weighted options, not a primary action + fallback link —
    /// the embedded browser doesn't work for every account/SSO setup.
    private var signInChoice: some View {
        HStack {
            Button("Sign in…") { onRequestSignIn() }
            Button("Paste cookie…") { onRequestCookieEntry() }
        }
        .buttonStyle(.bordered)
    }

    private var footer: some View {
        // Plain buttons, not a SwiftUI `Menu` — this view is hosted inside a real
        // NSMenu (see AppDelegate), and a nested Menu's own popup conflicts with
        // the outer NSMenu's event tracking and doesn't reliably open.
        HStack {
            if store.hasCookie {
                Button("Sign in…") { onRequestSignIn() }
                    .font(.caption)
                Button("Paste cookie…") { onRequestCookieEntry() }
                    .font(.caption)
                Button("Sign out") { store.clearCookie() }
                    .font(.caption)
            }
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .font(.caption)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private func color(for remaining: Double) -> Color {
        if remaining <= 10 { return .red }
        if remaining <= 30 { return .orange }
        return .green
    }

    private func resetLabel(_ date: Date) -> String {
        let seconds = date.timeIntervalSinceNow
        guard seconds > 0 else { return "now" }

        let totalMinutes = Int((seconds / 60).rounded())
        let days = totalMinutes / (60 * 24)
        let hours = (totalMinutes / 60) % 24
        let minutes = totalMinutes % 60

        if days > 0 {
            return hours > 0 ? "in \(days)d \(hours)h" : "in \(days)d"
        }
        if hours > 0 {
            return minutes > 0 ? "in \(hours)h \(minutes)m" : "in \(hours)h"
        }
        return "in \(minutes)m"
    }

    private func relativeTime(_ date: Date, now: Date) -> String {
        // RelativeDateTimeFormatter renders near-zero intervals as "in 0 seconds"
        // instead of "0 seconds ago" — since a refresh fires every time the menu
        // opens, that's the common case, so special-case it rather than showing
        // backwards-looking wording for something that just happened.
        guard now.timeIntervalSince(date) >= 10 else { return "just now" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: now)
    }
}
