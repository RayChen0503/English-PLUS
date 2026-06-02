package tw.edu.citizenaction.soracompanion.ai

import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL

class OpenRouterClient(
    private val apiKey: String,
    private val model: String = DEFAULT_MODEL
) {
    fun generateSupport(
        question: String,
        concept: String,
        answerContext: String,
        moodLabel: String,
        wrongAttempts: Int
    ): AiSupportResult {
        val body = buildSupportRequestBody(
            model = model,
            question = question,
            concept = concept,
            answerContext = answerContext,
            moodLabel = moodLabel,
            wrongAttempts = wrongAttempts
        )
        val response = postJson(ENDPOINT, body)
        return parseSupportResponse(response, model)
    }

    fun generateEmotionalSupport(
        routeTitle: String,
        nextStep: String,
        moodLabel: String,
        minutes: Int,
        confidence: Int,
        challengeWanted: Boolean,
        preferredTypes: List<String>
    ): AiSupportResult {
        val body = buildEmotionalSupportRequestBody(
            model = model,
            routeTitle = routeTitle,
            nextStep = nextStep,
            moodLabel = moodLabel,
            minutes = minutes,
            confidence = confidence,
            challengeWanted = challengeWanted,
            preferredTypes = preferredTypes
        )
        val response = postJson(ENDPOINT, body)
        return parseSupportResponse(response, model)
    }

    private fun postJson(endpoint: String, body: JSONObject): String {
        val connection = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 20_000
            readTimeout = 45_000
            doOutput = true
            setRequestProperty("Authorization", "Bearer $apiKey")
            setRequestProperty("Content-Type", "application/json; charset=utf-8")
            setRequestProperty("Accept", "application/json")
            setRequestProperty("X-Title", "English+ Android Prototype")
        }

        OutputStreamWriter(connection.outputStream, Charsets.UTF_8).use { writer ->
            writer.write(body.toString())
        }

        val stream = if (connection.responseCode in 200..299) connection.inputStream else connection.errorStream
        val text = BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).use { it.readText() }
        if (connection.responseCode !in 200..299) {
            throw IllegalStateException("OpenRouter API error ${connection.responseCode}: $text")
        }
        return text
    }

    companion object {
        const val DEFAULT_MODEL = "openrouter/free"
        const val ENDPOINT = "https://openrouter.ai/api/v1/chat/completions"

        fun isLikelyOpenRouterKey(value: String): Boolean {
            val key = value.trim()
            return key.startsWith("sk-or-") || key.startsWith("sk-or-v1-")
        }

        fun buildSupportRequestBody(
            model: String,
            question: String,
            concept: String,
            answerContext: String,
            moodLabel: String,
            wrongAttempts: Int
        ): JSONObject {
            val context = JSONObject()
                .put("question", question)
                .put("concept", concept)
                .put("answerContext", answerContext)
                .put("moodLabel", moodLabel)
                .put("wrongAttempts", wrongAttempts)

            val system = "You are English+ support AI for rural junior-high English learning. " +
                "Reply in Traditional Chinese. Be warm, brief, practical, and do not shame the student. " +
                "Return only JSON with diagnosis, studentFeedback, and handoffSummary."
            val user = "Create emotional breakpoint support from this learning context: $context"

            return JSONObject()
                .put("model", model.ifBlank { DEFAULT_MODEL })
                .put("messages", JSONArray()
                    .put(JSONObject().put("role", "system").put("content", system))
                    .put(JSONObject().put("role", "user").put("content", user)))
                .put("temperature", 0.4)
                .put("max_tokens", 420)
        }

        fun buildEmotionalSupportRequestBody(
            model: String,
            routeTitle: String,
            nextStep: String,
            moodLabel: String,
            minutes: Int,
            confidence: Int,
            challengeWanted: Boolean,
            preferredTypes: List<String>
        ): JSONObject {
            val context = JSONObject()
                .put("routeTitle", routeTitle)
                .put("nextStep", nextStep)
                .put("moodLabel", moodLabel)
                .put("minutes", minutes)
                .put("confidence", confidence)
                .put("challengeWanted", challengeWanted)
                .put("preferredTypes", JSONArray(preferredTypes))

            val system = "You are English+ emotional support AI for rural junior-high English learning. " +
                "Reply in Traditional Chinese. Give short emotional support, then one concrete next step. " +
                "Do not over-diagnose mental health. Return only JSON with diagnosis, studentFeedback, and handoffSummary."
            val user = "Create emotional support after the student's check-in and explain today's route from this context: $context"

            return JSONObject()
                .put("model", model.ifBlank { DEFAULT_MODEL })
                .put("messages", JSONArray()
                    .put(JSONObject().put("role", "system").put("content", system))
                    .put(JSONObject().put("role", "user").put("content", user)))
                .put("temperature", 0.45)
                .put("max_tokens", 420)
        }

        fun parseSupportResponse(responseText: String, model: String): AiSupportResult {
            val response = JSONObject(responseText.ifBlank { "{}" })
            val choices = response.optJSONArray("choices") ?: JSONArray()
            val message = choices.optJSONObject(0)?.optJSONObject("message")
            val rawContent = message?.optString("content").orEmpty()
            val content = extractJsonObject(rawContent)
            val json = JSONObject(content)
            return AiSupportResult(
                diagnosis = json.optString("diagnosis", "OpenRouter 已回覆，但沒有提供診斷欄位。"),
                studentFeedback = json.optString("studentFeedback", "OpenRouter 已回覆，但沒有提供學生回饋欄位。"),
                handoffSummary = json.optString("handoffSummary", "OpenRouter 已回覆，但沒有提供接力摘要欄位。"),
                source = "OpenRouter Chat Completions / $model"
            )
        }

        private fun extractJsonObject(text: String): String {
            val clean = text.trim()
                .removePrefix("```json")
                .removePrefix("```")
                .removeSuffix("```")
                .trim()
            val start = clean.indexOf('{')
            val end = clean.lastIndexOf('}')
            if (start >= 0 && end > start) return clean.substring(start, end + 1)
            return clean
        }
    }
}