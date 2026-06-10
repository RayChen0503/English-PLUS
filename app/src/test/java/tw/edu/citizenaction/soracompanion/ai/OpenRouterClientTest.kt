package tw.edu.citizenaction.soracompanion.ai

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OpenRouterClientTest {
    @Test
    fun supportRequestUsesFreeRouterChatCompletionsShape() {
        val body = OpenRouterClient.buildSupportRequestBody(
            model = OpenRouterClient.DEFAULT_MODEL,
            question = "He ___ a student.",
            concept = "be 動詞",
            answerContext = "學生選了 are\n正確答案是 is\nHe 要搭配 is。",
            moodLabel = "普通",
            wrongAttempts = 2
        )

        assertEquals("openrouter/free", body.getString("model"))
        val messages = body.getJSONArray("messages")
        assertEquals("system", messages.getJSONObject(0).getString("role"))
        assertEquals("user", messages.getJSONObject(1).getString("role"))
        assertTrue(messages.getJSONObject(0).getString("content").contains("Traditional Chinese"))
        assertTrue(messages.getJSONObject(1).getString("content").contains("He ___ a student."))
        assertTrue(messages.getJSONObject(1).getString("content").contains("學生選了 are"))
        assertTrue(messages.getJSONObject(1).getString("content").contains("正確答案是 is"))
        assertTrue(body.getInt("max_tokens") <= 500)
    }

    @Test
    fun parsesOpenRouterChatCompletionIntoSupportResult() {
        val content = JSONObject()
            .put("diagnosis", "學生卡在 be 動詞主詞搭配。")
            .put("studentFeedback", "先記住 He 要接 is，這題可以再試一次。")
            .put("handoffSummary", "志工可陪學生練 He is / She is。")
            .toString()
        val response = JSONObject()
            .put("model", "openrouter/free")
            .put("choices", JSONArray().put(JSONObject()
                .put("message", JSONObject().put("content", content))))

        val result = OpenRouterClient.parseSupportResponse(response.toString(), "openrouter/free")

        assertEquals("學生卡在 be 動詞主詞搭配。", result.diagnosis)
        assertEquals("先記住 He 要接 is，這題可以再試一次。", result.studentFeedback)
        assertEquals("志工可陪學生練 He is / She is。", result.handoffSummary)
        assertTrue(result.source.contains("OpenRouter"))
    }

    @Test
    fun emotionalSupportRequestIncludesCheckInContextAndPreferredTypes() {
        val body = OpenRouterClient.buildEmotionalSupportRequestBody(
            model = OpenRouterClient.DEFAULT_MODEL,
            routeTitle = "挑戰路線",
            nextStep = "今天可以先做一題閱讀理解。",
            moodLabel = "普通",
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
        assertTrue(user.contains("挑戰路線"))
        assertTrue(user.contains("閱讀理解"))
        assertTrue(user.contains("克漏字"))
        assertTrue(user.contains("8"))
    }

    @Test
    fun dailyTaskPlanRequestIncludesCheckInTimeAndQuestionBankIds() {
        val body = OpenRouterClient.buildDailyTaskPlanRequestBody(
            model = OpenRouterClient.DEFAULT_MODEL,
            routeTitle = "低壓修復",
            nextStep = "今天先做短題，不急著挑戰。",
            moodLabel = "普通",
            minutes = 8,
            confidence = 62,
            challengeWanted = true,
            preferredTypes = listOf("克漏字", "閱讀理解"),
            targetQuestionCount = 5,
            questionBank = listOf(
                AiQuestionBankOption(
                    id = "q-a2-cloze-001",
                    level = "A2",
                    questionType = "克漏字",
                    concept = "轉折連接詞",
                    skill = "文意判斷",
                    challengeScore = 4,
                    estimatedSeconds = 75
                ),
                AiQuestionBankOption(
                    id = "q-b1-reading-002",
                    level = "B1",
                    questionType = "閱讀理解",
                    concept = "主旨判斷",
                    skill = "短文閱讀",
                    challengeScore = 5,
                    estimatedSeconds = 120
                )
            )
        )

        val user = body.getJSONArray("messages").getJSONObject(1).getString("content")

        assertEquals("openrouter/free", body.getString("model"))
        assertTrue(user.contains("q-a2-cloze-001"))
        assertTrue(user.contains("q-b1-reading-002"))
        assertTrue(user.contains("8"))
        assertTrue(user.contains("5"))
        assertTrue(user.contains("克漏字"))
        assertTrue(user.contains("閱讀理解"))
        assertTrue(body.getInt("max_tokens") <= 700)
    }

    @Test
    fun parsesDailyTaskPlanAndDropsIdsThatAreNotInQuestionBank() {
        val content = JSONObject()
            .put("title", "今天的修復任務")
            .put("studentMessage", "先做短題，完成後再自由挑戰。")
            .put("recommendedItemIds", JSONArray().put("q-a2-cloze-001").put("made-up-id").put("q-b1-reading-002"))
            .toString()
        val response = JSONObject()
            .put("choices", JSONArray().put(JSONObject()
                .put("message", JSONObject().put("content", content))))

        val result = OpenRouterClient.parseDailyTaskPlanResponse(
            responseText = response.toString(),
            model = "openrouter/free",
            allowedIds = setOf("q-a2-cloze-001", "q-b1-reading-002")
        )

        assertEquals("今天的修復任務", result.title)
        assertEquals(listOf("q-a2-cloze-001", "q-b1-reading-002"), result.recommendedItemIds)
        assertTrue(result.studentMessage.contains("短題"))
        assertTrue(result.source.contains("OpenRouter"))
    }

    @Test
    fun emptyDailyTaskPlanFallbackUsesReadableStudentCopy() {
        val result = OpenRouterClient.parseDailyTaskPlanResponse(
            responseText = JSONObject()
                .put("choices", JSONArray().put(JSONObject()
                    .put("message", JSONObject().put("content", "{}"))))
                .toString(),
            model = "openrouter/free",
            allowedIds = setOf("q1")
        )

        assertEquals("今日任務建議", result.title)
        assertTrue(result.studentMessage.contains("English+"))
        assertFalse(result.studentMessage.contains("API"))
    }
}
