package com.novelforge.android.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AllInclusive
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ExposedDropdownMenuBox
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import com.novelforge.android.ai.AiProvider
import com.novelforge.android.ai.SettingsStore
import com.novelforge.android.data.Project
import com.novelforge.android.data.ProjectStore
import com.novelforge.android.data.ProjectStatus
import com.novelforge.android.engine.Orchestrator
import com.novelforge.android.engine.ProductionService
import com.novelforge.android.export.EpubExporter

@Composable
fun NovelForgeApp() {
    MaterialTheme {
        var tab by remember { mutableIntStateOf(0) }
        var readerProject by remember { mutableStateOf<Project?>(null) }

        val reader = readerProject
        if (reader != null) {
            ReaderScreen(project = reader, onBack = { readerProject = null })
            return@MaterialTheme
        }

        Scaffold(
            bottomBar = {
                NavigationBar {
                    NavigationBarItem(selected = tab == 0, onClick = { tab = 0 },
                        icon = { Icon(Icons.Filled.Book, null) }, label = { Text("Bücher") })
                    NavigationBarItem(selected = tab == 1, onClick = { tab = 1 },
                        icon = { Icon(Icons.Filled.PlayArrow, null) }, label = { Text("Produktion") })
                    NavigationBarItem(selected = tab == 2, onClick = { tab = 2 },
                        icon = { Icon(Icons.Filled.Settings, null) }, label = { Text("Einstellungen") })
                }
            }
        ) { padding ->
            Column(Modifier.padding(padding)) {
                when (tab) {
                    0 -> BooksScreen(onRead = { readerProject = it })
                    1 -> ProductionScreen()
                    else -> SettingsScreen()
                }
            }
        }
    }
}

// MARK: - Bücher

