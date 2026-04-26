import SwiftUI
import Security
import UniformTypeIdentifiers

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general
    
    enum SettingsTab: String, CaseIterable {
        case general = "Allgemein"
        case appearance = "Erscheinungsbild"
        case providers = "KI-Provider"
        case privacy = "Datenschutz"
        case storage = "Speicher"
        case shortcuts = "Tastenkürzel"
        case updates = "Updates"
        case backup = "Backup"
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView()
                .tabItem { Label("Allgemein", systemImage: "gear") }
                .tag(SettingsTab.general)
            
            AppearanceSettingsView()
                .tabItem { Label("Erscheinungsbild", systemImage: "paintbrush") }
                .tag(SettingsTab.appearance)
            
            ProviderSettingsView()
                .tabItem { Label("KI-Provider", systemImage: "cpu") }
                .tag(SettingsTab.providers)
            
            PrivacySettingsView()
                .tabItem { Label("Datenschutz", systemImage: "lock.shield") }
                .tag(SettingsTab.privacy)
            
            StorageSettingsView()
                .tabItem { Label("Speicher", systemImage: "externaldrive") }
                .tag(SettingsTab.storage)
            
            ShortcutsSettingsView()
                .tabItem { Label("Tastenkürzel", systemImage: "keyboard") }
                .tag(SettingsTab.shortcuts)
            
            UpdatesSettingsView()
                .tabItem { Label("Updates", systemImage: "arrow.clockwise") }
                .tag(SettingsTab.updates)
            
            BackupSettingsView()
                .tabItem { Label("Backup", systemImage: "archivebox") }
                .tag(SettingsTab.backup)
        }
        .frame(minWidth: 600, minHeight: 400)
        .navigationTitle("Einstellungen")
    }
}

struct GeneralSettingsView: View {
    @AppStorage("defaultLanguage") private var defaultLanguage = "Deutsch"
    @AppStorage("defaultGenre") private var defaultGenre = "Roman"
    @AppStorage("autoSave") private var autoSave = true
    @AppStorage("autoSaveInterval") private var autoSaveInterval = 5
    
    var body: some View {
        Form {
            Section("Standardeinstellungen") {
                Picker("Standardsprache", selection: $defaultLanguage) {
                    Text("Deutsch").tag("Deutsch")
                    Text("Englisch").tag("Englisch")
                    Text("Französisch").tag("Französisch")
                    Text("Spanisch").tag("Spanisch")
                }
                
                Picker("Standard-Genre", selection: $defaultGenre) {
                    Text("Thriller").tag("Thriller")
                    Text("Roman").tag("Roman")
                    Text("Fantasy").tag("Fantasy")
                    Text("Science Fiction").tag("Science Fiction")
                }
            }
            
            Section("Automatische Speicherung") {
                Toggle("Automatisch speichern", isOn: $autoSave)
                
                if autoSave {
                    Stepper("Intervall: \(autoSaveInterval) Minuten", value: $autoSaveInterval, in: 1...30)
                }
            }
            
            Section("Wiederherstellung") {
                Button("Nach Absturz wiederherstellen") {
                    // Check for unfinished projects
                }
            }
        }
        .formStyle(.grouped)
    }
}

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
                    Text("Graphit").tag("gray")
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ProviderSettingsView: View {
    @State private var providers: [ProviderConfiguration] = []
    @State private var showingAddProvider = false
    
    var body: some View {
        VStack {
            List {
                ForEach($providers) { $config in
                    ProviderRow(configuration: $config)
                }
                .onDelete { indexSet in
                    providers.remove(atOffsets: indexSet)
                }
            }
            
            Button("Provider hinzufügen") {
                showingAddProvider = true
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .onAppear {
            loadProviders()
        }
        .sheet(isPresented: $showingAddProvider) {
            AddProviderView { config in
                providers.append(config)
                saveProviders()
            }
        }
    }
    
    private func loadProviders() {
        // Load from UserDefaults or Keychain
        if let data = UserDefaults.standard.data(forKey: "providers"),
           let decoded = try? JSONDecoder().decode([ProviderConfiguration].self, from: data) {
            providers = decoded
        }
    }
    
    private func saveProviders() {
        if let encoded = try? JSONEncoder().encode(providers) {
            UserDefaults.standard.set(encoded, forKey: "providers")
        }
    }
}

struct ProviderRow: View {
    @Binding var configuration: ProviderConfiguration
    @State private var isTesting = false
    @State private var testResult: Bool?
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(configuration.provider.rawValue)
                    .font(.headline)
                if let model = configuration.defaultModel {
                    Text("Modell: \(model)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("Aktiv", isOn: $configuration.isActive)
            
            Button("Testen") {
                testConnection()
            }
            .buttonStyle(.bordered)
            .disabled(isTesting)
            
            if let result = testResult {
                Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(result ? .green : .red)
            }
        }
    }
    
    private func testConnection() {
        isTesting = true
        Task { @MainActor in
            let gateway = ProviderGateway.shared
            let result = await gateway.testConnection(configuration: configuration)
            testResult = result
            isTesting = false
        }
    }
}

struct AddProviderView: View {
    @Environment(\.dismiss) var dismiss
    let onAdd: (ProviderConfiguration) -> Void
    
    @State private var selectedProvider = AIProvider.openAI
    @State private var apiKey = ""
    @State private var baseURL = ""
    @State private var defaultModel = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                
                if selectedProvider.requiresAPIKey {
                    SecureField("API-Key", text: $apiKey)
                }
                
                TextField("Basis-URL (optional)", text: $baseURL)
                TextField("Standard-Modell", text: $defaultModel)
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
                        config.apiKey = apiKey
                        config.baseURL = baseURL.isEmpty ? nil : baseURL
                        config.defaultModel = defaultModel.isEmpty ? nil : defaultModel
                        config.isActive = true
                        
                        // Save API key to Keychain
                        if !apiKey.isEmpty {
                            KeychainService.saveAPIKey(apiKey, for: selectedProvider)
                        }
                        
                        onAdd(config)
                        dismiss()
                    }
                    .disabled(defaultModel.isEmpty)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 300)
    }
}

