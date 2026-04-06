import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let triggerReason: String?
    let isPremium: Bool
    let copyOverride: PaywallRemoteConfig?
    @State private var selectedProductID: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false

    init(triggerReason: String?, isPremium: Bool, copyOverride: PaywallRemoteConfig? = nil) {
        self.triggerReason = triggerReason
        self.isPremium = isPremium
        self.copyOverride = copyOverride
    }

    private var paywallConfig: PaywallRemoteConfig {
        copyOverride ?? subscriptionService.paywallConfig
    }

    var body: some View {
        ZStack {
            WWColor.white
                .ignoresSafeArea()
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        offerHero
                        packageSelector
                        primaryButton
                        footerLinks
                        if let errorMessage = subscriptionService.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(WWTypography.caption(13))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        Text(paywallConfig.footnote)
                            .font(WWTypography.caption(12))
                            .foregroundStyle(WWColor.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
        }
        .task {
            await subscriptionService.loadProducts()
            await subscriptionService.refreshEntitlements()
            if selectedProductID == nil {
                selectedProductID = subscriptionService.defaultPaywallProductID()
            }
        }
        .onChange(of: subscriptionService.products) { _, _ in
            guard let selectedProductID else {
                self.selectedProductID = subscriptionService.defaultPaywallProductID()
                return
            }
            let isSelectedStillValid = subscriptionService.products.contains(where: { $0.id == selectedProductID })
            if !isSelectedStillValid {
                self.selectedProductID = subscriptionService.defaultPaywallProductID()
            }
        }
        .onChange(of: subscriptionService.isPremium) { _, isPremium in
            if isPremium {
                dismiss()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(AppConstants.appName)
                    .font(WWTypography.heading(20))
                    .foregroundStyle(WWColor.nearBlack)
                Text(paywallConfig.subheadline)
                    .font(WWTypography.body(16))
                    .foregroundStyle(WWColor.muted)
            }
            Spacer()

            if paywallConfig.isDismissable {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(WWColor.muted)
                        .frame(width: 36, height: 36)
                        .background(WWColor.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("common.close", default: "Close"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .accessibilityElement(children: .combine)
    }

    private var offerHero: some View {
        VStack(spacing: 10) {
            Text(paywallConfig.headline)
                .font(WWTypography.display(34))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.72)

            Image("paywall_hero")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 170)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(WWColor.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var packageSelector: some View {
        VStack(spacing: 8) {
            if subscriptionService.isLoadingProducts && subscriptionService.products.isEmpty {
                ProgressView(L10n.string("paywall.loading_plans", default: "Loading plans…"))
                    .font(WWTypography.body(15))
                    .foregroundStyle(WWColor.nearBlack)
                    .padding(.vertical, 22)
            } else {
                ForEach(subscriptionService.products) { product in
                    planRow(for: product)
                }
            }
        }
    }

    private func planRow(for product: SubscriptionDisplayProduct) -> some View {
        let isSelected = product.id == selectedProductID
        let isAnnual = isAnnualProduct(product)

        return Button {
            selectedProductID = product.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 21, weight: .medium))
                        .foregroundStyle(isSelected ? WWColor.growGreen : WWColor.muted)

                    Text(planTitle(for: product))
                        .font(WWTypography.heading(24))
                        .foregroundStyle(WWColor.nearBlack)

                    Spacer()

                    Text(priceCaption(for: product))
                        .font(WWTypography.heading(19))
                        .foregroundStyle(WWColor.nearBlack)
                }

                Text(periodSubtitle(for: product))
                    .font(WWTypography.body(15))
                    .foregroundStyle(WWColor.muted)
                    .padding(.leading, 31)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WWColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? WWColor.growGreen : WWColor.muted.opacity(0.35), lineWidth: isSelected ? 2 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if isAnnual, let badge = paywallConfig.annualBadgeText, !badge.isEmpty {
                    Text(badge)
                        .font(WWTypography.caption(12))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 5)
                        .background(WWColor.growGreen, in: Capsule())
                        .shadow(color: .black.opacity(0.14), radius: 4, x: 0, y: 1)
                        .offset(x: -12, y: -12)
                        .zIndex(3)
                }
            }
        }
        .buttonStyle(.plain)
        .zIndex(isAnnual ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(planTitle(for: product)), \(priceCaption(for: product)), \(periodSubtitle(for: product))")
        .accessibilityValue(isSelected ? L10n.string("tab.selected", default: "Selected") : "")
        .accessibilityHint(L10n.string("paywall.plan.select_hint", default: "Double-tap to select this plan."))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var primaryButton: some View {
        Button {
            Task { await purchaseSelectedPackage() }
        } label: {
            HStack {
                Spacer()
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(paywallConfig.ctaTitle)
                        .font(WWTypography.heading(20))
                }
                Spacer()
            }
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(WWColor.growGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(selectedProductID == nil || isPurchasing || isRestoring || subscriptionService.products.isEmpty)
        .opacity((selectedProductID == nil || isPurchasing || isRestoring || subscriptionService.products.isEmpty) ? 0.65 : 1)
        .accessibilityLabel(paywallConfig.ctaTitle)
        .accessibilityHint(L10n.string("paywall.cta.hint", default: "Starts the selected subscription plan."))
    }

    private var footerLinks: some View {
        HStack(spacing: 20) {
            Button {
                Task { await restorePurchases() }
            } label: {
                if isRestoring {
                    ProgressView()
                        .font(WWTypography.caption(13))
                } else {
                    Text(L10n.string("settings.subscription.restore", default: "Restore Purchases"))
                        .font(WWTypography.caption(14))
                }
            }
            .buttonStyle(.plain)
            .frame(minHeight: 44)

            Button(L10n.string("paywall.footer.terms", default: "Terms")) {
                openURL(URL(string: AppConstants.termsURL)!)
            }
            .buttonStyle(.plain)
            .font(WWTypography.caption(14))
            .frame(minHeight: 44)

            Button(L10n.string("paywall.footer.privacy", default: "Privacy")) {
                openURL(URL(string: AppConstants.privacyURL)!)
            }
            .buttonStyle(.plain)
            .font(WWTypography.caption(14))
            .frame(minHeight: 44)
        }
        .foregroundStyle(WWColor.muted)
    }

    private func purchaseSelectedPackage() async {
        guard !isPurchasing else { return }
        let fallbackID = subscriptionService.defaultPaywallProductID()
        guard let productID = selectedProductID ?? fallbackID else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        await subscriptionService.purchase(productID: productID)
    }

    private func restorePurchases() async {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }
        await subscriptionService.restorePurchases()
    }

    private func planTitle(for product: SubscriptionDisplayProduct) -> String {
        let period = product.periodLabel.lowercased()
        if period.contains("year") { return L10n.string("paywall.plan.annual", default: "Annual") }
        if period.contains("month") { return L10n.string("paywall.plan.monthly", default: "Monthly") }
        if period.contains("week") { return L10n.string("paywall.plan.weekly", default: "Weekly") }
        if period.contains("day") { return L10n.string("paywall.plan.daily", default: "Daily") }
        return L10n.string("paywall.plan.subscription", default: "Subscription")
    }

    private func periodSubtitle(for product: SubscriptionDisplayProduct) -> String {
        switch planTitle(for: product) {
        case L10n.string("paywall.plan.annual", default: "Annual"):
            return L10n.string("paywall.plan.billed_yearly", default: "Billed yearly")
        case L10n.string("paywall.plan.monthly", default: "Monthly"):
            return L10n.string("paywall.plan.billed_monthly", default: "Billed monthly")
        case L10n.string("paywall.plan.weekly", default: "Weekly"):
            return L10n.string("paywall.plan.billed_weekly", default: "Billed weekly")
        case L10n.string("paywall.plan.daily", default: "Daily"):
            return L10n.string("paywall.plan.billed_daily", default: "Billed daily")
        default:
            return L10n.string("paywall.plan.recurring", default: "Recurring subscription")
        }
    }

    private func priceCaption(for product: SubscriptionDisplayProduct) -> String {
        product.displayPrice
    }

    private func isAnnualProduct(_ product: SubscriptionDisplayProduct) -> Bool {
        planTitle(for: product) == "Annual"
    }
}