@Composable
fun BooksScreen(onRead: (Project) -> Unit) {
    val context = LocalContext.current
    var refresh by remember { mutableIntStateOf(0) }
    val projects = remember(refresh) { ProjectStore.loadAll(context) }
    var showWizard by remember { mutableStateOf(false) }
    val engine by Orchestrator.state.collectAsState()

    Scaffold(
        floatingActionButton = {
            FloatingActionButton(onClick = { showWizard = true }) {
                Text("+", style = MaterialTheme.typography.headlineMedium)
            }
        }
    ) { padding ->
        if (projects.isEmpty()) {
            Column(
                Modifier.fillMaxSize().padding(32.dp),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text("Noch keine Bücher", style = MaterialTheme.typography.titleLarge)
                Spacer(Modifier.height(8.dp))
                Text("Tippe auf +, um die autonome Buchproduktion zu starten.",
                     style = MaterialTheme.typography.bodyMedium)
            }
        } else {
            LazyColumn(Modifier.padding(padding).padding(12.dp)) {
                items(projects, key = { it.id }) { project ->
                    Card(Modifier.fillMaxWidth().padding(vertical = 6.dp)) {
                        Column(Modifier.padding(14.dp)) {
                            Text(project.title, style = MaterialTheme.typography.titleMedium)
                            Text("${project.genre} · ${project.status.display} · ${project.totalWords} Wörter",
                                 style = MaterialTheme.typography.bodySmall)
                            if (project.lastError.isNotEmpty()) {
                                Text(project.lastError,
                                     style = MaterialTheme.typography.bodySmall,
                                     color = MaterialTheme.colorScheme.error)
                            }
                            Spacer(Modifier.height(8.dp))
                            Row {
                                if (project.chapters.any { it.bestText.isNotEmpty() }) {
                                    OutlinedButton(onClick = { onRead(project) }) { Text("Lesen") }
                                    Spacer(Modifier.width(8.dp))
                                }
                                if (project.status != ProjectStatus.COMPLETED && !engine.isRunning) {
                                    OutlinedButton(onClick = {
                                        ProductionService.startSingle(context, project.id)
                                    }) { Text("Fortsetzen") }
                                    Spacer(Modifier.width(8.dp))
                                }
                                TextButton(onClick = {
                                    ProjectStore.delete(context, project)
                                    refresh++
                                }) { Text("Löschen") }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showWizard) {
        WizardDialog(
            onDismiss = { showWizard = false },
            onStarted = { showWizard = false; refresh++ }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun WizardDialog(onDismiss: () -> Unit, onStarted: () -> Unit) {
    val context = LocalContext.current
    var title by remember { mutableStateOf("") }
    var author by remember { mutableStateOf(SettingsStore.authorName(context)) }
    var genre by remember { mutableStateOf("Thriller") }
    var style by remember { mutableStateOf("atmosphärisch") }
    var pages by remember { mutableStateOf("120") }
    val ready = SettingsStore.isReady(context)

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Neues Buch") },
        text = {
            Column {
                if (!ready) {
                    Text("Bitte zuerst unter Einstellungen einen Provider mit API-Key einrichten.",
                         color = MaterialTheme.colorScheme.error,
                         style = MaterialTheme.typography.bodySmall)
                    Spacer(Modifier.height(8.dp))
                }
                OutlinedTextField(value = title, onValueChange = { title = it },
                    label = { Text("Titel") }, singleLine = true)
                OutlinedTextField(value = author, onValueChange = { author = it },
                    label = { Text("Autor/Pseudonym") }, singleLine = true)
                Dropdown("Genre", ProductionService.genrePool, genre) { genre = it }
                Dropdown("Stil", ProductionService.stylePool, style) { style = it }
                OutlinedTextField(value = pages, onValueChange = { pages = it.filter(Char::isDigit) },
                    label = { Text("Zielseiten (50–500)") }, singleLine = true)
            }
        },
        confirmButton = {
            Button(
                enabled = ready && title.isNotBlank() && author.isNotBlank(),
                onClick = {
                    val project = Project(
                        title = title.trim(), author = author.trim(),
                        genre = genre, style = style,
                        targetPages = (pages.toIntOrNull() ?: 120).coerceIn(50, 500)
                    )
                    ProjectStore.save(context, project)
                    ProductionService.startSingle(context, project.id)
                    onStarted()
                }
            ) { Text("Produktion starten") }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text("Abbrechen") } }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun Dropdown(label: String, options: List<String>, selected: String, onSelect: (String) -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value = selected, onValueChange = {}, readOnly = true,
            label = { Text(label) },
            modifier = Modifier.menuAnchor().fillMaxWidth()
        )
        androidx.compose.material3.ExposedDropdownMenu(
            expanded = expanded, onDismissRequest = { expanded = false }
        ) {
            options.forEach { option ->
                DropdownMenuItem(text = { Text(option) },
                    onClick = { onSelect(option); expanded = false })
            }
        }
    }
}

// MARK: - Produktion

@Composable
fun ProductionScreen() {
    val context = LocalContext.current
    val engine by Orchestrator.state.collectAsState()
    var unlimitedGenre by remember { mutableStateOf("Zufällig") }
    var unlimitedStyle by remember { mutableStateOf("Zufällig") }
    var unlimitedPages by remember { mutableStateOf("120") }

    LazyColumn(Modifier.fillMaxSize().padding(16.dp)) {
        item {
            if (engine.isRunning) {
                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            CircularProgressIndicator(Modifier.width(24.dp).height(24.dp))
                            Spacer(Modifier.width(12.dp))
                            Column {
                                Text(if (engine.isUnlimited)
                                        "Dauerproduktion – läuft bis Stopp"
                                     else engine.projectTitle.ifEmpty { "Produktion" },
                                     style = MaterialTheme.typography.titleMedium)
                                Text("${engine.phase} ${engine.detail}".trim(),
                                     style = MaterialTheme.typography.bodySmall)
                            }
                        }
                        Spacer(Modifier.height(12.dp))
                        LinearProgressIndicator(progress = { engine.progress },
                            modifier = Modifier.fillMaxWidth())
                        Spacer(Modifier.height(8.dp))
                        Text(buildString {
                            if (engine.isUnlimited) append("${engine.booksCompleted} Bücher fertig · ")
                            append("${engine.tokensUsed} Tokens")
                        }, style = MaterialTheme.typography.bodySmall)
                        Spacer(Modifier.height(12.dp))
                        Button(onClick = { ProductionService.stop(context) }) {
                            Icon(Icons.Filled.Stop, null)
                            Spacer(Modifier.width(6.dp))
                            Text("Stoppen")
                        }
                    }
                }
            } else {
                if (engine.lastError.isNotEmpty()) {
                    Card(Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp)) {
                            Text("Letzte Produktion abgebrochen",
                                 style = MaterialTheme.typography.titleSmall,
                                 color = MaterialTheme.colorScheme.error)
                            Text(engine.lastError, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                    Spacer(Modifier.height(16.dp))
                }

                Card(Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.AllInclusive, null)
                            Spacer(Modifier.width(8.dp))
                            Text("Dauerproduktion (Unlimited)",
                                 style = MaterialTheme.typography.titleMedium)
                        }
                        Spacer(Modifier.height(8.dp))
                        Text("Erfindet eigene Buchideen und produziert Buch für Buch in den Ordner NovelForge – bis Stopp gedrückt wird.",
                             style = MaterialTheme.typography.bodySmall)
                        Spacer(Modifier.height(12.dp))
                        Dropdown("Genre", listOf("Zufällig") + ProductionService.genrePool,
                                 unlimitedGenre) { unlimitedGenre = it }
                        Spacer(Modifier.height(8.dp))
                        Dropdown("Stil", listOf("Zufällig") + ProductionService.stylePool,
                                 unlimitedStyle) { unlimitedStyle = it }
                        Spacer(Modifier.height(8.dp))
                        OutlinedTextField(value = unlimitedPages,
                            onValueChange = { unlimitedPages = it.filter(Char::isDigit) },
                            label = { Text("Seiten pro Buch") }, singleLine = true)
                        Spacer(Modifier.height(12.dp))
                        Button(
                            enabled = SettingsStore.isReady(context),
                            onClick = {
                                ProductionService.startUnlimited(
                                    context, unlimitedGenre, unlimitedStyle,
                                    (unlimitedPages.toIntOrNull() ?: 120).coerceIn(50, 500)
                                )
                            }
                        ) {
                            Icon(Icons.Filled.AllInclusive, null)
                            Spacer(Modifier.width(6.dp))
                            Text("Dauerproduktion starten")
                        }
                        if (!SettingsStore.isReady(context)) {
                            Spacer(Modifier.height(6.dp))
                            Text("Zuerst unter Einstellungen Provider & API-Key einrichten.",
                                 style = MaterialTheme.typography.bodySmall,
                                 color = MaterialTheme.colorScheme.error)
                        }
                    }
                }

                Spacer(Modifier.height(16.dp))
                Text("Fertige Bücher liegen unter Android/data/com.novelforge.android/files/NovelForge/ (per Dateien-App erreichbar): EPUB für Amazon KDP + TXT.",
                     style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}

// MARK: - Reader

@Composable
fun ReaderScreen(project: Project, onBack: () -> Unit) {
    var chapterIndex by remember { mutableIntStateOf(0) }
    val chapters = project.chapters.sortedBy { it.number }

    Scaffold { padding ->
        Column(Modifier.padding(padding).padding(16.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                TextButton(onClick = onBack) { Text("← Zurück") }
                Spacer(Modifier.width(8.dp))
                Text(project.title, style = MaterialTheme.typography.titleMedium)
            }
            Row {
                OutlinedButton(enabled = chapterIndex > 0,
                    onClick = { chapterIndex-- }) { Text("‹") }
                Spacer(Modifier.width(8.dp))
                Text("Kapitel ${chapterIndex + 1} / ${chapters.size}",
                     modifier = Modifier.padding(top = 12.dp))
                Spacer(Modifier.width(8.dp))
                OutlinedButton(enabled = chapterIndex < chapters.size - 1,
                    onClick = { chapterIndex++ }) { Text("›") }
            }
            Spacer(Modifier.height(8.dp))
            val chapter = chapters.getOrNull(chapterIndex)
            LazyColumn {
                item {
                    Text(chapter?.title ?: "", style = MaterialTheme.typography.titleLarge)
                    Spacer(Modifier.height(12.dp))
                    Text(chapter?.bestText ?: "Noch kein Text vorhanden.",
                         style = MaterialTheme.typography.bodyMedium)
                }
            }
        }
    }
}

// MARK: - Einstellungen

@Composable
fun SettingsScreen() {
    val context = LocalContext.current
    var provider by remember { mutableStateOf(SettingsStore.provider(context)) }
    var model by remember { mutableStateOf(SettingsStore.model(context)) }
    var apiKey by remember { mutableStateOf("") }
    var baseUrl by remember { mutableStateOf(SettingsStore.baseUrl(context)) }
    var author by remember { mutableStateOf(SettingsStore.authorName(context)) }
    var saved by remember { mutableStateOf(false) }

    LazyColumn(Modifier.fillMaxSize().padding(16.dp)) {
        item {
            Text("KI-Provider", style = MaterialTheme.typography.titleLarge)
            Spacer(Modifier.height(12.dp))

            Dropdown("Provider", AiProvider.entries.map { it.display },
                     provider.display) { display ->
                provider = AiProvider.entries.first { it.display == display }
                model = provider.suggestedModels.firstOrNull() ?: ""
            }
            Spacer(Modifier.height(8.dp))

            if (provider.suggestedModels.isNotEmpty()) {
                Dropdown("Modell", provider.suggestedModels, model) { model = it }
            } else {
                OutlinedTextField(value = model, onValueChange = { model = it },
                    label = { Text("Modellname") }, singleLine = true,
                    modifier = Modifier.fillMaxWidth())
            }
            Spacer(Modifier.height(8.dp))

            if (provider.requiresKey) {
                OutlinedTextField(value = apiKey, onValueChange = { apiKey = it },
                    label = { Text(if (SettingsStore.apiKey(context, provider).isNotEmpty())
                                       "API-Key (gespeichert – leer lassen zum Behalten)"
                                   else "API-Key") },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth())
                Spacer(Modifier.height(8.dp))
            }

            OutlinedTextField(value = baseUrl, onValueChange = { baseUrl = it },
                label = { Text("Basis-URL (optional, Standard: ${provider.defaultBaseUrl})") },
                singleLine = true, modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(8.dp))

            OutlinedTextField(value = author, onValueChange = { author = it },
                label = { Text("Standard-Autorname") }, singleLine = true,
                modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(16.dp))

            Button(onClick = {
                SettingsStore.save(context, provider, model,
                    apiKey.ifEmpty { null }, baseUrl,
                    SettingsStore.costLimit(context), author)
                apiKey = ""
                saved = true
            }) { Text("Speichern") }

            if (saved) {
                Spacer(Modifier.height(8.dp))
                Text("Gespeichert ✓ – API-Keys liegen verschlüsselt im Android Keystore.",
                     style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}
