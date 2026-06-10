package tw.edu.citizenaction.soracompanion.cloud

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import tw.edu.citizenaction.soracompanion.auth.AuthContract
import tw.edu.citizenaction.soracompanion.model.CollaborationFlowContract
import tw.edu.citizenaction.soracompanion.model.CollaborationNote
import tw.edu.citizenaction.soracompanion.model.OfflineSyncItem
import tw.edu.citizenaction.soracompanion.storage.LearningEvent

class CloudDataContractTest {
    @Test
    fun buildsStableClassAndUserPaths() {
        val scope = CloudDataContract.buildScope(
            classCode = " class-8a ",
            accountName = " Ray Chen ",
            roleLabel = AuthContract.ROLE_STUDENT
        )

        assertEquals("CLASS-8A", scope.classId)
        assertEquals("ray-chen", scope.userId)
        assertEquals("classes/CLASS-8A/students/ray-chen", scope.studentDocumentPath)
        assertEquals("classes/CLASS-8A/collaborationNotes", scope.collaborationCollectionPath)
    }

    @Test
    fun studentCanOnlyReadOwnLearningData() {
        val student = CloudDataContract.buildScope("CLASS-8A", "Ray Chen", AuthContract.ROLE_STUDENT)

        assertTrue(CloudDataContract.canReadStudentData(student, "ray-chen"))
        assertFalse(CloudDataContract.canReadStudentData(student, "other-student"))
        assertFalse(CloudDataContract.canWriteQuestionBank(student))
    }

    @Test
    fun teacherAndVolunteerCanReadClassScopedHandoffData() {
        val teacher = CloudDataContract.buildScope("CLASS-8A", "Teacher Lin", AuthContract.ROLE_TEACHER)
        val volunteer = CloudDataContract.buildScope("CLASS-8A", "Emily Mentor", AuthContract.ROLE_VOLUNTEER)

        assertTrue(CloudDataContract.canReadStudentData(teacher, "ray-chen"))
        assertTrue(CloudDataContract.canReadStudentData(volunteer, "ray-chen"))
        assertTrue(CloudDataContract.canWriteCollaboration(volunteer))
        assertTrue(CloudDataContract.canWriteQuestionBank(teacher))
        assertFalse(CloudDataContract.canWriteQuestionBank(volunteer))
    }

    @Test
    fun roleScopedCloudWritesMatchProductResponsibilities() {
        val student = CloudDataContract.buildScope("CLASS-8A", "Ray Chen", AuthContract.ROLE_STUDENT)
        val teacher = CloudDataContract.buildScope("CLASS-8A", "Teacher Lin", AuthContract.ROLE_TEACHER)
        val volunteer = CloudDataContract.buildScope("CLASS-8A", "Emily Mentor", AuthContract.ROLE_VOLUNTEER)

        assertTrue(CloudDataContract.canWriteRecord(student, "student_help_request", "ray-chen"))
        assertTrue(CloudDataContract.canWriteRecord(student, "learning_event", "ray-chen"))
        assertTrue(CloudDataContract.canWriteRecord(student, "mission_completion", "ray-chen"))
        assertFalse(CloudDataContract.canWriteRecord(student, "staff_reply", "ray-chen"))
        assertFalse(CloudDataContract.canWriteRecord(student, "student_help_request", "other-student"))

        assertTrue(CloudDataContract.canWriteRecord(teacher, "staff_reply", "ray-chen"))
        assertTrue(CloudDataContract.canWriteRecord(teacher, "staff_note", "ray-chen"))
        assertTrue(CloudDataContract.canWriteRecord(teacher, "question_bank", "ray-chen"))
        assertTrue(CloudDataContract.canWriteRecord(volunteer, "staff_reply", "ray-chen"))
        assertTrue(CloudDataContract.canWriteRecord(volunteer, "staff_note", "ray-chen"))
        assertFalse(CloudDataContract.canWriteRecord(volunteer, "question_bank", "ray-chen"))
    }

    @Test
    fun syncMetadataDeclaresSchemaAndCollections() {
        val scope = CloudDataContract.buildScope("CLASS-8A", "Teacher Lin", AuthContract.ROLE_TEACHER)
        val metadata = CloudDataContract.buildSyncMetadata(scope, "android-classroom")

        assertEquals(4, metadata["schemaVersion"])
        assertEquals("English+", metadata["app"])
        assertEquals("android-classroom", metadata["deviceLabel"])
        assertEquals("CLASS-8A", metadata["classId"])
        assertEquals("teacher-lin", metadata["userId"])
        assertEquals(AuthContract.ROLE_TEACHER, metadata["roleLabel"])
        assertTrue((metadata["collections"] as List<*>).contains("learningEvents"))
        assertTrue((metadata["collections"] as List<*>).contains("questionBank"))
    }

