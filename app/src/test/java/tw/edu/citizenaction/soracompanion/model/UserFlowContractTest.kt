package tw.edu.citizenaction.soracompanion.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import tw.edu.citizenaction.soracompanion.auth.AuthContract

class UserFlowContractTest {
    @Test
    fun studentTeacherAndVolunteerNavigationStaySeparated() {
        val studentLabels = UserFlowContract.bottomNavLabels(Role.Student)
        val teacherLabels = UserFlowContract.bottomNavLabels(Role.Teacher)
        val volunteerLabels = UserFlowContract.bottomNavLabels(Role.Volunteer)

        assertEquals(listOf("首頁", "練習", "支持", "地圖", "我的"), studentLabels)
        assertEquals(listOf("今日", "學生", "接力", "報告", "題庫"), teacherLabels)
        assertEquals(listOf("今日", "接力", "學生", "同步", "腳本"), volunteerLabels)
        assertFalse(teacherLabels.contains("練習"))
        assertFalse(volunteerLabels.contains("報告"))
        assertFalse(volunteerLabels.contains("題庫"))
    }

    @Test
    fun authRolesMapToDistinctAppRolesAndLabels() {
        assertEquals(Role.Student, UserFlowContract.roleForAuthLabel(AuthContract.ROLE_STUDENT))
        assertEquals(Role.Teacher, UserFlowContract.roleForAuthLabel(AuthContract.ROLE_TEACHER))
        assertEquals(Role.Volunteer, UserFlowContract.roleForAuthLabel(AuthContract.ROLE_VOLUNTEER))
        assertEquals(Role.Volunteer, UserFlowContract.roleForAuthLabel("mentor"))

        assertEquals("學生端", UserFlowContract.roleTitle(Role.Student))
        assertEquals("老師端", UserFlowContract.roleTitle(Role.Teacher))
        assertEquals("志工端", UserFlowContract.roleTitle(Role.Volunteer))
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
        assertEquals(SupportTarget.Recovery, UserFlowContract.supportTarget("復原任務"))
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

    @Test
    fun teacherAndVolunteerToolsDoNotCrossRoleBoundaries() {
        assertTrue(UserFlowContract.canUseTeacherTool(Role.Teacher, Screen.Report))
        assertTrue(UserFlowContract.canUseTeacherTool(Role.Teacher, Screen.QuestionBank))
        assertFalse(UserFlowContract.canUseTeacherTool(Role.Volunteer, Screen.Report))
        assertFalse(UserFlowContract.canUseTeacherTool(Role.Volunteer, Screen.QuestionBank))
        assertFalse(UserFlowContract.canUseTeacherTool(Role.Student, Screen.Report))

        assertTrue(UserFlowContract.canUseVolunteerTool(Role.Volunteer, Screen.MentorScript))
        assertTrue(UserFlowContract.canUseVolunteerTool(Role.Mentor, Screen.MentorScript))
        assertFalse(UserFlowContract.canUseVolunteerTool(Role.Teacher, Screen.MentorScript))
        assertFalse(UserFlowContract.canUseVolunteerTool(Role.Student, Screen.MentorScript))
    }

    @Test
    fun staffCopyChangesByTeacherOrVolunteerRole() {
        assertEquals("先看班級風險與需要接住的學生。", UserFlowContract.rosterSubtitle(Role.Teacher))
        assertEquals("先看分派給你的接力學生與下一步。", UserFlowContract.rosterSubtitle(Role.Volunteer))
        assertEquals("老師回覆", UserFlowContract.studentDetailActionTitle(Role.Teacher))
        assertEquals("志工陪練", UserFlowContract.studentDetailActionTitle(Role.Volunteer))
    }
}
