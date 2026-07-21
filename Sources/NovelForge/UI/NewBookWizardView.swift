import SwiftUI
import SwiftData

@MainActor
struct NewBookWizardView: View {
    static let availableGenres = UnlimitedSettings.genrePool
    /// Sentinel-Tag für „eigenes Genre frei eingeben" im Genre-Picker.
    static let customGenreTag = "__eigenes_genre__"

    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    @State private var contentType = BookContentType.fiction
    @State private var genre = ""
    @State private var customGenre = ""
    @State private var subgenre = ""
    @State private var imprint = ""
    @State private var authorBio = ""
    @State private var authorBioSuggestions: [String] = []
    @State private var isGeneratingAuthorBio = false
    @State private var authorBioError: String?

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
    private var genres: [String] {
        Self.availableGenres.filter { BookContentType.infer(from: $0) == contentType }
    }
    let styles = ["düster", "literarisch", "dialogstark", "humorvoll", "episch",
                  "emotional", "schnell erzählt", "minimalistisch", "atmosphärisch",
                  "actionreich", "psychologisch"]
    let perspectives = ["Ich-Erzähler", "Personaler Erzähler (Er/Sie)",
                        "Auktorialer Erzähler", "Wechselnde Perspektiven"]
    let tenses = ["Präteritum", "Präsens"]

    private let stepTitles = ["Basis", "Stil", "Umfang", "KI-Provider", "Prüfen"]
    private let stepIcons = ["book.closed", "text.quote", "doc.text", "cloud", "checkmark.seal"]

    /// Das tatsächlich zu verwendende Genre: bei „Andere…" der frei eingegebene Text,
    /// sonst die Picker-Auswahl.
    private var effectiveGenre: String {
        if genre == Self.customGenreTag {
            let custom = customGenre.trimmingCharacters(in: .whitespacesAndNewlines)
            return contentType == .nonfiction && !custom.isEmpty ? "Sachbuch: \(custom)" : custom
        }
        return genre
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StudioBackground()

                VStack(spacing: 0) {
                    wizardHeader

                    Form {
                        Group {
                            switch currentStep {
                            case 0: basicDataSection
                            case 1: styleSection
                            case 2: formatSection
                            case 3: providerSection
                            case 4: reviewSection
                            default: EmptyView()
                            }
                        }
                        .id(currentStep)
                        .transition(reduceMotion
                                    ? .opacity
                                    : .opacity.combined(with: .move(edge: .trailing)))
                    }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .animation(reduceMotion ? nil : Motion.standard, value: currentStep)

                    if let message = validationMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(StudioTheme.amber)
                            Text(message)
                                .font(.caption)
                                .foregroundStyle(StudioTheme.textMuted)
                            Spacer()
                        }
                        .padding(10)
                        .studioGlassTile(cornerRadius: 7, accent: StudioTheme.amber, opacity: 0.9)
                        .padding(.horizontal, 16)
                    }

