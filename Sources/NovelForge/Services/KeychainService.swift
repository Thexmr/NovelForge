import Foundation
import Security

enum KeychainService {
    private static let serviceName = "com.novelforge.app"
    private static var cachedAPIKeys: [AIProvider: String] = [:]
    private static var missingProviders: Set<AIProvider> = []

    // Prompt-freier Speicher in den App-Einstellungen. Die Keychain-Freigabe ist an
    // die Code-Signatur gebunden und bricht bei jeder Neuinstallation – dann fragt
    // macOS erneut nach dem Passwort. UserDefaults ist an die Bundle-ID gebunden,
    // überlebt Neuinstallationen und fragt NIE. Leicht kodiert (kein Klartext im
    // Grep), Keychain läuft best-effort als Backup mit.
    private static func defaultsKey(for provider: AIProvider) -> String {
        "apikey_store_\(provider.rawValue)"
    }

    private static func encode(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
    }

    private static func decode(_ stored: String) -> String? {
        guard let data = Data(base64Encoded: stored), let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    static func saveAPIKey(_ apiKey: String, for provider: AIProvider) {
        cachedAPIKeys[provider] = apiKey
        missingProviders.remove(provider)
        UserDefaults.standard.set(encode(apiKey), forKey: defaultsKey(for: provider))
        saveToKeychain(apiKey, for: provider) // best-effort Backup
    }

    static func getAPIKey(for provider: AIProvider) -> String? {
        if let value = storedAPIKeyWithoutPrompt(for: provider) {
            return value
        }
        if missingProviders.contains(provider) {
            return nil
        }
        // 2) Letzter Ausweg: Keychain (kann EINMAL nachfragen) – Ergebnis dann
        //    prompt-frei spiegeln, damit nie wieder gefragt wird.
        if let value = readFromKeychain(provider), !value.isEmpty {
            cachedAPIKeys[provider] = value
            UserDefaults.standard.set(encode(value), forKey: defaultsKey(for: provider))
            return value
        }
        missingProviders.insert(provider)
        return nil
    }

    // MARK: - KDP-Zugangsdaten
    //
    // Amazon-Anmeldedaten für den autonomen Upload. Sie liegen ausschließlich im
    // System-Schlüsselbund (gerätegebunden, nur bei entsperrtem Gerät lesbar) – nie in
    // Dateien, Einstellungen oder Protokollen. Weitergegeben werden sie einzig als
    // Umgebungsvariable an den Sidecar-Prozess, nicht über die Kommandozeile.
    private static let kdpEmailKey = "kdp_login_email"
    private static let kdpPasswordKey = "kdp_login_password"

    static func saveKDPCredentials(email: String, password: String) {
        writeGeneric(email, account: kdpEmailKey)
        writeGeneric(password, account: kdpPasswordKey)
    }

    static func kdpCredentials() -> (email: String, password: String)? {
        guard let mail = readGeneric(account: kdpEmailKey), !mail.isEmpty,
              let pass = readGeneric(account: kdpPasswordKey), !pass.isEmpty else { return nil }
        return (mail, pass)
    }

    static func hasKDPCredentials() -> Bool { kdpCredentials() != nil }

    static func deleteKDPCredentials() {
        for account in [kdpEmailKey, kdpPasswordKey] {
            SecItemDelete([
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: serviceName,
                kSecAttrAccount as String: account,
            ] as CFDictionary)
        }
    }

    private static func writeGeneric(_ value: String, account: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
        SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ] as CFDictionary, nil)
    }

    private static func readGeneric(account: String) -> String? {
        var result: AnyObject?
        let status = SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ] as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func saveToKeychain(_ apiKey: String, for provider: AIProvider) {
        let key = "api_key_\(provider.rawValue)"
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: apiKey.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func readFromKeychain(_ provider: AIProvider) -> String? {
        let key = "api_key_\(provider.rawValue)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func cachedAPIKey(for provider: AIProvider) -> String? {
        cachedAPIKeys[provider]
    }

    static func hasCachedAPIKey(for provider: AIProvider) -> Bool {
        cachedAPIKeys[provider]?.isEmpty == false
    }

    /// Prompt-freier Check, ob ein Key hinterlegt ist (Cache oder App-Einstellungen,
    /// nie Keychain). Für den Render-Pfad geeignet – löst keinen Dialog aus.
    static func hasStoredAPIKey(for provider: AIProvider) -> Bool {
        storedAPIKeyWithoutPrompt(for: provider) != nil
    }

    /// Liest Cache oder App-Einstellungen, aber niemals die Keychain. Geeignet für
    /// Modelllisten und Renderpfade, die garantiert keinen Passwortdialog auslösen dürfen.
    static func storedAPIKeyWithoutPrompt(for provider: AIProvider) -> String? {
        if let cached = cachedAPIKeys[provider], !cached.isEmpty { return cached }
        if let stored = UserDefaults.standard.string(forKey: defaultsKey(for: provider)),
           let value = decode(stored), !value.isEmpty {
            cachedAPIKeys[provider] = value
            missingProviders.remove(provider)
            return value
        }
        return nil
    }
    
    static func deleteAPIKey(for provider: AIProvider) {
        let key = "api_key_\(provider.rawValue)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: defaultsKey(for: provider))
        cachedAPIKeys.removeValue(forKey: provider)
        missingProviders.insert(provider)
    }

    static func deleteAllAPIKeys() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]

        SecItemDelete(query as CFDictionary)
        for provider in AIProvider.allCases {
            UserDefaults.standard.removeObject(forKey: defaultsKey(for: provider))
        }
        cachedAPIKeys.removeAll()
        missingProviders = Set(AIProvider.allCases)
    }
    
    static func loadAPIKeysForProviders(_ providers: inout [ProviderConfiguration]) {
        for index in providers.indices {
            if let apiKey = getAPIKey(for: providers[index].provider) {
                providers[index].apiKey = apiKey
            }
        }
    }
}
