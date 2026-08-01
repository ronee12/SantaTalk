import Foundation

/// Where the About rows in the vault point.
///
/// Placeholders until the real addresses land — every one of these is a
/// single-line change, and none of them is read anywhere else.
enum SupportLinks {

    static let privacyPolicy = URL(string: "https://santatalk.app/privacy")!

    static let contactAddress = "hello@santatalk.app"

    static var contactEmail: URL {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = contactAddress
        components.queryItems = [URLQueryItem(name: "subject", value: "SantaTalk support")]
        return components.url ?? URL(string: "mailto:\(contactAddress)")!
    }
}
