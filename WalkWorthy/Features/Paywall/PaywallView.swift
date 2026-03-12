import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService

    let triggerReason: String?
    let isPremium: Bool

    @State private var selectedProductID = AppConstants.Subscription.annualProductID

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

                        Text("Start your 3-day free trial on annual, or choose weekly access.")
                            .font(WWTypography.body())
                            .foregroundStyle(WWColor.charcoal.opacity(0.75))

                        benefits

                        subscriptionOptions

                        if let triggerReason {
                            Text("Unlock reason: \(friendlyTrigger(triggerReason))")
                                .font(WWTypography.detail())
                                .foregroundStyle(WWColor.charcoal.opacity(0.65))
                        }

                        Button(primaryActionTitle) {
                            Task {
                                if selectedProductID == AppConstants.Subscription.annualProductID {
                                    await subscriptionService.purchaseAnnualSubscription()
                                } else {
                                    await subscriptionService.purchase(productID: selectedProductID)
                                }
                            }
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

    private var subscriptionOptions: some View {
        VStack(spacing: 10) {
            optionRow(
                title: "Annual (3-day trial)",
                subtitle: annualPlanLabel,
                productID: AppConstants.Subscription.annualProductID
            )

            optionRow(
                title: "Weekly",
                subtitle: weeklyPlanLabel,
                productID: AppConstants.Subscription.weeklyProductID
            )
        }
    }

    private func optionRow(title: String, subtitle: String, productID: String) -> some View {
        Button {
            selectedProductID = productID
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(WWTypography.body(16).weight(.semibold))
                    Text(subtitle)
                        .font(WWTypography.detail())
                        .foregroundStyle(WWColor.charcoal.opacity(0.72))
                }
                Spacer()
                Image(systemName: selectedProductID == productID ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(WWColor.sapphire)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var annualPlanLabel: String {
        if let product = subscriptionService.annualProduct {
            return "\(product.displayPrice) / \(product.subscription?.subscriptionPeriod.debugLabel ?? "year")"
        }
        return AppConstants.Subscription.annualDisplayFallback
    }

    private var weeklyPlanLabel: String {
        if let product = subscriptionService.weeklyProduct {
            return "\(product.displayPrice) / \(product.subscription?.subscriptionPeriod.debugLabel ?? "week")"
        }
        return AppConstants.Subscription.weeklyDisplayFallback
    }

    private var primaryActionTitle: String {
        selectedProductID == AppConstants.Subscription.annualProductID ? "Start 3-Day Free Trial" : "Continue Weekly"
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
