package com.novelforge.android.engine

import android.content.Context
import com.novelforge.android.ai.Gateway
import com.novelforge.android.ai.Parsers
import com.novelforge.android.ai.Prompts
import com.novelforge.android.ai.ProviderConfig
import com.novelforge.android.data.Chapter
import com.novelforge.android.data.Project
import com.novelforge.android.data.ProjectStore
import com.novelforge.android.data.ProjectStatus
import com.novelforge.android.data.Scene
import com.novelforge.android.export.EpubExporter
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.coroutines.coroutineContext
import kotlinx.coroutines.ensureActive

data class EngineState(
    val isRunning: Boolean = false,
    val isUnlimited: Boolean = false,
    val projectTitle: String = "",
    val phase: String = "",
    val detail: String = "",
    val progress: Float = 0f,
    val booksCompleted: Int = 0,
    val tokensUsed: Int = 0,
    val lastError: String = ""
)

/**
 * Autonome Buchproduktions-Pipeline (Portierung der macOS-Logik).
 * Alle Phasen sind idempotent: Bereits geschriebene Szenen/Kapitel werden
 * beim Fortsetzen übersprungen.
 */
object Orchestrator {

    private val _state = MutableStateFlow(EngineState())
    val state: StateFlow<EngineState> = _state

    private var tokensUsed = 0

    private fun update(transform: (EngineState) -> EngineState) {
        _state.value = transform(_state.value)
    }

    fun markUnlimited(active: Boolean) = update { it.copy(isUnlimited = active) }

    fun incrementBooks() = update { it.copy(booksCompleted = it.booksCompleted + 1) }

    fun markSessionStart() {
        _state.value = EngineState(isRunning = true)
    }

    fun markStopped(error: String = "") = update {
        it.copy(isRunning = false, isUnlimited = false,
                lastError = error.ifEmpty { it.lastError })
    }

    private suspend fun generate(
        prompt: String, system: String, maxTokens: Int,
        temperature: Double, config: ProviderConfig
    ): String {
        coroutineContext.ensureActive()
        val response = Gateway.generate(prompt, system, maxTokens, temperature, config)
        tokensUsed += response.tokensUsed
        update { it.copy(tokensUsed = tokensUsed) }
        return response.text.trim()
    }

    private fun phase(name: String, detail: String = "", progress: Float? = null) {
        update {
            it.copy(phase = name, detail = detail, progress = progress ?: it.progress)
        }
    }

