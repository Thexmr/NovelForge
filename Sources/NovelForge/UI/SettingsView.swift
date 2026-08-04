import SwiftUI
import SwiftData

@MainActor
struct SettingsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedSection = SettingsSection.general

    private enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "Allgemein"
        case appearance = "Darstellung"
        case providers = "Textmodelle"
        case covers = "Cover"
        case privacy = "Daten"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general: return "slider.horizontal.3"
            case .appearance: return "paintbrush"
            case .providers: return "cpu"
            case .covers: return "photo"
            case .privacy: return "lock.shield"
            }
        }
    }

    var body: some View {
        ZStack {
            StudioBackground()

            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Einstellungen")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundStyle(StudioTheme.heroGradient)
                        Text("Vorgaben, Modelle, Cover-Erstellung und lokale Daten verwalten.")
                            .font(.subheadline)
                            .foregroundStyle(StudioTheme.textMuted)
                    }

                    Picker("Bereich", selection: $selectedSection) {
                        ForEach(SettingsSection.allCases) { section in
                            Label(section.rawValue, systemImage: section.icon).tag(section)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .overlay(alignment: .bottom) { StudioTheme.hairline.frame(height: 1) }

                Group {
                    switch selectedSection {
                    case .general: GeneralSettingsView()
                    case .appearance: AppearanceSettingsView()
                    case .providers: ProviderSettingsView()
                    case .covers: CoverImageSettingsView()
                    case .privacy: PrivacySettingsView()
                    }
                }
                .id(selectedSection)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing)))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(reduceMotion ? nil : Motion.standard, value: selectedSection)
            }
        }
        .frame(minWidth: 620, minHeight: 440)
        .navigationTitle("Einstellungen")
    }
}

// MARK: - Allgemein

@MainActor
struct GeneralSettingsView: View {
    @AppStorage("defaultLanguage") private var defaultLanguage = "Deutsch"
    @AppStorage("defaultGenre") private var defaultGenre = "Roman"
    @AppStorage("defaultAuthor") private var defaultAuthor = ""
    @AppStorage("defaultImprint") private var defaultImprint = DefaultBookSettings.imprint
    @AppStorage("defaultAuthorBio") private var defaultAuthorBio = DefaultBookSettings.authorBio
    @AppStorage("kdpCoverStudioPath") private var kdpCoverStudioPath = "/Users/dave/AMZ KDP KI"
    @AppStorage("novelforge.writingModel") private var writingModel = ""
    @AppStorage(KDPUploadService.visionModelDefaultsKey) private var visionModel = ""

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
                    ForEach(UnlimitedSettings.genrePool, id: \.self) {
                        Text($0).tag($0)
                    }
                }
            }

            Section("Sicht-Kontrolle beim KDP-Upload") {
                TextField("Sicht-Modell (leer = aus)", text: $visionModel)
                Text("Ein multimodales Modell im lokalen Ollama (z. B. qwen3-vl) sieht während "
                     + "des Uploads nach, was wirklich im KDP-Formular steht, und meldet sichtbare "
                     + "Fehlerhinweise. Maßgeblich bleibt immer das Zurücklesen aus dem Formular – "
                     + "Bildmodelle antworten erfahrungsgemäß zu optimistisch. Das Bildschirmfoto "
                     + "verlässt das Gerät nicht.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Schreibqualität · Autoren-Modell (Prosa)") {
                Picker("Autoren-Modell", selection: $writingModel) {
                    Text("Standard – kimi-k2.6 (schnell & günstig)").tag("")
                    Text("Tiefer & langsamer – mistral-large-3:675b").tag("mistral-large-3:675b")
                    ForEach(OllamaCloudModelCatalog.fallbackModels.filter {
                        $0 != OllamaCloudModelCatalog.defaultModel
                            && $0 != "mistral-large-3:675b"
                    }, id: \.self) {
                        Text($0).tag($0)
                    }
                }
                Text("Steuert kreative Prosa, Konzept, Struktur und Reparatur. Standard ist kimi-k2.6: schnell, günstig und mit der eingebauten Qualitäts-Pipeline (Planung, Gates, Judges) auf Bestseller-Niveau getrimmt. Größere Modelle kosten mehr und verlangsamen die Produktion – der Unterschied im fertigen Buch ist klein. Ist ein Modell nicht verfügbar, weicht die Produktion automatisch auf kimi aus.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
        .scrollContentBackground(.hidden)
        .background(Color.clear)
    }
}

// MARK: - Erscheinungsbild

@MainActor
struct AppearanceSettingsView: View {
    @AppStorage("colorScheme") private var colorScheme = "dark"
    @AppStorage("accentColor") private var accentColor = "teal"

    var body: some View {
        Form {
            Section("Darstellung") {
                LabeledContent("Erscheinungsbild", value: "Studio Dunkel")

                Picker("Akzentfarbe", selection: $accentColor) {
                    Text("Blau").tag("blue")
                    Text("Indigo").tag("indigo")
                    Text("Teal").tag("teal")
                    Text("Koralle").tag("coral")
                }
            }
            Section {
                Text("Das dunkle Studio-Design ist für lange Produktionsläufe optimiert. Die Akzentfarbe wird sofort auf interaktive Systemelemente angewendet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .onAppear {
            colorScheme = "dark"
        }
    }
}

// MARK: - KI-Provider

@MainActor
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
                    Button {
                        showingAddProvider = true
                    } label: {
                        Label("Provider hinzufügen", systemImage: "plus")
                    }
                    .buttonStyle(StudioPrimaryButtonStyle())
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
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                Divider()

                HStack {
                    Spacer()
                    Button {
                        showingAddProvider = true
                    } label: {
                        Label("Provider hinzufügen", systemImage: "plus")
                    }
                    .buttonStyle(StudioPrimaryButtonStyle())
                    .frame(width: 200)
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

@MainActor
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
                    Button {
                        newKey = ""
                        showingKeyEditor = true
                    } label: {
                        Label("Schlüssel", systemImage: "key")
                    }
                    .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.amber))
                }

                Button {
                    runTest()
                } label: {
                    Label(isTesting ? "Wird geprüft" : "Testen",
                          systemImage: isTesting ? "arrow.triangle.2.circlepath" : "network")
                }
                .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.cyan))
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
                .help("Provider-Konfiguration entfernen; der API-Key bleibt gespeichert")
                .accessibilityLabel("Provider entfernen")
            }

            if let result = testResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(13)
        .studioGlassTile(cornerRadius: 8,
                         accent: configuration.isActive ? StudioTheme.cyan : StudioTheme.textFaint,
                         opacity: 0.86)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .sheet(isPresented: $showingKeyEditor) {
            VStack(alignment: .leading, spacing: 16) {
                Text("API-Key für \(configuration.provider.rawValue)")
                    .font(.headline)
                SecureField("API-Key einfügen", text: $newKey)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 360)
                Text("Der Key wird lokal für NovelForge gespeichert und zusätzlich in der macOS Keychain gesichert.")
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

@MainActor
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

    private var canAdd: Bool {
        guard !effectiveModel.isEmpty else { return false }
        if selectedProvider.needsBaseURLInput
            && baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if selectedProvider.requiresAPIKey
            && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !ProviderSettingsStore.shared.hasAPIKey(for: selectedProvider) {
            return false
        }
        return true
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
                                   pendingAPIKey: apiKey,
                                   includeCustomField: selectedProvider != .ollamaCloud)

                if selectedProvider.requiresAPIKey {
                    SecureField("API-Key", text: $apiKey)
                }

                if selectedProvider.needsBaseURLInput {
                    TextField("Basis-URL", text: $baseURL)
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(StudioBackground())
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
                    .disabled(!canAdd)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 320)
    }
}

