import Foundation
import RevenueCat

private enum SubscriptionLocalization {
    static func string(_ key: String, default defaultValue: String) -> String {
        L10n.string(key, default: defaultValue)
    }
}

struct SubscriptionDisplayProduct: Identifiable, Equatable {
    let id: String
    let displayPrice: String
    let priceAmount: Decimal
    let currencyCode: String?
    let periodLabel: String
}

struct DownsellOfferSummary: Equatable {
    let introPriceLabel: String
    let basePriceLabel: String
    let offerIdentifier: String?
}

struct PaywallRemoteConfig: Equatable {
    let headline: String
    let subheadline: String
    let ctaTitle: String
    let annualBadgeText: String?
    let footnote: String
    let defaultPackageToken: String
    let isDismissable: Bool

    static var `default`: PaywallRemoteConfig {
        PaywallRemoteConfig(
            headline: SubscriptionLocalization.string("paywall.default.headline", default: "Keep tending what you're facing."),
            subheadline: SubscriptionLocalization.string("paywall.default.subheadline", default: "Continue your personalized prayer journey with Scripture, reflection, prayer, and one small step each day."),
            ctaTitle: SubscriptionLocalization.string("paywall.default.cta", default: "Start 3-Day Free Trial"),
            annualBadgeText: SubscriptionLocalization.string("paywall.default.badge", default: "Best Value"),
            footnote: SubscriptionLocalization.string("paywall.default.footnote", default: "Restore purchases, terms, and privacy are always available below."),
            defaultPackageToken: "annual",
            isDismissable: false
        )
    }

    static var resubscribe: PaywallRemoteConfig {
        PaywallRemoteConfig(
            headline: SubscriptionLocalization.string("paywall.resubscribe.headline", default: "Pick up where you left off."),
            subheadline: SubscriptionLocalization.string("paywall.resubscribe.subheadline", default: "Resubscribe to Tend Premium to continue your journey."),
            ctaTitle: SubscriptionLocalization.string("paywall.resubscribe.cta", default: "Resubscribe"),
            annualBadgeText: SubscriptionLocalization.string("paywall.default.badge", default: "Best Value"),
            footnote: SubscriptionLocalization.string("paywall.resubscribe.footnote", default: "Auto-renews unless canceled in Settings."),
            defaultPackageToken: "annual",
            isDismissable: true
        )
    }

    static func onboardingHardGate(from base: PaywallRemoteConfig) -> PaywallRemoteConfig {
        PaywallRemoteConfig(
            headline: base.headline,
            subheadline: base.subheadline,
            ctaTitle: base.ctaTitle,
            annualBadgeText: base.annualBadgeText,
            footnote: base.footnote,
            defaultPackageToken: base.defaultPackageToken,
            isDismissable: false
        )
    }
}

@MainActor
final class SubscriptionService: NSObject, ObservableObject {
    private static let pinnedOfferingIdentifier = "default"

    @Published private(set) var products: [SubscriptionDisplayProduct] = []
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var currentOfferingIdentifier: String?
    @Published private(set) var currentOfferingMetadataSummary: String = "{}"
    @Published private(set) var paywallMode: PaywallMode = .disabled
    @Published private(set) var paywallConfig: PaywallRemoteConfig = .default
    @Published private(set) var diagnostics: [String] = []
    @Published private(set) var isTrialActiveNonRenewing = false
    @Published private(set) var isLapsedSubscriber = false
    @Published private(set) var trialExpirationDate: Date?
    @Published private(set) var downsellOfferSummary: DownsellOfferSummary?
    @Published var errorMessage: String?

    private let productIDs = [
        AppConstants.Subscription.monthlyProductID,
        AppConstants.Subscription.annualProductID
    ]
    private var storeProductsByID: [String: StoreProduct] = [:]
    private var downsellPromotionalOffer: PromotionalOffer?
    private var isResolvingDownsellOffer = false

