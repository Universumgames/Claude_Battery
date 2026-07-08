import WidgetKit
import SwiftUI

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedUsageSnapshot?
}

/// Reads whatever the main app last wrote to the shared App Group container.
/// The widget itself never talks to claude.ai — the always-running menu bar
/// app does that and pushes fresh data via `WidgetCenter.reloadTimelines`.
/// The periodic timeline below is only a fallback in case that never happens
/// (e.g. the app isn't running yet after a reboot).
struct UsageProvider: TimelineProvider {
    func placeholder(in context: Context) -> UsageEntry {
        UsageEntry(date: Date(), snapshot: SharedUsageStore.load())
    }

    func getSnapshot(in context: Context, completion: @escaping (UsageEntry) -> Void) {
        completion(UsageEntry(date: Date(), snapshot: SharedUsageStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<UsageEntry>) -> Void) {
        let entry = UsageEntry(date: Date(), snapshot: SharedUsageStore.load())
        let nextCheck = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        completion(Timeline(entries: [entry], policy: .after(nextCheck)))
    }
}

struct ClaudeUsageWidgetView: View {
    let entry: UsageEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot {
                content(for: snapshot)
            } else {
                emptyState
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
    }

    @ViewBuilder
    private func content(for snapshot: SharedUsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Claude Usage", systemImage: "bolt.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            usageRow(title: "Session", percent: snapshot.sessionRemainingPercent, resetsAt: snapshot.sessionResetsAt)
            usageRow(title: "Week", percent: snapshot.weekRemainingPercent, resetsAt: snapshot.weekResetsAt)

            Spacer(minLength: 0)

            HStack(spacing: 3) {
                Text("Updated")
                Text(snapshot.fetchedAt, style: .relative)
                Text("ago")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private func usageRow(title: String, percent: Double?, resetsAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title).font(.subheadline.weight(.medium))
                Spacer()
                if let percent {
                    Text("\(Int(percent))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(color(for: percent))
                } else {
                    Text("—").foregroundStyle(.secondary)
                }
            }
            ProgressView(value: (percent ?? 0) / 100)
                .tint(color(for: percent ?? 0))
            if let resetsAt {
                HStack(spacing: 3) {
                    Text("Resets in")
                    Text(resetsAt, style: .relative)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func color(for percent: Double) -> Color {
        switch percent {
        case ..<15: return .red
        case ..<40: return .orange
        default: return .green
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "bolt.slash")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open Claude Usage to sign in")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ClaudeUsageWidget: Widget {
    let kind = "ClaudeUsageWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: UsageProvider()) { entry in
            ClaudeUsageWidgetView(entry: entry)
        }
        .configurationDisplayName("Claude Usage")
        .description("Shows your remaining Claude session and weekly usage.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
