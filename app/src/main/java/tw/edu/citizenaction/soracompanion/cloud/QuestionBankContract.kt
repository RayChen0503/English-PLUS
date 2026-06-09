package tw.edu.citizenaction.soracompanion.cloud

import tw.edu.citizenaction.soracompanion.model.QuestionBankItem

enum class QuestionReviewState {
    Draft,
    Approved,
    Archived
}

object QuestionBankContract {
    const val QUESTION_BANK_SCHEMA_VERSION = 5

    fun importId(scope: CloudAccessScope, item: QuestionBankItem): String {
        return "${scope.classId}:${normalizeQuestionId(item.id)}"
    }

    fun initialReviewState(item: QuestionBankItem): QuestionReviewState {
        return when (item.reviewState.trim().lowercase()) {
            "approved" -> QuestionReviewState.Approved
            "archived" -> QuestionReviewState.Archived
            else -> QuestionReviewState.Draft
        }
    }

    fun publishState(scope: CloudAccessScope, item: QuestionBankItem): QuestionReviewState {
        return if (canPublishQuestionBank(scope)) QuestionReviewState.Approved else initialReviewState(item)
    }

    fun canPublishQuestionBank(scope: CloudAccessScope): Boolean {
        return CloudDataContract.canWriteQuestionBank(scope)
    }

    fun buildQuestionBankMetadata(
        scope: CloudAccessScope,
        items: List<QuestionBankItem>
    ): Map<String, Any> {
        return mapOf(
            "questionBankSchemaVersion" to QUESTION_BANK_SCHEMA_VERSION,
            "collectionPath" to scope.questionBankCollectionPath,
            "publisherId" to scope.userId,
            "publisherRole" to scope.roleLabel,
            "permissionRule" to "teacher-only publish; student read-only",
            "conflictRule" to "importId keeps latest updatedAt",
            "levelCounts" to items.groupingBy { it.level.trim().lowercase() }.eachCount(),
            "skillCounts" to items.groupingBy { it.skill.trim().lowercase() }.eachCount()
        )
    }

    fun normalizeQuestionId(id: String): String {
        return id.trim()
            .lowercase()
            .replace(Regex("[^a-z0-9]+"), "-")
            .trim('-')
            .ifBlank { "question" }
    }
}