                    HStack(spacing: 12) {
                        if currentStep > 0 {
                            Button {
                                validationMessage = nil
                                withAnimation(reduceMotion ? nil : Motion.standard) {
                                    currentStep -= 1
                                }
                            } label: {
                                Label("Zurück", systemImage: "chevron.left")
                            }
                            .buttonStyle(StudioSecondaryButtonStyle(accent: StudioTheme.violet))
                        }

                        if !isCurrentStepValid, let requirement = currentStepRequirement {
                            Text(requirement)
                                .font(.caption)
                                .foregroundStyle(StudioTheme.textMuted)
                                .lineLimit(2)
                        }

                        Spacer()

                        if currentStep < 4 {
                            Button {
                                validationMessage = nil
                                withAnimation(reduceMotion ? nil : Motion.standard) {
                                    currentStep += 1
                                }
                            } label: {
                                Label("Weiter", systemImage: "chevron.right")
                                    .labelStyle(.titleAndIcon)
                            }
                            .buttonStyle(StudioPrimaryButtonStyle())
                            .frame(width: 150)
                            .disabled(!isCurrentStepValid)
                        } else {
                            Button {
                                createProjectAndStart()
                            } label: {
                                Label("Produktion starten", systemImage: "play.fill")
                            }
                            .buttonStyle(StudioPrimaryButtonStyle())
                            .frame(width: 210)
                        }
                    }
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .overlay(alignment: .top) { StudioTheme.hairline.frame(height: 1) }
                }
            }
            .navigationTitle("Neues Buch")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .onAppear {
                language = defaultLanguage
                contentType = BookContentType.infer(from: defaultGenre)
                if genre.isEmpty && genres.contains(defaultGenre) { genre = defaultGenre }
                if defaultAuthor.isEmpty { defaultAuthor = DefaultBookSettings.authorName }
                if authorName.isEmpty { authorName = defaultAuthor }
                if imprint.isEmpty { imprint = defaultImprint }
                if authorBio.isEmpty { authorBio = defaultAuthorBio }
            }
        }
        .frame(minWidth: 720, minHeight: 640)
    }

    // MARK: - Schritt-Indikator

    private var wizardHeader: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Buch einrichten")
                        .font(.title2.weight(.bold))
                    Text("Schritt \(currentStep + 1) von \(stepTitles.count) · \(stepTitles[currentStep])")
                        .font(.caption)
                        .foregroundStyle(StudioTheme.textMuted)
                }
                Spacer()
                Text("\(Int(Double(currentStep + 1) / Double(stepTitles.count) * 100)) %")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(StudioTheme.cyan)
            }

            HStack(spacing: 6) {
                ForEach(stepTitles.indices, id: \.self) { step in
                    Button {
                        guard step <= currentStep else { return }
                        validationMessage = nil
                        withAnimation(reduceMotion ? nil : Motion.standard) {
                            currentStep = step
                        }
                    } label: {
                        VStack(spacing: 6) {
                            HStack(spacing: 5) {
                                Image(systemName: step < currentStep ? "checkmark" : stepIcons[step])
                                    .font(.caption2.weight(.bold))
                                Text(stepTitles[step])
                                    .font(.caption.weight(step == currentStep ? .semibold : .regular))
                                    .lineLimit(1)
                            }
                            Rectangle()
                                .fill(step <= currentStep ? StudioTheme.accentGradient(StudioTheme.cyan) : StudioTheme.quietGradient)
                                .frame(height: 3)
                                .clipShape(Capsule())
                        }
                        .foregroundStyle(step <= currentStep ? Color.primary : StudioTheme.textFaint)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(step > currentStep)
                    .accessibilityLabel("Schritt \(step + 1): \(stepTitles[step])")
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { StudioTheme.hairline.frame(height: 1) }
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
                HStack {
                    Button {
                        generateAuthorBioSuggestions()
                    } label: {
                        if isGeneratingAuthorBio {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Autorprofil …")
                            }
                        } else {
                            Label("KI-Vorschläge", systemImage: "wand.and.stars")
                        }
                    }
                    .disabled(isGeneratingAuthorBio || authorName.trimmingCharacters(in: .whitespaces).isEmpty)
                    if let authorBioError {
                        Text(authorBioError).font(.caption).foregroundStyle(.red)
                    }
                }
                if !authorBioSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(authorBioSuggestions.enumerated()), id: \.offset) { index, suggestion in
                            Button {
                                authorBio = suggestion
                            } label: {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: authorBio == suggestion
                                          ? "checkmark.circle.fill" : "text.badge.plus")
                                        .foregroundStyle(authorBio == suggestion ? .green : .secondary)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Variante \(index + 1)").font(.caption.weight(.semibold))
                                        Text(suggestion).font(.caption).foregroundStyle(.primary)
                                    }
                                    Spacer()
                                }
                            }
                            .buttonStyle(.plain)
                        }
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

                Picker("Buchtyp", selection: $contentType) {
                    ForEach(BookContentType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: contentType) { _, _ in
                    if genre != Self.customGenreTag,
                       !genre.isEmpty,
                       BookContentType.infer(from: genre) != contentType {
                        genre = ""
                        subgenre = ""
                        tropes = ""
                        spiceLevel = 0
                    }
                }

                Picker(contentType == .nonfiction ? "Kategorie" : "Genre", selection: $genre) {
                    Text("Bitte wählen").tag("")
                    ForEach(genres, id: \.self) { Text($0).tag($0) }
                    Divider()
                    Text("Andere (frei eingeben)…").tag(Self.customGenreTag)
                }

                if genre == Self.customGenreTag {
                    TextField("Eigenes Genre", text: $customGenre)
                }

                TextField(contentType == .nonfiction ? "Themenschwerpunkt (optional)" : "Subgenre (optional)",
                          text: $subgenre)

                if contentType == .fiction {
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
                }

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
    private func generateAuthorBioSuggestions() {
        guard let config = usableIdeaConfig() else {
            authorBioError = "Kein KI-Provider konfiguriert."
            return
        }
        let name = authorName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            authorBioError = "Zuerst Autorname oder Pseudonym eintragen."
            return
        }
        isGeneratingAuthorBio = true
        authorBioError = nil
        let model = config.provider == .ollamaCloud
            ? OllamaCloudModelCatalog.recommendedWritingModel
            : (config.defaultModel ?? config.provider.suggestedModels.first ?? "")
        let request = GenerationRequest(
            prompt: PromptFactory.authorBioSuggestions(
                authorName: name, facts: authorBio, genre: effectiveGenre, language: language
            ),
            systemPrompt: "Du bist ein sorgfältiger Verlagsredakteur. Du formulierst nur belegte Angaben und erfindest keine biografischen Fakten.",
            model: model, provider: config.provider, maxTokens: 900, temperature: 0.55
        )
        Task { @MainActor in
            defer { isGeneratingAuthorBio = false }
            do {
                var suggestions: [String] = []
                for attempt in 1...2 {
                    let activeRequest: GenerationRequest
                    if attempt == 1 {
                        activeRequest = request
                    } else {
                        activeRequest = GenerationRequest(
                            prompt: request.prompt + "\n\nDer vorige Versuch verletzte Format oder Faktenbindung. Gib jetzt EXAKT drei einzelne BIO|-Zeilen mit je 45–90 Wörtern aus, ohne Nummern, Markdown, Einleitung oder erfundene Angaben.",
                            systemPrompt: request.systemPrompt,
                            model: request.model, provider: request.provider,
                            maxTokens: request.maxTokens, temperature: 0.35
                        )
                    }
                    let response = try await ProviderGateway.shared.generateText(
                        request: activeRequest, configuration: config
                    )
                    suggestions = AuthorBioParser.parse(response.text).filter {
                        AuthorBioQuality.isGrounded($0, facts: authorBio)
                    }
                    if suggestions.count >= 2 { break }
                }
                authorBioSuggestions = suggestions
                if authorBioSuggestions.isEmpty {
                    authorBioError = "Vorschläge enthielten unbelegte Angaben oder ein ungültiges Format. Bitte mehr echte Stichpunkte eintragen und erneut versuchen."
                }
            } catch let error as AIError {
                authorBioError = error.errorDescription
            } catch {
                authorBioError = error.localizedDescription
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
        contentType = BookContentType.infer(from: idea.genre)
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
                                   pendingAPIKey: apiKey,
                                   includeCustomField: selectedProvider != .ollamaCloud)

                if selectedProvider.needsBaseURLInput {
                    TextField("Basis-URL (OpenAI-kompatibler Endpunkt)", text: $baseURL)
                }
            }

            if selectedProvider.requiresAPIKey {
                Section("Zugang") {
                    SecureField("API-Key", text: $apiKey)
                    if hasStoredKey {
                        Label("Für diesen Provider ist bereits ein API-Key lokal hinterlegt. Feld leer lassen, um ihn zu verwenden.",
                              systemImage: "key.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Der API-Key wird lokal für NovelForge gespeichert und zusätzlich in der macOS Keychain gesichert.")
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
                ReviewRow(label: "Genre", value: subgenre.isEmpty ? effectiveGenre : "\(effectiveGenre) / \(subgenre)")
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
                Label(contentType == .nonfiction
                      ? "Die Produktion läuft vollautomatisch: Leserproblem → Lernarchitektur → Kapitel → Abschnitte → Sachlektorat → Quellenfreigabe → Export."
                      : "Die Produktion läuft vollautomatisch: Konzept → Plot → Figuren → Kapitel → Szenen → Rohfassung → Revision → Korrektorat → Export.",
                      systemImage: "wand.and.stars")
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

    private var providerStepValid: Bool {
        guard !effectiveModel.isEmpty else { return false }
        if selectedProvider == .custom && baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }
        if selectedProvider.requiresAPIKey
            && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !hasStoredKey {
            return false
        }
        return true
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
            return providerStepValid
        default:
            return true
        }
    }

    private var currentStepRequirement: String? {
        switch currentStep {
        case 0:
            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Titel eintragen" }
            if authorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "Autor eintragen" }
            if effectiveGenre.isEmpty { return "Genre wählen" }
        case 1:
            if styleProfile.isEmpty { return "Stilprofil wählen" }
        case 2:
            if selectedFormats.isEmpty { return "Mindestens ein Exportformat wählen" }
        case 3:
            if effectiveModel.isEmpty { return "Modell wählen" }
            if selectedProvider == .custom && baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Basis-URL eintragen"
            }
            if selectedProvider.requiresAPIKey
                && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !hasStoredKey {
                return "API-Key eintragen"
            }
        default:
            break
        }
        return nil
    }

    @MainActor
    private func createProjectAndStart() {
        validationMessage = nil

        guard providerStepValid else {
            currentStep = 3
            validationMessage = currentStepRequirement ?? "Provider-Einstellungen vervollständigen."
            return
        }

        let publicInputs = [title, authorBio, imprint, tropes, seedPremise]
        guard !publicInputs.contains(where: PublicContentGuard.disclosureViolation) else {
            currentStep = 0
            validationMessage = "Bitte Produktionshinweise aus den öffentlich sichtbaren Buchdaten entfernen."
            return
        }

        let copyrightCheck = CopyrightChecker.checkInput(title: title, style: styleProfile)
        guard copyrightCheck.isValid else {
            validationMessage = copyrightCheck.warnings.joined(separator: " · ")
            return
        }
        guard !AutonomousContentQuality.isWeakTitle(title, genre: effectiveGenre) else {
            currentStep = 0
            validationMessage = "Bitte einen konkreten, eigenständigen Buchtitel statt Platzhalter, Genrebezeichnung oder Berufsklischee verwenden."
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

        // API-Key im lokalen Schlüsselspeicher hinterlegen und Konfiguration aktualisieren.
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

@MainActor
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
