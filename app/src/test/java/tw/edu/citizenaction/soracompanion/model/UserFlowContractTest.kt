package tw.edu.citizenaction.soracompanion.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UserFlowContractTest {
    @Test
    fun studentAndStaffNavigationStaySeparated() {
        val studentLabels = UserFlowContract.bottomNavLabels(Role.Student)
        val staffLabels = UserFlowContract.bottomNavLabels(Role.Mentor)

        assertEquals(listOf("首頁", "練習", "支持", "地圖", "檔案"), studentLabels)
        assertEquals(listOf("今日", "學生", "接力", "同步", "報告"), staffLabels)
        assertFalse(staffLabels.contains("練習"))
        assertFalse(staffLabels.contains("檔案"))
    }

    @Test
    fun checkInUsesExactlyFourMeaningfulQuestions() {
        val questions = UserFlowContract.requiredCheckInQuestions()

        assertEquals(4, questions.size)
        assertEquals("今天的心情量表", questions[0])
        assertEquals("今天有足夠的時間練習英文嗎", questions[1])
        assertEquals("今天會想要挑戰更難的題目嗎", questions[2])
        assertEquals("想要多練習哪幾種題型", questions[3])
    }

    @Test
    fun timeScaleDrivesDailyQuestionGoalWithoutAskingMinutesAgain() {
        assertEquals(3, UserFlowContract.minutesFromTimeScale(1))
        assertEquals(3, UserFlowContract.minutesFromTimeScale(2))
        assertEquals(5, UserFlowContract.minutesFromTimeScale(3))
        assertEquals(8, UserFlowContract.minutesFromTimeScale(4))
        assertEquals(12, UserFlowContract.minutesFromTimeScale(5))

        assertEquals(1, UserFlowContract.questionGoal(3))
        assertEquals(2, UserFlowContract.questionGoal(5))
        assertEquals(3, UserFlowContract.questionGoal(8))
        assertEquals(4, UserFlowContract.questionGoal(12))
    }

    @Test
    fun helpRoutesDoNotCollapseIntoTheSameSupportPath() {
        assertEquals(SupportTarget.AiCoach, UserFlowContract.supportTarget("AI 陪伴"))
        assertEquals(SupportTarget.ReadingBreakdown, UserFlowContract.supportTarget("閱讀拆解"))
        assertEquals(SupportTarget.Recovery, UserFlowContract.supportTarget("復原模式"))
        assertEquals(SupportTarget.HumanHandoff, UserFlowContract.supportTarget("志工接力"))
        assertEquals(SupportTarget.HumanHandoff, UserFlowContract.supportTarget("老師接力"))
    }

    @Test
    fun questionTypeOptionsCoverAllCurrentPracticeModes() {
        assertTrue(UserFlowContract.questionTypes.contains("選擇題"))
        assertTrue(UserFlowContract.questionTypes.contains("填空題"))
        assertTrue(UserFlowContract.questionTypes.contains("克漏字"))
        assertTrue(UserFlowContract.questionTypes.contains("閱讀理解"))
        assertTrue(UserFlowContract.questionTypes.contains("翻譯/句子重組"))
    }
}