struct PrivacySettingsView: View {
    @AppStorage("sendDiagnostics") private var sendDiagnostics = false
    @AppStorage("cloudProcessing") private var cloudProcessing = true
    
    var body: some View {
        Form {
            Section("Datenschutz") {
                Toggle("Diagnosedaten senden", isOn: $sendDiagnostics)
                Toggle("Cloud-Verarbeitung erlauben", isOn: $cloudProcessing)
            }
            
            Section("Sicherheit") {
                Button("Alle API-Keys löschen") {
                    KeychainService.deleteAllAPIKeys()
                }
                .foregroundStyle(.red)
                
                Button("Alle Projektdaten löschen") {
                    // Clear all project data
                }
                .foregroundStyle(.red)
            }
            
            Section("Information") {
                Text("API-Keys werden sicher in der macOS Keychain gespeichert und niemals unverschlüsselt angezeigt.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

struct StorageSettingsView: View {
    @AppStorage("projectsPath") private var projectsPath = ""
    
    var body: some View {
        Form {
            Section("Speicherort") {
                HStack {
                    TextField("Projektpfad", text: $projectsPath)
                    Button("Durchsuchen") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK {
                            projectsPath = panel.url?.path ?? ""
                        }
                    }
                }
            }
            
            Section("Cache") {
                Button("Cache leeren") {
                    // Clear cache
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Tastenkürzel") {
                ShortcutRow(action: "Neues Buch", shortcut: "⌘N")
                ShortcutRow(action: "Speichern", shortcut: "⌘S")
                ShortcutRow(action: "Pipeline starten", shortcut: "⌘R")
                ShortcutRow(action: "Pause", shortcut: "⌘.")
                ShortcutRow(action: "Exportieren", shortcut: "⌘E")
                ShortcutRow(action: "Einstellungen", shortcut: "⌘,")
            }
        }
        .formStyle(.grouped)
    }
}

struct ShortcutRow: View {
    let action: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
        }
    }
}

struct UpdatesSettingsView: View {
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true
    @State private var currentVersion = "1.0.0"
    
    var body: some View {
        Form {
            Section("Updates") {
                Toggle("Automatisch nach Updates suchen", isOn: $autoCheckUpdates)
                
                HStack {
                    Text("Aktuelle Version")
                    Spacer()
                    Text(currentVersion)
                        .foregroundStyle(.secondary)
                }
                
                Button("Jetzt suchen") {
                    // Check for updates
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct BackupSettingsView: View {
    var body: some View {
        Form {
            Section("Backup") {
                Button("Vollständiges Backup erstellen") {
                    createBackup()
                }
                
                Button("Backup wiederherstellen") {
                    restoreBackup()
                }
                
                Button("Einstellungen exportieren") {
                    exportSettings()
                }
            }
        }
        .formStyle(.grouped)
    }
    
    private func createBackup() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "NovelForge_Backup.zip"
        if panel.runModal() == .OK, let _ = panel.url {
            // TODO: Implement backup creation
        }
    }
    
    private func restoreBackup() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.zip]
        if panel.runModal() == .OK, let _ = panel.url {
            // TODO: Implement backup restoration
        }
    }
    
    private func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "NovelForge_Settings.json"
        if panel.runModal() == .OK, let _ = panel.url {
            // TODO: Implement settings export
        }
    }
}