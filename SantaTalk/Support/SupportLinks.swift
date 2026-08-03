import Foundation

/// Where the About rows in the vault point.
///
/// Placeholders until the real addresses land — every one of these is a
/// single-line change, and none of them is read anywhere else.
enum SupportLinks {

    static let privacyPolicy = URL(string: "https://santatalk.app/privacy")!

    /// Apple's standard EULA, which is what applies unless a custom one is filed
    /// in App Store Connect. Linking it satisfies the review requirement that a
    /// paid screen state its terms; swap this for a hosted page if a custom
    /// agreement is ever written.
    static let termsOfUse = URL(
        string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
    )!

    static let contactAddress = "hello@santatalk.app"

    static var contactEmail: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = contactAddress
        components.queryItems = [URLQueryItem(name: "subject", value: "SantaTalk support")]
        return components.url ?? URL(string: "mailto:\(contactAddress)")!
    }
}
