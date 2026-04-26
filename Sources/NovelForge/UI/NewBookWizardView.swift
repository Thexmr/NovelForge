import SwiftUI
import SwiftData

struct NewBookWizardView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    
    @State private var currentStep = 0
    
    // Step 1: Basic Data
    @State private var title = ""
    @State private var authorName = ""
    @State private var language = "Deutsch"
    @State private var genre = ""
    @State private var subgenre = ""
    
    // Step 2: Style
    @State private var styleProfile = ""
    @State private var tonality = ""
    @State private var targetAudience = ""
    @State private var narrativePerspective = ""
    @State private var tense = "Präsens"
    
    // Step 3: Length and Format
    @State private var targetPageCount = 300
    @State private var ebookFormat = true
    @State private var paperbackFormat = false
    @State private var hardcoverFormat = false
    @State private var trimSize = "6 x 9 Zoll"
    
    // Step 4: Provider
    @State private var selectedProvider = AIProvider.openAI
    @State private var selectedModel = "gpt-4o"
    @State private var apiKey = ""
    @State private var costLimit = 50.0
    
    let languages = ["Deutsch", "Englisch", "Französisch", "Spanisch"]
    let genres = ["Thriller", "Roman", "Fantasy", "Science Fiction", "Krimi", "Liebesroman", "Historischer Roman", "Horror"]
    let styles = ["düster", "literarisch", "dialogstark", "humorvoll", "episch", "emotional", "schnell erzählt", "minimalistisch", "atmosphärisch", "actionreich", "psychologisch"]
    let perspectives = ["Ich-Erzähler", "Er-Erzähler", "Außerirdischer Erzähler", "Wechselnde Perspektiven"]
    let tenses = ["Präsens", "Präteritum", "Perfekt"]
    let trimSizes = ["5 x 8 Zoll", "5.5 x 8.5 Zoll", "6 x 9 Zoll"]
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                HStack(spacing: 4) {
                    ForEach(0..<5) { step in
                        Rectangle()
                            .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(height: 4)
                    }
                }
                .padding()
                
                // Step content
                Form {
                    switch currentStep {
                    case 0:
                        basicDataSection
                    case 1:
                        styleSection
                    case 2:
                        formatSection
                    case 3:
                        providerSection
                    case 4:
                        reviewSection
                    default:
                        EmptyView()
                    }
                }
                .formStyle(.grouped)
                
                Spacer()
                
                // Navigation buttons
                HStack {
                    if currentStep > 0 {
                        Button("Zurück") {
                            currentStep -= 1
                        }
                    }
                    
                    Spacer()
                    
                    if currentStep < 4 {
                        Button("Weiter") {
                            if validateCurrentStep() {
                                currentStep += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isCurrentStepValid)
                    } else {
                        Button("Buchproduktion starten") {
                            createProject()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle("Neues Buch")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
        .frame(minWidth: 600, minHeight: 500)
    }
    
    private var basicDataSection: some View {
        Section("Basisdaten") {
            TextField("Titel", text: $title)
            TextField("Autorname oder Pseudonym", text: $authorName)
            
            Picker("Sprache", selection: $language) {
                ForEach(languages, id: \.self) { lang in
                    Text(lang).tag(lang)
                }
            }
            
            Picker("Genre", selection: $genre) {
                Text("Bitte wählen").tag("")
                ForEach(genres, id: \.self) { g in
                    Text(g).tag(g)
                }
            }
            
            TextField("Subgenre (optional)", text: $subgenre)
        }
    }
    
    private var styleSection: some View {
        Section("Stil und Zielgruppe") {
            Picker("Stilprofil", selection: $styleProfile) {
                Text("Bitte wählen").tag("")
                ForEach(styles, id: \.self) { style in
                    Text(style).tag(style)
                }
            }
            
            TextField("Tonalität", text: $tonality)
            TextField("Zielgruppe", text: $targetAudience)
            
            Picker("Erzählperspektive", selection: $narrativePerspective) {
                ForEach(perspectives, id: \.self) { p in
                    Text(p).tag(p)
                }
            }
            
            Picker("Zeitform", selection: $tense) {
                ForEach(tenses, id: \.self) { t in
                    Text(t).tag(t)
                }
            }
        }
    }
    
    private var formatSection: some View {
        Section("Länge und Format") {
            Stepper("Zielseitenzahl: \(targetPageCount)", value: $targetPageCount, in: 50...500, step: 10)
            
            Toggle("eBook", isOn: $ebookFormat)
            Toggle("Paperback", isOn: $paperbackFormat)
            Toggle("Hardcover", isOn: $hardcoverFormat)
            
            Picker("Trim Size", selection: $trimSize) {
                ForEach(trimSizes, id: \.self) { size in
                    Text(size).tag(size)
                }
            }
        }
    }
    
    private var providerSection: some View {
        Section("KI-Provider") {
            Picker("Provider", selection: $selectedProvider) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.rawValue).tag(provider)
                }
            }
            
            if selectedProvider.requiresAPIKey {
                SecureField("API-Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            TextField("Modell", text: $selectedModel)
            
            Stepper("Kostenlimit: \(costLimit, specifier: "%.0f") USD", value: $costLimit, in: 10...500, step: 10)
        }
    }
    
    private var reviewSection: some View {
        Section("Prüfung") {
            VStack(alignment: .leading, spacing: 12) {
                ReviewRow(label: "Titel", value: title)
                ReviewRow(label: "Autor", value: authorName)
                ReviewRow(label: "Genre", value: genre)
                ReviewRow(label: "Sprache", value: language)
                ReviewRow(label: "Stil", value: styleProfile)
                ReviewRow(label: "Seiten", value: "\(targetPageCount)")
                ReviewRow(label: "Geschätzte Wörter", value: "\(targetPageCount * 250)")
                ReviewRow(label: "Geschätzte Kapitel", value: "\(max(10, targetPageCount / 15))")
                ReviewRow(label: "Provider", value: selectedProvider.rawValue)
                ReviewRow(label: "Modell", value: selectedModel)
                
                Divider()
                
                Text("KDP-Hinweise")
                    .font(.headline)
                Text("• Ein Buchprojekt hat genau eine Hauptsprache")
                Text("• Übersetzungen sollten als eigene Projekte behandelt werden")
                Text("• Die finale Veröffentlichung bleibt beim Nutzer")
                
                if !apiKey.isEmpty {
                    Divider()
                    Text("API-Key wird sicher in der macOS Keychain gespeichert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 0:
            return !title.isEmpty && !authorName.isEmpty && !genre.isEmpty
        case 1:
            return !styleProfile.isEmpty
        case 2:
            return targetPageCount >= 50 && targetPageCount <= 500
        case 3:
            return !selectedModel.isEmpty && (!selectedProvider.requiresAPIKey || !apiKey.isEmpty)
        default:
            return true
        }
    }
    
    private func validateCurrentStep() -> Bool {
        return isCurrentStepValid
    }
    
    private func createProject() {
        var formats: [String] = []
        if ebookFormat { formats.append("EPUB") }
        if paperbackFormat { formats.append("PDF") }
        if hardcoverFormat { formats.append("PDF") }
        
        let project = Project(
            title: title,
            authorName: authorName,
            language: language,
            genre: genre,
            styleProfile: styleProfile,
            targetPageCount: targetPageCount,
            outputFormats: formats
        )
        
        let bookProfile = BookProfile(
            premise: "",
            theme: "",
            targetAudience: targetAudience,
            tonality: tonality,
            narrativePerspective: narrativePerspective,
            tense: tense
        )
        bookProfile.project = project
        
        let storyBible = StoryBible()
        storyBible.project = project
        
        project.bookProfile = bookProfile
        project.storyBible = storyBible
        
        modelContext.insert(project)
        modelContext.insert(bookProfile)
        modelContext.insert(storyBible)
        
        // Save API key to Keychain if provided
        if !apiKey.isEmpty {
            KeychainService.saveAPIKey(apiKey, for: selectedProvider)
        }
        
        dismiss()
    }
}

struct ReviewRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
    }
}