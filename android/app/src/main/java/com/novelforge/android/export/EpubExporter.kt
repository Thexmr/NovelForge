package com.novelforge.android.export

import android.content.Context
import com.novelforge.android.data.Project
import java.io.File
import java.util.UUID
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

/**
 * EPUB-3-Export – spezifikationskonform: mimetype als erster,
 * unkomprimierter (STORED) ZIP-Eintrag, nav-Dokument + NCX-Fallback.
 * Bücher landen in /Android/data/<app>/files/NovelForge/<Titel>/
 * (über die Dateien-App zugänglich, ohne Berechtigungen).
 */
object EpubExporter {

    fun exportRoot(context: Context): File =
        File(context.getExternalFilesDir(null) ?: context.filesDir, "NovelForge")
            .apply { mkdirs() }

    fun exportDir(context: Context, project: Project): File =
        File(exportRoot(context), sanitize(project.title)).apply { mkdirs() }

    fun export(context: Context, project: Project): File {
        val file = File(exportDir(context, project), "${sanitize(project.title)}.epub")
        if (file.exists()) file.delete()

        ZipOutputStream(file.outputStream()).use { zip ->
            // mimetype: erster Eintrag, STORED (unkomprimiert) – EPUB-Pflicht.
            val mimetype = "application/epub+zip".toByteArray(Charsets.US_ASCII)
            val entry = ZipEntry("mimetype").apply {
                method = ZipEntry.STORED
                size = mimetype.size.toLong()
                crc = CRC32().apply { update(mimetype) }.value
            }
            zip.putNextEntry(entry)
            zip.write(mimetype)
            zip.closeEntry()

            fun put(path: String, content: String) {
                zip.putNextEntry(ZipEntry(path))
                zip.write(content.toByteArray(Charsets.UTF_8))
                zip.closeEntry()
            }

            put("META-INF/container.xml", containerXml())
            put("OEBPS/stylesheet.css", stylesheet())
            put("OEBPS/titlepage.xhtml", titlePage(project))
            put("OEBPS/toc.xhtml", navDocument(project))

            project.chapters.sortedBy { it.number }.forEach { chapter ->
                put("OEBPS/chapter${chapter.number}.xhtml", chapterXhtml(chapter.title, chapter.bestText))
            }
            put("OEBPS/content.opf", contentOpf(project))
            put("OEBPS/toc.ncx", tocNcx(project))
        }

        // Reiner Text als Bonus (einfach weiterzuverarbeiten).
        val txt = File(exportDir(context, project), "${sanitize(project.title)}.txt")
        txt.writeText(buildString {
            appendLine(project.title)
            appendLine(project.author)
            appendLine()
            project.chapters.sortedBy { it.number }.forEach { chapter ->
                appendLine(chapter.title)
                appendLine()
                appendLine(chapter.bestText)
                appendLine()
            }
        })

        return file
    }

    private fun sanitize(name: String): String =
        name.replace(Regex("[:/\\\\?%*|\"<>]"), "_").ifEmpty { "Unbenannt" }

    private fun escape(text: String): String = text
        .replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        .replace("\"", "&quot;").replace("'", "&apos;")

    private fun languageCode(language: String): String = when (language) {
        "Englisch" -> "en"; "Französisch" -> "fr"; "Spanisch" -> "es"; else -> "de"
    }

    private fun containerXml() = """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
            <rootfiles>
                <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml" />
            </rootfiles>
        </container>
    """.trimIndent()

    private fun stylesheet() = """
        body { font-family: Georgia, serif; line-height: 1.5; margin: 0 4%; }
        h1 { text-align: center; font-weight: normal; font-size: 1.4em; margin: 3em 0 2em 0; }
        p { margin: 0; text-indent: 1.2em; text-align: justify; }
        p.first { text-indent: 0; }
        p.scenebreak { text-indent: 0; text-align: center; margin: 1em 0; }
        .titlepage { text-align: center; margin-top: 30%; }
    """.trimIndent()

