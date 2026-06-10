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

data class CloudRetryPlan(
    val attemptCount: Int,
    val canRetry: Boolean,
    val isDue: Boolean,
    val retryAfterMillis: Long,
    val nextAttemptAt: Long,
    val userMessage: String
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
    const val SCHEMA_VERSION = 4

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
            classId = normalizeId(classCode, fallback = "CLASS-LOCAL").uppercase(),
            userId = normalizeId(accountName, fallback = "class-user"),
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

    fun canWriteRecord(scope: CloudAccessScope, recordType: String, targetUserId: String): Boolean {
        val type = recordType.trim().lowercase().replace("-", "_")
        val target = normalizeId(targetUserId, fallback = "")
        val isOwnStudentRecord = scope.userId == target
        return when {
            AuthContract.isStudentRole(scope.roleLabel) -> {
                isOwnStudentRecord && type in setOf(
                    "student_help_request",
                    "learning_event",
                    "mission_completion"
                )
            }
            AuthContract.normalizeRole(scope.roleLabel) == AuthContract.ROLE_TEACHER -> {
                type in setOf("staff_reply", "staff_note", "question_bank")
            }
            AuthContract.normalizeRole(scope.roleLabel) == AuthContract.ROLE_VOLUNTEER -> {
                type in setOf("staff_reply", "staff_note")
            }
            else -> false
        }
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

    fun recordSyncSuccess(
        item: CloudSyncQueueItem,
        now: Long
    ): CloudSyncQueueItem {
        return item.copy(
            attemptCount = 0,
            status = "synced",
            lastError = "",
            updatedAt = now
        )
    }

    fun retryPlanFor(
        item: CloudSyncQueueItem,
        now: Long
    ): CloudRetryPlan {
        val safeAttempt = item.attemptCount.coerceAtLeast(0)
        val blocked = item.status == "blocked" || safeAttempt >= 3
        val synced = item.status == "synced"
        val delay = if (safeAttempt <= 0) {
            0L
        } else {
            (30_000L * (1 shl (safeAttempt - 1).coerceAtMost(3))).coerceAtMost(300_000L)
        }
        val nextAttemptAt = item.updatedAt + delay
        val canRetry = !blocked && !synced
        val message = when {
            synced -> "這筆資料已同步完成。"
            blocked -> "同步已暫停，需要處理錯誤後再補傳。"
            delay == 0L -> "資料已排入同步佇列。"
            else -> "資料會在稍後自動重試；你可以先繼續使用。"
        }
        return CloudRetryPlan(
            attemptCount = safeAttempt,
            canRetry = canRetry,
            isDue = canRetry && now >= nextAttemptAt,
            retryAfterMillis = delay,
            nextAttemptAt = nextAttemptAt,
            userMessage = message
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
            "wait-for-network" -> "目前沒有可用網路，資料已保存在這台裝置，稍後會再補傳。"
            "resolve-blocked-items" -> "有資料重試太多次，需要處理錯誤後再補傳。"
            "sync-now" -> "有資料等待同步，可以現在補傳到班級空間。"
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
        val studentVisible = recordType == "student_help_request" || recordType == "staff_reply"
        return mapOf(
            "schemaVersion" to SCHEMA_VERSION,
            "collectionPath" to scope.collaborationCollectionPath,
            "documentId" to normalizeId("${note.target}-${note.createdAt}-${recordType}", fallback = "collaboration-note"),
            "recordType" to recordType,
            "studentVisible" to studentVisible,
            "staffOnly" to !studentVisible,
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
