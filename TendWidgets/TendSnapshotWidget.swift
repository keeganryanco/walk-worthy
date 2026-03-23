import WidgetKit
import SwiftUI

struct TendSnapshotEntry: TimelineEntry {
    enum SnapshotState {
        case active
        case noActiveJourney
        case noCachedSnapshot
    }

    let date: Date
    let snapshot: TendWidgetSnapshot
    let state: SnapshotState
}

struct TendSnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> TendSnapshotEntry {
        TendSnapshotEntry(
            date: .now,
            snapshot: TendWidgetSnapshot.empty,
            state: .noCachedSnapshot
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (TendSnapshotEntry) -> Void) {
        completion(buildEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TendSnapshotEntry>) -> Void) {
        let entry = buildEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func buildEntry() -> TendSnapshotEntry {
        guard let snapshot = TendWidgetSnapshotStore.load() else {
            return TendSnapshotEntry(date: .now, snapshot: .empty, state: .noCachedSnapshot)
        }

        let state: TendSnapshotEntry.SnapshotState = snapshot.hasActiveJourney ? .active : .noActiveJourney
        return TendSnapshotEntry(date: .now, snapshot: snapshot, state: state)
    }
}

struct TendSnapshotWidget: Widget {
    private let kind = "TendSnapshotWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TendSnapshotProvider()) { entry in
            TendSnapshotWidgetView(entry: entry)
                .widgetURL(URL(string: "\(AppConstants.DeepLink.scheme)://\(AppConstants.DeepLink.homeHost)"))
        }
        .configurationDisplayName("Tend")
        .description("See today's tend at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct TendSnapshotWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: TendSnapshotEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallBody
                .containerBackground(WWColor.surface, for: .widget)
        default:
            mediumBody
                .containerBackground(WWColor.surface, for: .widget)
        }
    }

    private var smallBody: some View {
        ZStack(alignment: .bottomLeading) {
            Image("WidgetArtSmall")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            if entry.state == .active {
                VStack(alignment: .trailing, spacing: 6) {
                    streakBadge
                    Text(entry.snapshot.todayStep)
                        .font(WWTypography.caption(12).weight(.medium))
                        .foregroundStyle(WWColor.nearBlack)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            } else {
                fallbackStack
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var mediumBody: some View {
        ZStack(alignment: .leading) {
            Image("WidgetArtMedium")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            if entry.state == .active {
                HStack(spacing: 0) {
                    Spacer(minLength: 96)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(entry.snapshot.activeJourneyTitle)
                            .font(WWTypography.caption(12).weight(.semibold))
                            .foregroundStyle(WWColor.muted)
                            .lineLimit(1)
                        Text(entry.snapshot.scriptureSnippet)
                            .font(WWTypography.body(15).weight(.semibold))
                            .foregroundStyle(WWColor.nearBlack)
                            .lineLimit(3)
                        Text(entry.snapshot.todayStep)
                            .font(WWTypography.caption(12))
                            .foregroundStyle(WWColor.nearBlack)
                            .lineLimit(2)
                        streakBadge
                    }
                    .padding(.trailing, 12)
                    .padding(.vertical, 12)
                }
            } else {
                fallbackStack
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var fallbackStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tend")
                .font(WWTypography.caption(12).weight(.semibold))
                .foregroundStyle(WWColor.muted)

            Text(fallbackTitle)
                .font(WWTypography.body(14).weight(.semibold))
                .foregroundStyle(WWColor.nearBlack)
                .lineLimit(3)

            Text(fallbackSubtitle)
                .font(WWTypography.caption(11))
                .foregroundStyle(WWColor.muted)
                .lineLimit(2)
        }
    }

    private var fallbackTitle: String {
        switch entry.state {
        case .noCachedSnapshot:
            return "Open Tend to sync today's snapshot."
        case .noActiveJourney:
            return "Start a journey to see your daily tend."
        case .active:
            return ""
        }
    }

    private var fallbackSubtitle: String {
        switch entry.state {
        case .noCachedSnapshot:
            return "Tap to open Home"
        case .noActiveJourney:
            return "Tap to create your first journey"
        case .active:
            return ""
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 10, weight: .semibold))
            Text("\(max(0, entry.snapshot.streakCount))")
                .font(WWTypography.caption(11).weight(.semibold))
        }
        .foregroundStyle(WWColor.growGreen)
    }
}
