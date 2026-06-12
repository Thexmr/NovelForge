import SwiftUI
import SwiftData

@MainActor
struct NewBookWizardView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext

    /// Wird nach erfolgreichem Produktionsstart aufgerufen (z.B. um zur Produktionsansicht zu wechseln).
    var onStarted: (() -> Void)? = nil

    @AppStorage("defaultLanguage") private var defaultLanguage = "Deutsch"
    @AppStorage("defaultGenre") private var defaultGenre = "Roman"
    @AppStorage("defaultAuthor") private var defaultAuthor = ""
    @AppStorage("defaultImprint") private var defaultImprint = DefaultBookSettings.imprint
    @AppStorage("defaultAuthorBio") private var defaultAuthorBio = DefaultBookSettings.authorBio

    @State private var currentStep = 0

    // Schritt 1: Basisdaten
    @State private var title = ""
    @State private var authorName = ""
    @State private var language = "Deutsch"
    @State private var genre = ""
    @State private var subgenre = ""
    @State private var imprint = ""
    @State private var authorBio = ""

    // Schritt 2: Stil
    @State private var styleProfile = ""
    @State private var tonality = ""
    @State private var targetAudience = ""
    @State private var narrativePerspective = "Personaler Erzähler (Er/Sie)"
    @State private var tense = "Präteritum"

    // Schritt 3: Umfang und Formate
    @State private var targetPageCount = 250
    @State private var epubFormat = true
    @State private var pdfFormat = false
    @State private var docxFormat = false
    @State private var trimSize = TrimSize.sixByNine

    // Schritt 4: Provider
    @State private var selectedProvider = AIProvider.ollamaCloud
    @State private var selectedModel = AIProvider.ollamaCloud.suggestedModels.first ?? ""
    @State private var customModel = ""
    @State private var apiKey = ""
    @State private var baseURL = ""
    @State private var costLimit = 0.0

    @State private var validationMessage: String?

    // Ideen-Generator
    @State private var ideaSuggestions: [ParsedIdea] = []
    @State private var isGeneratingIdeas = false
    @State private var ideaError: String?
    @State private var seedPremise = ""

    let languages = ["Deutsch", "Englisch", "Französisch", "Spanisch"]
    let genres = ["Thriller", "Roman", "Fantasy", "Science Fiction", "Krimi",
                  "Liebesroman", "Historischer Roman", "Horror", "Jugendbuch", "Abenteuer"]
    let styles = ["düster", "literarisch", "dialogstark", "humorvoll", "episch",
                  "emotional", "schnell erzählt", "minimalistisch", "atmosphärisch",
                  "actionreich", "psychologisch"]
    let perspectives = ["Ich-Erzähler", "Personaler Erzähler (Er/Sie)",
                        "Auktorialer Erzähler", "Wechselnde Perspektiven"]
    let tenses = ["Präteritum", "Präsens"]

    private let stepTitles = ["Basis", "Stil", "Umfang", "KI-Provider", "Prüfen"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                    .padding(.horizontal)
                    .padding(.top, 12)

                Form {
                    switch currentStep {
                    case 0: basicDataSection
                    case 1: styleSection
                    case 2: formatSection
                    case 3: providerSection
                    case 4: reviewSection
                    default: EmptyView()
                    }
                }
                .formStyle(.grouped)

                if let message = validationMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                }

                HStack {
                    if currentStep > 0 {
                        Button("Zurück") {
                            validationMessage = nil
                            currentStep -= 1
                        }
                    }

                    Spacer()

                    if currentStep < 4 {
                        Button("Weiter") {
                            validationMessage = nil
                            currentStep += 1
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!isCurrentStepValid)
                    } else {
                        Button {
                            createProjectAndStart()
                        } label: {
                            Label("Produktion starten", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding()
            }
            .navigationTitle("Neues Buch")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .onAppear {
                language = defaultLanguage
                if genre.isEmpty && genres.contains(defaultGenre) { genre = defaultGenre }
                if defaultAuthor.isEmpty { defaultAuthor = DefaultBookSettings.authorName }
                if authorName.isEmpty { authorName = defaultAuthor }
                if imprint.isEmpty { imprint = defaultImprint }
                if authorBio.isEmpty { authorBio = defaultAuthorBio }
            }
        }
        .frame(minWidth: 640, minHeight: 560)
    }

    // MARK: - Schritt-Indikator

    private var stepIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<5) { step in
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(step <= currentStep ? Color.accentColor : Color.gray.opacity(0.25))
                        .frame(height: 4)
                        .clipShape(Capsule())
                    Text(stepTitles[step])
                        .font(.caption2)
                        .foregroundStyle(step <= currentStep ? .primary : .tertiary)
                }
            }
        }
    }

    // MARK: - Schritte

    private var basicDataSection: some View {
        Group {
            Section("Basisdaten") {
                TextField("Titel", text: $title)
                TextField("Autorname oder Pseudonym", text: $authorName)
                TextEditor(text: $authorBio)
                    .frame(minHeight: 70)
                    .overlay(alignment: .topLeading) {
                        if authorBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Über den Autor (kurze Bio für Buch und KDP-Metadaten)")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                TextEditor(text: $imprint)
                    .frame(minHeight: 70)
                    .overlay(alignment: .topLeading) {
                        if imprint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Impressum / Copyright-Hinweis für KDP")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }

                Picker("Sprache", selection: $language) {
                    ForEach(languages, id: \.self) { Text($0).tag($0) }
                }

                Picker("Genre", selection: $genre) {
                    Text("Bitte wählen").tag("")
                    ForEach(genres, id: \.self) { Text($0).tag($0) }
                }

                TextField("Subgenre (optional)", text: $subgenre)
            }

            Section("Inspiration") {
                ForEach(Array(ideaSuggestions.enumerated()), id: \.offset) { _, idea in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(idea.title)
                                .fontWeight(.semibold)
                            Text(idea.genre)
                                .font(.caption)
                                .foregroundStyle(.tint)
                            Text(idea.premise)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Übernehmen") {
                            applyIdea(idea)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.vertical, 2)
                }

                if !seedPremise.isEmpty {
                    Label("Ideenkern übernommen – fließt als Ausgangspunkt in die Konzeptentwicklung ein.",
                          systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }

                if let ideaError {
                    Text(ideaError)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Button {
                    generateIdeas()
                } label: {
                    Label(isGeneratingIdeas ? "Ideen werden entwickelt …" : "Buchideen vorschlagen lassen",
                          systemImage: isGeneratingIdeas ? "hourglass" : "lightbulb")
                }
                .disabled(isGeneratingIdeas || usableIdeaConfig() == nil)

                if usableIdeaConfig() == nil {
                    Text("Für den Ideen-Generator zuerst einen KI-Provider mit API-Key hinterlegen (Einstellungen → KI-Provider).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @MainActor
    private func usableIdeaConfig() -> ProviderConfiguration? {
        let store = ProviderSettingsStore.shared
        for var config in store.configurations where config.isActive {
            if !config.provider.requiresAPIKey || store.hasAPIKey(for: config.provider) {
                config.apiKey = KeychainService.getAPIKey(for: config.provider)
                return config
            }
        }
        return nil
    }

    @MainActor
    private func generateIdeas() {
        guard let config = usableIdeaConfig() else { return }
        isGeneratingIdeas = true
        ideaError = nil

        let request = GenerationRequest(
            prompt: PromptFactory.bookIdeas(genre: genre, language: language),
            systemPrompt: "Du bist ein Verlagslektor mit sicherem Gespür für verkäufliche, originelle Buchideen.",
            model: config.defaultModel ?? config.provider.suggestedModels.first ?? "",
            provider: config.provider,
            maxTokens: 800,
            temperature: 0.9
        )

        Task { @MainActor in
            defer { isGeneratingIdeas = false }
            do {
                let response = try await ProviderGateway.shared.generateText(request: request, configuration: config)
                ideaSuggestions = StructureParser.parseIdeas(response.text)
                if ideaSuggestions.isEmpty {
                    ideaError = "Keine Ideen erkannt – bitte erneut versuchen."
                }
            } catch let error as AIError {
                ideaError = error.errorDescription
            } catch {
                ideaError = error.localizedDescription
            }
        }
    }

    @MainActor
    private func applyIdea(_ idea: ParsedIdea) {
        title = idea.title
        if genres.contains(idea.genre) {
            genre = idea.genre
        } else if !idea.genre.isEmpty {
            subgenre = idea.genre
        }
        seedPremise = idea.premise
    }

    private var styleSection: some View {
        Section("Stil und Zielgruppe") {
            Picker("Stilprofil", selection: $styleProfile) {
                Text("Bitte wählen").tag("")
                ForEach(styles, id: \.self) { Text($0).tag($0) }
            }

            TextField("Tonalität (z.B. melancholisch, hoffnungsvoll)", text: $tonality)
            TextField("Zielgruppe (z.B. Erwachsene 30+, Krimifans)", text: $targetAudience)

            Picker("Erzählperspektive", selection: $narrativePerspective) {
                ForEach(perspectives, id: \.self) { Text($0).tag($0) }
            }

            Picker("Zeitform", selection: $tense) {
                ForEach(tenses, id: \.self) { Text($0).tag($0) }
            }
        }
    }

    private var formatSection: some View {
        Group {
            Section("Umfang") {
                Stepper("Zielseitenzahl: \(targetPageCount)", value: $targetPageCount,
                        in: AppConstants.minPageCount...AppConstants.maxPageCount, step: 10)
                LabeledContent("Geschätzte Wörter", value: FormattingHelpers.formatWordCount(targetPageCount * AppConstants.wordsPerPage))
                LabeledContent("Geschätzte Kapitel", value: "\(max(10, targetPageCount / 15))")
            }
            Section("Exportformate") {
                Toggle("EPUB (eBook, Amazon KDP)", isOn: $epubFormat)
                Toggle("PDF (Print: Paperback/Hardcover)", isOn: $pdfFormat)
                Toggle("DOCX (bearbeitbares Manuskript)", isOn: $docxFormat)
            }
            Section("Print-Format (KDP)") {
                Picker("Trim-Größe", selection: $trimSize) {
                    ForEach(TrimSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                Text("Der PDF-Export verwendet Spiegelränder mit KDP-konformem Bundsteg, Blocksatz und Seitenzahlen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var providerSection: some View {
        Group {
            Section("KI-Provider") {
                Picker("Provider", selection: $selectedProvider) {
                    ForEach(AIProvider.allCases) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                }
                .onChange(of: selectedProvider) {
                    selectedModel = selectedProvider.suggestedModels.first ?? ""
                    customModel = ""
                    baseURL = ""
                }

                DynamicModelPicker(provider: selectedProvider,
                                   selectedModel: $selectedModel,
                                   customModel: $customModel,
                                   pendingAPIKey: apiKey)

                if selectedProvider.needsBaseURLInput {
                    TextField("Basis-URL (OpenAI-kompatibler Endpunkt)", text: $baseURL)
                }
            }

            if selectedProvider.requiresAPIKey {
                Section("Zugang") {
                    SecureField("API-Key", text: $apiKey)
                    if hasStoredKey {
                        Label("Für diesen Provider ist bereits ein API-Key in der Keychain hinterlegt. Feld leer lassen, um ihn zu verwenden.",
                              systemImage: "key.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Der API-Key wird sicher in der macOS Keychain gespeichert – niemals im Klartext.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Kostenkontrolle") {
                Stepper(costLimit == 0 ? "Kostenlimit: kein App-Limit" : "Kostenlimit: \(Int(costLimit)) USD",
                        value: $costLimit, in: 0...1000, step: 10)
                if let estimate = estimatedCostText {
                    LabeledContent("Geschätzte Produktionskosten", value: estimate)
                }
                Text("Die Pipeline stoppt automatisch, wenn die geschätzten Kosten das Limit erreichen. Der Fortschritt bleibt erhalten.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var reviewSection: some View {
        Group {
            Section("Zusammenfassung") {
                ReviewRow(label: "Titel", value: title)
                ReviewRow(label: "Autor", value: authorName)
                if !authorBio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ReviewRow(label: "Autorprofil", value: authorBio.truncated(to: 120))
                }
                if !imprint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ReviewRow(label: "Impressum", value: imprint.truncated(to: 120))
                }
                ReviewRow(label: "Genre", value: subgenre.isEmpty ? genre : "\(genre) / \(subgenre)")
                ReviewRow(label: "Sprache", value: language)
                ReviewRow(label: "Stil", value: "\(styleProfile)\(tonality.isEmpty ? "" : ", \(tonality)")")
                ReviewRow(label: "Perspektive", value: "\(narrativePerspective), \(tense)")
                ReviewRow(label: "Umfang", value: "\(targetPageCount) Seiten · ca. \(FormattingHelpers.formatWordCount(targetPageCount * AppConstants.wordsPerPage)) Wörter")
                ReviewRow(label: "Formate", value: selectedFormats.joined(separator: ", "))
                ReviewRow(label: "Trim-Größe", value: trimSize.displayName)
                ReviewRow(label: "Provider", value: selectedProvider.rawValue)
                ReviewRow(label: "Modell", value: effectiveModel)
                ReviewRow(label: "Kostenlimit", value: "\(Int(costLimit)) USD")
            }
            Section("Hinweise") {
                Label("Die Produktion läuft vollautomatisch: Konzept → Plot → Figuren → Kapitel → Szenen → Rohfassung → Revision → Korrektorat → Export.", systemImage: "wand.and.stars")
                Label("Sie können jederzeit pausieren und später fortsetzen – ohne doppelte Kosten.", systemImage: "pause.circle")
                Label("Die finale Veröffentlichung (z.B. bei Amazon KDP) bleibt bei Ihnen.", systemImage: "person.crop.circle.badge.checkmark")
            }
            .font(.callout)
        }
    }

    // MARK: - Logik

    private var selectedFormats: [String] {
        var formats: [String] = []
        if epubFormat { formats.append("EPUB") }
        if pdfFormat { formats.append("PDF") }
        if docxFormat { formats.append("DOCX") }
        return formats
    }

    private var effectiveModel: String {
        let custom = customModel.trimmingCharacters(in: .whitespaces)
        return custom.isEmpty ? selectedModel : custom
    }

    private var hasStoredKey: Bool {
        ProviderSettingsStore.shared.hasAPIKey(for: selectedProvider)
    }

    private var estimatedCostText: String? {
        let rate = ModelPricing.ratePer1K(model: effectiveModel)
        guard rate > 0 else {
            return selectedProvider == .ollamaLocal ? "kostenlos (lokal)" : nil
        }
        // Grobe Schätzung: ~6 Tokens je Zielwort über alle Phasen (Ein- und Ausgabe).
        let estimatedTokens = targetPageCount * AppConstants.wordsPerPage * 6
        return "ca. " + FormattingHelpers.formatCost(Double(estimatedTokens) / 1000.0 * rate)
    }

    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 0:
            return !title.trimmingCharacters(in: .whitespaces).isEmpty
                && !authorName.trimmingCharacters(in: .whitespaces).isEmpty
                && !genre.isEmpty
        case 1:
            return !styleProfile.isEmpty
        case 2:
            return !selectedFormats.isEmpty
        case 3:
            if effectiveModel.isEmpty { return false }
            if selectedProvider == .custom && baseURL.trimmingCharacters(in: .whitespaces).isEmpty { return false }
            return true
        default:
            return true
        }
    }

    @MainActor
    private func createProjectAndStart() {
        validationMessage = nil

        let copyrightCheck = CopyrightChecker.checkInput(title: title, style: styleProfile)
        guard copyrightCheck.isValid else {
            validationMessage = copyrightCheck.warnings.joined(separator: " · ")
            return
        }

        let project = Project(
            title: title.trimmingCharacters(in: .whitespaces),
            authorName: authorName.trimmingCharacters(in: .whitespaces),
            language: language,
            genre: genre,
            styleProfile: styleProfile,
            targetPageCount: targetPageCount,
            outputFormats: selectedFormats
        )
        project.subgenre = subgenre.isEmpty ? nil : subgenre
        project.trimSizeRaw = trimSize.rawValue
        project.preferredProviderRaw = selectedProvider.rawValue
        project.preferredModel = effectiveModel
        project.costLimitUSD = costLimit
        project.imprint = imprint.trimmingCharacters(in: .whitespacesAndNewlines)
        project.authorBio = authorBio.trimmingCharacters(in: .whitespacesAndNewlines)

        let bookProfile = BookProfile(
            premise: seedPremise,
            theme: "",
            targetAudience: targetAudience,
            tonality: tonality.isEmpty ? styleProfile : tonality,
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
        try? modelContext.save()

        // API-Key in der Keychain hinterlegen und Provider-Konfiguration aktualisieren.
        if !apiKey.isEmpty {
            ProviderSettingsStore.shared.setAPIKey(apiKey, for: selectedProvider)
        }
        var config = ProviderConfiguration(provider: selectedProvider)
        config.isActive = true
        config.defaultModel = effectiveModel
        if !baseURL.isEmpty {
            config.baseURL = baseURL
        }
        config.costLimit = costLimit
        ProviderSettingsStore.shared.upsert(config)
        config.apiKey = KeychainService.getAPIKey(for: selectedProvider)

        // Autor & Sprache als Standard merken.
        defaultAuthor = project.authorName
        defaultLanguage = language
        defaultImprint = project.imprint
        defaultAuthorBio = project.authorBio

        PipelineOrchestrator.shared.startPipeline(project: project, providerConfig: config)
        onStarted?()
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
                .multilineTextAlignment(.trailing)
        }
    }
}
