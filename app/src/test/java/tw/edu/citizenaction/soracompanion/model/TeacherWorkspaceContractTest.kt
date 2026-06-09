package tw.edu.citizenaction.soracompanion.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import tw.edu.citizenaction.soracompanion.auth.AuthContract

class TeacherWorkspaceContractTest {
    @Test
    fun teacherHomePrioritizesClassRiskAndNextAction() {
        val rows = listOf(
            StudentRow("Ray", "高", "Reading stuck", "Needs reply"),
            StudentRow("Ann", "低", "Practicing", "Stable")
        )
        val requests = listOf(
            CollaborationNote(
                actor = "Ray",
                role = AuthContract.ROLE_STUDENT,
                target = "Ray",
                note = "I need help.",
                status = CollaborationFlowContract.STATUS_STUDENT_REQUEST,
                createdAt = 10
            )
        )

        val home = TeacherWorkspaceContract.homeSummary(
            roster = rows,
            notes = requests,
            pendingSyncCount = 2
        )

        assertEquals("Ray", home.priorityStudent)
        assertEquals(1, home.highRiskCount)
        assertEquals(1, home.helpPending)
        assertTrue(home.nextAction.contains("回覆"))
        assertEquals(listOf(Screen.StudentDetail, Screen.ActionQueue, Screen.Report, Screen.QuestionBank), home.primaryScreens)
    }

    @Test
    fun studentDetailIncludesProgressHelpRecentAnswersAndReplyAction() {
        val row = StudentRow("Ray", "高", "Reading stuck", "Needs reply")
        val notes = listOf(
            CollaborationNote(
                actor = "Ray",
                role = AuthContract.ROLE_STUDENT,
                target = "Ray",
                note = "Reading question is hard.",
                status = CollaborationFlowContract.STATUS_STUDENT_REQUEST,
                createdAt = 10
            )
        )
        val detail = TeacherWorkspaceContract.studentDetail(
            row = row,
            notes = notes,
            recentAnswerTitles = listOf("B1 reading item", "A2 blank item"),
            missionProgress = "2/3"
        )

        assertEquals("Ray", detail.studentName)
        assertEquals("2/3", detail.missionProgress)
        assertEquals(1, detail.helpRequestCount)
        assertEquals(listOf("B1 reading item", "A2 blank item"), detail.recentAnswers)
        assertEquals("write_teacher_reply", detail.primaryAction)
    }

    @Test
    fun teacherResourcesExposeReportsAndQuestionBankWithoutVolunteerScripts() {
        val resources = TeacherWorkspaceContract.resourcesFor(Role.Teacher)

        assertTrue(resources.contains(Screen.Report))
        assertTrue(resources.contains(Screen.QuestionBank))
        assertTrue(resources.contains(Screen.StudentManager))
        assertFalse(resources.contains(Screen.MentorScript))
        assertFalse(resources.contains(Screen.Mentor))
    }
}