    /** Produziert EIN Buch vollständig (wirft bei Fehler; Fortschritt bleibt gespeichert). */
    suspend fun produceBook(context: Context, project: Project, config: ProviderConfig) {
        tokensUsed = 0
        update {
            it.copy(isRunning = true, projectTitle = project.title,
                    progress = 0f, tokensUsed = 0, lastError = "")
        }

        try {
            // 1. Konzept
            if (project.logline.isEmpty()) {
                project.status = ProjectStatus.CONCEPT
                phase("Konzeptentwicklung", progress = 0.02f)
                val text = generate(
                    Prompts.concept(project.title, project.genre, project.language,
                                    project.style, project.targetPages, project.premise),
                    "Du bist ein erfahrener Verlagslektor und entwickelst originelle Buchkonzepte.",
                    1500, 0.8, config
                )
                val concept = Parsers.concept(text)
                if (concept.premise.isNotEmpty()) project.premise = concept.premise
                project.logline = concept.logline.ifEmpty { text.take(200) }
                project.synopsis = concept.synopsis.ifEmpty { text }
                ProjectStore.save(context, project)
            }

            // 2. Plot + Figuren
            val chapterCount = maxOf(8, project.targetPages / 15)
            if (project.plot.isEmpty()) {
                project.status = ProjectStatus.STRUCTURE
                phase("Strukturplanung", "Plot", 0.06f)
                project.plot = generate(
                    Prompts.plot(project.title, project.genre, project.style,
                                 project.synopsis.ifEmpty { project.premise },
                                 project.targetPages, chapterCount),
                    "Du bist ein Plot-Architekt für Romane.",
                    3500, 0.7, config
                )
                ProjectStore.save(context, project)
            }
            if (project.charactersText.isEmpty()) {
                phase("Strukturplanung", "Figuren", 0.10f)
                project.charactersText = generate(
                    Prompts.characters(project.title, project.genre, project.plot),
                    "Du bist ein Charakter-Entwickler für Romane.",
                    3000, 0.7, config
                )
                ProjectStore.save(context, project)
            }

            // 3. Kapitelplanung
            if (project.chapters.isEmpty()) {
                project.status = ProjectStatus.CHAPTER_PLANNING
                phase("Kapitelplanung", progress = 0.14f)
                val wordsPerChapter = project.targetWords / chapterCount
                val text = generate(
                    Prompts.chapterPlan(project.title, project.genre, project.plot,
                                        chapterCount, wordsPerChapter),
                    "Du bist ein Strukturplaner. Halte dich exakt an das Ausgabeformat.",
                    3000, 0.6, config
                )
                var planned = Parsers.chapters(text)
                if (planned.isEmpty()) {
                    planned = (1..chapterCount).map { index ->
                        com.novelforge.android.ai.ParsedChapter(
                            index, "Kapitel $index", "Setze den Plot konsequent fort.", "")
                    }
                }
                planned.forEach { item ->
                    project.chapters.add(Chapter(
                        number = item.number, title = item.title, goal = item.goal,
                        conflict = item.conflict,
                        targetWords = maxOf(1, project.targetWords / planned.size)
                    ))
                }
                ProjectStore.save(context, project)
            }

            // 4. Szenenplanung (idempotent je Kapitel)
            project.status = ProjectStatus.SCENE_PLANNING
            for ((index, chapter) in project.chapters.withIndex()) {
                if (chapter.scenes.isNotEmpty()) continue
                phase("Szenenplanung", "Kapitel ${chapter.number}/${project.chapters.size}",
                      0.16f + 0.06f * index / project.chapters.size)
                val text = generate(
                    Prompts.scenePlan(project.title, chapter.number, chapter.title,
                                      chapter.goal, chapter.conflict, project.plot,
                                      chapter.targetWords),
                    "Du bist ein Szenenplaner. Halte dich exakt an das Ausgabeformat.",
                    1200, 0.6, config
                )
                var planned = Parsers.scenes(text)
                if (planned.isEmpty()) {
                    planned = (1..4).map { sceneIndex ->
                        com.novelforge.android.ai.ParsedScene(
                            sceneIndex, "", "", "",
                            "Führe das Kapitelziel weiter: ${chapter.goal}", "", "")
                    }
                }
                planned.forEach { item ->
                    chapter.scenes.add(Scene(
                        number = item.number, perspective = item.perspective,
                        location = item.location, time = item.time, goal = item.goal,
                        obstacle = item.obstacle, turn = item.turn,
                        targetWords = maxOf(1, chapter.targetWords / planned.size)
                    ))
                }
                ProjectStore.save(context, project)
            }

            // 5. Rohfassung – mit Langstrecken-Gedächtnis & Qualitäts-Gate
            project.status = ProjectStatus.DRAFTING
            val totalScenes = project.chapters.sumOf { it.scenes.size }
            var done = project.chapters.sumOf { chapter -> chapter.scenes.count { it.text.isNotEmpty() } }

            val chapterDigests = mutableListOf<String>()
            val recentSummaries = mutableListOf<String>()
            var previousSceneText: String? = null
            project.chapters.forEach { chapter ->
                if (chapter.summary.isNotEmpty()) {
                    chapterDigests.add("Kapitel ${chapter.number} (${chapter.title}): ${chapter.summary}")
                }
                chapter.scenes.filter { it.text.isNotEmpty() }.forEach { scene ->
                    if (scene.summary.isNotEmpty()) {
                        recentSummaries.add("Kap. ${chapter.number}, Szene ${scene.number}: ${scene.summary}")
                    }
                    previousSceneText = scene.text
                }
            }

            val charactersSummary = project.charactersText.take(1200)

            for ((chapterIndex, chapter) in project.chapters.withIndex()) {
                for ((sceneIndex, scene) in chapter.scenes.withIndex()) {
                    if (scene.text.isNotEmpty()) { previousSceneText = scene.text; continue }
                    coroutineContext.ensureActive()

                    phase("Rohfassung",
                          "Kapitel ${chapter.number}, Szene ${scene.number} · $done/$totalScenes Szenen",
                          0.22f + 0.50f * done / maxOf(1, totalScenes))

                    val contextParts = mutableListOf<String>()
                    if (chapterDigests.isNotEmpty()) {
                        contextParts.add("BISHERIGE KAPITEL:\n" + chapterDigests.joinToString("\n"))
                    }
                    if (recentSummaries.isNotEmpty()) {
                        contextParts.add("LETZTE SZENEN IM DETAIL:\n" +
                            recentSummaries.takeLast(6).joinToString("\n"))
                    }

                    var sceneText = generate(
                        Prompts.draftScene(
                            project.language, project.style, project.genre, project.title,
                            chapter.number, chapter.title, chapter.goal,
                            scene.number, scene.goal, scene.location, scene.time,
                            scene.obstacle, scene.turn, scene.perspective,
                            charactersSummary, contextParts.joinToString("\n\n"),
                            previousSceneText?.takeLast(600) ?: "",
                            chapterIndex == 0 && sceneIndex == 0,
                            chapterIndex == project.chapters.size - 1 && sceneIndex == chapter.scenes.size - 1,
                            scene.targetWords
                        ),
                        "Du bist ein professioneller Romanautor. Du schreibst lebendige, atmosphärische Prosa.",
                        minOf(4000, maxOf(1200, scene.targetWords * 3)), 0.85, config
                    )

                    // Qualitäts-Gate: deutlich zu kurze Szenen einmalig erweitern.
                    if (Parsers.wordCount(sceneText) < scene.targetWords * 0.6) {
                        runCatching {
                            val expanded = generate(
                                Prompts.expandScene(project.language, project.style,
                                                    sceneText, scene.targetWords),
                                "Du vertiefst Szenen, ohne die Handlung zu verändern.",
                                minOf(4000, maxOf(1200, scene.targetWords * 3)), 0.7, config
                            )
                            if (Parsers.wordCount(expanded) > Parsers.wordCount(sceneText)) {
                                sceneText = expanded
                            }
                        }
                    }

                    scene.text = sceneText
                    previousSceneText = sceneText

                    scene.summary = runCatching {
                        generate(Prompts.summarizeScene(sceneText),
                                 "Du fasst Romanszenen präzise zusammen.", 250, 0.3, config)
                    }.getOrDefault(sceneText.take(300))
                    recentSummaries.add("Kap. ${chapter.number}, Szene ${scene.number}: ${scene.summary}")

                    done += 1
                    ProjectStore.save(context, project)
                }

                if (chapter.summary.isEmpty()) {
                    val joined = chapter.scenes.joinToString(" ") { it.summary }
                    if (joined.isNotBlank()) {
                        chapter.summary = runCatching {
                            generate(Prompts.condenseChapter(chapter.number, chapter.title, joined),
                                     "Du verdichtest Kapitelzusammenfassungen präzise.", 160, 0.2, config)
                        }.getOrDefault(joined.take(350))
                        chapterDigests.add("Kapitel ${chapter.number} (${chapter.title}): ${chapter.summary}")
                        ProjectStore.save(context, project)
                    }
                }
            }

            // 6. Kapitelrevision (idempotent)
            project.status = ProjectStatus.REVISION
            for ((index, chapter) in project.chapters.withIndex()) {
                if (chapter.revisedText.isNotEmpty()) continue
                val draft = chapter.draftText
                if (draft.isEmpty()) continue
                coroutineContext.ensureActive()
                phase("Kapitelrevision", "Kapitel ${chapter.number}/${project.chapters.size}",
                      0.74f + 0.10f * index / project.chapters.size)
                val revised = generate(
                    Prompts.reviseChapter(project.language, project.style,
                                          chapter.number, chapter.title, draft),
                    "Du bist ein erfahrener Lektor. Du verbesserst Prosa, ohne Handlung oder Stimme zu verändern.",
                    minOf(12000, maxOf(3000, Parsers.wordCount(draft) * 3)), 0.4, config
                )
                chapter.revisedText =
                    if (Parsers.wordCount(revised) >= Parsers.wordCount(draft) / 2) revised else draft
                ProjectStore.save(context, project)
            }

            // 7. Korrektorat (idempotent)
            project.status = ProjectStatus.PROOFREADING
            for ((index, chapter) in project.chapters.withIndex()) {
                if (chapter.finalText.isNotEmpty()) continue
                val source = chapter.revisedText.ifEmpty { chapter.draftText }
                if (source.isEmpty()) continue
                coroutineContext.ensureActive()
                phase("Korrektorat", "Kapitel ${chapter.number}/${project.chapters.size}",
                      0.84f + 0.08f * index / project.chapters.size)
                val corrected = generate(
                    Prompts.proofread(project.language, source),
                    "Du bist ein professioneller Korrektor. Du korrigierst nur Fehler, nie den Stil.",
                    minOf(12000, maxOf(3000, Parsers.wordCount(source) * 3)), 0.1, config
                )
                chapter.finalText =
                    if (Parsers.wordCount(corrected) >= Parsers.wordCount(source) / 2) corrected else source
                ProjectStore.save(context, project)
            }

            // 8. KDP-Metadaten (nicht produktionskritisch)
            if (project.kdpDescription.isEmpty()) {
                project.status = ProjectStatus.METADATA
                phase("KDP-Metadaten", progress = 0.94f)
                runCatching {
                    val text = generate(
                        Prompts.kdpMetadata(project.title, project.author, project.genre,
                                            project.synopsis.ifEmpty { project.premise },
                                            project.language),
                        "Du bist ein Buchmarketing-Texter für Amazon KDP.",
                        1200, 0.7, config
                    )
                    val metadata = Parsers.metadata(text)
                    project.kdpDescription = metadata.description.ifEmpty { text }
                    project.kdpKeywords = metadata.keywords
                    project.kdpCategories = metadata.categories
                }
                ProjectStore.save(context, project)
            }

            // 9. Export
            project.status = ProjectStatus.EXPORT
            phase("Export", "EPUB wird erzeugt", 0.98f)
            EpubExporter.export(context, project)

            project.status = ProjectStatus.COMPLETED
            project.lastError = ""
            ProjectStore.save(context, project)
            phase("Abgeschlossen", "", 1f)

        } catch (error: Exception) {
            project.status = if (error is kotlinx.coroutines.CancellationException)
                ProjectStatus.PAUSED else ProjectStatus.FAILED
            project.lastError = error.message ?: ""
            ProjectStore.save(context, project)
            update { it.copy(lastError = project.lastError) }
            throw error
        }
    }
}
