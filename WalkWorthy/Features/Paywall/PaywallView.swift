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

    init(
        triggerReason: String?,
        isPremium: Bool,
        copyOverride: PaywallRemoteConfig? = nil,
        personalizationContext: PaywallPersonalizationContext? = nil
    ) {
        self.triggerReason = triggerReason
        self.isPremium = isPremium
        self.copyOverride = copyOverride
        self.personalizationContext = personalizationContext
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
                    VStack(spacing: 12) {
                        heroCopy
                        PaywallPreviewCard(context: personalizationContext)
                        benefitsList
                        packageSelector
                        if let specialOfferPricingLine {
                            Text(specialOfferPricingLine)
                                .font(WWTypography.caption(13))
                                .foregroundStyle(WWColor.muted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        Text(standardTrustLine)
                            .font(WWTypography.caption(12))
                            .foregroundStyle(WWColor.muted)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
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
                    .padding(.top, 4)
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
                if let plantProgressText = personalizationContext?.plantProgressText {
                    Text(plantProgressText)
                        .font(WWTypography.caption(13))
                        .foregroundStyle(WWColor.growGreen)
                }
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

    private var heroCopy: some View {
        VStack(spacing: 8) {
            Text(paywallConfig.headline)
                .font(WWTypography.display(34))
                .foregroundStyle(WWColor.nearBlack)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(3)
                .minimumScaleFactor(0.72)

            Text(paywallConfig.subheadline)
                .font(WWTypography.body(17))
                .foregroundStyle(WWColor.muted)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
    }

    private var benefitsList: some View {
        VStack(spacing: 8) {
            PaywallBenefitRow(
                iconName: "sparkles",
                title: L10n.string("paywall.benefit.personalized", default: "Personalized daily Tends"),
                detail: L10n.string("paywall.benefit.personalized_detail", default: "Scripture, reflection, prayer, and one small step for this journey.")
            )
            PaywallBenefitRow(
                iconName: "bell.badge",
                title: L10n.string("paywall.benefit.rhythm", default: "Reminders, widgets, and journal"),
                detail: L10n.string("paywall.benefit.rhythm_detail", default: "Keep your prayer rhythm visible without extra friction.")
            )
            PaywallBenefitRow(
                iconName: "leaf.fill",
                title: L10n.string("paywall.benefit.growth", default: "Plant and streak growth"),
                detail: L10n.string("paywall.benefit.growth_detail", default: "See your consistency become visible over time.")
            )
        }
    }

    private var packageSelector: some View {
        VStack(spacing: 8) {
            if subscriptionService.isLoadingProducts && subscriptionService.products.isEmpty {
                ProgressView(L10n.string("paywall.loading_plans", default: "Loading plans…"))
                    .font(WWTypography.body(15))
                    .foregroundStyle(WWColor.nearBlack)
                    .padding(.vertical, 22)
            } else {
                ForEach(displayedProducts) { product in
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
            return L10n.string("paywall.plan.annual_subtitle", default: "Best value, billed yearly")
        case L10n.string("paywall.plan.monthly", default: "Monthly"):
            return L10n.string("paywall.plan.monthly_subtitle", default: "Flexible, billed monthly")
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

    private var standardTrustLine: String {
        let annualPrice = subscriptionService.products.first(where: isAnnualProduct)?.displayPrice
        let monthlyPrice = subscriptionService.products.first(where: isMonthlyProduct)?.displayPrice
        return PaywallPricingCopy.standardTrustLine(annualPrice: annualPrice, monthlyPrice: monthlyPrice)
    }

    private var displayedProducts: [SubscriptionDisplayProduct] {
        subscriptionService.products.sorted { lhs, rhs in
            if isAnnualProduct(lhs) != isAnnualProduct(rhs) {
                return isAnnualProduct(lhs)
            }
            if isMonthlyProduct(lhs) != isMonthlyProduct(rhs) {
                return isMonthlyProduct(lhs) && !isAnnualProduct(rhs)
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

    private func isMonthlyProduct(_ product: SubscriptionDisplayProduct) -> Bool {
        let period = product.periodLabel.lowercased()
        let identifier = product.id.lowercased()
        return period.contains("month") || identifier.contains("monthly")
    }
}

private struct PaywallPreviewCard: View {
    let context: PaywallPersonalizationContext?

    private var journeyTitle: String {
        context?.journeyTitle
            ?? context?.prayerConcern
            ?? L10n.string("paywall.preview.fallback_title", default: "Your prayer journey")
    }

    private var dailyTitle: String {
        context?.dailyTitle
            ?? L10n.string("paywall.preview.fallback_daily_title", default: "Today’s Tend")
    }

    private var reflectionExcerpt: String {
        context?.reflectionExcerpt
            ?? L10n.string("paywall.preview.reflection_fallback", default: "A daily reflection shaped around what you brought to prayer.")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image("paywall_hero")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 62, height: 62)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.string("paywall.preview.label", default: "Your next Tend"))
                        .font(WWTypography.caption(12))
                        .foregroundStyle(WWColor.growGreen)
                        .textCase(.uppercase)
                    Text(journeyTitle)
                        .font(WWTypography.heading(21))
                        .foregroundStyle(WWColor.nearBlack)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(dailyTitle)
                    .font(WWTypography.heading(18))
                    .foregroundStyle(WWColor.nearBlack)
                if let scriptureReference = context?.scriptureReference {
                    Text(scriptureReference)
                        .font(WWTypography.caption(13))
                        .foregroundStyle(WWColor.growGreen)
                }
                Text(reflectionExcerpt)
                    .font(WWTypography.body(15))
                    .foregroundStyle(WWColor.muted)
                    .lineLimit(4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WWColor.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(WWColor.growGreen.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}

private struct PaywallBenefitRow: View {
    let iconName: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: iconName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WWColor.growGreen)
                .frame(width: 28, height: 28)
                .background(WWColor.growGreen.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WWTypography.heading(16))
                    .foregroundStyle(WWColor.nearBlack)
                Text(detail)
                    .font(WWTypography.caption(13))
                    .foregroundStyle(WWColor.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(WWColor.surface.opacity(0.62), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct DownsellPaywallView: View {
    @EnvironmentObject private var subscriptionService: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    let personalizationContext: PaywallPersonalizationContext?
    @State private var isPurchasing = false
    private let analytics: AnalyticsTracking = AnalyticsServiceFactory.makeDefault()

    init(personalizationContext: PaywallPersonalizationContext? = nil) {
        self.personalizationContext = personalizationContext
    }

    var body: some View {
        ZStack {
            WWColor.white.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        heroCopy
                        PaywallPreviewCard(context: personalizationContext)
                        downsellBenefits
                        Text(offerLine)
                            .font(WWTypography.body(15))
                            .foregroundStyle(WWColor.nearBlack)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(WWColor.growGreen.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                        Button {
                            Task { await purchase() }
                        } label: {
                            HStack {
                                Spacer()
                                if isPurchasing {
                                    ProgressView().tint(.white)
                                } else {
                                    Text(L10n.string("downsell.cta.keep_going", default: "Keep My Journey Going"))
                                        .font(WWTypography.heading(20))
                                }
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .foregroundStyle(.white)
                            .background(WWColor.growGreen, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .disabled(isPurchasing || !subscriptionService.hasEligibleDownsellOffer)
                        .opacity((isPurchasing || !subscriptionService.hasEligibleDownsellOffer) ? 0.65 : 1)
                        .accessibilityHint(L10n.string("downsell.cta.hint", default: "Purchases the limited-time renewal offer."))

                        footerLinks

                        if let errorMessage = subscriptionService.errorMessage, !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(WWTypography.caption(13))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 24)
                }
            }
        }
        .task {
            await subscriptionService.loadProducts()
            await subscriptionService.refreshEntitlements()
        }
        .onChange(of: subscriptionService.isPremium) { _, isPremium in
            if isPremium {
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
            VStack(alignment: .leading, spacing: 2) {
                Text(AppConstants.appName)
                    .font(WWTypography.heading(20))
                    .foregroundStyle(WWColor.nearBlack)
                Text(L10n.string("downsell.subtitle", default: "You canceled your trial. This offer keeps your journey open."))
                    .font(WWTypography.body(16))
                    .foregroundStyle(WWColor.muted)
            }
            Spacer()
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
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }

    private var heroCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.string("downsell.headline", default: "Keep praying through what you started."))
                .font(WWTypography.display(34))
                .foregroundStyle(WWColor.nearBlack)
                .lineLimit(3)
                .minimumScaleFactor(0.72)
            Text(L10n.string("downsell.body", default: "Your trial is still active. This offer keeps daily Scripture, prayer, journal, reminders, and plant growth available after it ends."))
                .font(WWTypography.body(17))
                .foregroundStyle(WWColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var downsellBenefits: some View {
        VStack(spacing: 8) {
            PaywallBenefitRow(
                iconName: "book.closed.fill",
                title: L10n.string("paywall.benefit.personalized", default: "Personalized daily Tends"),
                detail: L10n.string("paywall.benefit.personalized_detail", default: "Scripture, reflection, prayer, and one small step for this journey.")
            )
            PaywallBenefitRow(
                iconName: "chart.line.uptrend.xyaxis",
                title: L10n.string("paywall.benefit.growth", default: "Plant and streak growth"),
                detail: L10n.string("paywall.benefit.growth_detail", default: "See your consistency become visible over time.")
            )
        }
    }

    private var offerLine: String {
        PaywallPricingCopy.downsellOfferLine(
            introPrice: subscriptionService.downsellOfferSummary?.introPriceLabel,
            basePrice: subscriptionService.downsellOfferSummary?.basePriceLabel
        )
    }

    private var footerLinks: some View {
        HStack(spacing: 20) {
            Button(L10n.string("settings.subscription.restore", default: "Restore Purchases")) {
                Task { await subscriptionService.restorePurchases() }
            }
            .buttonStyle(.plain)
            .font(WWTypography.caption(14))
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
