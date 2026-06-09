package tw.edu.citizenaction.soracompanion.cloud

import tw.edu.citizenaction.soracompanion.auth.AuthContract
import tw.edu.citizenaction.soracompanion.model.CollaborationFlowContract
import tw.edu.citizenaction.soracompanion.model.CollaborationNote
import tw.edu.citizenaction.soracompanion.model.OfflineSyncItem
import tw.edu.citizenaction.soracompanion.storage.LearningEvent

data class CloudSyncQueueItem(
    val collection: String,
    val documentId: String,
    val operation: String,
    val payload: Map<String, Any>,
    val attemptCount: Int = 0,
    val status: String = "pending",
    val lastError: String = "",
    val updatedAt: Long
)

data class CloudQueueState(
    val pendingCount: Int,
    val retryCount: Int,
    val blockedCount: Int,
    val lastSuccessAt: Long,
    val nextAction: String,
    val message: String
)

data class CloudAccessScope(
    val classId: String,
    val userId: String,
    val roleLabel: String
) {
    val classDocumentPath: String = "classes/$classId"
    val studentDocumentPath: String = "classes/$classId/students/$userId"
    val collaborationCollectionPath: String = "classes/$classId/collaborationNotes"
    val questionBankCollectionPath: String = "classes/$classId/questionBank"
}

object CloudDataContract {
    const val SCHEMA_VERSION = 3

    val syncedCollections = listOf(
        "appState",
        "learningEvents",
        "collaborationNotes",
        "offlineSyncItems",
        "missionCompletions",
        "questionBank"
    )

    fun buildScope(classCode: String, accountName: String, roleLabel: String): CloudAccessScope {
        return CloudAccessScope(
            classId = normalizeId(classCode, fallback = "DEMO-CLASS").uppercase(),
            userId = normalizeId(accountName, fallback = "demo-user"),
            roleLabel = AuthContract.normalizeRole(roleLabel)
        )
    }

    fun buildSyncMetadata(scope: CloudAccessScope, deviceLabel: String): Map<String, Any> {
        return mapOf(
            "schemaVersion" to SCHEMA_VERSION,
            "app" to "English+",
            "deviceLabel" to deviceLabel,
            "classId" to scope.classId,
            "userId" to scope.userId,
            "roleLabel" to scope.roleLabel,
            "classPath" to scope.classDocumentPath,
            "studentPath" to scope.studentDocumentPath,
            "collections" to syncedCollections
        )
    }

    fun canReadStudentData(scope: CloudAccessScope, targetUserId: String): Boolean {
        return when {
            AuthContract.isStudentRole(scope.roleLabel) -> scope.userId == normalizeId(targetUserId, fallback = "")
            AuthContract.isStaffRole(scope.roleLabel) -> true
            else -> false
        }
    }

    fun canWriteCollaboration(scope: CloudAccessScope): Boolean {
        return AuthContract.isStaffRole(scope.roleLabel)
    }

    fun canWriteQuestionBank(scope: CloudAccessScope): Boolean {
        return AuthContract.normalizeRole(scope.roleLabel) == AuthContract.ROLE_TEACHER
    }

    fun queueItemFromOfflineSync(item: OfflineSyncItem): CloudSyncQueueItem {
        return CloudSyncQueueItem(
            collection = item.category.trim().ifBlank { "offlineSyncItems" },
            documentId = normalizeId("${item.category}-${item.title}-${item.updatedAt}", fallback = "offline-sync-item"),
            operation = "upsert",
            payload = mapOf(
                "title" to item.title,
                "category" to item.category,
                "detail" to item.detail,
                "status" to item.status,
                "updatedAt" to item.updatedAt
            ),
            updatedAt = item.updatedAt
        )
    }

    fun recordSyncFailure(
        item: CloudSyncQueueItem,
        error: String,
        now: Long
    ): CloudSyncQueueItem {
        val nextAttempt = item.attemptCount + 1
        return item.copy(
            attemptCount = nextAttempt,
            status = if (nextAttempt >= 3) "blocked" else "retry",
            lastError = error,
            updatedAt = now
        )
    }

