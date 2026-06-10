import SwiftUI
import SwiftData

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem { Label("Allgemein", systemImage: "gear") }

            AppearanceSettingsView()
                .tabItem { Label("Erscheinungsbild", systemImage: "paintbrush") }

            ProviderSettingsView()
                .tabItem { Label("KI-Provider", systemImage: "cpu") }

            PrivacySettingsView()
                .tabItem { Label("Datenschutz", systemImage: "lock.shield") }
        }
        .frame(minWidth: 620, minHeight: 440)
        .navigationTitle("Einstellungen")
    }
}

// MARK: - Allgemein

struct GeneralSettingsView: View {
    @AppStorage("defaultLanguage") private var defaultLanguage = "Deutsch"
    @AppStorage("defaultGenre") private var defaultGenre = "Roman"
    @AppStorage("defaultAuthor") private var defaultAuthor = ""

    var body: some View {
        Form {
            Section("Vorgaben für neue Bücher") {
                TextField("Standard-Autorname", text: $defaultAuthor)

                Picker("Standardsprache", selection: $defaultLanguage) {
                    Text("Deutsch").tag("Deutsch")
                    Text("Englisch").tag("Englisch")
                    Text("Französisch").tag("Französisch")
                    Text("Spanisch").tag("Spanisch")
                }

                Picker("Standard-Genre", selection: $defaultGenre) {
                    ForEach(["Thriller", "Roman", "Fantasy", "Science Fiction", "Krimi",
                             "Liebesroman", "Historischer Roman", "Horror"], id: \.self) {
                        Text($0).tag($0)
                    }
                }
            }

            Section {
                LabeledContent("Version", value: AppConstants.appVersion)
                LabeledContent("Speicherung", value: "Projekte werden automatisch lokal gespeichert")
            } header: {
                Text("Über NovelForge")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Erscheinungsbild

struct AppearanceSettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = "system"
    @AppStorage("accentColor") private var accentColor = "blue"

    var body: some View {
        Form {
            Section("Darstellung") {
                Picker("Erscheinungsbild", selection: $colorScheme) {
                    Text("System").tag("system")
                    Text("Hell").tag("light")
                    Text("Dunkel").tag("dark")
                }
                .pickerStyle(.segmented)

                Picker("Akzentfarbe", selection: $accentColor) {
                    Text("Blau").tag("blue")
                    Text("Violett").tag("purple")
                    Text("Indigo").tag("indigo")
                    Text("Teal").tag("teal")
                }
            }
            Section {
                Text("Änderungen werden sofort auf die gesamte App angewendet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - KI-Provider

struct ProviderSettingsView: View {
    @ObservedObject private var store = ProviderSettingsStore.shared
    @State private var showingAddProvider = false

    var body: some View {
        VStack(spacing: 0) {
            if store.configurations.isEmpty {
                ContentUnavailableView {
                    Label("Keine Provider konfiguriert", systemImage: "cpu")
                } description: {
                    Text("Fügen Sie einen KI-Provider hinzu, um Bücher produzieren zu können. Der Provider kann auch direkt im Buch-Assistenten eingerichtet werden.")
                } actions: {
                    Button("Provider hinzufügen") { showingAddProvider = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                List {
                    ForEach($store.configurations) { $config in
                        ProviderRow(configuration: $config)
                    }
                    .onDelete { indexSet in
                        for index in indexSet.sorted(by: >) {
                            store.configurations.remove(at: index)
                        }
                        store.save()
                    }
                }

                Divider()

                HStack {
                    Spacer()
                    Button("Provider hinzufügen") {
                        showingAddProvider = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(12)
            }
        }
        .sheet(isPresented: $showingAddProvider) {
            AddProviderView { config, apiKey in
                if !apiKey.isEmpty {
                    store.setAPIKey(apiKey, for: config.provider)
                }
                store.upsert(config)
            }
        }
    }
}

struct ProviderRow: View {
    @Binding var configuration: ProviderConfiguration
    @ObservedObject private var store = ProviderSettingsStore.shared

    @State private var isTesting = false
    @State private var testResult: String?
    @State private var testSucceeded: Bool?
    @State private var showingKeyEditor = false
    @State private var newKey = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(configuration.provider.rawValue)
                        .font(.headline)
                    HStack(spacing: 8) {
                        if let model = configuration.defaultModel, !model.isEmpty {
                            Text("Modell: \(model)")
                        }
                        if configuration.provider.requiresAPIKey {
                            Label(store.hasAPIKey(for: configuration.provider) ? "Key hinterlegt" : "Kein API-Key",
                                  systemImage: store.hasAPIKey(for: configuration.provider) ? "key.fill" : "key.slash")
                                .foregroundStyle(store.hasAPIKey(for: configuration.provider) ? Color.green : Color.orange)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("Aktiv", isOn: $configuration.isActive)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .onChange(of: configuration.isActive) {
                        store.save()
                    }

                if configuration.provider.requiresAPIKey {
                    Button("API-Key …") {
                        newKey = ""
                        showingKeyEditor = true
                    }
                    .buttonStyle(.bordered)
                }

                Button(isTesting ? "Teste …" : "Testen") {
                    runTest()
                }
                .buttonStyle(.bordered)
                .disabled(isTesting)

                if let succeeded = testSucceeded {
                    Image(systemName: succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(succeeded ? .green : .red)
                }
            }

            if let result = testResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingKeyEditor) {
            VStack(alignment: .leading, spacing: 16) {
                Text("API-Key für \(configuration.provider.rawValue)")
                    .font(.headline)
                SecureField("API-Key einfügen", text: $newKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 360)
                Text("Der Key wird ausschließlich in der macOS Keychain gespeichert.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Spacer()
                    Button("Abbrechen") { showingKeyEditor = false }
                    Button("Speichern") {
                        if !newKey.isEmpty {
                            store.setAPIKey(newKey, for: configuration.provider)
                        }
                        showingKeyEditor = false
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newKey.isEmpty)
                }
            }
            .padding(24)
        }
    }

    private func runTest() {
        isTesting = true
        testResult = nil
        testSucceeded = nil

        var config = configuration
        config.apiKey = KeychainService.getAPIKey(for: configuration.provider)

        Task { @MainActor in
            let error = await ProviderGateway.shared.testConnection(configuration: config)
            testSucceeded = (error == nil)
            testResult = error
            isTesting = false
        }
    }
}

struct AddProviderView: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: (ProviderConfiguration, String) -> Void

    @State private var selectedProvider = AIProvider.openAI
    @State private var apiKey = ""
    @State private var baseURL = ""
    @State private var selectedModel = AIProvider.openAI.suggestedModels.first ?? ""
    @State private var customModel = ""

    private var effectiveModel: String {
        let custom = customModel.trimmingCharacters(in: .whitespaces)
        return custom.isEmpty ? selectedModel : custom
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .onChange(of: selectedProvider) {
                    selectedModel = selectedProvider.suggestedModels.first ?? ""
                    customModel = ""
                }

                if selectedProvider.suggestedModels.isEmpty {
                    TextField("Modellname", text: $customModel)
                } else {
                    Picker("Modell", selection: $selectedModel) {
                        ForEach(selectedProvider.suggestedModels, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Eigenes Modell (optional)", text: $customModel)
                }

                if selectedProvider.requiresAPIKey {
                    SecureField("API-Key", text: $apiKey)
                }

                TextField("Basis-URL (optional)", text: $baseURL)
            }
            .formStyle(.grouped)
            .navigationTitle("Provider hinzufügen")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hinzufügen") {
                        var config = ProviderConfiguration(provider: selectedProvider)
                        config.baseURL = baseURL.isEmpty ? nil : baseURL
                        config.defaultModel = effectiveModel
                        config.isActive = true
                        onAdd(config, apiKey)
                        dismiss()
                    }
                    .disabled(effectiveModel.isEmpty)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 320)
    }
}

// MARK: - Datenschutz

struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]

    @State private var confirmDeleteKeys = false
    @State private var confirmDeleteProjects = false

    var body: some View {
        Form {
            Section("Datenhaltung") {
                LabeledContent("Projekte & Manuskripte", value: "Lokal auf diesem Mac")
                LabeledContent("API-Keys", value: "macOS Keychain (verschlüsselt)")
                LabeledContent("Prompts", value: "Werden nur an den gewählten Provider gesendet")
            }

            Section("Zurücksetzen") {
                Button("Alle API-Keys löschen", role: .destructive) {
                    confirmDeleteKeys = true
                }
                Button("Alle Projektdaten löschen (\(projects.count) Projekte)", role: .destructive) {
                    confirmDeleteProjects = true
                }
                .disabled(projects.isEmpty)
            }

            Section {
                Text("API-Keys werden ausschließlich in der macOS Keychain gespeichert und niemals unverschlüsselt abgelegt oder angezeigt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Wirklich alle API-Keys löschen?", isPresented: $confirmDeleteKeys) {
            Button("Alle Keys löschen", role: .destructive) {
                KeychainService.deleteAllAPIKeys()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Ohne API-Key kann keine Buchproduktion gestartet werden, bis ein neuer Key hinterlegt wird.")
        }
        .confirmationDialog("Wirklich ALLE Projekte löschen?", isPresented: $confirmDeleteProjects) {
            Button("\(projects.count) Projekte endgültig löschen", role: .destructive) {
                for project in projects {
                    modelContext.delete(project)
                }
                try? modelContext.save()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle Bücher, Kapitel, Szenen und Berichte werden unwiderruflich gelöscht.")
        }
    }
}
