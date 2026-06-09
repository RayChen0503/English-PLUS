package tw.edu.citizenaction.soracompanion.model

object CollaborationFlowContract {
    const val STATUS_STUDENT_REQUEST = "待老師/志工回覆"
    const val STATUS_STAFF_REPLY = "已回覆給學生"
    const val STATUS_STAFF_NOTE = "接力紀錄"

    fun isStudentHelpRequest(note: CollaborationNote): Boolean {
        return note.status == STATUS_STUDENT_REQUEST
    }

    fun isStaffReply(note: CollaborationNote): Boolean {
        return note.status == STATUS_STAFF_REPLY || note.status == "已回覆" || note.status == "腳本已用"
    }

    fun pendingRequests(notes: List<CollaborationNote>, studentName: String? = null): List<CollaborationNote> {
        return notes.filter { note ->
            isStudentHelpRequest(note) && (studentName == null || note.target == studentName)
        }
    }

    fun unansweredRequests(notes: List<CollaborationNote>, studentName: String): List<CollaborationNote> {
        val replies = notes.filter { note ->
            note.target == studentName && isStaffReply(note)
        }
        return pendingRequests(notes, studentName).filter { request ->
            replies.none { reply -> reply.createdAt > request.createdAt }
        }
    }

    fun visibleToStudent(note: CollaborationNote, studentName: String): Boolean {
        return note.target == studentName && (isStudentHelpRequest(note) || isStaffReply(note))
    }

    fun defaultStaffReply(studentName: String, concept: String): String {
        return "$studentName，我有看到你的求助。先不要急著加新題，我們先把「$concept」用同一種題型陪你練兩題；如果還卡住，我會再幫你拆更小。"
    }
}