    fun buildQueueState(
        items: List<CloudSyncQueueItem>,
        networkAvailable: Boolean,
        lastSuccessAt: Long
    ): CloudQueueState {
        val blocked = items.count { it.status == "blocked" || it.attemptCount >= 3 }
        val retry = items.count { it.status == "retry" && it.attemptCount < 3 }
        val pending = items.count { it.status == "pending" }
        val nextAction = when {
            !networkAvailable -> "wait-for-network"
            blocked > 0 -> "resolve-blocked-items"
            items.isNotEmpty() -> "sync-now"
            else -> "idle"
        }
        val message = when (nextAction) {
            "wait-for-network" -> "網路尚未可用，系統會保留本機資料並等待補傳。"
            "resolve-blocked-items" -> "有同步項目重試多次仍失敗，需要人工確認後再補傳。"
            "sync-now" -> "已有本機資料待同步，可以開始補傳。"
            else -> "目前沒有待同步資料。"
        }
        return CloudQueueState(
            pendingCount = pending,
            retryCount = retry,
            blockedCount = blocked,
            lastSuccessAt = lastSuccessAt,
            nextAction = nextAction,
            message = message
        )
    }

    fun collaborationPayload(
        scope: CloudAccessScope,
        note: CollaborationNote
    ): Map<String, Any> {
        val recordType = when {
            CollaborationFlowContract.isStudentHelpRequest(note) -> "student_help_request"
            CollaborationFlowContract.isStaffReply(note) -> "staff_reply"
            else -> "staff_note"
        }
        return mapOf(
            "schemaVersion" to SCHEMA_VERSION,
            "collectionPath" to scope.collaborationCollectionPath,
            "documentId" to normalizeId("${note.target}-${note.createdAt}-${recordType}", fallback = "collaboration-note"),
            "recordType" to recordType,
            "classId" to scope.classId,
            "actor" to note.actor,
            "role" to AuthContract.normalizeRole(note.role),
            "target" to note.target,
            "note" to note.note,
            "status" to note.status,
            "createdAt" to note.createdAt
        )
    }

    fun learningEventPayload(
        scope: CloudAccessScope,
        event: LearningEvent
    ): Map<String, Any> {
        return mapOf(
            "schemaVersion" to SCHEMA_VERSION,
            "collectionPath" to "${scope.studentDocumentPath}/learningEvents",
            "documentId" to normalizeId("${event.type}-${event.createdAt}", fallback = "learning-event"),
            "recordType" to "learning_event",
            "classId" to scope.classId,
            "studentId" to scope.userId,
            "type" to event.type,
            "title" to event.title,
            "detail" to event.detail,
            "createdAt" to event.createdAt
        )
    }

    fun missionCompletionPayload(
        scope: CloudAccessScope,
        goal: Int,
        done: Int,
        routeLabel: String,
        completedAt: Long
    ): Map<String, Any> {
        val safeGoal = goal.coerceAtLeast(1)
        val safeDone = done.coerceIn(0, safeGoal)
        return mapOf(
            "schemaVersion" to SCHEMA_VERSION,
            "collectionPath" to "${scope.studentDocumentPath}/missionCompletions",
            "documentId" to normalizeId("mission-$completedAt", fallback = "mission-completion"),
            "recordType" to "mission_completion",
            "classId" to scope.classId,
            "studentId" to scope.userId,
            "progress" to "$safeDone/$safeGoal",
            "routeLabel" to routeLabel,
            "completedAt" to completedAt
        )
    }

    private fun normalizeId(value: String, fallback: String): String {
        val normalized = value.trim()
            .lowercase()
            .replace(Regex("[^a-z0-9]+"), "-")
            .trim('-')
        return normalized.ifBlank { fallback }
    }
}
