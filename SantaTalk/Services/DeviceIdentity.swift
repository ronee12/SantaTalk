import Foundation
import Security

/// A stable per-device identifier, and the only thing about this install that
/// deliberately outlives the app.
///
/// It sits in the Keychain rather than SwiftData because Keychain items are not
/// removed when an app is deleted, so deleting and reinstalling returns the same
/// id and cannot mint a second free call. Everything *about the child* does the
/// opposite — it lives in SwiftData and goes with the app. See `ChildProfile`.
///
/// Two things this is not. It is not a promise: Apple has never documented
/// Keychain survival across uninstall, it is observed behaviour, and it is
/// defeated by erasing the device. And it is not identity — the value is a bare
/// UUID with no name, age or person attached, and the Worker stores nothing
/// beside it but a timestamp and a call count.
enum DeviceIdentity {
    private static let service = "app.santacall.device"
    private static let account = "device-id"

    /// `AfterFirstUnlock` so a call can start without the phone having been
    /// unlocked this boot. `ThisDeviceOnly` keeps the id out of encrypted
    /// backups, so restoring onto a genuinely new phone earns a fresh free call
    /// while a reinstall on the same phone does not.
    private static let accessibility = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

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
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: accessibility
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
}
