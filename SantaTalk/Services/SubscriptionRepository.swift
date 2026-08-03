import Foundation
import RevenueCat

/// The only place in the app that speaks RevenueCat.
///
/// Everything above this line — `AppState`, the paywall, the confirmation
/// screen — deals in `SubscriptionPlan`, `Bool` and plain strings, and never in
/// `Package` or `CustomerInfo`. That boundary is the point: the store is the one
/// dependency that cannot be exercised in a preview or on a simulator without
/// setup, so it lives behind a door the rest of the app does not have to open.
///
/// `Purchases.shared` is a singleton the SDK owns, so this type holds no
/// connection of its own. What it does hold is the last `CustomerInfo` it
/// fetched, because `isPro` is read on every screen change and must answer
/// without awaiting the network.
@Observable
final class SubscriptionRepository {

    /// The entitlement configured in the RevenueCat dashboard. All three plans —
    /// weekly, monthly and yearly — unlock this same one, which is why the rest
    /// of the app only ever asks "is this parent Pro?" and never "which plan did
    /// they buy?".
    ///
    /// This string must match the identifier in RevenueCat exactly. If it does
    /// not, purchases succeed and the app still shows the paywall.
    static let entitlementID = "pro"

    /// Installed once, before anything reads `Purchases.shared`. Called from
    /// `AppDelegate.didFinishLaunching` for the same reason Firebase is: the
    /// first read can happen before any view exists.
    static func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        Purchases.configure(withAPIKey: BackendConfig.revenueCatPublicKey)
    }

    /// What the last fetch said. Nil before the first one lands, which is why
    /// `isPro` is false rather than unknown at launch — a parent who has paid
    /// sees the paywall for the fraction of a second it takes to answer, and
    /// never the other way round.
    private(set) var customerInfo: CustomerInfo?

    /// Set alongside `customerInfo`. RevenueCat can tell us an entitlement was
    /// tampered with; `isPro` refuses to unlock on `.failed` rather than
    /// trusting a claim the SDK has already flagged.
    private(set) var verification: VerificationResult?

    /// The packages from the current offering, in the order RevenueCat returned
    /// them. Empty until `loadOffering()` succeeds — the paywall falls back to
    /// its hardcoded prices for exactly that window.
    private(set) var packages: [Package] = []

    /// Whether this parent has never had an introductory offer on these
    /// products. Drives whether the paywall may promise a free trial at all:
    /// promising one to somebody ineligible is a refund request waiting to
    /// happen.
    private(set) var isEligibleForIntroOffer = false

    var isPro: Bool {
        guard let customerInfo else { return false }
        return customerInfo.entitlements.active.keys.contains(Self.entitlementID)
            && verification != .failed
    }

    /// RevenueCat's id for this install. Useful in a support email when a parent
    /// says a purchase did not land.
    var customerID: String { Purchases.shared.appUserID }

    // MARK: Reading

    /// Fetches the offering and the packages inside it.
    ///
    /// `offerings.current` is what the dashboard marks as current, so the plans
    /// on the paywall can be changed without shipping a build. The named
    /// `"default"` lookup behind it is a safety net for a dashboard where no
    /// offering was marked current — without it that misconfiguration shows an
    /// empty paywall rather than a working one.
    @discardableResult
    func loadOffering() async -> Offering? {
        do {
            let offerings = try await Purchases.shared.offerings()
            let offering = offerings.current ?? offerings.all["default"]
            packages = offering?.availablePackages ?? []
            return offering
        } catch {
            packages = []
            return nil
        }
    }

    /// The package backing a plan tile, or nil if the dashboard does not offer
    /// it. A nil here is what makes a tile show its hardcoded price and refuse
    /// to be bought, rather than crashing on a force-unwrap.
    func package(for plan: SubscriptionPlan) -> Package? {
        packages.first { $0.identifier == plan.packageID }
    }

    /// Translates the loaded packages into the store-free shape the paywall
    /// reads. Plans the dashboard does not offer are simply absent, which is
    /// what makes `Pricing` fall back to its hardcoded value for them.
    func storePrices() -> [SubscriptionPlan: StorePrice] {
        var prices: [SubscriptionPlan: StorePrice] = [:]
        for plan in SubscriptionPlan.allCases {
            guard let package = package(for: plan) else { continue }
            prices[plan] = StorePrice(
                display: package.localizedPriceString,
                perWeek: plan == .week ? nil : weeklyRate(of: package, over: plan.weeksPerPeriod),
                trialDays: trialDays(of: package)
            )
        }
        return prices
    }

    /// A plan's price restated per week, formatted by the same formatter the
    /// store used for the headline price so the currency symbol, separators and
    /// placement match it exactly rather than approximating them ourselves.
    private func weeklyRate(of package: Package, over weeks: Decimal) -> String? {
        guard weeks > 0 else { return nil }
        let product = package.storeProduct
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatter?.locale ?? .current
        return formatter.string(from: (product.price / weeks) as NSDecimalNumber)
    }

    /// An introductory offer's length in days, whatever unit the product states
    /// it in. Returns nil when the product has no introductory offer at all —
    /// which is not the same as this parent having already used one.
    private func trialDays(of package: Package) -> Int? {
        guard let intro = package.storeProduct.introductoryDiscount else { return nil }
        let period = intro.subscriptionPeriod
        switch period.unit {
        case .day: return period.value
        case .week: return period.value * 7
        case .month: return period.value * 30
        case .year: return period.value * 365
        @unknown default: return period.value
        }
    }

    /// Asks the store, for every product currently on offer, whether this parent
    /// could still take an introductory price. Ineligible on any one of them is
    /// treated as ineligible overall — the paywall shows a single trial line, so
    /// a partial yes has nothing honest to say.
    func refreshIntroEligibility() async {
        let productIDs = packages.map(\.storeProduct.productIdentifier)
        guard !productIDs.isEmpty else {
            isEligibleForIntroOffer = false
            return
        }
        let statuses = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            productIdentifiers: productIDs
        )
        isEligibleForIntroOffer = statuses.values.allSatisfy { $0.status == .eligible }
    }

    /// Re-reads the entitlement. Cheap and cached by the SDK, so it is safe to
    /// call on launch and on every return to the foreground — a subscription
    /// cancelled in Settings is only visible to the app if it asks again.
    func refreshCustomerInfo() async {
        do {
            let info = try await Purchases.shared.customerInfo()
            customerInfo = info
            verification = info.entitlements.verification
        } catch {
            // Leave the last known answer standing. A network blip on Christmas
            // Eve must not put the paywall back in front of a parent who paid.
        }
    }

    // MARK: Buying

    /// The outcome of a purchase or a restore, in terms the UI can act on.
    ///
    /// `cancelled` is deliberately not an error: a parent backing out of the
    /// App Store sheet has done nothing wrong and must not see an alert.
    enum Outcome {
        case unlocked
        case cancelled
        case nothingToRestore
        case failed(String)
    }

    func purchase(_ plan: SubscriptionPlan) async -> Outcome {
        guard let package = package(for: plan) else {
            return .failed("That plan is not available right now. Please try again in a moment.")
        }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            guard !result.userCancelled else { return .cancelled }
            customerInfo = result.customerInfo
            verification = result.customerInfo.entitlements.verification
            return isPro ? .unlocked : .failed(Self.unlockFailureMessage)
        } catch {
            // Depending on where in the sheet the parent backed out, the SDK
            // reports a cancellation as a thrown error rather than as the
            // `userCancelled` flag above. Matched on domain and code rather than
            // by casting, which is the one form guaranteed to survive an SDK
            // reshuffle of its error types.
            let nsError = error as NSError
            if nsError.domain == ErrorCode.errorDomain,
               nsError.code == ErrorCode.purchaseCancelledError.rawValue {
                return .cancelled
            }
            return .failed(error.localizedDescription)
        }
    }

    func restore() async -> Outcome {
        do {
            let info = try await Purchases.shared.restorePurchases()
            customerInfo = info
            verification = info.entitlements.verification
            return isPro ? .unlocked : .nothingToRestore
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    /// Shown when the store took the money but the entitlement did not appear —
    /// almost always a dashboard misconfiguration rather than anything the
    /// parent did, so it points at support instead of asking them to retry.
    private static let unlockFailureMessage =
        "The purchase went through but Santa Pro did not unlock. "
        + "Tap Restore, or email \(SupportLinks.contactAddress) and we will sort it out."
}
