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
    @State private var scheduledRefresh: Task<Void, Never>?
    @State private var requestID = UUID()

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
                    Button {
                        refreshModels()
                    } label: {
                        Label(isLoading ? "Modelle werden geladen" : "Cloud-Modelle aktualisieren",
                              systemImage: isLoading ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                    }
                    .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.cyan))
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
                scheduleModelRefresh()
            }
        }
        .onDisappear {
            scheduledRefresh?.cancel()
            requestID = UUID()
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
        scheduledRefresh?.cancel()
        guard provider == .ollamaCloud || provider == .ollamaLocal else { return }
        if provider == .ollamaCloud && effectiveAPIKey().isEmpty {
            return
        }

        let activeRequestID = UUID()
        requestID = activeRequestID
        isLoading = true
        loadError = nil

        let requestConfig: ProviderConfiguration = {
            var config = ProviderConfiguration(provider: provider)
            config.isActive = true
            config.defaultModel = selectedModel.isEmpty ? provider.suggestedModels.first : selectedModel
            config.apiKey = effectiveAPIKey()
            return config
        }()

        Task { @MainActor in
            defer {
                if requestID == activeRequestID {
                    isLoading = false
                }
            }
            do {
                let models = try await ProviderGateway.shared.listModels(configuration: requestConfig)
                guard requestID == activeRequestID else { return }
                guard !models.isEmpty else { return }
                availableModels = models
                if selectedModel.isEmpty || !models.contains(selectedModel) {
                    selectedModel = models.first ?? ""
                }
            } catch {
                guard requestID == activeRequestID else { return }
                loadError = "Fallback-Liste aktiv"
            }
        }
    }

    private func scheduleModelRefresh() {
        scheduledRefresh?.cancel()
        scheduledRefresh = Task {
            try? await Task.sleep(nanoseconds: 550_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                refreshModels()
            }
        }
    }

    private func effectiveAPIKey() -> String {
        let pending = pendingAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pending.isEmpty { return pending }
        return KeychainService.storedAPIKeyWithoutPrompt(for: provider) ?? ""
    }
}
