package tw.edu.citizenaction.soracompanion.cloud

import tw.edu.citizenaction.soracompanion.model.QuestionBankItem

data class PracticeBlueprint(
    val totalQuestions: Int,
    val availableLevels: List<String>,
    val availableTypes: List<String>,
    val recommendation: String
)

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

    fun practiceBlueprint(
        items: List<QuestionBankItem>,
        preferredTypes: Set<String>,
        challengeWanted: Boolean
    ): PracticeBlueprint {
        val availableLevels = items
            .map { it.level.trim().uppercase() }
            .filter { it.isNotBlank() }
            .distinct()
            .sortedWith(compareBy { levelOrder(it) })
        val availableTypes = items
            .map { it.question.type.trim() }
            .filter { it.isNotBlank() }
            .distinct()
        val preferred = preferredTypes.ifEmpty { availableTypes.toSet() }
        val matchingCount = items.count { it.question.type in preferred }
        val recommendation = when {
            challengeWanted -> "挑戰模式會優先加入 B1/B2 題，但仍保留 A1/A2 當暖身。"
            matchingCount == 0 -> "目前偏好題型不足，系統會先用可用題型安排暖身。"
            else -> "一般模式會先穩定 A1/A2，再逐步混入 B1 題。"
        }
        return PracticeBlueprint(
            totalQuestions = items.distinctBy { it.question.prompt }.size,
            availableLevels = availableLevels,
            availableTypes = availableTypes,
            recommendation = recommendation
        )
    }

    fun sessionCandidates(
        items: List<QuestionBankItem>,
        preferredTypes: Set<String>,
        recentlySeenPrompts: Set<String>,
        challengeWanted: Boolean
    ): List<QuestionBankItem> {
        val preferred = preferredTypes.ifEmpty {
            items.map { it.question.type }.toSet()
        }
        val typed = items.filter { it.question.type in preferred }
        val source = if (typed.isNotEmpty()) typed else items
        return source
            .filter { it.question.prompt !in recentlySeenPrompts }
            .distinctBy { it.question.prompt }
            .sortedWith(
                compareBy(
                    { levelWeight(it.level, challengeWanted) },
                    { it.question.type },
                    { normalizeQuestionId(it.id) }
                )
            )
    }

    private fun levelOrder(level: String): Int {
        return when {
            level.startsWith("A1") -> 1
            level.startsWith("A2") -> 2
            level.startsWith("B1") -> 3
            level.startsWith("B2") -> 4
            else -> 9
        }
    }

    private fun levelWeight(level: String, challengeWanted: Boolean): Int {
        val order = levelOrder(level.trim().uppercase())
        return if (challengeWanted) -order else order
    }
}
