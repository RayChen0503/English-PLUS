package tw.edu.citizenaction.soracompanion.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class CollaborationFlowContractTest {
    @Test
    fun studentRequestsArePendingForStaff() {
        val request = CollaborationNote(
            actor = "小安",
            role = "學生",
            target = "小安",
            note = "我看不懂這題在問什麼。",
            status = CollaborationFlowContract.STATUS_STUDENT_REQUEST
        )

        assertTrue(CollaborationFlowContract.isStudentHelpRequest(request))
        assertEquals(listOf(request), CollaborationFlowContract.pendingRequests(listOf(request), "小安"))
    }

    @Test
    fun staffRepliesAreVisibleToStudentButInternalNotesAreNot() {
        val reply = CollaborationNote(
            actor = "林老師",
            role = "教師",
            target = "小安",
            note = "先看題目問什麼，再找關鍵句。",
            status = CollaborationFlowContract.STATUS_STAFF_REPLY
        )
        val internal = CollaborationNote(
            actor = "林老師",
            role = "教師",
            target = "小安",
            note = "下週追蹤閱讀理解。",
            status = CollaborationFlowContract.STATUS_STAFF_NOTE
        )

        assertTrue(CollaborationFlowContract.visibleToStudent(reply, "小安"))
        assertFalse(CollaborationFlowContract.visibleToStudent(internal, "小安"))
    }

    @Test
    fun defaultReplyNamesTheStudentAndConcept() {
        val reply = CollaborationFlowContract.defaultStaffReply("小安", "閱讀理解")

        assertTrue(reply.contains("小安"))
        assertTrue(reply.contains("閱讀理解"))
        assertTrue(reply.contains("先不要急著加新題"))
    }

    @Test
    fun answeredRequestsAreRemovedFromStaffPendingList() {
        val request = CollaborationNote(
            actor = "小安",
            role = "學生",
            target = "小安",
            note = "我想請老師協助。",
            status = CollaborationFlowContract.STATUS_STUDENT_REQUEST,
            createdAt = 10
        )
        val reply = CollaborationNote(
            actor = "林老師",
            role = "教師",
            target = "小安",
            note = "先做同題型兩題。",
            status = CollaborationFlowContract.STATUS_STAFF_REPLY,
            createdAt = 20
        )

        assertEquals(emptyList<CollaborationNote>(), CollaborationFlowContract.unansweredRequests(listOf(reply, request), "小安"))
    }
}
