package tw.edu.citizenaction.soracompanion.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UserVisibleCopyContractTest {
    @Test
    fun auditFlagsInternalImplementationTerms() {
        val result = UserVisibleCopyContract.audit(
            listOf("目前使用本機 SQLite 備援，等待正式 API Key 與端點。")
        )

        assertFalse(result.isClean)
        assertTrue(result.offendingTerms.contains("本機"))
        assertTrue(result.offendingTerms.contains("SQLite"))
        assertTrue(result.offendingTerms.contains("API"))
        assertTrue(result.offendingTerms.contains("Key"))
    }

    @Test
    fun coreStudentFacingCopyStaysOperationalAndNonTechnical() {
        val daily = DailyMissionContract.summary(
            minutes = 5,
            goal = 2,
            preferredTypes = setOf("填空題", "閱讀理解"),
            challengeWanted = true
        )
        val completion = DailyMissionContract.completionCopy(goal = 2, done = 2)
        val progress = DailyMissionContract.progressCopy(
            inDailyMission = true,
            goal = 2,
            done = 1
        )
        val checkInCopy = listOf(
            "先看今天適合怎麼開始",
            "English+ 會依你的狀態安排任務長度，讓開始比硬撐更容易。",
            "今天會優先放入較有挑戰的題型與程度。"
        )

        val audit = UserVisibleCopyContract.audit(
            listOf(
                daily.title,
                daily.description,
                daily.routeLabel,
                daily.progressRule,
                completion.title,
                completion.body,
                completion.nextAction,
                progress?.title.orEmpty(),
                progress?.body.orEmpty()
            ) + checkInCopy
        )

        assertEquals(emptyList<String>(), audit.offendingTerms)
        assertTrue(audit.isClean)
    }
}
