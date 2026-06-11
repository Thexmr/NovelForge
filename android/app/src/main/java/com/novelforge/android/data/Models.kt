package com.novelforge.android.data

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.util.UUID

// MARK: - Modelle (JSON-persistiert, resume-fähig)

enum class ProjectStatus(val display: String) {
    CREATED("Angelegt"),
    CONCEPT("Konzeptentwicklung"),
    STRUCTURE("Strukturplanung"),
    CHAPTER_PLANNING("Kapitelplanung"),
    SCENE_PLANNING("Szenenplanung"),
    DRAFTING("Rohfassung"),
    REVISION("Kapitelrevision"),
    PROOFREADING("Korrektorat"),
    METADATA("KDP-Metadaten"),
    EXPORT("Export"),
    COMPLETED("Abgeschlossen"),
    FAILED("Fehlgeschlagen"),
    PAUSED("Pausiert");

    companion object {
        fun from(name: String): ProjectStatus =
            entries.firstOrNull { it.name == name } ?: CREATED
    }
}

class Scene(
    var number: Int = 1,
    var perspective: String = "",
    var location: String = "",
    var time: String = "",
    var goal: String = "",
    var obstacle: String = "",
    var turn: String = "",
    var targetWords: Int = 800,
    var text: String = "",
    var summary: String = ""
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("number", number); put("perspective", perspective); put("location", location)
        put("time", time); put("goal", goal); put("obstacle", obstacle); put("turn", turn)
        put("targetWords", targetWords); put("text", text); put("summary", summary)
    }

    companion object {
        fun fromJson(json: JSONObject) = Scene(
            number = json.optInt("number", 1),
            perspective = json.optString("perspective"),
            location = json.optString("location"),
            time = json.optString("time"),
            goal = json.optString("goal"),
            obstacle = json.optString("obstacle"),
            turn = json.optString("turn"),
            targetWords = json.optInt("targetWords", 800),
            text = json.optString("text"),
            summary = json.optString("summary")
        )
    }
}

class Chapter(
    var number: Int = 1,
    var title: String = "",
    var goal: String = "",
    var conflict: String = "",
    var targetWords: Int = 3000,
    var scenes: MutableList<Scene> = mutableListOf(),
    var revisedText: String = "",
    var finalText: String = "",
    var summary: String = ""
) {
    val draftText: String
        get() = scenes.filter { it.text.isNotEmpty() }
            .joinToString("\n\n***\n\n") { it.text }

    /** Bester verfügbarer Text: final > überarbeitet > Szenen. */
    val bestText: String
        get() = finalText.ifEmpty { revisedText.ifEmpty { draftText } }

    val wordCount: Int
        get() = bestText.split(Regex("\\s+")).count { it.isNotEmpty() }

    fun toJson(): JSONObject = JSONObject().apply {
        put("number", number); put("title", title); put("goal", goal); put("conflict", conflict)
        put("targetWords", targetWords)
        put("scenes", JSONArray(scenes.map { it.toJson() }))
        put("revisedText", revisedText); put("finalText", finalText); put("summary", summary)
    }

    companion object {
        fun fromJson(json: JSONObject): Chapter {
            val chapter = Chapter(
                number = json.optInt("number", 1),
                title = json.optString("title"),
                goal = json.optString("goal"),
                conflict = json.optString("conflict"),
                targetWords = json.optInt("targetWords", 3000),
                revisedText = json.optString("revisedText"),
                finalText = json.optString("finalText"),
                summary = json.optString("summary")
            )
            val scenes = json.optJSONArray("scenes") ?: JSONArray()
            for (index in 0 until scenes.length()) {
                chapter.scenes.add(Scene.fromJson(scenes.getJSONObject(index)))
            }
            return chapter
        }
    }
}

class Project(
    val id: String = UUID.randomUUID().toString(),
    var title: String = "",
    var author: String = "",
    var language: String = "Deutsch",
    var genre: String = "Roman",
    var style: String = "atmosphärisch",
    var targetPages: Int = 120,
    var status: ProjectStatus = ProjectStatus.CREATED,
    var premise: String = "",
    var logline: String = "",
    var synopsis: String = "",
    var plot: String = "",
    var charactersText: String = "",
    var kdpDescription: String = "",
    var kdpKeywords: String = "",
    var kdpCategories: String = "",
    var lastError: String = "",
    var chapters: MutableList<Chapter> = mutableListOf(),
    var createdAt: Long = System.currentTimeMillis(),
    var updatedAt: Long = System.currentTimeMillis()
) {
    val targetWords: Int get() = targetPages * 250

    val totalWords: Int get() = chapters.sumOf { it.wordCount }

    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id); put("title", title); put("author", author); put("language", language)
        put("genre", genre); put("style", style); put("targetPages", targetPages)
        put("status", status.name); put("premise", premise); put("logline", logline)
        put("synopsis", synopsis); put("plot", plot); put("charactersText", charactersText)
        put("kdpDescription", kdpDescription); put("kdpKeywords", kdpKeywords)
        put("kdpCategories", kdpCategories); put("lastError", lastError)
        put("chapters", JSONArray(chapters.map { it.toJson() }))
        put("createdAt", createdAt); put("updatedAt", updatedAt)
    }

    companion object {
        fun fromJson(json: JSONObject): Project {
            val project = Project(
                id = json.optString("id", UUID.randomUUID().toString()),
                title = json.optString("title"),
                author = json.optString("author"),
                language = json.optString("language", "Deutsch"),
                genre = json.optString("genre", "Roman"),
                style = json.optString("style", "atmosphärisch"),
                targetPages = json.optInt("targetPages", 120),
                status = ProjectStatus.from(json.optString("status")),
                premise = json.optString("premise"),
                logline = json.optString("logline"),
                synopsis = json.optString("synopsis"),
                plot = json.optString("plot"),
                charactersText = json.optString("charactersText"),
                kdpDescription = json.optString("kdpDescription"),
                kdpKeywords = json.optString("kdpKeywords"),
                kdpCategories = json.optString("kdpCategories"),
                lastError = json.optString("lastError"),
                createdAt = json.optLong("createdAt", System.currentTimeMillis()),
                updatedAt = json.optLong("updatedAt", System.currentTimeMillis())
            )
            val chapters = json.optJSONArray("chapters") ?: JSONArray()
            for (index in 0 until chapters.length()) {
                project.chapters.add(Chapter.fromJson(chapters.getJSONObject(index)))
            }
            return project
        }
    }
}

// MARK: - Persistenz (eine JSON-Datei pro Projekt)

object ProjectStore {

    private fun directory(context: Context): File =
        File(context.filesDir, "projects").apply { mkdirs() }

    fun loadAll(context: Context): List<Project> =
        directory(context).listFiles { file -> file.extension == "json" }
            ?.mapNotNull { file ->
                runCatching { Project.fromJson(JSONObject(file.readText())) }.getOrNull()
            }
            ?.sortedByDescending { it.updatedAt }
            ?: emptyList()

    fun load(context: Context, id: String): Project? {
        val file = File(directory(context), "$id.json")
        if (!file.exists()) return null
        return runCatching { Project.fromJson(JSONObject(file.readText())) }.getOrNull()
    }

    fun save(context: Context, project: Project) {
        project.updatedAt = System.currentTimeMillis()
        File(directory(context), "${project.id}.json")
            .writeText(project.toJson().toString())
    }

    fun delete(context: Context, project: Project) {
        File(directory(context), "${project.id}.json").delete()
    }
}
