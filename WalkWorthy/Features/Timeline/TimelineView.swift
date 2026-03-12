import SwiftUI
import SwiftData

struct TimelineView: View {
    let isPremium: Bool
    let onRequirePaywall: (PaywallTriggerReason) -> Void

    @Query(sort: \AnsweredPrayer.date, order: .reverse)
    private var answeredPrayers: [AnsweredPrayer]

    var body: some View {
        NavigationStack {
            Group {
                if !isPremium {
                    lockedView
                } else if answeredPrayers.isEmpty {
                    emptyView
                } else {
                    List(answeredPrayers) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.notes)
                                .font(WWTypography.body(16))
                                .foregroundStyle(WWColor.charcoal)
                            Text(item.date.formatted(date: .abbreviated, time: .omitted))
                                .font(WWTypography.detail())
                                .foregroundStyle(WWColor.sapphire)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Timeline")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            guard !isPremium else { return }
            onRequirePaywall(.timelineAccess)
        }
    }

    private var lockedView: some View {
        WWCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Timeline is premium")
                    .font(WWTypography.section(24))
                    .foregroundStyle(WWColor.charcoal)

                Text("Unlock answered-prayer history and long-term reflection with the premium plan.")
                    .font(WWTypography.body())
                    .foregroundStyle(WWColor.charcoal.opacity(0.75))

                Button("Unlock Premium") {
                    onRequirePaywall(.timelineAccess)
                }
                .buttonStyle(WWPrimaryButtonStyle())
            }
        }
        .padding(20)
    }

    private var emptyView: some View {
        WWCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("No answered prayers logged yet")
                    .font(WWTypography.section(22))
                Text("Mark an entry as answered from Today to build your timeline.")
                    .font(WWTypography.body())
                    .foregroundStyle(WWColor.charcoal.opacity(0.75))
            }
        }
        .padding(20)
    }
}
