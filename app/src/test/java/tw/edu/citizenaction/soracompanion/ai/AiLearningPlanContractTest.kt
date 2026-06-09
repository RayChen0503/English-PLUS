package tw.edu.citizenaction.soracompanion.ai

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AiLearningPlanContractTest {
    @Test
    fun localPlanTurnsCheckInIntoOneDailyMission() {
        val plan = AiLearningPlanContract.localDailyMissionPlan(
            moodLabel = "低",
            minutes = 3,
            challengeWanted = false,
            preferredTypes = setOf("填空題", "翻譯/句子重組"),
            availableTypes = listOf("選擇題", "填空題", "閱讀理解", "翻譯/句子重組")
        )

        assertEquals("低壓修復", plan.routeLabel)
        assertEquals(1, plan.questionGoal)
        assertEquals(listOf("填空題", "翻譯/句子重組"), plan.recommendedTypes)
        assertTrue(plan.studentMessage.contains("先完成 1 題"))
        assertFalse(plan.studentMessage.contains("API"))
    }

    @Test
    fun remotePayloadUsesProductLanguageAndNoMobileSecret() {
        val payload = AiLearningPlanContract.buildMissionPayload(
            classCode = "YILAN-8A",
            studentName = "小安",
            moodLabel = "普通",
            minutes = 8,
            challengeWanted = true,
            preferredTypes = setOf("閱讀理解"),
            availableTypes = listOf("選擇題", "填空題", "閱讀理解")
        )

        assertEquals("generateDailyMission", payload["action"])
        assertEquals("English+", payload["app"])
        assertEquals("YILAN-8A", payload["classCode"])
        assertEquals("小安", payload["studentName"])
        assertEquals(8, payload["minutes"])
        assertEquals(true, payload["challengeWanted"])
        assertFalse(payload.keys.any { it.contains("key", ignoreCase = true) })
    }
}
