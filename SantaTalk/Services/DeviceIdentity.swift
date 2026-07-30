import Foundation
import Security

/// A stable per-install identifier, kept in the Keychain so it survives app
/// restarts. It identifies a device for entitlement accounting only — it is
/// never tied to a child, a name, or a person.
enum DeviceIdentity {
    private static let service = "app.santacall.device"
    private static let account = "device-id"

    static func current() -> String {
        if let existing = read() { return existing }
        let created = UUID().uuidString
        write(created)
        return created
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func write(_ value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8)
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
