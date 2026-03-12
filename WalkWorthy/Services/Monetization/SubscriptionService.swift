import Foundation
import StoreKit

@MainActor
final class SubscriptionService: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var isLoadingProducts = false
    @Published var errorMessage: String?

    private let productIDs = [
        AppConstants.Subscription.weeklyProductID,
        AppConstants.Subscription.annualProductID
    ]

    func initialize() async {
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(for: productIDs)
            if products.isEmpty {
                errorMessage = "Subscription products not found. Check App Store Connect product IDs."
            }
        } catch {
            errorMessage = "Unable to load subscription products: \(error.localizedDescription)"
        }
    }

    var weeklyProduct: Product? {
        products.first(where: { $0.id == AppConstants.Subscription.weeklyProductID })
    }

    var annualProduct: Product? {
        products.first(where: { $0.id == AppConstants.Subscription.annualProductID })
    }

    func purchaseAnnualSubscription() async {
        let preferred = annualProduct ?? weeklyProduct
        guard let product = preferred else {
            errorMessage = "No subscription product is currently available."
            return
        }
        await purchase(product)
    }

    func purchase(productID: String) async {
        guard let product = products.first(where: { $0.id == productID }) else {
            errorMessage = "Selected subscription option is unavailable."
            return
        }
        await purchase(product)
    }

    private func purchase(_ product: Product) async {

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var premium = false

        for await verification in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(verification)
                if productIDs.contains(transaction.productID) {
                    premium = true
                }
            } catch {
                continue
            }
        }

        isPremium = premium
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe):
            return safe
        case .unverified:
            throw StoreError.failedVerification
        }
    }
}

enum StoreError: Error {
    case failedVerification
}
