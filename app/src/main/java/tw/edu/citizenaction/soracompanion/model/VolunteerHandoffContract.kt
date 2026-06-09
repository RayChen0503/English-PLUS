package tw.edu.citizenaction.soracompanion.model

import tw.edu.citizenaction.soracompanion.auth.AuthContract

data class VolunteerWorkspace(
    val role: Role,
    val allowedScreens: Set<Screen>,
    val primaryAction: String
)

data class VolunteerHandoffAction(
    val studentName: String,
    val nextStep: String,
    val script: String,
    val isComplete: Boolean,
    val completionNote: String
)

object VolunteerHandoffContract {
    const val STATUS_INTERNAL_HANDOFF_NOTE = "internal_handoff_note"

    fun workspaceFor(role: Role): VolunteerWorkspace {
        val normalized = UserFlowContract.normalizedRole(role)
        val allowed = if (normalized == Role.Volunteer) {
            setOf(Screen.Handoff, Screen.ActionQueue, Screen.MentorScript, Screen.StudentDetail, Screen.SyncCenter)
        } else {
            emptySet()
        }
        return VolunteerWorkspace(
            role = normalized,
            allowedScreens = allowed,
            primaryAction = "先看學生求助，再照腳本陪練。"
        )
    }

    fun actionForRequest(
        request: CollaborationNote,
        completed: Boolean
    ): VolunteerHandoffAction {
        return VolunteerHandoffAction(
            studentName = request.target,
            nextStep = "先陪 ${request.target} 看懂卡住的那一句，再留下一則接力摘要。",
            script = "先肯定學生願意求助，再問：你覺得答案線索在哪一句？最後只陪一題，不追加作業。",
            isComplete = completed,
            completionNote = if (completed) "已完成陪練並留下接力紀錄。" else "尚未完成，等待志工陪練。"
        )
    }

    fun markCompleted(
        action: VolunteerHandoffAction,
        volunteerName: String
    ): VolunteerHandoffAction {
        return action.copy(
            isComplete = true,
            completionNote = "${volunteerName.trim().ifBlank { "志工" }} 已完成陪練並留下接力紀錄。"
        )
    }

    fun internalHandoffNote(
        volunteerName: String,
        studentName: String,
        summary: String,
        createdAt: Long
    ): CollaborationNote {
        return CollaborationNote(
            actor = volunteerName.trim().ifBlank { "志工" },
            role = AuthContract.ROLE_VOLUNTEER,
            target = studentName,
            note = summary.trim(),
            status = STATUS_INTERNAL_HANDOFF_NOTE,
            createdAt = createdAt
        )
    }

    fun visibleToTeacher(note: CollaborationNote): Boolean {
        return note.status == STATUS_INTERNAL_HANDOFF_NOTE ||
            CollaborationFlowContract.isStudentHelpRequest(note) ||
            CollaborationFlowContract.isStaffReply(note)
    }

    fun visibleToStudent(note: CollaborationNote, studentName: String): Boolean {
        return note.status != STATUS_INTERNAL_HANDOFF_NOTE &&
            CollaborationFlowContract.visibleToStudent(note, studentName)
    }
}
