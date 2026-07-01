import Foundation
import SwiftUI

/// Zentrale Verwaltung der Provider-Konfigurationen.
/// Konfigurationen (ohne API-Keys) liegen in UserDefaults,
/// API-Keys ausschließlich in der macOS Keychain.
@MainActor
final class ProviderSettingsStore: ObservableObject {
    static let shared = ProviderSettingsStore()

    @Published var configurations: [ProviderConfiguration] = []

    private static let storageKey = "novelforge.providers.v2"
    private static let legacyKey = "providers"

    init() {
        load()
    }

    func load() {
        // Alte, unsichere Speicherung (enthielt API-Keys im Klartext) entfernen.
        if UserDefaults.standard.data(forKey: Self.legacyKey) != nil {
            UserDefaults.standard.removeObject(forKey: Self.legacyKey)
        }

        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([ProviderConfiguration].self, from: data) {
            configurations = decoded
        }

        migrateLegacyProviderDefaults()
        normalizeConfigurations()

        // API-Keys werden erst bei Start/Test geladen. SwiftUI rendert häufig;
        // Keychain-Zugriffe im Renderpfad erzeugen sonst wiederholte macOS-Prompts.
    }

    func save() {
        // apiKey ist nicht Teil der CodingKeys und wird daher nie kodiert.
        if let data = try? JSONEncoder().encode(configurations) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func upsert(_ config: ProviderConfiguration) {
        if let index = configurations.firstIndex(where: { $0.provider == config.provider }) {
            configurations[index] = Self.normalized(config)
        } else {
            configurations.append(Self.normalized(config))
        }
        save()
    }

    func remove(_ config: ProviderConfiguration) {
        configurations.removeAll { $0.id == config.id }
        save()
    }

    func setAPIKey(_ key: String, for provider: AIProvider) {
        KeychainService.saveAPIKey(key, for: provider)
        if let index = configurations.firstIndex(where: { $0.provider == provider }) {
            configurations[index].apiKey = key
        }
    }

    func hasAPIKey(for provider: AIProvider) -> Bool {
        if KeychainService.hasStoredAPIKey(for: provider) { return true }
        return configurations.first(where: { $0.provider == provider })?.apiKey?.isEmpty == false
    }

    /// Baut die Laufzeitkonfiguration für ein Projekt zusammen:
    /// gespeicherte Provider-Einstellung + projektspezifisches Modell + Keychain-Key.
    static func configuration(for project: Project) -> ProviderConfiguration {
        let provider = AIProvider(rawValue: project.preferredProviderRaw) ?? .openAI
        var config = shared.configurations.first(where: { $0.provider == provider })
            ?? ProviderConfiguration(provider: provider)
        config.isActive = true
        if !project.preferredModel.isEmpty {
            config.defaultModel = project.preferredModel
        }
        if config.defaultModel == nil || config.defaultModel?.isEmpty == true {
            config.defaultModel = provider.suggestedModels.first
        }
        if provider == .ollamaCloud {
            // Nur die Laufzeit-Konfiguration normalisieren – NICHT als Seiteneffekt in das
            // (evtl. inzwischen gelöschte) SwiftData-Projekt zurückschreiben. Das frühere
            // `project.preferredModel = …` konnte a) beim Schreiben auf ein gelöschtes @Model
            // abstürzen und b) die vom Nutzer bewusst gewählte Modellwahl dauerhaft
            // überschreiben. Die Normalisierung passiert bei jedem Aufruf erneut und muss
            // daher nicht persistiert werden.
            config.defaultModel = OllamaCloudModelCatalog.bestModel(preferred: config.defaultModel)
        }
        config.apiKey = KeychainService.getAPIKey(for: provider)
        return config
    }

    private func normalizeConfigurations() {
        let normalized = configurations.map(Self.normalized)
        if normalized != configurations {
            configurations = normalized
            save()
        }
    }

    private static func normalized(_ config: ProviderConfiguration) -> ProviderConfiguration {
        var normalized = config
        if normalized.baseURL?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            normalized.baseURL = normalized.provider.defaultBaseURL
        }
        if normalized.provider == .ollamaCloud {
            normalized.baseURL = AIProvider.ollamaCloud.defaultBaseURL
            normalized.defaultModel = OllamaCloudModelCatalog.bestModel(preferred: normalized.defaultModel)
        } else if normalized.defaultModel?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
            normalized.defaultModel = normalized.provider.suggestedModels.first
        }
        return normalized
    }

    private func migrateLegacyProviderDefaults() {
        let defaults = UserDefaults.standard
        for provider in AIProvider.allCases {
            let secretKey = "local_secret_api_key_\(provider.rawValue)"
            if let legacyAPIKey = defaults.string(forKey: secretKey),
               !legacyAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                KeychainService.saveAPIKey(legacyAPIKey, for: provider)
                defaults.removeObject(forKey: secretKey)
            }
            defaults.removeObject(forKey: "provider_base_url_\(provider.rawValue)")
            defaults.removeObject(forKey: "provider_default_model_\(provider.rawValue)")
        }
        defaults.removeObject(forKey: "active_provider")
    }
}
