import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService

    let triggerReason: String?
    let isPremium: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WWColor.alabaster, WWColor.sage.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                WWCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Build a daily rhythm")
                            .font(WWTypography.title(32))
                            .foregroundStyle(WWColor.charcoal)

                        Text("Start your 3-day free trial, then continue with annual premium.")
                            .font(WWTypography.body())
                            .foregroundStyle(WWColor.charcoal.opacity(0.75))

                        benefits

                        Text(planLabel)
                            .font(WWTypography.body(18).weight(.semibold))
                            .foregroundStyle(WWColor.sapphire)

                        if let triggerReason {
                            Text("Unlock reason: \(friendlyTrigger(triggerReason))")
                                .font(WWTypography.detail())
                                .foregroundStyle(WWColor.charcoal.opacity(0.65))
                        }

                        Button("Start Free Trial") {
                            Task { await subscriptionService.purchaseAnnualSubscription() }
                        }
                        .buttonStyle(WWPrimaryButtonStyle())

                        Button("Restore Purchases") {
                            Task { await subscriptionService.restorePurchases() }
                        }
                        .font(WWTypography.detail())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)

                        Text("Payment is charged to your Apple ID after trial unless canceled at least 24 hours before renewal.")
                            .font(WWTypography.detail(12))
                            .foregroundStyle(WWColor.charcoal.opacity(0.7))
                    }
                }
                .padding(.horizontal, 20)

                if isPremium {
                    Text("Premium active")
                        .font(WWTypography.body().weight(.semibold))
                        .foregroundStyle(.green)
                }

#if DEBUG
                Text("DEBUG: Use StoreKit config or sandbox for purchase flow.")
                    .font(WWTypography.detail(12))
                    .foregroundStyle(.secondary)
#endif

                Spacer()
            }
        }
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Unlimited prayer journeys", systemImage: "checkmark.circle.fill")
            Label("Answered prayer timeline", systemImage: "checkmark.circle.fill")
            Label("Templates, export, widgets", systemImage: "checkmark.circle.fill")
        }
        .font(WWTypography.body(15))
        .foregroundStyle(WWColor.charcoal)
    }

    private var planLabel: String {
        if let product = subscriptionService.products.first {
            return "\(product.displayPrice) / \(product.subscription?.subscriptionPeriod.debugLabel ?? "year")"
        }

        return "Annual premium (3-day free trial)"
    }

    private func friendlyTrigger(_ value: String) -> String {
        switch value {
        case PaywallTriggerReason.sessionCount.rawValue:
            return "Second session reached"
        case PaywallTriggerReason.secondJourney.rawValue:
            return "Second journey is premium"
        case PaywallTriggerReason.timelineAccess.rawValue:
            return "Timeline is premium"
        default:
            return value
        }
    }
}

private extension Product.SubscriptionPeriod {
    var debugLabel: String {
        switch unit {
        case .day:
            return value == 1 ? "day" : "\(value) days"
        case .week:
            return value == 1 ? "week" : "\(value) weeks"
        case .month:
            return value == 1 ? "month" : "\(value) months"
        case .year:
            return value == 1 ? "year" : "\(value) years"
        @unknown default:
            return "term"
        }
    }
}
