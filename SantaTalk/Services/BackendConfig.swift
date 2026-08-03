import Foundation

/// Where the app looks for santa_backend.
///
/// Debug and Release both point at the deployed Worker: it is HTTPS, so the app
/// needs no App Transport Security exception, and the Simulator and a physical
/// iPhone reach it identically without a LAN address to keep in sync.
enum BackendConfig {
    static let baseURL = URL(string: "https://santa-backend.ron-mehedi.workers.dev")!

    /// Matches the SANTA_DEV_KEY secret on the deployed Worker.
    ///
    /// This is a shared secret shipped inside the binary, which means anyone who
    /// unpacks a build can mint conversation tokens and spend real credits. It is
    /// tolerable only while no build is distributed. Firebase App Check replaces
    /// it before TestFlight — see §9 of the backend spec.
    static let devKey = "468d206064d31ef852c4248ff8f4374142827fd31a1e8e77909cb5eb405958d5"

    /// RevenueCat's public SDK key for the iOS app.
    ///
    /// Unlike `devKey` above, this one is meant to live in the binary: it can
    /// only read offerings and start purchases the App Store still has to
    /// approve, and RevenueCat verifies the resulting receipt server-side. The
    /// secret key — the one that can grant entitlements — is not here and must
    /// never be.
    static let revenueCatPublicKey = "appl_UfeTYGmaiueGhGzmWTBtOgnlUcE"
}
