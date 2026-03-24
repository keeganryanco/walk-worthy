import WidgetKit
import SwiftUI
import os

private let widgetLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "co.keeganryan.tend.widgets",
    category: "TendSnapshotWidget"
)

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
        previewEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (TendSnapshotEntry) -> Void) {
        if context.isPreview {
            completion(previewEntry())
            return
        }
        completion(buildEntry())
    }

    private func previewEntry() -> TendSnapshotEntry {
        let dummy = TendWidgetSnapshot(
            hasActiveJourney: true,
            activeJourneyTitle: "Growing in Patience",
            scriptureSnippet: "Be joyful in hope, patient in affliction, faithful in prayer. - Rom 12:12",
            todayStep: "When frustrated today, take 3 deep breaths before responding.",
            streakCount: 12,
            updatedAt: .now
        )
        return TendSnapshotEntry(date: .now, snapshot: dummy, state: .active)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TendSnapshotEntry>) -> Void) {
        let entry = buildEntry()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func buildEntry() -> TendSnapshotEntry {
        guard let snapshot = TendWidgetSnapshotStore.load() else {
#if DEBUG
            widgetLogger.debug("snapshot load: no cached snapshot")
#endif
            return TendSnapshotEntry(date: .now, snapshot: .empty, state: .noCachedSnapshot)
        }

        let state: TendSnapshotEntry.SnapshotState = snapshot.hasActiveJourney ? .active : .noActiveJourney
#if DEBUG
        widgetLogger.debug("snapshot load: active=\(snapshot.hasActiveJourney, privacy: .public) title=\(snapshot.activeJourneyTitle, privacy: .public) streak=\(snapshot.streakCount, privacy: .public)")
#endif
        return TendSnapshotEntry(date: .now, snapshot: snapshot, state: state)
    }
}

struct TendSnapshotWidget: Widget {
    private let kind = AppConstants.Widget.snapshotKind

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
    @Environment(\.colorScheme) private var colorScheme

    let entry: TendSnapshotEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallBody
                .containerBackground(for: .widget) {
                    widgetBackground(for: .systemSmall)
                }
        default:
            mediumBody
                .containerBackground(for: .widget) {
                    widgetBackground(for: .systemMedium)
                }
        }
    }

    @ViewBuilder
    private func widgetBackground(for family: WidgetFamily) -> some View {
        ZStack {
            artFallbackBackground
            Image(artAssetName(for: family))
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            
            if family != .systemSmall {
                LinearGradient(
                    stops: [
                        .init(color: Color.black.opacity(0.00), location: 0.18),
                        .init(color: Color.black.opacity(0.12), location: 0.36),
                        .init(color: Color.black.opacity(0.34), location: 0.53),
                        .init(color: Color.black.opacity(0.62), location: 0.72),
                        .init(color: Color.black.opacity(0.90), location: 1.00)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }

    private var smallBody: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                if entry.state == .active {
                    let panelWidth = proxy.size.width * 0.72
                    let panelHeight = proxy.size.height * 0.72

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 0) {
                            Spacer()
                            streakBadge
                        }

                        Text("TODAY'S STEP")
                            .font(WWTypography.caption(9).weight(.heavy))
                            .tracking(1.0)
                            .foregroundStyle(Color.white.opacity(0.78))

                        Text(stepText)
                            .font(WWTypography.caption(14).weight(.semibold))
                            .foregroundStyle(primaryTextColor)
                            .multilineTextAlignment(.leading)
                            .lineLimit(4)
                            .minimumScaleFactor(0.88)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                    .frame(width: panelWidth, height: panelHeight, alignment: .topLeading)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: colorScheme == .dark
                                        ? [Color.black.opacity(0.80), Color.black.opacity(0.66)]
                                        : [Color.black.opacity(0.62), Color.black.opacity(0.50)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        RadialGradient(
                                            colors: colorScheme == .dark
                                                ? [Color.black.opacity(0.48), Color.black.opacity(0.18), Color.clear]
                                                : [Color.black.opacity(0.34), Color.black.opacity(0.12), Color.clear],
                                            center: .center,
                                            startRadius: 8,
                                            endRadius: 120
                                        )
                                    )
                            )
                    )
                    .padding(8)
                } else {
                    fallbackStack
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
    }

    private var mediumBody: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                Spacer(minLength: proxy.size.width * 0.25)

                if entry.state == .active {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(journeyTitle)
                            .font(WWTypography.caption(11).weight(.semibold))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.tail)

                        Text(scriptureText)
                            .font(WWTypography.body(14).weight(.semibold))
                            .foregroundStyle(Color.white)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)

                        Text(stepText)
                            .font(WWTypography.caption(12).weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.85))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)

                        streakBadge
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                } else {
                    fallbackStack
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                }
            }
            .padding(10)
        }
    }

    private var artFallbackBackground: some View {
        LinearGradient(
            colors: [
                colorScheme == .dark ? Color(red: 0.10, green: 0.12, blue: 0.10) : Color(red: 0.96, green: 0.97, blue: 0.95),
                colorScheme == .dark ? Color(red: 0.13, green: 0.14, blue: 0.18) : Color(red: 0.92, green: 0.95, blue: 0.93)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func artAssetName(for family: WidgetFamily) -> String {
        switch (family, colorScheme) {
        case (.systemSmall, .dark):
            return "WidgetArtSmallDark"
        case (.systemSmall, _):
            return "WidgetArtSmallLight"
        case (_, .dark):
            return "WidgetArtMediumDark"
        default:
            return "WidgetArtMediumLight"
        }
    }

    private var fallbackStack: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tend")
                .font(WWTypography.caption(12).weight(.semibold))
                .foregroundStyle(mutedTextColor)

            Text(fallbackTitle)
                .font(WWTypography.body(14).weight(.semibold))
                .foregroundStyle(primaryTextColor)
                .lineLimit(3)

            Text(fallbackSubtitle)
                .font(WWTypography.caption(11))
                .foregroundStyle(secondaryTextColor)
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

    private var journeyTitle: String {
        let trimmed = entry.snapshot.activeJourneyTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Today's Journey" : trimmed
    }

    private var scriptureText: String {
        let trimmed = entry.snapshot.scriptureSnippet.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? TendWidgetSnapshot.empty.scriptureSnippet : trimmed
    }

    private var stepText: String {
        let trimmed = entry.snapshot.todayStep.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? TendWidgetSnapshot.empty.todayStep : trimmed
    }

    private var primaryTextColor: Color {
        colorScheme == .dark ? Color.white : Color(red: 0.08, green: 0.09, blue: 0.08)
    }

    private var secondaryTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.88) : Color(red: 0.16, green: 0.20, blue: 0.16)
    }

    private var mutedTextColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.74) : WWColor.muted
    }

    private var textPanelBackground: Color {
        colorScheme == .dark ? Color.black.opacity(0.32) : Color.white.opacity(0.68)
    }
}
