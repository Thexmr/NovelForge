package com.novelforge.android.ai

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL

class AiException(message: String, val retryable: Boolean = false) : Exception(message)

data class AiResponse(val text: String, val tokensUsed: Int)

/**
 * Einheitliche Anbindung aller Provider über HttpURLConnection –
 * bewusst ohne externe Abhängigkeiten (maximale Build-Stabilität).
 */
object Gateway {

    private const val MAX_RETRIES = 3

    suspend fun generate(
        prompt: String,
        system: String,
        maxTokens: Int,
        temperature: Double,
        config: ProviderConfig
    ): AiResponse = withContext(Dispatchers.IO) {
        var lastError: AiException? = null
        repeat(MAX_RETRIES) { attempt ->
            try {
                return@withContext execute(prompt, system, maxTokens, temperature, config)
            } catch (error: AiException) {
                lastError = error
                if (!error.retryable) throw error
                delay((attempt + 1) * 2000L)
            }
        }
        throw lastError ?: AiException("Unbekannter Fehler")
    }

    private fun execute(
        prompt: String, system: String, maxTokens: Int,
        temperature: Double, config: ProviderConfig
    ): AiResponse = when (config.provider) {
        AiProvider.ANTHROPIC -> anthropic(prompt, system, maxTokens, config)
        AiProvider.OLLAMA -> ollama(prompt, system, maxTokens, temperature, config)
        else -> openAiCompatible(prompt, system, maxTokens, temperature, config)
    }

    private fun request(url: String, headers: Map<String, String>, body: JSONObject): Pair<Int, String> {
        val connection = URL(url).openConnection() as HttpURLConnection
        return try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 30_000
            connection.readTimeout = 300_000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            headers.forEach { (key, value) -> connection.setRequestProperty(key, value) }
            connection.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }

            val code = connection.responseCode
            val stream = if (code in 200..299) connection.inputStream else connection.errorStream
            val text = stream?.bufferedReader()?.use { it.readText() } ?: ""
            code to text
        } catch (error: Exception) {
            throw AiException("Netzwerkfehler: ${error.message}", retryable = true)
        } finally {
            connection.disconnect()
        }
    }

    private fun mapHttpError(code: Int, body: String): AiException {
        val message = runCatching {
            JSONObject(body).optJSONObject("error")?.optString("message")
        }.getOrNull()?.takeIf { !it.isNullOrEmpty() } ?: "HTTP $code"
        return when (code) {
            401, 403 -> AiException("API-Key ungültig oder fehlt ($message)")
            404 -> AiException("Modell nicht verfügbar ($message)")
            429 -> AiException("Rate Limit erreicht", retryable = true)
            in 500..599 -> AiException("Provider nicht erreichbar (HTTP $code)", retryable = true)
            else -> AiException(message)
        }
    }

    private fun openAiCompatible(
        prompt: String, system: String, maxTokens: Int,
        temperature: Double, config: ProviderConfig
    ): AiResponse {
        if (config.provider.requiresKey && config.apiKey.isEmpty()) {
            throw AiException("Kein API-Key hinterlegt")
        }
        val base = config.baseUrl.trimEnd('/')
        val body = JSONObject().apply {
            put("model", config.model)
            put("messages", JSONArray().apply {
                put(JSONObject().put("role", "system").put("content", system))
                put(JSONObject().put("role", "user").put("content", prompt))
            })
            put("max_tokens", maxTokens)
            put("temperature", temperature)
        }
        val (code, text) = request(
            "$base/chat/completions",
            mapOf("Authorization" to "Bearer ${config.apiKey}"),
            body
        )
        if (code !in 200..299) throw mapHttpError(code, text)

        val json = JSONObject(text)
        val content = json.getJSONArray("choices").getJSONObject(0)
            .getJSONObject("message").getString("content")
        val tokens = json.optJSONObject("usage")?.optInt("total_tokens", 0) ?: 0
        return AiResponse(content, tokens)
    }

    private fun anthropic(
        prompt: String, system: String, maxTokens: Int, config: ProviderConfig
    ): AiResponse {
        if (config.apiKey.isEmpty()) throw AiException("Kein API-Key hinterlegt")
        val base = config.baseUrl.trimEnd('/')
        // Bewusst ohne temperature – neuere Claude-Modelle lehnen Sampling-Parameter ab.
        val body = JSONObject().apply {
            put("model", config.model)
            put("max_tokens", maxTokens)
            put("system", system)
            put("messages", JSONArray().put(
                JSONObject().put("role", "user").put("content", prompt)
            ))
        }
        val (code, text) = request(
            "$base/v1/messages",
            mapOf("x-api-key" to config.apiKey, "anthropic-version" to "2023-06-01"),
            body
        )
        if (code !in 200..299) throw mapHttpError(code, text)

        val json = JSONObject(text)
        val content = StringBuilder()
        val blocks = json.getJSONArray("content")
        for (index in 0 until blocks.length()) {
            val block = blocks.getJSONObject(index)
            if (block.optString("type") == "text") content.append(block.optString("text"))
        }
        val usage = json.optJSONObject("usage")
        val tokens = (usage?.optInt("input_tokens", 0) ?: 0) + (usage?.optInt("output_tokens", 0) ?: 0)
        return AiResponse(content.toString(), tokens)
    }

    private fun ollama(
        prompt: String, system: String, maxTokens: Int,
        temperature: Double, config: ProviderConfig
    ): AiResponse {
        val base = config.baseUrl.trimEnd('/')
        val body = JSONObject().apply {
            put("model", config.model)
            put("prompt", prompt)
            put("system", system)
            put("stream", false)
            put("options", JSONObject().put("temperature", temperature).put("num_predict", maxTokens))
        }
        val (code, text) = request("$base/api/generate", emptyMap(), body)
        if (code !in 200..299) throw mapHttpError(code, text)

        val json = JSONObject(text)
        return AiResponse(json.optString("response"), json.optInt("eval_count", 0))
    }
}
