package tw.edu.citizenaction.soracompanion.ai

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class OpenRouterClientTest {
    @Test
    fun supportRequestUsesFreeRouterChatCompletionsShape() {
        val body = OpenRouterClient.buildSupportRequestBody(
            model = OpenRouterClient.DEFAULT_MODEL,
            question = "He ___ a student.",
            concept = "be 動詞",
            answerContext = "He 要搭配 is。",
            moodLabel = "普通",
            wrongAttempts = 2
        )

        assertEquals("openrouter/free", body.getString("model"))
        val messages = body.getJSONArray("messages")
        assertEquals("system", messages.getJSONObject(0).getString("role"))
        assertEquals("user", messages.getJSONObject(1).getString("role"))
        assertTrue(messages.getJSONObject(0).getString("content").contains("Traditional Chinese"))
        assertTrue(messages.getJSONObject(1).getString("content").contains("He ___ a student."))
        assertTrue(body.getInt("max_tokens") <= 500)
    }

    @Test
    fun parsesOpenRouterChatCompletionIntoSupportResult() {
        val content = JSONObject()
            .put("diagnosis", "學生卡在 be 動詞主詞搭配。")
            .put("studentFeedback", "先看主詞 He，再選 is。")
            .put("handoffSummary", "志工可用 He is / She is 陪練兩題。")
            .toString()
        val response = JSONObject()
            .put("model", "openrouter/free")
            .put("choices", JSONArray().put(JSONObject()
                .put("message", JSONObject().put("content", content))))

        val result = OpenRouterClient.parseSupportResponse(response.toString(), "openrouter/free")

        assertEquals("學生卡在 be 動詞主詞搭配。", result.diagnosis)
        assertEquals("先看主詞 He，再選 is。", result.studentFeedback)
        assertEquals("志工可用 He is / She is 陪練兩題。", result.handoffSummary)
        assertTrue(result.source.contains("OpenRouter"))
    }

    @Test
    fun emotionalSupportRequestIncludesCheckInContextAndPreferredTypes() {
        val body = OpenRouterClient.buildEmotionalSupportRequestBody(
            model = OpenRouterClient.DEFAULT_MODEL,
            routeTitle = "進階挑戰",
            nextStep = "今天先開啟進階挑戰，優先練閱讀理解。",
            moodLabel = "不錯",
            minutes = 8,
            confidence = 74,
            challengeWanted = true,
            preferredTypes = listOf("閱讀理解", "克漏字")
        )

        val messages = body.getJSONArray("messages")
        val system = messages.getJSONObject(0).getString("content")
        val user = messages.getJSONObject(1).getString("content")

        assertEquals("openrouter/free", body.getString("model"))
        assertTrue(system.contains("emotional support"))
        assertTrue(user.contains("進階挑戰"))
        assertTrue(user.contains("閱讀理解"))
        assertTrue(user.contains("克漏字"))
        assertTrue(user.contains("8"))
    }
}