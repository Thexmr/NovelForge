package com.novelforge.android.ai

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

enum class AiProvider(val display: String, val defaultBaseUrl: String, val requiresKey: Boolean) {
    OPENAI("OpenAI", "https://api.openai.com/v1", true),
    ANTHROPIC("Anthropic Claude", "https://api.anthropic.com", true),
    OLLAMA("Ollama (lokal/Netzwerk)", "http://192.168.0.1:11434", false),
    KIMI("Kimi/Moonshot", "https://api.moonshot.ai/v1", true),
    CUSTOM("Eigener Endpunkt", "", true);

    val suggestedModels: List<String>
        get() = when (this) {
            OPENAI -> listOf("gpt-4o", "gpt-4o-mini", "gpt-4-turbo")
            ANTHROPIC -> listOf("claude-opus-4-8", "claude-sonnet-4-6", "claude-haiku-4-5")
            OLLAMA -> listOf("llama3.1", "qwen2.5", "mistral-nemo")
            KIMI -> listOf("kimi-k2-0711-preview", "moonshot-v1-128k")
            CUSTOM -> emptyList()
        }

    companion object {
        fun from(name: String): AiProvider =
            entries.firstOrNull { it.name == name } ?: OPENAI
    }
}

data class ProviderConfig(
    val provider: AiProvider,
    val model: String,
    val apiKey: String,
    val baseUrl: String,
    val costLimitUsd: Double
)

/**
 * Einstellungen inkl. API-Keys – Keys liegen ausschließlich in
 * EncryptedSharedPreferences (Android Keystore), nie im Klartext.
 */
object SettingsStore {

    private fun prefs(context: Context) = EncryptedSharedPreferences.create(
        context,
        "novelforge_secure",
        MasterKey.Builder(context).setKeyScheme(MasterKey.KeyScheme.AES256_GCM).build(),
        EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
        EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
    )

    fun provider(context: Context): AiProvider =
        AiProvider.from(prefs(context).getString("provider", null) ?: AiProvider.OPENAI.name)

    fun model(context: Context): String =
        prefs(context).getString("model", null)
            ?: provider(context).suggestedModels.firstOrNull() ?: ""

    fun apiKey(context: Context, provider: AiProvider): String =
        prefs(context).getString("key_${provider.name}", null) ?: ""

    fun baseUrl(context: Context): String =
        prefs(context).getString("baseUrl", null) ?: ""

    fun costLimit(context: Context): Double =
        prefs(context).getFloat("costLimit", 20f).toDouble()

    fun authorName(context: Context): String =
        prefs(context).getString("author", null) ?: ""

    fun save(context: Context, provider: AiProvider, model: String,
             apiKey: String?, baseUrl: String, costLimit: Double, author: String) {
        prefs(context).edit().apply {
            putString("provider", provider.name)
            putString("model", model)
            if (!apiKey.isNullOrEmpty()) putString("key_${provider.name}", apiKey)
            putString("baseUrl", baseUrl)
            putFloat("costLimit", costLimit.toFloat())
            putString("author", author)
            apply()
        }
    }

    fun activeConfig(context: Context): ProviderConfig {
        val provider = provider(context)
        return ProviderConfig(
            provider = provider,
            model = model(context),
            apiKey = apiKey(context, provider),
            baseUrl = baseUrl(context).ifEmpty { provider.defaultBaseUrl },
            costLimitUsd = costLimit(context)
        )
    }

    fun isReady(context: Context): Boolean {
        val config = activeConfig(context)
        return config.model.isNotEmpty() && (!config.provider.requiresKey || config.apiKey.isNotEmpty())
    }
}
