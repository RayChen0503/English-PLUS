package tw.edu.citizenaction.soracompanion.model

import tw.edu.citizenaction.soracompanion.auth.AuthContract

data class StudentHelpThread(
    val request: CollaborationNote,
    val latestReply: CollaborationNote?
)

data class StaffQueueSummary(
    val helpPending: Int,
    val normalPending: Int,
    val totalPending: Int,
    val completed: Int
)

data class StaffRoleQueue(
    val roleLabel: String,
    val meaning: String,
    val helpPending: Int,
    val repliedCount: Int
)

object CollaborationFlowContract {
    const val STATUS_STAFF_REPLY_READ = "?單撌脩"
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

    fun unansweredRequests(notes: List<CollaborationNote>, studentName: String? = null): List<CollaborationNote> {
        val replies = notes.filter { note ->
            isStaffReply(note) && (studentName == null || note.target == studentName)
        }
        return pendingRequests(notes, studentName).filter { request ->
            replies.none { reply -> reply.target == request.target && reply.createdAt > request.createdAt }
        }
    }

    fun visibleToStudent(note: CollaborationNote, studentName: String): Boolean {
        return note.target == studentName && (isStudentHelpRequest(note) || isStaffReply(note))
    }

    fun buildCustomStaffReply(
        request: CollaborationNote,
        staffName: String,
        staffRole: String,
        message: String,
        createdAt: Long
    ): CollaborationNote {
        return CollaborationNote(
            actor = staffName.trim().ifBlank { "English+ staff" },
            role = AuthContract.normalizeRole(staffRole),
            target = request.target,
            note = message.trim().ifBlank { defaultStaffReply(request.target, "English+") },
            status = STATUS_STAFF_REPLY,
            createdAt = createdAt
        )
    }

    fun markReplyRead(reply: CollaborationNote): CollaborationNote {
        return if (isStaffReply(reply) && !reply.note.startsWith("[read] ")) {
            reply.copy(status = STATUS_STAFF_REPLY, note = "[read] ${reply.note}")
        } else {
            reply
        }
    }

    fun unreadRepliesForStudent(notes: List<CollaborationNote>, studentName: String): List<CollaborationNote> {
        return notes
            .filter { note ->
                note.target == studentName &&
                    isStaffReply(note) &&
                    note.status != STATUS_STAFF_REPLY_READ &&
                    !note.note.startsWith("[read] ")
            }
            .sortedByDescending { it.createdAt }
    }

    fun latestReplyFor(request: CollaborationNote, notes: List<CollaborationNote>): CollaborationNote? {
        return notes
            .filter { note ->
                note.target == request.target &&
                    isStaffReply(note) &&
                    note.createdAt > request.createdAt
            }
            .maxByOrNull { it.createdAt }
    }

    fun requestStatusLabel(request: CollaborationNote, notes: List<CollaborationNote>): String {
        return if (latestReplyFor(request, notes) == null) "等待中" else "已回覆"
    }

    fun waitingRequestCount(notes: List<CollaborationNote>, studentName: String): Int {
        return unansweredRequests(notes, studentName).size
    }

    fun studentThreads(notes: List<CollaborationNote>, studentName: String, limit: Int = 8): List<StudentHelpThread> {
        return pendingRequests(notes, studentName)
            .map { request -> StudentHelpThread(request, latestReplyFor(request, notes)) }
            .sortedByDescending { it.request.createdAt }
            .take(limit)
    }

    fun staffQueueSummary(
        notes: List<CollaborationNote>,
        normalActionTotal: Int,
        normalActionDone: Int
    ): StaffQueueSummary {
        val helpPending = unansweredRequests(notes).size
        val safeDone = normalActionDone.coerceIn(0, normalActionTotal)
        val normalPending = (normalActionTotal - safeDone).coerceAtLeast(0)
        val staffReplies = notes.count { isStaffReply(it) }
        return StaffQueueSummary(
            helpPending = helpPending,
            normalPending = normalPending,
            totalPending = helpPending + normalPending,
            completed = safeDone + staffReplies
        )
    }

    fun staffRoleQueue(notes: List<CollaborationNote>, staffRole: String): StaffRoleQueue {
        val role = AuthContract.normalizeRole(staffRole)
        val meaning = when (role) {
            AuthContract.ROLE_TEACHER -> "teacher_follow_up"
            AuthContract.ROLE_VOLUNTEER -> "volunteer_handoff"
            else -> "student_visible_support"
        }
        return StaffRoleQueue(
            roleLabel = role,
            meaning = meaning,
            helpPending = unansweredRequests(notes).size,
            repliedCount = notes.count { isStaffReply(it) && AuthContract.normalizeRole(it.role) == role }
        )
    }

    fun defaultStaffReply(studentName: String, concept: String): String {
        return "$studentName，我有看到你的求助。先不要急著加新題，我們先把「$concept」用同一種題型陪你練兩題；如果還卡住，我會再幫你拆更小。"
    }
}
