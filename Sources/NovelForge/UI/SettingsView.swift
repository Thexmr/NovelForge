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

            CoverImageSettingsView()
                .tabItem { Label("Cover-KI", systemImage: "photo") }

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
    @AppStorage("defaultImprint") private var defaultImprint = DefaultBookSettings.imprint
    @AppStorage("defaultAuthorBio") private var defaultAuthorBio = DefaultBookSettings.authorBio
    @AppStorage("kdpCoverStudioPath") private var kdpCoverStudioPath = "/Users/dave/AMZ KDP KI"

    var body: some View {
        Form {
            Section("Vorgaben für neue Bücher") {
                TextField("Standard-Autorname", text: $defaultAuthor)
                TextEditor(text: $defaultAuthorBio)
                    .frame(minHeight: 70)
                    .overlay(alignment: .topLeading) {
                        if defaultAuthorBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Standard-Autorprofil")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                TextEditor(text: $defaultImprint)
                    .frame(minHeight: 120)
                    .overlay(alignment: .topLeading) {
                        if defaultImprint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Standard-Impressum")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }

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

            Section("KDP Cover Studio") {
                TextField("Pfad zum Cover Studio", text: $kdpCoverStudioPath)
                Text("Ordner mit „Start KDP Cover Studio.command“ – für druckfertige KDP-Cover (Paperback/Hardcover-Wrap, 300 DPI).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    @AppStorage("colorScheme") private var colorScheme = "dark"
    @AppStorage("accentColor") private var accentColor = "teal"

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
                        ProviderRow(configuration: $config, onDelete: {
                            store.remove(config)
                        })
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
    var onDelete: () -> Void = {}
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
                        .accessibilityLabel(succeeded ? "Verbindung erfolgreich" : "Verbindung fehlgeschlagen")
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Provider entfernen (API-Key bleibt in der Keychain)")
                .accessibilityLabel("Provider entfernen")
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

    @State private var selectedProvider = AIProvider.ollamaCloud
    @State private var apiKey = ""
    @State private var baseURL = ""
    @State private var selectedModel = AIProvider.ollamaCloud.suggestedModels.first ?? ""
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

                DynamicModelPicker(provider: selectedProvider,
                                   selectedModel: $selectedModel,
                                   customModel: $customModel,
                                   pendingAPIKey: apiKey)

                if selectedProvider.requiresAPIKey {
                    SecureField("API-Key", text: $apiKey)
                }

                if selectedProvider.needsBaseURLInput {
                    TextField("Basis-URL", text: $baseURL)
                }
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
                        if !baseURL.isEmpty {
                            config.baseURL = baseURL
                        }
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

// MARK: - Cover-KI

struct CoverImageSettingsView: View {
    @ObservedObject private var store = CoverImageSettingsStore.shared
    @State private var newAPIKey = ""

    var body: some View {
        Form {
            Section("Bild-Anbieter") {
                Picker("Anbieter", selection: providerBinding) {
                    ForEach(CoverImageSettings.providers) { p in
                        Text(p.name).tag(p.id)
                    }
                }
                Text(activePreset.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("API-Key holen unter: \(activePreset.keyHint) — danach unten nur den Key eintragen.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Section("Bildmodell") {
                if !modelChoices.isEmpty {
                    Picker("Modell", selection: binding(\.model)) {
                        ForEach(modelChoices, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }

                TextField("Eigenes Modell (optional)", text: binding(\.model))
                    .textFieldStyle(.roundedBorder)

                Picker("Format", selection: binding(\.size)) {
                    Text("KDP Frontcover 2:3").tag("1024x1536")
                    Text("Quadratisch").tag("1024x1024")
                    Text("Querformat").tag("1536x1024")
                }

                Picker("Qualität", selection: binding(\.quality)) {
                    ForEach(CoverImageSettings.qualityOptions, id: \.self) { quality in
                        Text(quality.capitalized).tag(quality)
                    }
                }

                TextField("Basis-URL", text: binding(\.baseURL))
                    .textFieldStyle(.roundedBorder)

                Text("Standard ist OpenAI Images API. Benutzerdefinierte OpenAI-kompatible Endpunkte sind möglich, solange sie /images/generations unterstützen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("API-Key") {
                HStack {
                    Label(store.hasAPIKey() ? "Bild-API-Key ist hinterlegt" : "Kein Bild-API-Key hinterlegt",
                          systemImage: store.hasAPIKey() ? "key.fill" : "key.slash")
                        .foregroundStyle(store.hasAPIKey() ? Color.green : Color.orange)
                    Spacer()
                }

                SecureField("API-Key des gewählten Bild-Anbieters", text: $newAPIKey)
                HStack {
                    Spacer()
                    Button("Key speichern") {
                        store.saveAPIKey(newAPIKey)
                        newAPIKey = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(newAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Text("Ohne Bild-API-Key kann NovelForge trotzdem einen perfekten Cover-Prompt erzeugen, den Sie extern in einem Bildmodell nutzen können.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func binding(_ keyPath: WritableKeyPath<CoverImageSettings, String>) -> Binding<String> {
        Binding {
            store.settings[keyPath: keyPath]
        } set: { newValue in
            store.settings[keyPath: keyPath] = newValue
            store.save()
        }
    }

    private var activePreset: ImageProviderPreset {
        CoverImageSettings.preset(store.settings.provider)
    }

    /// Kuratierte Modelle des aktiven Anbieters; das aktuell gewählte Modell ist
    /// immer enthalten, damit der Picker einen gültigen Tag hat (sonst SwiftUI-Warnung).
    private var modelChoices: [String] {
        var choices = CoverImageSettings.modelChoices(for: store.settings.provider)
        let current = store.settings.model.trimmingCharacters(in: .whitespacesAndNewlines)
        if !current.isEmpty, !choices.contains(current) {
            choices.insert(current, at: 0)
        }
        return choices
    }

    /// Wählt einen Anbieter und übernimmt dessen Endpoint + Modell automatisch.
    private var providerBinding: Binding<String> {
        Binding {
            store.settings.provider
        } set: { id in
            let preset = CoverImageSettings.preset(id)
            store.settings.provider = id
            store.settings.baseURL = preset.baseURL
            store.settings.model = preset.model
            store.save()
        }
    }
}

// MARK: - Datenschutz

struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var projects: [Project]
    @ObservedObject private var orchestrator = PipelineOrchestrator.shared

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
                .disabled(projects.isEmpty || orchestrator.isRunning)
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
                for project in projects where !orchestrator.activeProjectIDs.contains(project.id) && orchestrator.currentProject?.id != project.id {
                    ChatMessage.deleteMessages(forProjectID: project.id, in: modelContext)
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