    func initialize() async {
        _ = configureRevenueCatIfNeeded()
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        guard configureRevenueCatIfNeeded() else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let offerings = try await Purchases.shared.offerings()
            let experimentAssignedOffering = offerings.current
            let selectedOffering = offerings.all[Self.pinnedOfferingIdentifier] ?? experimentAssignedOffering
            let selectedIdentifier = selectedOffering?.identifier ?? "none"
            let experimentIdentifier = experimentAssignedOffering?.identifier ?? "none"

            currentOfferingIdentifier = selectedOffering?.identifier
            currentOfferingMetadataSummary = metadataSummary(from: selectedOffering)
            paywallMode = resolvePaywallMode(from: selectedOffering)
            let allOfferingIdentifiers = offerings.all.keys.sorted()
            let sourcePackages = selectedOffering?.availablePackages
                ?? offerings.all.values.flatMap(\.availablePackages)
            let sourceProducts = sourcePackages.map(\.storeProduct)
            let deduped = dedupeStoreProducts(sourceProducts)
            let filteredByKnownIDs = deduped.filter { productIDs.contains($0.productIdentifier) }
            let filtered = filteredByKnownIDs.isEmpty ? deduped : filteredByKnownIDs

            storeProductsByID = Dictionary(uniqueKeysWithValues: filtered.map { ($0.productIdentifier, $0) })
            paywallConfig = await resolvePaywallConfig(from: selectedOffering)

            let order = Dictionary(uniqueKeysWithValues: productIDs.enumerated().map { ($1, $0) })
            products = filtered
                .map {
                    SubscriptionDisplayProduct(
                        id: $0.productIdentifier,
                        displayPrice: $0.localizedPriceString,
                        priceAmount: $0.price,
                        currencyCode: $0.currencyCode,
                        periodLabel: $0.subscriptionPeriod?.debugLabel ?? "term"
                    )
                }
                .sorted { lhs, rhs in
                    let lhsOrder = order[lhs.id]
                    let rhsOrder = order[rhs.id]
                    if let lhsOrder, let rhsOrder {
                        return lhsOrder < rhsOrder
                    }
                    return sortPriority(for: lhs) < sortPriority(for: rhs)
                }

            diagnostics = [
                "Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")",
                "RC App User ID: \(Purchases.shared.appUserID)",
                "App-selected offering: \(selectedIdentifier)",
                "RevenueCat current offering: \(experimentIdentifier)",
                "Pinned offering: \(Self.pinnedOfferingIdentifier)",
                "Paywall mode: \(paywallMode.rawValue)",
                "Paywall dismissable: \(paywallConfig.isDismissable ? "true" : "false")",
                "Offering metadata: \(currentOfferingMetadataSummary)",
                "Offerings: \(allOfferingIdentifiers.joined(separator: ", "))",
                "Fetched product IDs: \(filtered.map(\.productIdentifier).joined(separator: ", "))",
                "Downsell offer: \(downsellOfferSummary?.offerIdentifier ?? "none")",
                "Environment: \(runtimeEnvironmentLabel)"
            ]

            if products.isEmpty {
                errorMessage = SubscriptionLocalization.string(
                    "paywall.error.no_products",
                    default: "No RevenueCat products found in the current offering."
                )
            }

