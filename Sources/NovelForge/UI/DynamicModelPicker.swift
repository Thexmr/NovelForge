import SwiftUI

struct DynamicModelPicker: View {
    let provider: AIProvider
    @Binding var selectedModel: String
    @Binding var customModel: String
    var pendingAPIKey: String = ""
    var includeCustomField = true

    @State private var availableModels: [String] = []
    @State private var isLoading = false
    @State private var loadError: String?

    var body: some View {
        Group {
            if availableModels.isEmpty {
                TextField("Modellname", text: $customModel)
            } else {
                Picker("Modell", selection: $selectedModel) {
                    ForEach(availableModels, id: \.self) { Text($0).tag($0) }
                }
            }

            if includeCustomField && !availableModels.isEmpty {
                TextField("Eigenes Modell (optional, überschreibt Auswahl)", text: $customModel)
            }

            if provider == .ollamaCloud {
                HStack {
                    Button(isLoading ? "Modelle laden ..." : "Cloud-Modelle aktualisieren") {
                        refreshModels()
                    }
                    .disabled(isLoading)
                    if let loadError {
                        Text(loadError)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .onAppear {
            resetModels()
            refreshModels()
        }
        .onChange(of: provider) {
            resetModels()
            refreshModels()
        }
        .onChange(of: pendingAPIKey) {
            if provider == .ollamaCloud {
                refreshModels()
            }
        }
    }

    private func resetModels() {
        availableModels = provider.suggestedModels
        loadError = nil
        if selectedModel.isEmpty || !availableModels.contains(selectedModel) {
            selectedModel = availableModels.first ?? ""
        }
    }

    private func refreshModels() {
        guard provider == .ollamaCloud || provider == .ollamaLocal else { return }
        if provider == .ollamaCloud && effectiveAPIKey().isEmpty {
            return
        }

        isLoading = true
        loadError = nil

        var config = ProviderConfiguration(provider: provider)
        config.isActive = true
        config.defaultModel = selectedModel.isEmpty ? provider.suggestedModels.first : selectedModel
        config.apiKey = effectiveAPIKey()

        Task { @MainActor in
            defer { isLoading = false }
            do {
                let models = try await ProviderGateway.shared.listModels(configuration: config)
                guard !models.isEmpty else { return }
                availableModels = models
                if selectedModel.isEmpty || !models.contains(selectedModel) {
                    selectedModel = models.first ?? ""
                }
            } catch {
                loadError = "Fallback-Liste aktiv"
            }
        }
    }

    private func effectiveAPIKey() -> String {
        let pending = pendingAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pending.isEmpty { return pending }
        return KeychainService.getAPIKey(for: provider) ?? ""
    }
}