    @Test
    fun syncQueueTracksRetryBackoffBlockedAndReadableState() {
        val pending = OfflineSyncItem(
            title = "學生求助",
            category = "help_request",
            detail = "需要老師回覆",
            status = "queued",
            updatedAt = 100L
        )

        val queued = CloudDataContract.queueItemFromOfflineSync(pending)
        val retried = CloudDataContract.recordSyncFailure(queued, "network unavailable", now = 1_000L)
        val retryPlan = CloudDataContract.retryPlanFor(retried, now = 1_000L)
        val blocked = retried.copy(attemptCount = 3, status = "blocked")
        val blockedPlan = CloudDataContract.retryPlanFor(blocked, now = 2_000L)
        val state = CloudDataContract.buildQueueState(
            items = listOf(blocked),
            networkAvailable = true,
            lastSuccessAt = 150L
        )

        assertEquals("help_request", queued.collection)
        assertEquals(1, retried.attemptCount)
        assertEquals("retry", retried.status)
        assertTrue(retryPlan.canRetry)
        assertEquals(30_000L, retryPlan.retryAfterMillis)
        assertEquals(31_000L, retryPlan.nextAttemptAt)
        assertFalse(blockedPlan.canRetry)
        assertTrue(blockedPlan.userMessage.contains("需要處理"))
        assertEquals(1, state.blockedCount)
        assertEquals(150L, state.lastSuccessAt)
        assertEquals("resolve-blocked-items", state.nextAction)
        assertTrue(state.message.contains("需要處理"))
        assertFalse(state.message.any { it.code in 0xE000..0xF8FF })
    }

    @Test
    fun successfulSyncClearsRetryState() {
        val queued = CloudDataContract.queueItemFromOfflineSync(
            OfflineSyncItem("學生回覆已讀", "collaborationNotes", "學生看見老師回覆", "待上傳", 100L)
        )
        val failed = CloudDataContract.recordSyncFailure(queued, "timeout", now = 200L)
        val synced = CloudDataContract.recordSyncSuccess(failed, now = 300L)

        assertEquals(0, synced.attemptCount)
        assertEquals("synced", synced.status)
        assertEquals("", synced.lastError)
        assertEquals(300L, synced.updatedAt)
    }

    @Test
    fun cloudPayloadsMapCoreOfflineRecords() {
        val scope = CloudDataContract.buildScope("CLASS-8A", "Ray Chen", AuthContract.ROLE_STUDENT)
        val request = CollaborationNote(
            actor = "Ray Chen",
            role = AuthContract.ROLE_STUDENT,
            target = "Ray Chen",
            note = "I need help with reading.",
            status = CollaborationFlowContract.STATUS_STUDENT_REQUEST,
            createdAt = 1000L
        )
        val reply = request.copy(
            actor = "Teacher Lin",
            role = AuthContract.ROLE_TEACHER,
            note = "Start from the first paragraph.",
            status = CollaborationFlowContract.STATUS_STAFF_REPLY,
            createdAt = 2000L
        )
        val event = LearningEvent(
            type = "answer_correct",
            title = "Finished reading item",
            detail = "B1 reading question",
            createdAt = 3000L
        )

        val requestPayload = CloudDataContract.collaborationPayload(scope, request)
        val replyPayload = CloudDataContract.collaborationPayload(scope, reply)
        val eventPayload = CloudDataContract.learningEventPayload(scope, event)
        val missionPayload = CloudDataContract.missionCompletionPayload(
            scope = scope,
            goal = 3,
            done = 3,
            routeLabel = "challenge",
            completedAt = 4000L
        )

        assertEquals(scope.collaborationCollectionPath, requestPayload["collectionPath"])
        assertEquals("student_help_request", requestPayload["recordType"])
        assertEquals(true, requestPayload["studentVisible"])
        assertEquals(false, requestPayload["staffOnly"])
        assertEquals("staff_reply", replyPayload["recordType"])
        assertEquals(true, replyPayload["studentVisible"])
        assertEquals(false, replyPayload["staffOnly"])
        assertEquals("learning_event", eventPayload["recordType"])
        assertEquals("mission_completion", missionPayload["recordType"])
        assertEquals("3/3", missionPayload["progress"])
    }

    @Test
    fun staffNotesStayStaffOnlyInCloudPayloads() {
        val scope = CloudDataContract.buildScope("CLASS-8A", "Teacher Lin", AuthContract.ROLE_TEACHER)
        val internalNote = CollaborationNote(
            actor = "Teacher Lin",
            role = AuthContract.ROLE_TEACHER,
            target = "Ray Chen",
            note = "下次先觀察閱讀題，不直接增加作業。",
            status = CollaborationFlowContract.STATUS_STAFF_NOTE,
            createdAt = 5000L
        )

        val payload = CloudDataContract.collaborationPayload(scope, internalNote)

        assertEquals("staff_note", payload["recordType"])
        assertEquals(false, payload["studentVisible"])
        assertEquals(true, payload["staffOnly"])
    }
}
