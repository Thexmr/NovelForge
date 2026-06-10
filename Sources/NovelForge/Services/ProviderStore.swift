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

        // API-Keys aus der Keychain nachladen (werden nie mitgespeichert).
        for index in configurations.indices {
            configurations[index].apiKey = KeychainService.getAPIKey(for: configurations[index].provider)
        }
    }

    func save() {
        // apiKey ist nicht Teil der CodingKeys und wird daher nie kodiert.
        if let data = try? JSONEncoder().encode(configurations) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func upsert(_ config: ProviderConfiguration) {
        if let index = configurations.firstIndex(where: { $0.provider == config.provider }) {
            configurations[index] = config
        } else {
            configurations.append(config)
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
        KeychainService.getAPIKey(for: provider)?.isEmpty == false
    }

    /// Baut die Laufzeitkonfiguration für ein Projekt zusammen:
    /// gespeicherte Provider-Einstellung + projektspezifisches Modell/Kostenlimit + Keychain-Key.
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
        if project.costLimitUSD > 0 {
            config.costLimit = project.costLimitUSD
        }
        config.apiKey = KeychainService.getAPIKey(for: provider)
        return config
    }
}