    private fun header(title: String) = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE html>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops">
        <head><title>${escape(title)}</title>
        <link rel="stylesheet" type="text/css" href="stylesheet.css" /></head>
        <body>
    """.trimIndent()

    private fun titlePage(project: Project) = header(project.title) + """

        <div class="titlepage">
            <h1>${escape(project.title)}</h1>
            <p class="first" style="text-align:center;">${escape(project.author)}</p>
        </div>
        </body></html>
    """.trimIndent()

    private fun navDocument(project: Project): String {
        val items = project.chapters.sortedBy { it.number }.joinToString("\n") { chapter ->
            """        <li><a href="chapter${chapter.number}.xhtml">${escape(chapter.title)}</a></li>"""
        }
        return header("Inhalt") + """

        <nav epub:type="toc" id="toc"><h1>Inhalt</h1><ol>
        $items
        </ol></nav>
        </body></html>
        """.trimIndent()
    }

    private fun chapterXhtml(title: String, text: String): String {
        val body = StringBuilder()
        var afterBreak = true
        text.lines().map { it.trim() }.filter { it.isNotEmpty() }.forEach { paragraph ->
            if (paragraph.replace(" ", "") == "***") {
                body.append("\n    <p class=\"scenebreak\">* * *</p>")
                afterBreak = true
            } else {
                val css = if (afterBreak) " class=\"first\"" else ""
                body.append("\n    <p$css>${escape(paragraph)}</p>")
                afterBreak = false
            }
        }
        return header(title) + "\n    <h1>${escape(title)}</h1>$body\n</body></html>"
    }

    private fun contentOpf(project: Project): String {
        val uuid = UUID.randomUUID()
        val chapters = project.chapters.sortedBy { it.number }
        val manifest = chapters.joinToString("\n") { chapter ->
            """        <item id="chapter${chapter.number}" href="chapter${chapter.number}.xhtml" media-type="application/xhtml+xml" />"""
        }
        val spine = chapters.joinToString("\n") { chapter ->
            """        <itemref idref="chapter${chapter.number}" />"""
        }
        val description = if (project.kdpDescription.isNotEmpty())
            "\n        <dc:description>${escape(project.kdpDescription)}</dc:description>" else ""

        return """
            <?xml version="1.0" encoding="UTF-8"?>
            <package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
                <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
                    <dc:title>${escape(project.title)}</dc:title>
                    <dc:creator>${escape(project.author)}</dc:creator>
                    <dc:language>${languageCode(project.language)}</dc:language>
                    <dc:identifier id="bookid">urn:uuid:$uuid</dc:identifier>
                    <meta property="dcterms:modified">2026-01-01T00:00:00Z</meta>$description
                </metadata>
                <manifest>
                    <item id="css" href="stylesheet.css" media-type="text/css" />
                    <item id="titlepage" href="titlepage.xhtml" media-type="application/xhtml+xml" />
                    <item id="toc" href="toc.xhtml" media-type="application/xhtml+xml" properties="nav" />
            $manifest
                    <item id="ncx" href="toc.ncx" media-type="application/x-dtbncx+xml" />
                </manifest>
                <spine toc="ncx">
                    <itemref idref="titlepage" />
                    <itemref idref="toc" />
            $spine
                </spine>
            </package>
        """.trimIndent()
    }

    private fun tocNcx(project: Project): String {
        val navPoints = project.chapters.sortedBy { it.number }
            .mapIndexed { index, chapter ->
                """        <navPoint id="chapter${chapter.number}" playOrder="${index + 1}">
            <navLabel><text>${escape(chapter.title)}</text></navLabel>
            <content src="chapter${chapter.number}.xhtml" />
        </navPoint>"""
            }.joinToString("\n")

        return """
            <?xml version="1.0" encoding="UTF-8"?>
            <ncx version="2005-1" xmlns="http://www.daisy.org/z3986/2005/ncx/">
                <head><meta name="dtb:uid" content="urn:uuid:${UUID.randomUUID()}" /></head>
                <docTitle><text>${escape(project.title)}</text></docTitle>
                <navMap>
            $navPoints
                </navMap>
            </ncx>
        """.trimIndent()
    }
}
