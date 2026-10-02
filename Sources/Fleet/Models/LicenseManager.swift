import Foundation
import Security

/// Manages Fleet's license state. During the free period every install is
/// treated as unlocked — isUnlocked always returns true and no key is needed.
///
/// When switching to a paid model:
///   1. Implement activate(key:email:) to call your payment provider's API
///      (LemonSqueezy: POST /v1/licenses/validate; Paddle: similar).
///   2. Change isUnlocked to: `if case .active = status { return true }; return false`
///   3. Gate premium features behind LicenseManager.shared.isUnlocked.
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    enum Status: Equatable {
        case free               // free period — all features on, no key needed
        case active(email: String)  // paid, validated
        case invalid            // key was entered but failed validation
    }

    @Published private(set) var status: Status = .free

    /// True when the user has full access to all features.
    /// Flip to `if case .active = status { return true }; return false`
    /// when the app becomes paid.
    var isUnlocked: Bool { true }

    private init() {
        if let email = KeychainHelper.load(account: "licenseEmail") {
            status = .active(email: email)
        }
    }

    /// Validates a license key against the payment provider API and, on
    /// success, persists the activation to Keychain.
    @discardableResult
    func activate(key: String, email: String) async -> Bool {
        // TODO: replace stub with real provider call, e.g.:
        //   POST https://api.lemonsqueezy.com/v1/licenses/validate
        //   body: { "license_key": key }  headers: { Authorization: Bearer <token> }
        // On HTTP 200 with valid response: fall through to the success path below.
        // On failure: return false.

        // Stub — always invalid until provider is wired up.
        await MainActor.run { self.status = .invalid }
        return false
    }

    func deactivate() {
        KeychainHelper.delete(account: "licenseKey")
        KeychainHelper.delete(account: "licenseEmail")
        status = .free
    }
}

/// Minimal Keychain helper for storing small strings (license key, email).
enum KeychainHelper {
    private static let service = "com.davidkr.fleet"

    static func save(_ value: String, account: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
