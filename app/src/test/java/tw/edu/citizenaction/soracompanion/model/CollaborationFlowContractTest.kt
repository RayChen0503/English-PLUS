package tw.edu.citizenaction.soracompanion.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import tw.edu.citizenaction.soracompanion.auth.AuthContract

class CollaborationFlowContractTest {
    @Test
    fun studentRequestCreatesClearLocalLoopForTeacherAndVolunteer() {
        val request = CollaborationNote(
            actor = "小安",
            role = AuthContract.ROLE_STUDENT,
            target = "小安",
            note = "求助原因：閱讀卡住\n學生說：我不知道這題要先看哪裡。",
            status = CollaborationFlowContract.STATUS_STUDENT_REQUEST,
            createdAt = 10
        )

        val snapshot = CollaborationFlowContract.localSupportLoopSnapshot(listOf(request), "小安")
        val teacherQueue = CollaborationFlowContract.staffVisibleQueue(listOf(request), AuthContract.ROLE_TEACHER)
        val volunteerQueue = CollaborationFlowContract.staffVisibleQueue(listOf(request), AuthContract.ROLE_VOLUNTEER)

        assertTrue(CollaborationFlowContract.isStudentHelpRequest(request))
        assertEquals(1, snapshot.waitingRequests)
        assertEquals(0, snapshot.unreadReplies)
        assertEquals("等待回覆", snapshot.latestStatus)
        assertTrue(snapshot.studentNextAction.contains("先做一題"))
        assertTrue(snapshot.teacherNextAction.contains("回覆"))
        assertTrue(snapshot.volunteerNextAction.contains("陪練"))
        assertEquals(listOf(request), teacherQueue)
        assertEquals(listOf(request), volunteerQueue)
    }

    @Test
    fun teacherReplyClosesPendingRequestAndBecomesStudentVisible() {
        val request = helpRequest()
        val reply = CollaborationFlowContract.buildCustomStaffReply(
            request = request,
            staffName = "林老師",
            staffRole = AuthContract.ROLE_TEACHER,
            message = "先圈出時間字，再看主詞和動詞。",
            createdAt = 20
        )

        val notes = listOf(request, reply)
        val snapshot = CollaborationFlowContract.localSupportLoopSnapshot(notes, "小安")
        val timeline = CollaborationFlowContract.studentVisibleTimeline(notes, "小安")

        assertTrue(CollaborationFlowContract.isStaffReply(reply))
        assertEquals(emptyList<CollaborationNote>(), CollaborationFlowContract.unansweredRequests(notes, "小安"))
        assertEquals(0, snapshot.waitingRequests)
        assertEquals(1, snapshot.unreadReplies)
        assertEquals("已有回覆", snapshot.latestStatus)
        assertTrue(snapshot.studentNextAction.contains("閱讀回覆"))
        assertEquals(listOf(request, reply), timeline)
    }

    @Test
    fun readReplyKeepsThreadVisibleButRemovesUnreadBadge() {
        val request = helpRequest()
        val reply = CollaborationFlowContract.buildCustomStaffReply(
            request = request,
            staffName = "Emily",
            staffRole = AuthContract.ROLE_VOLUNTEER,
            message = "我們先一起讀第一句。",
            createdAt = 20
        )
        val readReply = CollaborationFlowContract.markReplyRead(reply)
        val notes = listOf(request, readReply)
        val snapshot = CollaborationFlowContract.localSupportLoopSnapshot(notes, "小安")

        assertTrue(CollaborationFlowContract.isStaffReply(readReply))
        assertEquals(CollaborationFlowContract.STATUS_STAFF_REPLY_READ, readReply.status)
        assertEquals(0, snapshot.waitingRequests)
        assertEquals(0, snapshot.unreadReplies)
        assertEquals("已讀回覆", snapshot.latestStatus)
        assertTrue(snapshot.studentNextAction.contains("照回饋練一題"))
        assertEquals(readReply, CollaborationFlowContract.studentThreads(notes, "小安").single().latestReply)
    }

    @Test
    fun internalNotesStayStaffOnly() {
        val request = helpRequest()
        val internal = CollaborationNote(
            actor = "林老師",
            role = AuthContract.ROLE_TEACHER,
            target = "小安",
            note = "今天先不要加難度，等學生完成一題再追蹤。",
            status = CollaborationFlowContract.STATUS_STAFF_NOTE,
            createdAt = 30
        )

        assertFalse(CollaborationFlowContract.visibleToStudent(internal, "小安"))
        assertEquals(listOf(request), CollaborationFlowContract.studentVisibleTimeline(listOf(request, internal), "小安"))
    }

    @Test
    fun staffQueueSummaryKeepsHelpRequestsSeparateFromNormalActions() {
        val request = helpRequest()
        val reply = CollaborationFlowContract.buildCustomStaffReply(
            request = request,
            staffName = "林老師",
            staffRole = AuthContract.ROLE_TEACHER,
            message = "先圈出時間字。",
            createdAt = 20
        )

        val summary = CollaborationFlowContract.staffQueueSummary(
            notes = listOf(reply, request),
            normalActionTotal = 4,
            normalActionDone = 1
        )

        assertEquals(0, summary.helpPending)
        assertEquals(3, summary.normalPending)
        assertEquals(3, summary.totalPending)
        assertEquals(2, summary.completed)
    }

    @Test
    fun teacherAndVolunteerQueuesKeepDifferentMeanings() {
        val request = helpRequest()

        val teacherQueue = CollaborationFlowContract.staffRoleQueue(listOf(request), AuthContract.ROLE_TEACHER)
        val volunteerQueue = CollaborationFlowContract.staffRoleQueue(listOf(request), AuthContract.ROLE_VOLUNTEER)

        assertEquals("teacher_follow_up", teacherQueue.meaning)
        assertEquals("volunteer_handoff", volunteerQueue.meaning)
        assertEquals(1, teacherQueue.helpPending)
        assertEquals(1, volunteerQueue.helpPending)
        assertEquals(AuthContract.ROLE_TEACHER, teacherQueue.roleLabel)
        assertEquals(AuthContract.ROLE_VOLUNTEER, volunteerQueue.roleLabel)
    }

    @Test
    fun defaultReplyNamesTheStudentAndConceptWithoutInternalCopy() {
        val reply = CollaborationFlowContract.defaultStaffReply("小安", "閱讀找主旨")

        assertTrue(reply.contains("小安"))
        assertTrue(reply.contains("閱讀找主旨"))
        assertTrue(reply.contains("下一步"))
        assertFalse(reply.contains("debug", ignoreCase = true))
        assertFalse(reply.contains("API"))
    }

    private fun helpRequest(): CollaborationNote {
        return CollaborationNote(
            actor = "小安",
            role = AuthContract.ROLE_STUDENT,
            target = "小安",
            note = "求助原因：閱讀卡住\n學生說：我看不懂這題。",
            status = CollaborationFlowContract.STATUS_STUDENT_REQUEST,
            createdAt = 10
        )
    }
}
