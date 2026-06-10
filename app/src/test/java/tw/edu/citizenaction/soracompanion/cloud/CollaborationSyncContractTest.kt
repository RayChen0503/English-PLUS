package tw.edu.citizenaction.soracompanion.cloud

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import tw.edu.citizenaction.soracompanion.auth.AuthContract
import tw.edu.citizenaction.soracompanion.model.CollaborationFlowContract
import tw.edu.citizenaction.soracompanion.model.CollaborationNote

class CollaborationSyncContractTest {
    @Test
    fun eventIdIsStableAcrossDevicesForSameHandoffContent() {
        val note = CollaborationNote(
            actor = "Emily",
            role = AuthContract.ROLE_VOLUNTEER,
            target = "Ray",
            note = "Practice He is twice.",
            status = CollaborationFlowContract.STATUS_STAFF_REPLY,
            createdAt = 1000L
        )
        val sameNoteLater = note.copy(createdAt = 5000L)

        assertEquals(
            CollaborationSyncContract.eventId(note),
            CollaborationSyncContract.eventId(sameNoteLater)
        )
    }

    @Test
    fun mergeRemoteNotesDeduplicatesAndKeepsLatestStatus() {
        val local = listOf(
            CollaborationNote("Emily", AuthContract.ROLE_VOLUNTEER, "Ray", "Practice He is twice.", CollaborationFlowContract.STATUS_STAFF_NOTE, 1000L)
        )
        val remote = listOf(
            CollaborationNote("Emily", AuthContract.ROLE_VOLUNTEER, "Ray", "Practice He is twice.", CollaborationFlowContract.STATUS_STAFF_REPLY, 3000L),
            CollaborationNote("Teacher Lin", AuthContract.ROLE_TEACHER, "Ray", "Check mood tomorrow.", CollaborationFlowContract.STATUS_STAFF_NOTE, 2000L)
        )

        val merged = CollaborationSyncContract.mergeNotes(local, remote)

        assertEquals(2, merged.size)
        assertEquals(CollaborationFlowContract.STATUS_STAFF_REPLY, merged.first { it.actor == "Emily" }.status)
        assertEquals(3000L, merged.first { it.actor == "Emily" }.createdAt)
    }

    @Test
    fun conflictReportExplainsWhatWasMergedForStaffReview() {
        val local = listOf(
            CollaborationNote("Emily", AuthContract.ROLE_VOLUNTEER, "Ray", "Practice He is twice.", CollaborationFlowContract.STATUS_STAFF_NOTE, 1000L)
        )
        val remote = listOf(
            CollaborationNote("Emily", AuthContract.ROLE_VOLUNTEER, "Ray", "Practice He is twice.", CollaborationFlowContract.STATUS_STAFF_REPLY, 3000L),
            CollaborationNote("Teacher Lin", AuthContract.ROLE_TEACHER, "Ray", "Check mood tomorrow.", CollaborationFlowContract.STATUS_STAFF_NOTE, 2000L)
        )

        val report = CollaborationSyncContract.resolveConflictReport(local, remote)

        assertEquals("latest-createdAt-wins", report.rule)
        assertEquals(2, report.mergedNotes.size)
        assertEquals(1, report.deduplicatedEvents)
        assertEquals(1, report.remoteOnlyEvents)
        assertTrue(report.userMessage.contains("已保留最新紀錄"))
        assertFalse(report.userMessage.any { it.code in 0xE000..0xF8FF })
    }

    @Test
    fun declaresBidirectionalSyncMetadata() {
        val scope = CloudDataContract.buildScope("CLASS-8A", "Teacher Lin", AuthContract.ROLE_TEACHER)
        val metadata = CollaborationSyncContract.buildCollaborationSyncMetadata(scope, pushFirst = true)

        assertEquals(5, metadata["collaborationSchemaVersion"])
        assertEquals("bidirectional", metadata["direction"])
        assertEquals(scope.collaborationCollectionPath, metadata["collectionPath"])
        assertEquals(true, metadata["pushBeforeFetch"])
        assertEquals("latest-createdAt-wins", metadata["conflictRule"])
    }

    @Test
    fun studentsCannotWriteOfficialCollaborationNotes() {
        val student = CloudDataContract.buildScope("CLASS-8A", "Ray", AuthContract.ROLE_STUDENT)
        val teacher = CloudDataContract.buildScope("CLASS-8A", "Teacher Lin", AuthContract.ROLE_TEACHER)

        assertFalse(CollaborationSyncContract.canCreateOfficialNote(student))
        assertTrue(CollaborationSyncContract.canCreateOfficialNote(teacher))
    }
}
