import Foundation
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

    private var isDismissOfferPaywall: Bool {
        triggerReason == PaywallTriggerReason.paywallDismissOffer.rawValue
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
                        if let specialOfferPricingLine {
                            Text(specialOfferPricingLine)
                                .font(WWTypography.caption(13))
                                .foregroundStyle(WWColor.muted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
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
                selectedProductID = defaultProductIDForCurrentPaywall()
            }
        }
        .onChange(of: subscriptionService.products) { _, _ in
            guard let selectedProductID else {
                self.selectedProductID = defaultProductIDForCurrentPaywall()
                return
            }
            let isSelectedStillValid = subscriptionService.products.contains(where: { $0.id == selectedProductID })
            if !isSelectedStillValid {
                self.selectedProductID = defaultProductIDForCurrentPaywall()
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
                    planPriceView(for: product)
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
        .accessibilityLabel(
            String(
                format: L10n.string("paywall.plan.accessibility_label", default: "%@, %@, %@"),
                planTitle(for: product),
                accessibilityPriceCaption(for: product),
                periodSubtitle(for: product)
            )
        )
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
        let fallbackID = defaultProductIDForCurrentPaywall()
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
        if isDismissOfferPaywall, isAnnualProduct(product), let basePrice = annualBasePriceCaption(for: product) {
            let format = L10n.string(
                "paywall.dismiss_offer.renewal_line",
                default: "Then %@ per year after year one."
            )
            return String(format: format, basePrice)
        }

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

    private func accessibilityPriceCaption(for product: SubscriptionDisplayProduct) -> String {
        if let discounted = annualDiscountedPriceCaption(for: product), let base = annualBasePriceCaption(for: product) {
            let format = L10n.string(
                "paywall.dismiss_offer.accessibility_price",
                default: "%@ first year, then %@ yearly"
            )
            return String(format: format, discounted, base)
        }
        return priceCaption(for: product)
    }

    @ViewBuilder
    private func planPriceView(for product: SubscriptionDisplayProduct) -> some View {
        if let discountedPrice = annualDiscountedPriceCaption(for: product) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(priceCaption(for: product))
                    .font(WWTypography.caption(12))
                    .foregroundStyle(WWColor.muted)
                    .strikethrough()
                Text(discountedPrice)
                    .font(WWTypography.heading(19))
                    .foregroundStyle(WWColor.nearBlack)
            }
        } else {
            Text(priceCaption(for: product))
                .font(WWTypography.heading(19))
                .foregroundStyle(WWColor.nearBlack)
        }
    }

    private var specialOfferPricingLine: String? {
        guard isDismissOfferPaywall else { return nil }
        guard let annualProduct = subscriptionService.products.first(where: isAnnualProduct) else { return nil }
        guard let discounted = annualDiscountedPriceCaption(for: annualProduct) else { return nil }
        let base = annualBasePriceCaption(for: annualProduct) ?? annualProduct.displayPrice
        let format = L10n.string(
            "paywall.dismiss_offer.price_line",
            default: "%@ for your first year, then %@ each year."
        )
        return String(format: format, discounted, base)
    }

    private func annualDiscountedPriceCaption(for product: SubscriptionDisplayProduct) -> String? {
        guard isDismissOfferPaywall, isAnnualProduct(product) else { return nil }
        let baseAmount = NSDecimalNumber(decimal: product.priceAmount)
        let halfPrice = baseAmount.multiplying(by: NSDecimalNumber(value: 0.5)).decimalValue
        return localizedCurrency(amount: halfPrice, currencyCode: product.currencyCode)
    }

    private func annualBasePriceCaption(for product: SubscriptionDisplayProduct) -> String? {
        guard isAnnualProduct(product) else { return nil }
        return product.displayPrice
    }

    private func localizedCurrency(amount: Decimal, currencyCode: String?) -> String? {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        if let currencyCode, !currencyCode.isEmpty {
            formatter.currencyCode = currencyCode
        }
        return formatter.string(from: NSDecimalNumber(decimal: amount))
    }

    private func defaultProductIDForCurrentPaywall() -> String? {
        if isDismissOfferPaywall {
            if let annualID = subscriptionService.annualProduct?.id {
                return annualID
            }
            if let annualFallback = subscriptionService.products.first(where: isAnnualProduct)?.id {
                return annualFallback
            }
        }
        return subscriptionService.defaultPaywallProductID()
    }

    private func isAnnualProduct(_ product: SubscriptionDisplayProduct) -> Bool {
        let period = product.periodLabel.lowercased()
        let identifier = product.id.lowercased()
        return period.contains("year") || identifier.contains("annual")
    }
}
