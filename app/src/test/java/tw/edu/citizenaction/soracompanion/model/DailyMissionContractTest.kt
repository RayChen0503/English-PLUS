package tw.edu.citizenaction.soracompanion.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DailyMissionContractTest {
    @Test
    fun missionSelectionRespectsPreferredTypesAndAvoidsRepeatedPrompts() {
        val items = listOf(
            bankItem("q1", "A1", "選擇題", "Choose the correct word."),
            bankItem("q2", "A2", "填空題", "Fill in the blank."),
            bankItem("q3", "B1", "填空題", "Fill in the blank."),
            bankItem("q4", "B1", "閱讀理解", "Read the short passage.")
        )

        val selected = DailyMissionContract.selectQuestions(
            bankItems = items,
            fallbackQuestions = emptyList(),
            requestedGoal = 3,
            preferredTypes = setOf("填空題", "閱讀理解"),
            challengeWanted = true,
            seed = 0
        )

        assertEquals(2, selected.distinctBy { it.prompt }.size)
        assertEquals(listOf("閱讀理解", "填空題"), selected.map { it.type })
        assertFalse(selected.any { it.type == "選擇題" })
    }

    @Test
    fun missionProgressOnlyMovesAfterCorrectAnswers() {
        val first = DailyMissionContract.progressAfterAnswer(
            done = 0,
            goal = 2,
            isCorrect = false
        )

        assertEquals(0, first.done)
        assertFalse(first.isComplete)

        val second = DailyMissionContract.progressAfterAnswer(
            done = first.done,
            goal = 2,
            isCorrect = true
        )

        assertEquals(1, second.done)
        assertFalse(second.isComplete)

        val third = DailyMissionContract.progressAfterAnswer(
            done = second.done,
            goal = 2,
            isCorrect = true
        )

        assertEquals(2, third.done)
        assertTrue(third.isComplete)
    }

    @Test
    fun dailyProgressIsHiddenOutsideAssignedMission() {
        assertFalse(DailyMissionContract.shouldShowProgress(inDailyMission = false, goal = 3))
        assertFalse(DailyMissionContract.shouldShowProgress(inDailyMission = true, goal = 0))
        assertTrue(DailyMissionContract.shouldShowProgress(inDailyMission = true, goal = 3))
        assertEquals(2, DailyMissionContract.remaining(goal = 3, done = 1))
        assertEquals(100, DailyMissionContract.progressPercent(goal = 3, done = 5))
    }

    @Test
    fun missionSummaryUsesOneClearStudentFacingNextStep() {
        val summary = DailyMissionContract.summary(
            minutes = 5,
            goal = 2,
            preferredTypes = setOf("填空題", "閱讀理解"),
            challengeWanted = true
        )

        assertEquals("完成 2 題今日任務", summary.title)
        assertEquals("5 分鐘內先完成填空題、閱讀理解，不急著把整張卷子寫完。", summary.description)
        assertEquals("挑戰路線", summary.routeLabel)
        assertEquals("答對才會前進，答錯會停在原題看提示。", summary.progressRule)
    }

    @Test
    fun completionCopyCreatesARealFinishMoment() {
        val copy = DailyMissionContract.completionCopy(goal = 3, done = 3)

        assertEquals("今日任務完成", copy.title)
        assertTrue(copy.body.contains("3/3"))
        assertTrue(copy.body.contains("可以停在這裡"))
        assertTrue(copy.nextAction.contains("自主練習"))
    }

    private fun bankItem(
        id: String,
        level: String,
        type: String,
        prompt: String
    ): QuestionBankItem {
        return QuestionBankItem(
            id = id,
            level = level,
            unit = "test",
            skill = type,
            source = "unit-test",
            question = Question(
                prompt = prompt,
                options = listOf("A", "B"),
                answer = "A",
                explanation = "Because A is correct.",
                concept = "test concept",
                type = type
            )
        )
    }
}