            await refreshDownsellOfferIfNeeded()
        } catch {
            errorMessage = "Unable to load subscription products from RevenueCat: \(error.localizedDescription)\n\(troubleshootingHint)"
            paywallMode = .disabled
            currentOfferingIdentifier = nil
            currentOfferingMetadataSummary = "{}"
            paywallConfig = .default
            clearDownsellOffer()
            diagnostics = [
                "Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")",
                "RC App User ID: \(Purchases.shared.appUserID)",
                "Expected product IDs: \(productIDs.joined(separator: ", "))",
                "Entitlement ID: \(AppConstants.Subscription.revenueCatEntitlementID)",
                "Environment: \(runtimeEnvironmentLabel)"
            ]
        }
    }

    var monthlyProduct: SubscriptionDisplayProduct? {
        products.first(where: { $0.id == AppConstants.Subscription.monthlyProductID })
    }

    var annualProduct: SubscriptionDisplayProduct? {
        products.first(where: { $0.id == AppConstants.Subscription.annualProductID })
    }

    func defaultPaywallProductID() -> String? {
        if let explicit = productID(matching: paywallConfig.defaultPackageToken) {
            return explicit
        }
        if let annualID = annualLikeProduct()?.id {
            return annualID
        }
        if let monthlyID = monthlyLikeProduct()?.id {
            return monthlyID
        }
        if let weeklyID = weeklyLikeProduct()?.id {
            return weeklyID
        }
        return products.first?.id
    }

    func purchaseAnnualSubscription() async {
        let preferredID = annualProduct?.id ?? monthlyProduct?.id ?? weeklyLikeProduct()?.id
        guard let preferredID else {
            errorMessage = "No subscription product is currently available."
            return
        }
        await purchase(productID: preferredID)
    }

    var hasEligibleDownsellOffer: Bool {
        isTrialActiveNonRenewing && downsellOfferSummary != nil
    }

    var downsellSettingsButtonTitle: String {
        if let introPrice = downsellOfferSummary?.introPriceLabel {
            let format = SubscriptionLocalization.string("downsell.settings.renew_with_price", default: "Renew for %@ / mo")
            return String(format: format, introPrice)
        }
        return SubscriptionLocalization.string("downsell.settings.renew_generic", default: "Renew with intro offer")
    }

    func purchase(productID: String) async {
        guard configureRevenueCatIfNeeded() else { return }
        guard let storeProduct = storeProductsByID[productID] else {
            errorMessage = "Selected subscription option is unavailable."
            return
        }

        do {
            let purchaseResult = try await Purchases.shared.purchase(product: storeProduct)
            if purchaseResult.userCancelled {
                return
            }
            isPremium = hasPremiumEntitlement(customerInfo: purchaseResult.customerInfo)
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func purchaseDownsellOffer() async {
        guard configureRevenueCatIfNeeded() else { return }
        guard let monthlyStoreProduct = monthlyLikeProductStore() else {
            errorMessage = "Monthly subscription is unavailable."
            return
        }
        guard let promotionalOffer = downsellPromotionalOffer else {
            errorMessage = "This renewal offer is currently unavailable. Please try again in a moment."
            return
        }

        do {
            let result = try await Purchases.shared.purchase(product: monthlyStoreProduct, promotionalOffer: promotionalOffer)

            if result.userCancelled {
                return
            }

            apply(customerInfo: result.customerInfo)
        } catch {
            errorMessage = "Downsell purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        guard configureRevenueCatIfNeeded() else { return }
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            isPremium = hasPremiumEntitlement(customerInfo: customerInfo)
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        guard configureRevenueCatIfNeeded() else { return }
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            apply(customerInfo: customerInfo)
        } catch {
            errorMessage = "Unable to refresh subscription status: \(error.localizedDescription)"
        }
    }

    func apply(customerInfo: CustomerInfo) {
        isPremium = hasPremiumEntitlement(customerInfo: customerInfo)

        let entitlement = premiumEntitlement(from: customerInfo)
        let isTrialNonRenewing = entitlement?.isActive == true
            && entitlement?.periodType == .trial
            && entitlement?.willRenew == false
        let isLapsed = entitlement?.isActive == false
            && entitlement?.expirationDate != nil
            && (entitlement?.expirationDate ?? .distantFuture) <= .now

        isTrialActiveNonRenewing = isTrialNonRenewing
        isLapsedSubscriber = isLapsed
        trialExpirationDate = entitlement?.expirationDate

        if isTrialNonRenewing {
            Task { await refreshDownsellOfferIfNeeded() }
        } else {
            clearDownsellOffer()
        }
    }

    private func configureRevenueCatIfNeeded() -> Bool {
        let apiKey = AppConstants.Subscription.revenueCatPublicSDKKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            errorMessage = "RevenueCat API key is missing."
            paywallMode = .disabled
            currentOfferingIdentifier = nil
            diagnostics = ["RevenueCat key missing in Info.plist/xcconfig."]
            return false
        }
        if !Purchases.isConfigured {
            Purchases.configure(withAPIKey: apiKey)
        }
        Purchases.shared.delegate = self
        return true
    }

    private func hasPremiumEntitlement(customerInfo: CustomerInfo) -> Bool {
        if let entitlement = premiumEntitlement(from: customerInfo) {
            return entitlement.isActive
        }
        return !customerInfo.entitlements.active.isEmpty
    }

    private func premiumEntitlement(from customerInfo: CustomerInfo) -> EntitlementInfo? {
        let entitlementID = AppConstants.Subscription.revenueCatEntitlementID
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !entitlementID.isEmpty else { return nil }
        return customerInfo.entitlements[entitlementID]
    }

    private var troubleshootingHint: String {
        if runtimeEnvironmentLabel == "Simulator" {
            return "Live App Store products are often unavailable in Simulator. Test on a physical iPhone signed into Sandbox Apple account."
        }
        return "Check App Store Connect agreements, product status (Ready to Submit/Approved), and RevenueCat In-App Purchase key configuration."
    }

    private var runtimeEnvironmentLabel: String {
#if targetEnvironment(simulator)
        return "Simulator"
#else
        return "Device"
#endif
    }

    private func dedupeStoreProducts(_ input: [StoreProduct]) -> [StoreProduct] {
        var seen = Set<String>()
        return input.filter {
            if seen.contains($0.productIdentifier) {
                return false
            }
            seen.insert($0.productIdentifier)
            return true
        }
    }

    private func resolvePaywallMode(from offering: Offering?) -> PaywallMode {
        guard let offering else { return .disabled }

        if let metadataMode: String = offering.getMetadataValue(for: "paywall_mode"),
           let mode = PaywallMode.fromRevenueCatMetadata(metadataMode) {
            return mode
        }

        if let metadataMode: String = offering.getMetadataValue(for: "paywallMode"),
           let mode = PaywallMode.fromRevenueCatMetadata(metadataMode) {
            return mode
        }

        return PaywallMode.fromRevenueCatOfferingIdentifier(offering.identifier)
    }

    private func metadataSummary(from offering: Offering?) -> String {
        guard let offering else { return "{}" }
        guard !offering.metadata.isEmpty else { return "{}" }
        if let data = try? JSONSerialization.data(withJSONObject: offering.metadata, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "\(offering.metadata)"
    }

    private func resolvePaywallConfig(from offering: Offering?) async -> PaywallRemoteConfig {
        guard offering != nil else { return .default }
        return PaywallRemoteConfig.default
    }

    private func refreshDownsellOfferIfNeeded() async {
        guard !isResolvingDownsellOffer else { return }
        guard isTrialActiveNonRenewing else {
            clearDownsellOffer()
            return
        }
        guard let monthlyStoreProduct = monthlyLikeProductStore() else {
            clearDownsellOffer()
            return
        }

        isResolvingDownsellOffer = true
        defer { isResolvingDownsellOffer = false }

        let eligibleOffers = await Purchases.shared.eligiblePromotionalOffers(forProduct: monthlyStoreProduct)
        let selected = eligibleOffers.first(where: {
            guard let identifier = $0.discount.offerIdentifier?.lowercased() else { return false }
            return identifier.contains("downsell")
        }) ?? eligibleOffers.first

        guard let selected else {
            clearDownsellOffer()
            return
        }

        downsellPromotionalOffer = selected
        let basePrice = monthlyStoreProduct.localizedPriceString
        downsellOfferSummary = DownsellOfferSummary(
            introPriceLabel: selected.discount.localizedPriceString,
            basePriceLabel: basePrice,
            offerIdentifier: selected.discount.offerIdentifier
        )
    }

    private func clearDownsellOffer() {
        downsellPromotionalOffer = nil
        downsellOfferSummary = nil
    }

    private func monthlyLikeProductStore() -> StoreProduct? {
        if let exact = storeProductsByID[AppConstants.Subscription.monthlyProductID] {
            return exact
        }
        return storeProductsByID.values.first {
            let period = $0.subscriptionPeriod?.debugLabel.lowercased() ?? ""
            let identifier = $0.productIdentifier.lowercased()
            return period.contains("month") || identifier.contains("month")
        }
    }

    private func productID(matching token: String) -> String? {
        let normalized = token
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !normalized.isEmpty else { return nil }

        if storeProductsByID.keys.contains(token) {
            return token
        }

        if normalized == "annual" || normalized == "yearly" || normalized == "year" {
            return annualLikeProduct()?.id
        }

        if normalized == "monthly" || normalized == "month" {
            return monthlyLikeProduct()?.id
        }

        if normalized == "weekly" || normalized == "week" {
            // Backward compatibility if a legacy weekly package is still returned.
            return weeklyLikeProduct()?.id
        }

        return storeProductsByID.keys.first(where: { $0.lowercased() == normalized })
    }

    private func annualLikeProduct() -> SubscriptionDisplayProduct? {
        products.first(where: { $0.periodLabel.contains("year") || $0.id.lowercased().contains("annual") })
    }

    private func weeklyLikeProduct() -> SubscriptionDisplayProduct? {
        products.first(where: { $0.periodLabel.contains("week") || $0.id.lowercased().contains("weekly") })
    }

    private func monthlyLikeProduct() -> SubscriptionDisplayProduct? {
        products.first(where: { $0.periodLabel.contains("month") || $0.id.lowercased().contains("month") })
    }

    private func sortPriority(for product: SubscriptionDisplayProduct) -> Int {
        let period = product.periodLabel.lowercased()
        if period.contains("year") { return 0 }
        if period.contains("month") { return 1 }
        if period.contains("week") { return 2 }
        if period.contains("day") { return 3 }
        return 10
    }
}

extension SubscriptionService: PurchasesDelegate {
    nonisolated func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.apply(customerInfo: customerInfo)
        }
    }
}

private extension SubscriptionPeriod {
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
