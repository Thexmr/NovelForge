import SwiftUI
import SwiftData

@MainActor
struct NewBookWizardView: View {
    static let availableGenres = UnlimitedSettings.genrePool
    /// Sentinel-Tag für „eigenes Genre frei eingeben" im Genre-Picker.
    static let customGenreTag = "__eigenes_genre__"

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
    @State private var customGenre = ""
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

    @State private var validationMessage: String?

    // Ideen-Generator
    @State private var ideaSuggestions: [ParsedIdea] = []
    @State private var isGeneratingIdeas = false
    @State private var ideaError: String?
    @State private var seedPremise = ""

    // Viraler Titel-Generator
    @State private var titleSuggestions: [String] = []
    @State private var isGeneratingTitles = false
    @State private var titleError: String?

    // Trope-Vertrag
    @State private var tropes = ""
    @State private var spiceLevel = 0
    @State private var tropeSuggestions: [String] = []
    @State private var isGeneratingTropes = false
    @State private var tropeError: String?

    // Serie (Read-Through)
    @State private var seriesName = ""
    @State private var seriesNumber = 1

    let languages = ["Deutsch", "Englisch", "Französisch", "Spanisch"]
    let genres = Self.availableGenres
    let styles = ["düster", "literarisch", "dialogstark", "humorvoll", "episch",
                  "emotional", "schnell erzählt", "minimalistisch", "atmosphärisch",
                  "actionreich", "psychologisch"]
    let perspectives = ["Ich-Erzähler", "Personaler Erzähler (Er/Sie)",
                        "Auktorialer Erzähler", "Wechselnde Perspektiven"]
    let tenses = ["Präteritum", "Präsens"]

    private let stepTitles = ["Basis", "Stil", "Umfang", "KI-Provider", "Prüfen"]

    /// Das tatsächlich zu verwendende Genre: bei „Andere…" der frei eingegebene Text,
    /// sonst die Picker-Auswahl.
    private var effectiveGenre: String {
        if genre == Self.customGenreTag {
            return customGenre.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return genre
    }

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
                HStack {
                    Button {
                        generateViralTitles()
                    } label: {
                        if isGeneratingTitles {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Titel …") }
                        } else {
                            Label("Virale Titel vorschlagen", systemImage: "sparkles")
                        }
                    }
                    .disabled(isGeneratingTitles)
                    if let titleError {
                        Text(titleError).font(.caption).foregroundStyle(.red)
                    }
                }
                if !titleSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(titleSuggestions, id: \.self) { t in
                            Button { title = t } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: title == t ? "checkmark.circle.fill" : "wand.and.stars")
                                        .font(.caption)
                                        .foregroundStyle(title == t ? .green : .secondary)
                                    Text(t).foregroundStyle(.primary)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                TextField("Autorname oder Pseudonym", text: $authorName)

                Text("Autorprofil")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
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

                Text("Impressum / Copyright (für KDP)")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
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
                    Divider()
                    Text("Andere (frei eingeben)…").tag(Self.customGenreTag)
                }

                if genre == Self.customGenreTag {
                    TextField("Eigenes Genre", text: $customGenre)
                }

                TextField("Subgenre (optional)", text: $subgenre)

