import Foundation
import RevenueCat

struct SubscriptionDisplayProduct: Identifiable, Equatable {
    let id: String
    let displayPrice: String
    let periodLabel: String
}

@MainActor
final class SubscriptionService: ObservableObject {
    @Published private(set) var products: [SubscriptionDisplayProduct] = []
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var diagnostics: [String] = []
    @Published var errorMessage: String?

    private let productIDs = [
        AppConstants.Subscription.weeklyProductID,
        AppConstants.Subscription.annualProductID
    ]
    private var storeProductsByID: [String: StoreProduct] = [:]

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
            let currentIdentifier = offerings.current?.identifier ?? "none"
            let allOfferingIdentifiers = offerings.all.keys.sorted()
            let sourceProducts = offerings.current?.availablePackages.map(\.storeProduct)
                ?? offerings.all.values.flatMap { $0.availablePackages.map(\.storeProduct) }
            let deduped = dedupeStoreProducts(sourceProducts)
            let filtered = deduped.filter { productIDs.contains($0.productIdentifier) }

            storeProductsByID = Dictionary(uniqueKeysWithValues: filtered.map { ($0.productIdentifier, $0) })

            let order = Dictionary(uniqueKeysWithValues: productIDs.enumerated().map { ($1, $0) })
            products = filtered
                .map {
                    SubscriptionDisplayProduct(
                        id: $0.productIdentifier,
                        displayPrice: $0.localizedPriceString,
                        periodLabel: $0.subscriptionPeriod?.debugLabel ?? "term"
                    )
                }
                .sorted { order[$0.id, default: .max] < order[$1.id, default: .max] }

            diagnostics = [
                "Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")",
                "RC App User ID: \(Purchases.shared.appUserID)",
                "Current offering: \(currentIdentifier)",
                "Offerings: \(allOfferingIdentifiers.joined(separator: ", "))",
                "Fetched product IDs: \(filtered.map(\.productIdentifier).joined(separator: ", "))",
                "Environment: \(runtimeEnvironmentLabel)"
            ]

            if products.isEmpty {
                errorMessage = "No RevenueCat products found in the current offering."
            }
        } catch {
            errorMessage = "Unable to load subscription products from RevenueCat: \(error.localizedDescription)\n\(troubleshootingHint)"
            diagnostics = [
                "Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")",
                "RC App User ID: \(Purchases.shared.appUserID)",
                "Expected product IDs: \(productIDs.joined(separator: ", "))",
                "Entitlement ID: \(AppConstants.Subscription.revenueCatEntitlementID)",
                "Environment: \(runtimeEnvironmentLabel)"
            ]
        }
    }

    var weeklyProduct: SubscriptionDisplayProduct? {
        products.first(where: { $0.id == AppConstants.Subscription.weeklyProductID })
    }

    var annualProduct: SubscriptionDisplayProduct? {
        products.first(where: { $0.id == AppConstants.Subscription.annualProductID })
    }

    func purchaseAnnualSubscription() async {
        let preferredID = annualProduct?.id ?? weeklyProduct?.id
        guard let preferredID else {
            errorMessage = "No subscription product is currently available."
            return
        }
        await purchase(productID: preferredID)
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
            isPremium = hasPremiumEntitlement(customerInfo: customerInfo)
        } catch {
            errorMessage = "Unable to refresh subscription status: \(error.localizedDescription)"
        }
    }

    private func configureRevenueCatIfNeeded() -> Bool {
        let apiKey = AppConstants.Subscription.revenueCatPublicSDKKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else {
            errorMessage = "RevenueCat API key is missing."
            diagnostics = ["RevenueCat key missing in Info.plist/xcconfig."]
            return false
        }
        if !Purchases.isConfigured {
            Purchases.configure(withAPIKey: apiKey)
        }
        return true
    }

    private func hasPremiumEntitlement(customerInfo: CustomerInfo) -> Bool {
        let entitlementID = AppConstants.Subscription.revenueCatEntitlementID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !entitlementID.isEmpty, let entitlement = customerInfo.entitlements[entitlementID] {
            return entitlement.isActive
        }
        return !customerInfo.entitlements.active.isEmpty
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
