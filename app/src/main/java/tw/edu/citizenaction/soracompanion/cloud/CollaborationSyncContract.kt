package tw.edu.citizenaction.soracompanion.cloud

import tw.edu.citizenaction.soracompanion.model.CollaborationNote

data class CollaborationConflictReport(
    val mergedNotes: List<CollaborationNote>,
    val deduplicatedEvents: Int,
    val localOnlyEvents: Int,
    val remoteOnlyEvents: Int,
    val rule: String,
    val userMessage: String
)

object CollaborationSyncContract {
    const val COLLABORATION_SCHEMA_VERSION = 5

    fun eventId(note: CollaborationNote): String {
        return listOf(note.actor, note.role, note.target, note.note)
            .joinToString("|")
            .lowercase()
            .replace(Regex("[^a-z0-9\\u4e00-\\u9fff]+"), "-")
            .trim('-')
            .ifBlank { "collaboration-note" }
    }

    fun mergeNotes(
        localNotes: List<CollaborationNote>,
        remoteNotes: List<CollaborationNote>
    ): List<CollaborationNote> {
        return (localNotes + remoteNotes)
            .groupBy { eventId(it) }
            .map { (_, notes) -> notes.maxBy { it.createdAt } }
            .sortedByDescending { it.createdAt }
    }

    fun resolveConflictReport(
        localNotes: List<CollaborationNote>,
        remoteNotes: List<CollaborationNote>
    ): CollaborationConflictReport {
        val localIds = localNotes.map { eventId(it) }.toSet()
        val remoteIds = remoteNotes.map { eventId(it) }.toSet()
        val merged = mergeNotes(localNotes, remoteNotes)
        return CollaborationConflictReport(
            mergedNotes = merged,
            deduplicatedEvents = localIds.intersect(remoteIds).size,
            localOnlyEvents = (localIds - remoteIds).size,
            remoteOnlyEvents = (remoteIds - localIds).size,
            rule = "latest-createdAt-wins",
            userMessage = "已保留最新紀錄，重複接力內容不會顯示兩次。"
        )
    }

    fun buildCollaborationSyncMetadata(
        scope: CloudAccessScope,
        pushFirst: Boolean
    ): Map<String, Any> {
        return mapOf(
            "collaborationSchemaVersion" to COLLABORATION_SCHEMA_VERSION,
            "direction" to if (pushFirst) "bidirectional" else "fetch-only",
            "pushBeforeFetch" to pushFirst,
            "classId" to scope.classId,
            "userId" to scope.userId,
            "roleLabel" to scope.roleLabel,
            "collectionPath" to scope.collaborationCollectionPath,
            "conflictRule" to "latest-createdAt-wins"
        )
    }

    fun canCreateOfficialNote(scope: CloudAccessScope): Boolean {
        return CloudDataContract.canWriteCollaboration(scope)
    }
}