                TextField("Tropes (kommagetrennt – z.B. Enemies to Lovers, Slow Burn)", text: $tropes)
                HStack {
                    Button {
                        generateTropes()
                    } label: {
                        if isGeneratingTropes {
                            HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Tropes …") }
                        } else {
                            Label("Tropes vorschlagen", systemImage: "tag")
                        }
                    }
                    .disabled(isGeneratingTropes)
                    if let tropeError {
                        Text(tropeError).font(.caption).foregroundStyle(.red)
                    }
                }
                if !tropeSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(tropeSuggestions, id: \.self) { t in
                            Button { addTrope(t) } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: tropeIsSelected(t) ? "checkmark.circle.fill" : "plus.circle")
                                        .font(.caption)
                                        .foregroundStyle(tropeIsSelected(t) ? .green : .secondary)
                                    Text(t).foregroundStyle(.primary)
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Picker("Sinnlichkeitsgrad", selection: $spiceLevel) {
                    Text("Nicht angegeben").tag(0)
                    ForEach(SpiceLevel.range, id: \.self) { lvl in
                        Text(SpiceLevel.pickerLabel(lvl)).tag(lvl)
                    }
                }
                Text("Branchenübliche Einstufung der erotischen Intensität (1–5). Steuert die Ausführlichkeit intimer Szenen und die passende Einordnung in Verkaufstext, Keywords und Kategorien.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Serie / Reihe (optional – für Read-Through)")
                    .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                HStack(spacing: 12) {
                    TextField("Reihenname", text: $seriesName)
                    if !seriesName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Stepper("Band \(seriesNumber)", value: $seriesNumber, in: 1...50)
                            .fixedSize()
                    }
                }
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
            prompt: PromptFactory.bookIdeas(genre: effectiveGenre, language: language),
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
    private func generateViralTitles() {
        guard let config = usableIdeaConfig() else {
            titleError = "Kein KI-Provider konfiguriert – bitte im Schritt KI-Provider einrichten."
            return
        }
        isGeneratingTitles = true
        titleError = nil

        let request = GenerationRequest(
            prompt: PromptFactory.viralTitles(genre: effectiveGenre, premise: seedPremise, language: language),
            systemPrompt: "Du bist ein Bestseller-Titel-Experte für virale, unverwechselbare Buchtitel, die beim Scrollen sofort hängenbleiben.",
            model: config.defaultModel ?? config.provider.suggestedModels.first ?? "",
            provider: config.provider,
            maxTokens: 400,
            temperature: 0.95
        )

        Task { @MainActor in
            defer { isGeneratingTitles = false }
            do {
                let response = try await ProviderGateway.shared.generateText(request: request, configuration: config)
                let titles = StructureParser.parseTitleLines(response.text)
                if titles.isEmpty {
                    titleError = "Keine Titel erkannt – bitte erneut versuchen."
                } else {
                    // Stärksten Titel nach oben (gleiche Heuristik wie die Auto-Produktion).
                    titleSuggestions = titles.sorted {
                        AutonomousContentQuality.titleViralityScore($0)
                            > AutonomousContentQuality.titleViralityScore($1)
                    }
                }
            } catch let error as AIError {
                titleError = error.errorDescription
            } catch {
                titleError = error.localizedDescription
            }
        }
    }

    @MainActor
    private func generateTropes() {
        guard let config = usableIdeaConfig() else {
            tropeError = "Kein KI-Provider konfiguriert."
            return
        }
        isGeneratingTropes = true
        tropeError = nil
        let request = GenerationRequest(
            prompt: PromptFactory.tropeSuggestions(genre: effectiveGenre, premise: seedPremise),
            systemPrompt: "Du kennst die meistgesuchten, bankfähigen Tropes pro Genre auf Amazon KDP.",
            model: config.defaultModel ?? config.provider.suggestedModels.first ?? "",
            provider: config.provider, maxTokens: 300, temperature: 0.8)
        Task { @MainActor in
            defer { isGeneratingTropes = false }
            do {
                let response = try await ProviderGateway.shared.generateText(request: request, configuration: config)
                let list = StructureParser.parseTitleLines(response.text)
                if list.isEmpty { tropeError = "Keine Tropes erkannt – bitte erneut." }
                else { tropeSuggestions = list }
            } catch let error as AIError {
                tropeError = error.errorDescription
            } catch {
                tropeError = error.localizedDescription
            }
        }
    }

    private func tropeIsSelected(_ trope: String) -> Bool {
        tropes.localizedCaseInsensitiveContains(trope)
    }

    private func addTrope(_ trope: String) {
        guard !tropeIsSelected(trope) else { return }
        let trimmed = tropes.trimmingCharacters(in: .whitespacesAndNewlines)
        tropes = trimmed.isEmpty ? trope : trimmed + ", " + trope
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

            Section("Nutzung") {
                if let estimate = estimatedCostText {
                    LabeledContent("Geschätzte Produktionskosten", value: estimate)
                }
                Text("Die Produktion läuft durch, solange der Provider Antworten liefert.")
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
                if SpiceLevel.isValid(spiceLevel) {
                    ReviewRow(label: "Sinnlichkeit", value: SpiceLevel.pickerLabel(spiceLevel))
                }
                ReviewRow(label: "Sprache", value: language)
                ReviewRow(label: "Stil", value: "\(styleProfile)\(tonality.isEmpty ? "" : ", \(tonality)")")
                ReviewRow(label: "Perspektive", value: "\(narrativePerspective), \(tense)")
                ReviewRow(label: "Umfang", value: "\(targetPageCount) Seiten · ca. \(FormattingHelpers.formatWordCount(targetPageCount * AppConstants.wordsPerPage)) Wörter")
                ReviewRow(label: "Formate", value: selectedFormats.joined(separator: ", "))
                ReviewRow(label: "Trim-Größe", value: trimSize.displayName)
                ReviewRow(label: "Provider", value: selectedProvider.rawValue)
                ReviewRow(label: "Modell", value: effectiveModel)
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
                && !effectiveGenre.isEmpty
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
            genre: effectiveGenre,
            styleProfile: styleProfile,
            targetPageCount: targetPageCount,
            outputFormats: selectedFormats
        )
        project.subgenre = subgenre.isEmpty ? nil : subgenre
        project.tropes = tropes.trimmingCharacters(in: .whitespacesAndNewlines)
        project.spiceLevel = spiceLevel
        let trimmedSeries = seriesName.trimmingCharacters(in: .whitespacesAndNewlines)
        project.seriesName = trimmedSeries
        project.seriesNumber = trimmedSeries.isEmpty ? 0 : seriesNumber
        project.trimSizeRaw = trimSize.rawValue
        project.preferredProviderRaw = selectedProvider.rawValue
        project.preferredModel = effectiveModel
        project.imprint = imprint.trimmingCharacters(in: .whitespacesAndNewlines)
        project.authorBio = authorBio.trimmingCharacters(in: .whitespacesAndNewlines)

        // Einzigartige Stil-DNA pro Buch (gegen Amazon-„Programmatic Content"-Erkennung).
        // Die vom Autor gewählte Perspektive/Zeitform bleibt erhalten; die übrigen
        // Dimensionen (Struktur, Eröffnung, Stimme, Leitmotiv …) variieren pro Buch.
        let signature = NarrativeSignature.make(
            seed: NarrativeSignature.stableSeed("\(project.id.uuidString)|\(project.title)|\(effectiveGenre)")
        )
        project.styleSignature = signature.directiveText(
            povOverride: narrativePerspective, tenseOverride: tense
        )

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
        modelContext.saveOrLog()

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
