import Foundation
import Security

enum KeychainService {
    private static let serviceName = "com.novelforge.app"
    
    static func saveAPIKey(_ apiKey: String, for provider: AIProvider) {
        let key = "api_key_\(provider.rawValue)"
        
        // Delete existing item first
        deleteAPIKey(for: provider)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: apiKey.data(using: .utf8)!,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status != errSecSuccess {
            print("Failed to save API key to Keychain: \(status)")
        }
    }
    
    static func getAPIKey(for provider: AIProvider) -> String? {
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
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return apiKey
    }
    
    static func deleteAPIKey(for provider: AIProvider) {
        let key = "api_key_\(provider.rawValue)"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    static func deleteAllAPIKeys() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    static func loadAPIKeysForProviders(_ providers: inout [ProviderConfiguration]) {
        for index in providers.indices {
            if let apiKey = getAPIKey(for: providers[index].provider) {
                providers[index].apiKey = apiKey
            }
        }
    }
}