// MARK: - Cover-KI

@MainActor
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
        .scrollContentBackground(.hidden)
        .background(Color.clear)
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

@MainActor
struct PrivacySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    private var _projects = Query<Project, [Project]>()
    private var projects: [Project] { _projects.wrappedValue }
    @ObservedObject private var orchestrator = PipelineOrchestrator.shared

    @State private var confirmDeleteKeys = false
    @State private var confirmDeleteProjects = false
    @State private var kdpEmail = ""
    @State private var kdpPasswort = ""
    @State private var kdpGespeichert = KeychainService.hasKDPCredentials()

    var body: some View {
        Form {
            Section {
                Text(kdpGespeichert
                     ? "Zugangsdaten sind hinterlegt. Die Fabrik meldet sich damit selbst an, wenn die Browser-Sitzung abgelaufen ist."
                     : "Optional. Ohne Zugangsdaten nutzt die Fabrik die bestehende Anmeldung aus deinem Chrome – das genügt meistens und ist sicherer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Amazon-E-Mail", text: $kdpEmail)
                    .textContentType(.username)
                SecureField("Amazon-Passwort", text: $kdpPasswort)
                    .textContentType(.password)
                HStack {
                    Button("Sicher speichern") {
                        KeychainService.saveKDPCredentials(email: kdpEmail.trimmingCharacters(in: .whitespaces),
                                                           password: kdpPasswort)
                        kdpEmail = ""; kdpPasswort = ""
                        kdpGespeichert = KeychainService.hasKDPCredentials()
                    }
                    .disabled(kdpEmail.isEmpty || kdpPasswort.isEmpty)
                    if kdpGespeichert {
                        Button("Löschen", role: .destructive) {
                            KeychainService.deleteKDPCredentials()
                            kdpGespeichert = false
                        }
                    }
                }
                Text("Gespeichert wird ausschließlich im macOS-Schlüsselbund (gerätegebunden, nur bei entsperrtem Mac lesbar) – nicht in Dateien, Einstellungen oder Protokollen. Verlangt Amazon zusätzlich einen Bestätigungscode, musst du diesen weiterhin selbst eingeben.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } header: {
                Text("KDP-Anmeldung")
            }

            Section("Datenhaltung") {
                LabeledContent("Projekte & Manuskripte", value: "Lokal auf diesem Mac")
                LabeledContent("API-Keys", value: "Lokaler App-Speicher mit Keychain-Backup")
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
                Text("API-Keys bleiben lokal und werden nie in Projektexporte oder Buchdateien geschrieben. Über „Alle API-Keys löschen“ werden App-Speicher und Keychain-Backup gemeinsam entfernt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
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
                modelContext.saveOrLog()
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Alle Bücher, Kapitel, Szenen und Berichte werden unwiderruflich gelöscht.")
        }
    }
}
