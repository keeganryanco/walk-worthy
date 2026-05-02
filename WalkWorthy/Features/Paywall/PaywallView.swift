import Foundation
import SwiftUI

struct PaywallPersonalizationContext: Equatable {
    let journeyTitle: String?
    let dailyTitle: String?
    let scriptureReference: String?
    let reflectionExcerpt: String?
    let plantProgressText: String?
    let prayerConcern: String?

    init(
        journeyTitle: String? = nil,
        dailyTitle: String? = nil,
        scriptureReference: String? = nil,
        reflectionExcerpt: String? = nil,
        plantProgressText: String? = nil,
        prayerConcern: String? = nil
    ) {
        self.journeyTitle = Self.clean(journeyTitle)
        self.dailyTitle = Self.clean(dailyTitle)
        self.scriptureReference = Self.clean(scriptureReference)
        self.reflectionExcerpt = Self.excerpt(reflectionExcerpt)
        self.plantProgressText = Self.clean(plantProgressText)
        self.prayerConcern = Self.clean(prayerConcern)
    }

    var hasPreview: Bool {
        journeyTitle != nil || dailyTitle != nil || scriptureReference != nil || reflectionExcerpt != nil || prayerConcern != nil
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func excerpt(_ value: String?) -> String? {
        guard let clean = clean(value) else { return nil }
        guard clean.count > 150 else { return clean }
        let index = clean.index(clean.startIndex, offsetBy: 147)
        return String(clean[..<index]).trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
}

enum PaywallPricingCopy {
    static func standardTrustLine(annualPrice: String?, monthlyPrice: String?) -> String {
        let annual = clean(annualPrice)
        let monthly = clean(monthlyPrice)
        if let annual, let monthly {
            let format = L10n.string(
                "paywall.trust_line.with_prices",
                default: "Then continue for %@/year or %@/month. Cancel anytime."
            )
            return String(format: format, annual, monthly)
        }
        return L10n.string(
            "paywall.trust_line.generic",
            default: "Cancel anytime in Settings."
        )
    }

    static func downsellOfferLine(introPrice: String?, basePrice: String?) -> String {
        let intro = clean(introPrice)
        let base = clean(basePrice)
        if let intro, let base {
            let format = L10n.string(
                "downsell.offer_line.with_prices",
                default: "First 3 months at %@/month, then %@/month. Cancel anytime."
            )
            return String(format: format, intro, base)
        }
        return L10n.string(
            "downsell.offer_line.generic",
            default: "A limited-time monthly offer is available. Cancel anytime."
        )
    }

    private static func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum DownsellPresentationPolicy {
    static func shouldPresent(
        profileExists: Bool,
        hasEligibleOffer: Bool,
        alreadyShownThisForegroundSession: Bool,
        isStandardPaywallPresented: Bool
    ) -> Bool {
        profileExists && hasEligibleOffer && !alreadyShownThisForegroundSession && !isStandardPaywallPresented
    }
}

struct PaywallView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let triggerReason: String?
    let isPremium: Bool
    let copyOverride: PaywallRemoteConfig?
    let personalizationContext: PaywallPersonalizationContext?

    @State private var selectedProductID: String?
    @State private var isPurchasing = false
    @State private var isRestoring = false

    private let analytics: AnalyticsTracking

    init(
        triggerReason: String?,
        isPremium: Bool,
        copyOverride: PaywallRemoteConfig? = nil,
        personalizationContext: PaywallPersonalizationContext? = nil,
        analytics: AnalyticsTracking = AnalyticsServiceFactory.makeDefault()
    ) {
        self.triggerReason = triggerReason
        self.isPremium = isPremium
        self.copyOverride = copyOverride
        self.personalizationContext = personalizationContext
        self.analytics = analytics
    }

    private var paywallConfig: PaywallRemoteConfig {
        copyOverride ?? subscriptionService.paywallConfig
    }

    private var isDismissOfferPaywall: Bool {
        triggerReason == PaywallTriggerReason.paywallDismissOffer.rawValue
    }

    private var paywallVariant: String {
        if triggerReason == PaywallTriggerReason.onboardingCompletion.rawValue {
            return "onboarding_hard"
        }
        if triggerReason == PaywallTriggerReason.paywallDismissOffer.rawValue {
            return "dismiss_offer"
        }
        return "standard_personalized"
    }

    private var eventBaseProperties: [String: String] {
        [
            "paywall_variant": paywallVariant,
            "trigger_reason": triggerReason ?? "unspecified",
            "is_downsell": "false",
            "has_personalized_preview": personalizationContext?.hasPreview == true ? "true" : "false"
        ]
    }

    var body: some View {
        ZStack {
            WWColor.white
                .ignoresSafeArea()

            GeometryReader { geometry in
                let compact = geometry.size.height <= 760

                VStack(spacing: compact ? 10 : 14) {
                    header
                    heroCopy(compact: compact)

                    PaywallJourneyCard(
                        context: personalizationContext,
                        label: L10n.string("paywall.preview.label", default: "Your Journey"),
                        supportingText: L10n.string("paywall.preview.supporting", default: "Tomorrow’s Tend is ready when you are.")
                    )

                    packageSelector(compact: compact)

                    if let specialOfferPricingLine {
                        Text(specialOfferPricingLine)
                            .font(WWTypography.caption(12))
                            .foregroundStyle(WWColor.muted)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }

                    primaryButton

                    VStack(spacing: 6) {
                        Text(standardTrustLine)
                            .font(WWTypography.caption(12))
                            .foregroundStyle(WWColor.muted)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        if let errorMessage = subscriptionService.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(WWTypography.caption(12))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .minimumScaleFactor(0.82)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    footerLinks
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

            let isSelectedStillValid = selectableProducts.contains(where: { $0.id == selectedProductID })
            if !isSelectedStillValid {
                self.selectedProductID = defaultProductIDForCurrentPaywall()
            }
        }
        .onChange(of: subscriptionService.isPremium) { _, premium in
            if premium {
                dismiss()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text(L10n.string("paywall.label", default: "Tend Premium"))
                .font(WWTypography.caption(13))
                .foregroundStyle(WWColor.growGreen)
                .textCase(.uppercase)
                .tracking(0.8)

            Spacer()

            if paywallConfig.isDismissable {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(WWColor.muted)
                        .frame(width: 34, height: 34)
                        .background(WWColor.surface, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.string("common.close", default: "Close"))
            }
        }
    }

    private func heroCopy(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            Text(paywallConfig.headline)
                .font(WWTypography.display(compact ? 40 : 44))
                .foregroundStyle(WWColor.nearBlack)
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(paywallConfig.subheadline)
                .font(WWTypography.body(compact ? 15 : 16))
                .foregroundStyle(WWColor.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func packageSelector(compact: Bool) -> some View {
        VStack(spacing: compact ? 8 : 10) {
            if subscriptionService.isLoadingProducts && selectableProducts.isEmpty {
                ProgressView(L10n.string("paywall.loading_plans", default: "Loading plans…"))
                    .font(WWTypography.body(15))
                    .foregroundStyle(WWColor.nearBlack)
                    .padding(.vertical, 18)
            } else {
                ForEach(selectableProducts) { product in
                    planRow(for: product, compact: compact)
                }
            }
        }
    }

    private func planRow(for product: SubscriptionDisplayProduct, compact: Bool) -> some View {
        let isSelected = product.id == selectedProductID
        let isAnnual = isAnnualProduct(product)

        return Button {
            let didChange = selectedProductID != product.id
            selectedProductID = product.id

            guard didChange else { return }

            var properties = eventBaseProperties
            properties["selected_plan"] = selectedPlanToken(for: product)
            analytics.track(.paywallPlanSelected, properties: properties)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 18 : 20, weight: .semibold))
                    .foregroundStyle(isSelected ? WWColor.growGreen : WWColor.muted)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(planTitle(for: product))
                            .font(WWTypography.heading(compact ? 19 : 21))
                            .foregroundStyle(WWColor.nearBlack)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        if isAnnual, let annualBadge = paywallConfig.annualBadgeText, !annualBadge.isEmpty {
                            Text(annualBadge)
                                .font(WWTypography.caption(10))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(WWColor.growGreen, in: Capsule())
                        }
                    }

                    Text(periodSubtitle(for: product))
                        .font(WWTypography.caption(12))
                        .foregroundStyle(WWColor.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                Text(priceCaption(for: product))
                    .font(WWTypography.heading(compact ? 18 : 19))
                    .foregroundStyle(WWColor.nearBlack)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, compact ? 11 : 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WWColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? WWColor.growGreen : WWColor.muted.opacity(0.26), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(
                format: L10n.string("paywall.plan.accessibility_label", default: "%@, %@, %@"),
                planTitle(for: product),
                priceCaption(for: product),
                periodSubtitle(for: product)
            )
        )
        .accessibilityValue(isSelected ? L10n.string("tab.selected", default: "Selected") : "")
        .accessibilityHint(L10n.string("paywall.plan.select_hint", default: "Double-tap to select this plan."))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var primaryButton: some View {
        Button {
            let selectedPlan = selectedPlanToken(for: selectedProduct)
            var properties = eventBaseProperties
            properties["selected_plan"] = selectedPlan
            analytics.track(.paywallCTATapped, properties: properties)

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
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
            }
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(WWColor.growGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(selectedProductID == nil || isPurchasing || isRestoring || selectableProducts.isEmpty)
        .opacity((selectedProductID == nil || isPurchasing || isRestoring || selectableProducts.isEmpty) ? 0.65 : 1)
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
            .frame(minHeight: 36)

            Button(L10n.string("paywall.footer.terms", default: "Terms")) {
                openURL(URL(string: AppConstants.termsURL)!)
            }
            .buttonStyle(.plain)
            .font(WWTypography.caption(14))
            .frame(minHeight: 36)

            Button(L10n.string("paywall.footer.privacy", default: "Privacy")) {
                openURL(URL(string: AppConstants.privacyURL)!)
            }
            .buttonStyle(.plain)
            .font(WWTypography.caption(14))
            .frame(minHeight: 36)
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

    private var selectedProduct: SubscriptionDisplayProduct? {
        guard let selectedProductID else { return nil }
        return selectableProducts.first(where: { $0.id == selectedProductID })
    }

    private func selectedPlanToken(for product: SubscriptionDisplayProduct?) -> String {
        guard let product else { return "unknown" }
        if isAnnualProduct(product) { return "annual" }
        if isMonthlyProduct(product) { return "monthly" }
        return "subscription"
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
            return L10n.string("paywall.plan.annual_subtitle", default: "Best value")
        case L10n.string("paywall.plan.monthly", default: "Monthly"):
            return L10n.string("paywall.plan.monthly_subtitle", default: "Flexible")
        case L10n.string("paywall.plan.weekly", default: "Weekly"):
            return L10n.string("paywall.plan.billed_weekly", default: "Billed weekly")
        case L10n.string("paywall.plan.daily", default: "Daily"):
            return L10n.string("paywall.plan.billed_daily", default: "Billed daily")
        default:
            return L10n.string("paywall.plan.recurring", default: "Recurring subscription")
        }
    }

    private func priceCaption(for product: SubscriptionDisplayProduct) -> String {
        if let discounted = annualDiscountedPriceCaption(for: product) {
            return discounted
        }
        return product.displayPrice
    }

    private var specialOfferPricingLine: String? {
        guard isDismissOfferPaywall else { return nil }
        guard let annualProduct = selectableProducts.first(where: isAnnualProduct) else { return nil }
        guard let discounted = annualDiscountedPriceCaption(for: annualProduct) else { return nil }
        let base = annualBasePriceCaption(for: annualProduct) ?? annualProduct.displayPrice
        let format = L10n.string(
            "paywall.dismiss_offer.price_line",
            default: "%@ for your first year, then %@ each year."
        )
        return String(format: format, discounted, base)
    }

    private var standardTrustLine: String {
        let annualPrice = selectableProducts.first(where: isAnnualProduct)?.displayPrice
        let monthlyPrice = selectableProducts.first(where: isMonthlyProduct)?.displayPrice
        return PaywallPricingCopy.standardTrustLine(annualPrice: annualPrice, monthlyPrice: monthlyPrice)
    }

    private var selectableProducts: [SubscriptionDisplayProduct] {
        let annual = subscriptionService.products.first(where: isAnnualProduct)
        let monthly = subscriptionService.products.first(where: isMonthlyProduct)

        let focused = [annual, monthly].compactMap { $0 }
        if !focused.isEmpty {
            return focused
        }

        return subscriptionService.products.sorted { lhs, rhs in
            if isAnnualProduct(lhs) != isAnnualProduct(rhs) {
                return isAnnualProduct(lhs)
            }
            if isMonthlyProduct(lhs) != isMonthlyProduct(rhs) {
                return isMonthlyProduct(lhs)
            }
            return lhs.displayPrice < rhs.displayPrice
        }
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
            if let annualFallback = selectableProducts.first(where: isAnnualProduct)?.id {
                return annualFallback
            }
        }

        if let configured = subscriptionService.defaultPaywallProductID(),
           selectableProducts.contains(where: { $0.id == configured }) {
            return configured
        }

        return selectableProducts.first?.id
    }

    private func isAnnualProduct(_ product: SubscriptionDisplayProduct) -> Bool {
        let period = product.periodLabel.lowercased()
        let identifier = product.id.lowercased()
        return period.contains("year") || identifier.contains("annual")
    }

    private func isMonthlyProduct(_ product: SubscriptionDisplayProduct) -> Bool {
        let period = product.periodLabel.lowercased()
        let identifier = product.id.lowercased()
        return period.contains("month") || identifier.contains("monthly")
    }
}

private struct PaywallJourneyCard: View {
    let context: PaywallPersonalizationContext?
    let label: String
    let supportingText: String

    private var journeyTitle: String {
        context?.journeyTitle
            ?? context?.prayerConcern
            ?? L10n.string("paywall.preview.fallback_title", default: "Your prayer journey")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(WWTypography.caption(12))
                .foregroundStyle(WWColor.growGreen)
                .textCase(.uppercase)
                .tracking(0.7)

            Text(journeyTitle)
                .font(WWTypography.heading(24))
                .foregroundStyle(WWColor.nearBlack)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            Text(supportingText)
                .font(WWTypography.caption(13))
                .foregroundStyle(WWColor.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(WWColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(WWColor.growGreen.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

struct DownsellPaywallView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let personalizationContext: PaywallPersonalizationContext?

    @State private var isPurchasing = false
    @State private var hasTrackedDefaultPlanSelection = false

    private let analytics: AnalyticsTracking

    init(
        personalizationContext: PaywallPersonalizationContext? = nil,
        analytics: AnalyticsTracking = AnalyticsServiceFactory.makeDefault()
    ) {
        self.personalizationContext = personalizationContext
        self.analytics = analytics
    }

    var body: some View {
        ZStack {
            WWColor.white.ignoresSafeArea()

            GeometryReader { geometry in
                let compact = geometry.size.height <= 760

                VStack(spacing: compact ? 10 : 14) {
                    header

                    heroCopy(compact: compact)

                    PaywallJourneyCard(
                        context: personalizationContext,
                        label: L10n.string("paywall.preview.label", default: "Your Journey"),
                        supportingText: L10n.string("downsell.preview.supporting", default: "Don’t lose what you’ve started. Tomorrow’s Tend is ready.")
                    )

                    downsellOfferCard

                    ctaButton

                    VStack(spacing: 6) {
                        Text(offerLine)
                            .font(WWTypography.caption(12))
                            .foregroundStyle(WWColor.muted)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)

                        if let errorMessage = subscriptionService.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(WWTypography.caption(12))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .minimumScaleFactor(0.82)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    footerLinks
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 12))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .task {
            await subscriptionService.loadProducts()
            await subscriptionService.refreshEntitlements()
            trackDefaultPlanSelectionIfNeeded()
        }
        .onChange(of: subscriptionService.isPremium) { _, premium in
            if premium {
                dismiss()
            }
        }
        .onChange(of: subscriptionService.hasEligibleDownsellOffer) { _, isAvailable in
            if !isAvailable {
                dismiss()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text(L10n.string("paywall.label", default: "Tend Premium"))
                .font(WWTypography.caption(13))
                .foregroundStyle(WWColor.growGreen)
                .textCase(.uppercase)
                .tracking(0.8)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(WWColor.muted)
                    .frame(width: 34, height: 34)
                    .background(WWColor.surface, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.string("common.close", default: "Close"))
        }
    }

    private func heroCopy(compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: compact ? 6 : 8) {
            Text(L10n.string("downsell.headline", default: "Keep tending what you started."))
                .font(WWTypography.display(compact ? 38 : 42))
                .foregroundStyle(WWColor.nearBlack)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text(L10n.string("downsell.body", default: "Your trial is still active. Keep your personalized daily prayer journey going without losing momentum."))
                .font(WWTypography.body(compact ? 15 : 16))
                .foregroundStyle(WWColor.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var downsellOfferCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L10n.string("downsell.plan.title", default: "Limited Renewal Offer"))
                .font(WWTypography.heading(19))
                .foregroundStyle(WWColor.nearBlack)

            Text(downsellPlanPriceLine)
                .font(WWTypography.caption(13))
                .foregroundStyle(WWColor.muted)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(WWColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(WWColor.growGreen.opacity(0.16), lineWidth: 1)
        )
    }

    private var ctaButton: some View {
        Button {
            var properties = eventBaseProperties
            properties["selected_plan"] = "downsell_intro_monthly"
            analytics.track(.paywallCTATapped, properties: properties)

            Task { await purchase() }
        } label: {
            HStack {
                Spacer()
                if isPurchasing {
                    ProgressView().tint(.white)
                } else {
                    Text(L10n.string("downsell.cta.keep_going", default: "Keep My Journey Going"))
                        .font(WWTypography.heading(20))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                Spacer()
            }
            .padding(.vertical, 15)
            .foregroundStyle(.white)
            .background(WWColor.growGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing || !subscriptionService.hasEligibleDownsellOffer)
        .opacity((isPurchasing || !subscriptionService.hasEligibleDownsellOffer) ? 0.65 : 1)
        .accessibilityHint(L10n.string("downsell.cta.hint", default: "Purchases the limited-time renewal offer."))
    }

    private var footerLinks: some View {
        HStack(spacing: 20) {
            Button(L10n.string("settings.subscription.restore", default: "Restore Purchases")) {
                Task { await subscriptionService.restorePurchases() }
            }
            .buttonStyle(.plain)
            .font(WWTypography.caption(14))
            .frame(minHeight: 36)

            Button(L10n.string("paywall.footer.terms", default: "Terms")) {
                openURL(URL(string: AppConstants.termsURL)!)
            }
            .buttonStyle(.plain)
            .font(WWTypography.caption(14))
            .frame(minHeight: 36)

            Button(L10n.string("paywall.footer.privacy", default: "Privacy")) {
                openURL(URL(string: AppConstants.privacyURL)!)
            }
            .buttonStyle(.plain)
            .font(WWTypography.caption(14))
            .frame(minHeight: 36)
        }
        .foregroundStyle(WWColor.muted)
    }

    private var downsellPlanPriceLine: String {
        let intro = subscriptionService.downsellOfferSummary?.introPriceLabel ?? L10n.string("downsell.price.fallback_intro", default: "$2.99")
        let base = subscriptionService.downsellOfferSummary?.basePriceLabel
            ?? subscriptionService.monthlyProduct?.displayPrice
            ?? AppConstants.Subscription.monthlyDisplayFallback

        let format = L10n.string(
            "downsell.plan.price_line",
            default: "%@/month for 3 months, then %@/month"
        )
        return String(format: format, intro, base)
    }

    private var offerLine: String {
        PaywallPricingCopy.downsellOfferLine(
            introPrice: subscriptionService.downsellOfferSummary?.introPriceLabel,
            basePrice: subscriptionService.downsellOfferSummary?.basePriceLabel
        )
    }

    private var eventBaseProperties: [String: String] {
        [
            "paywall_variant": "downsell_personalized",
            "trigger_reason": "trial_cancel_downsell",
            "is_downsell": "true",
            "has_personalized_preview": personalizationContext?.hasPreview == true ? "true" : "false"
        ]
    }

    private func trackDefaultPlanSelectionIfNeeded() {
        guard !hasTrackedDefaultPlanSelection else { return }
        hasTrackedDefaultPlanSelection = true

        var properties = eventBaseProperties
        properties["selected_plan"] = "downsell_intro_monthly"
        analytics.track(.paywallPlanSelected, properties: properties)
    }

    private func purchase() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        await subscriptionService.purchaseDownsellOffer()

        if subscriptionService.isPremium {
            analytics.track(
                .downsellPurchased,
                properties: [
                    "paywall_variant": "downsell_personalized",
                    "trigger_reason": "trial_cancel_downsell",
                    "has_personalized_preview": personalizationContext?.hasPreview == true ? "true" : "false"
                ]
            )
        }
    }
}
