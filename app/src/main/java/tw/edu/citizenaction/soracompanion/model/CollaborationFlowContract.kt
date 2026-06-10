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

data class LocalSupportLoopSnapshot(
    val studentName: String,
    val waitingRequests: Int,
    val unreadReplies: Int,
    val latestStatus: String,
    val studentNextAction: String,
    val teacherNextAction: String,
    val volunteerNextAction: String,
    val staffCanReply: Boolean,
    val closed: Boolean
)

data class StudentHelpRequestDecision(
    val canCreate: Boolean,
    val message: String,
    val existingRequest: CollaborationNote?
)

object CollaborationFlowContract {
    const val STATUS_STUDENT_REQUEST = "學生求助"
    const val STATUS_STAFF_REPLY = "老師/志工已回覆"
    const val STATUS_STAFF_REPLY_READ = "學生已讀回覆"
    const val STATUS_STAFF_NOTE = "內部接力紀錄"

    fun isStudentHelpRequest(note: CollaborationNote): Boolean {
        return note.status == STATUS_STUDENT_REQUEST
    }

    fun isStaffReply(note: CollaborationNote): Boolean {
        return note.status == STATUS_STAFF_REPLY ||
            note.status == STATUS_STAFF_REPLY_READ ||
            note.status == "已回覆"
    }

    fun pendingRequests(notes: List<CollaborationNote>, studentName: String? = null): List<CollaborationNote> {
        return notes.filter { note ->
            isStudentHelpRequest(note) && (studentName == null || note.target == studentName)
        }.sortedBy { it.createdAt }
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

    fun studentVisibleTimeline(notes: List<CollaborationNote>, studentName: String): List<CollaborationNote> {
        return notes
            .filter { visibleToStudent(it, studentName) }
            .sortedBy { it.createdAt }
    }

    fun staffVisibleQueue(notes: List<CollaborationNote>, staffRole: String): List<CollaborationNote> {
        val role = AuthContract.normalizeRole(staffRole)
        if (!AuthContract.isStaffRole(role)) return emptyList()
        return unansweredRequests(notes)
    }

    fun buildCustomStaffReply(
        request: CollaborationNote,
        staffName: String,
        staffRole: String,
        message: String,
        createdAt: Long
    ): CollaborationNote {
        return CollaborationNote(
            actor = staffName.trim().ifBlank { "English+ 接力者" },
            role = AuthContract.normalizeRole(staffRole),
            target = request.target,
            note = message.trim().ifBlank { defaultStaffReply(request.target, "今天的題目") },
            status = STATUS_STAFF_REPLY,
            createdAt = createdAt
        )
    }

    fun markReplyRead(reply: CollaborationNote): CollaborationNote {
        return if (isStaffReply(reply)) {
            reply.copy(status = STATUS_STAFF_REPLY_READ, note = reply.note.removePrefix("[read] ").trim())
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
        val reply = latestReplyFor(request, notes)
        return when {
            reply == null -> "等待回覆"
            reply.status == STATUS_STAFF_REPLY_READ || reply.note.startsWith("[read] ") -> "已讀回覆"
            else -> "已有回覆"
        }
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

    fun studentHelpRequestDecision(
        notes: List<CollaborationNote>,
        studentName: String,
        reason: String
    ): StudentHelpRequestDecision {
        val normalizedReason = normalizeReason(reason)
        val sameOpenRequest = unansweredRequests(notes, studentName).firstOrNull { request ->
            normalizeReason(extractReason(request.note)) == normalizedReason
        }
        return if (sameOpenRequest == null) {
            StudentHelpRequestDecision(
                canCreate = true,
                message = "可以送出這次求助，English+ 會整理給老師或志工。",
                existingRequest = null
            )
        } else {
            StudentHelpRequestDecision(
                canCreate = false,
                message = "這個求助仍在等待回覆，先看目前進度或做一題低壓練習。",
                existingRequest = sameOpenRequest
            )
        }
    }

    fun localSupportLoopSnapshot(notes: List<CollaborationNote>, studentName: String): LocalSupportLoopSnapshot {
        val waiting = unansweredRequests(notes, studentName)
        val unread = unreadRepliesForStudent(notes, studentName)
        val threads = studentThreads(notes, studentName)
        val latestThread = threads.firstOrNull()
        val latestStatus = when {
            unread.isNotEmpty() -> "已有回覆"
            waiting.isNotEmpty() -> "等待回覆"
            latestThread?.latestReply != null -> "已讀回覆"
            else -> "沒有求助"
        }
        val studentNextAction = when (latestStatus) {
            "等待回覆" -> "先做一題低壓練習，不需要重複送同一個求助。"
            "已有回覆" -> "閱讀回覆，確認下一步，再回到一題小練習。"
            "已讀回覆" -> "照回饋練一題，完成後再決定要不要繼續挑戰。"
            else -> "需要幫忙時可以先說一句卡在哪裡。"
        }
        return LocalSupportLoopSnapshot(
            studentName = studentName,
            waitingRequests = waiting.size,
            unreadReplies = unread.size,
            latestStatus = latestStatus,
            studentNextAction = studentNextAction,
            teacherNextAction = if (waiting.isNotEmpty()) "回覆第一位等待中的學生，給一個明確下一步。" else "檢查已回覆學生是否完成下一題。",
            volunteerNextAction = if (waiting.isNotEmpty()) "依照陪練腳本陪練，不新增老師行政任務。" else "整理接力紀錄，等待下一位需要陪練的學生。",
            staffCanReply = waiting.isNotEmpty(),
            closed = waiting.isEmpty() && unread.isEmpty() && latestThread?.latestReply != null
        )
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
            helpPending = if (AuthContract.isStaffRole(role)) unansweredRequests(notes).size else 0,
            repliedCount = notes.count { isStaffReply(it) && AuthContract.normalizeRole(it.role) == role }
        )
    }

    fun defaultStaffReply(studentName: String, concept: String): String {
        return "$studentName，我先陪你把「$concept」拆小一點。下一步先看題目裡最明顯的線索，完成一題就好；如果還卡住，再把你卡住的句子圈起來，我們一起看。"
    }

    private fun extractReason(note: String): String {
        return note.lineSequence()
            .firstOrNull { it.startsWith("求助原因：") }
            ?.substringAfter("求助原因：")
            ?.trim()
            .orEmpty()
    }

    private fun normalizeReason(reason: String): String {
        return reason.trim().lowercase().replace(Regex("\\s+"), "")
    }
}
