package tw.edu.citizenaction.soracompanion.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import tw.edu.citizenaction.soracompanion.auth.AuthContract

class VolunteerHandoffContractTest {
    @Test
    fun volunteerWorkspaceOnlyIncludesSupportAndHandoffScreens() {
        val workspace = VolunteerHandoffContract.workspaceFor(Role.Volunteer)

        assertEquals(Role.Volunteer, workspace.role)
        assertTrue(workspace.allowedScreens.contains(Screen.Handoff))
        assertTrue(workspace.allowedScreens.contains(Screen.ActionQueue))
        assertTrue(workspace.allowedScreens.contains(Screen.MentorScript))
        assertTrue(workspace.allowedScreens.contains(Screen.StudentDetail))
        assertFalse(workspace.allowedScreens.contains(Screen.QuestionBank))
        assertFalse(workspace.allowedScreens.contains(Screen.Report))
        assertFalse(workspace.allowedScreens.contains(Screen.StudentManager))
    }

    @Test
    fun volunteerActionAlwaysHasNextStepScriptAndCompletionState() {
        val request = CollaborationNote(
            actor = "Ray Chen",
            role = AuthContract.ROLE_STUDENT,
            target = "Ray Chen",
            note = "I got stuck on a reading question.",
            status = CollaborationFlowContract.STATUS_STUDENT_REQUEST,
            createdAt = 10
        )

        val action = VolunteerHandoffContract.actionForRequest(request, completed = false)
        val completed = VolunteerHandoffContract.markCompleted(action, volunteerName = "Emily")

        assertEquals("Ray Chen", action.studentName)
        assertTrue(action.nextStep.contains("陪"))
        assertTrue(action.script.contains("先"))
        assertFalse(action.isComplete)
        assertTrue(completed.isComplete)
        assertTrue(completed.completionNote.contains("Emily"))
    }

    @Test
    fun internalHandoffNotesAreVisibleToTeacherButNotStudentFacing() {
        val note = VolunteerHandoffContract.internalHandoffNote(
            volunteerName = "Emily",
            studentName = "Ray Chen",
            summary = "Student needs help finding the key sentence.",
            createdAt = 30
        )

        assertTrue(VolunteerHandoffContract.visibleToTeacher(note))
        assertFalse(VolunteerHandoffContract.visibleToStudent(note, "Ray Chen"))
        assertFalse(CollaborationFlowContract.visibleToStudent(note, "Ray Chen"))
    }
}
