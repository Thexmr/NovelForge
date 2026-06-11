package com.novelforge.android.engine

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat
import com.novelforge.android.ai.Gateway
import com.novelforge.android.ai.Parsers
import com.novelforge.android.ai.Prompts
import com.novelforge.android.ai.SettingsStore
import com.novelforge.android.data.Project
import com.novelforge.android.data.ProjectStore
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch

/**
 * Foreground-Service: hält die Buchproduktion am Leben, auch wenn die App
 * in den Hintergrund geht. Der Unlimited-Modus produziert Buch für Buch –
 * bis Stopp gedrückt wird.
 */
class ProductionService : Service() {

    companion object {
        const val ACTION_SINGLE = "single"
        const val ACTION_UNLIMITED = "unlimited"
        const val EXTRA_PROJECT_ID = "projectId"
        const val EXTRA_GENRE = "genre"
        const val EXTRA_STYLE = "style"
        const val EXTRA_PAGES = "pages"
        private const val CHANNEL = "production"
        private const val NOTIFICATION_ID = 1

        val genrePool = listOf("Thriller", "Roman", "Fantasy", "Science Fiction", "Krimi",
                               "Liebesroman", "Historischer Roman", "Horror")
        val stylePool = listOf("düster", "literarisch", "dialogstark", "humorvoll",
                               "emotional", "atmosphärisch", "actionreich", "psychologisch")

        fun startSingle(context: Context, projectId: String) {
            val intent = Intent(context, ProductionService::class.java)
                .setAction(ACTION_SINGLE)
                .putExtra(EXTRA_PROJECT_ID, projectId)
            context.startForegroundService(intent)
        }

        fun startUnlimited(context: Context, genre: String, style: String, pages: Int) {
            val intent = Intent(context, ProductionService::class.java)
                .setAction(ACTION_UNLIMITED)
                .putExtra(EXTRA_GENRE, genre)
                .putExtra(EXTRA_STYLE, style)
                .putExtra(EXTRA_PAGES, pages)
            context.startForegroundService(intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ProductionService::class.java))
        }
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private var work: Job? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, notification("NovelForge", "Produktion läuft …"))
        if (work?.isActive == true) return START_NOT_STICKY

        Orchestrator.markSessionStart()

        when (intent?.action) {
            ACTION_UNLIMITED -> {
                val genre = intent.getStringExtra(EXTRA_GENRE) ?: "Zufällig"
                val style = intent.getStringExtra(EXTRA_STYLE) ?: "Zufällig"
                val pages = intent.getIntExtra(EXTRA_PAGES, 120)
                Orchestrator.markUnlimited(true)
                work = scope.launch { runUnlimited(genre, style, pages) }
            }
            else -> {
                val projectId = intent?.getStringExtra(EXTRA_PROJECT_ID)
                work = scope.launch { runSingle(projectId) }
            }
        }
        return START_NOT_STICKY
    }

    private suspend fun runSingle(projectId: String?) {
        val context = applicationContext
        val project = projectId?.let { ProjectStore.load(context, it) }
        if (project == null) {
            Orchestrator.markStopped("Projekt nicht gefunden")
            stopSelf()
            return
        }
        try {
            updateNotification(project.title)
            Orchestrator.produceBook(context, project, SettingsStore.activeConfig(context))
            Orchestrator.markStopped()
        } catch (error: Exception) {
            Orchestrator.markStopped(error.message ?: "")
        }
        stopSelf()
    }

    private suspend fun runUnlimited(genreSetting: String, styleSetting: String, pages: Int) {
        val context = applicationContext
        val config = SettingsStore.activeConfig(context)
        val author = SettingsStore.authorName(context).ifEmpty { "NovelForge" }
        val usedTitles = mutableSetOf<String>()

        while (scope.isActive) {
            try {
                val genre = if (genreSetting == "Zufällig") genrePool.random() else genreSetting
                val style = if (styleSetting == "Zufällig") stylePool.random() else styleSetting

                updateNotification("Ideenfindung für das nächste Buch …")
                val ideasText = Gateway.generate(
                    Prompts.bookIdeas(genre, "Deutsch"),
                    "Du bist ein Verlagslektor mit Gespür für verkäufliche Buchideen.",
                    800, 0.95, config
                ).text
                val idea = Parsers.ideas(ideasText).randomOrNull()

                var title = idea?.title ?: "$genre-Roman"
                if (!usedTitles.add(title.lowercase())) {
                    title += " ${System.currentTimeMillis() % 10000}"
                    usedTitles.add(title.lowercase())
                }

                val project = Project(
                    title = title, author = author, genre = genre,
                    style = style, targetPages = pages,
                    premise = idea?.premise ?: ""
                )
                ProjectStore.save(context, project)

                updateNotification("Buch ${Orchestrator.state.value.booksCompleted + 1}: $title")
                Orchestrator.produceBook(context, project, config)
                Orchestrator.incrementBooks()

            } catch (error: kotlinx.coroutines.CancellationException) {
                break
            } catch (error: Exception) {
                // Buch fehlgeschlagen (bleibt fortsetzbar) – weiter mit dem nächsten.
                val message = error.message ?: ""
                if (message.contains("API-Key", ignoreCase = true)) {
                    Orchestrator.markStopped(message)
                    break
                }
                delay(5000)
            }
        }
        Orchestrator.markStopped()
        stopSelf()
    }

    private fun notification(title: String, text: String): Notification {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL, "Buchproduktion", NotificationManager.IMPORTANCE_LOW)
        )
        return NotificationCompat.Builder(this, CHANNEL)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_edit)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification(text: String) {
        getSystemService(NotificationManager::class.java)
            .notify(NOTIFICATION_ID, notification("NovelForge produziert", text))
    }

    override fun onDestroy() {
        scope.cancel()
        Orchestrator.markStopped()
        super.onDestroy()
    }
}
