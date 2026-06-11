package com.novelforge.android.ai

data class ParsedConcept(
    val premise: String, val logline: String, val synopsis: String,
    val theme: String, val audience: String
)

data class ParsedChapter(val number: Int, val title: String, val goal: String, val conflict: String)
data class ParsedScene(
    val number: Int, val perspective: String, val location: String, val time: String,
    val goal: String, val obstacle: String, val turn: String
)
data class ParsedIdea(val title: String, val genre: String, val premise: String)
data class ParsedMetadata(val description: String, val keywords: String, val categories: String)

/**
 * Parser für die strukturierten KI-Antworten – tolerant gegenüber
 * Markdown-Resten und lückenhafter Nummerierung (Portierung der macOS-Logik).
 */
object Parsers {

    private fun sections(text: String, labels: List<String>): Map<String, String> {
        val result = mutableMapOf<String, String>()
        var currentLabel: String? = null

        for (rawLine in text.lines()) {
            val cleaned = rawLine.replace("*", "").replace("#", "").trim()
            var matched = false
            for (label in labels) {
                if (cleaned.uppercase().startsWith("$label:")) {
                    result[label] = cleaned.drop(label.length + 1).trim()
                    currentLabel = label
                    matched = true
                    break
                }
            }
            if (!matched && currentLabel != null && cleaned.isNotEmpty()) {
                val existing = result[currentLabel] ?: ""
                result[currentLabel!!] = if (existing.isEmpty()) cleaned else "$existing\n$cleaned"
            }
        }
        return result
    }

    fun concept(text: String): ParsedConcept {
        val parsed = sections(text, listOf(
            "PRÄMISSE", "PRAEMISSE", "LOGLINE", "EXPOSÉ", "EXPOSE",
            "HAUPTKONFLIKT", "THEMA", "ZIELGRUPPE"
        ))
        return ParsedConcept(
            premise = parsed["PRÄMISSE"] ?: parsed["PRAEMISSE"] ?: "",
            logline = parsed["LOGLINE"] ?: "",
            synopsis = parsed["EXPOSÉ"] ?: parsed["EXPOSE"] ?: "",
            theme = parsed["THEMA"] ?: "",
            audience = parsed["ZIELGRUPPE"] ?: ""
        )
    }

    fun metadata(text: String): ParsedMetadata {
        val parsed = sections(text, listOf("VERKAUFSTEXT", "KEYWORDS", "KATEGORIEN"))
        return ParsedMetadata(
            description = parsed["VERKAUFSTEXT"] ?: "",
            keywords = parsed["KEYWORDS"] ?: "",
            categories = parsed["KATEGORIEN"] ?: ""
        )
    }

    private fun fields(line: String, marker: String): List<String>? {
        val index = line.indexOf("$marker|")
        if (index < 0) return null
        return line.substring(index + marker.length + 1)
            .split("|")
            .map { it.trim().replace("**", "") }
    }

    fun chapters(text: String): List<ParsedChapter> {
        val result = mutableListOf<ParsedChapter>()
        for (line in text.lines()) {
            val parts = fields(line, "KAPITEL") ?: continue
            if (parts.size < 2 || parts[1].isEmpty()) continue
            result.add(ParsedChapter(
                number = result.size + 1, // fortlaufend – Modellnummern können lückenhaft sein
                title = parts[1],
                goal = parts.getOrElse(2) { "" },
                conflict = parts.getOrElse(3) { "" }
            ))
        }
        return result
    }

    fun scenes(text: String): List<ParsedScene> {
        val result = mutableListOf<ParsedScene>()
        for (line in text.lines()) {
            val parts = fields(line, "SZENE") ?: continue
            if (parts.size < 2) continue
            result.add(ParsedScene(
                number = result.size + 1,
                perspective = parts.getOrElse(1) { "" },
                location = parts.getOrElse(2) { "" },
                time = parts.getOrElse(3) { "" },
                goal = parts.getOrElse(4) { "" },
                obstacle = parts.getOrElse(5) { "" },
                turn = parts.getOrElse(6) { "" }
            ))
        }
        return result
    }

    fun ideas(text: String): List<ParsedIdea> {
        val result = mutableListOf<ParsedIdea>()
        for (line in text.lines()) {
            val parts = fields(line, "IDEE") ?: continue
            if (parts.size < 3 || parts[0].isEmpty()) continue
            result.add(ParsedIdea(parts[0], parts[1], parts[2]))
        }
        return result
    }

    fun wordCount(text: String): Int =
        text.split(Regex("\\s+")).count { it.isNotEmpty() }
}
