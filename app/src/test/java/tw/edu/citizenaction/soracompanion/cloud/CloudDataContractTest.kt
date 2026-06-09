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
    fun syncMetadataDeclaresSchemaAndCollections() {
        val scope = CloudDataContract.buildScope("CLASS-8A", "Teacher Lin", AuthContract.ROLE_TEACHER)
        val metadata = CloudDataContract.buildSyncMetadata(scope, "android-demo")

        assertEquals(3, metadata["schemaVersion"])
        assertEquals("English+", metadata["app"])
        assertEquals("android-demo", metadata["deviceLabel"])
        assertEquals("CLASS-8A", metadata["classId"])
        assertEquals("teacher-lin", metadata["userId"])
        assertEquals(AuthContract.ROLE_TEACHER, metadata["roleLabel"])
        assertTrue((metadata["collections"] as List<*>).contains("learningEvents"))
        assertTrue((metadata["collections"] as List<*>).contains("questionBank"))
    }

    @Test
    fun syncQueueTracksRetryBlockedAndLastSuccessState() {
        val pending = OfflineSyncItem(
            title = "Student help request",
            category = "help_request",
            detail = "Need teacher reply",
            status = "queued",
            updatedAt = 100L
        )

        val queued = CloudDataContract.queueItemFromOfflineSync(pending)
        val retried = CloudDataContract.recordSyncFailure(queued, "network unavailable", now = 200L)
        val blocked = retried.copy(attemptCount = 3)
        val state = CloudDataContract.buildQueueState(
            items = listOf(blocked),
            networkAvailable = true,
            lastSuccessAt = 150L
        )

        assertEquals("help_request", queued.collection)
        assertEquals(1, retried.attemptCount)
        assertEquals("retry", retried.status)
        assertEquals(1, state.blockedCount)
        assertEquals(150L, state.lastSuccessAt)
        assertEquals("resolve-blocked-items", state.nextAction)
        assertTrue(state.message.contains("需要人工確認"))
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
        assertEquals("staff_reply", replyPayload["recordType"])
        assertEquals("learning_event", eventPayload["recordType"])
        assertEquals("mission_completion", missionPayload["recordType"])
        assertEquals("3/3", missionPayload["progress"])
    }
}
