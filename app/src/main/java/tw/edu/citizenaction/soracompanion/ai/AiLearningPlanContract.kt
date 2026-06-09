package tw.edu.citizenaction.soracompanion.ai

data class AiDailyMissionPlan(
    val routeLabel: String,
    val questionGoal: Int,
    val recommendedTypes: List<String>,
    val studentMessage: String,
    val handoffHint: String
)

object AiLearningPlanContract {
    fun localDailyMissionPlan(
        moodLabel: String,
        minutes: Int,
        challengeWanted: Boolean,
        preferredTypes: Set<String>,
        availableTypes: List<String>
    ): AiDailyMissionPlan {
        val safeMinutes = minutes.coerceAtLeast(1)
        val questionGoal = when {
            safeMinutes <= 3 -> 1
            safeMinutes <= 5 -> 2
            safeMinutes <= 8 -> 3
            else -> 4
        }
        val selectedTypes = preferredTypes
            .filter { it in availableTypes }
            .ifEmpty { availableTypes.take(2) }
        val isLowPressure = moodLabel.contains("低") || moodLabel.contains("不好") || !challengeWanted
        val routeLabel = if (isLowPressure) "低壓修復" else "挑戰路線"
        val typeText = selectedTypes.joinToString("、").ifBlank { "選擇題" }
        val message = if (isLowPressure) {
            "先完成 $questionGoal 題$typeText。今天重點是重新開始，不是衝題數。"
        } else {
            "先完成 $questionGoal 題$typeText。答對後再開放更難的自主練習。"
        }
        return AiDailyMissionPlan(
            routeLabel = routeLabel,
            questionGoal = questionGoal,
            recommendedTypes = selectedTypes,
            studentMessage = message,
            handoffHint = "若連續卡住，先給提示，再由老師或志工接力。"
        )
    }

    fun buildMissionPayload(
        classCode: String,
        studentName: String,
        moodLabel: String,
        minutes: Int,
        challengeWanted: Boolean,
        preferredTypes: Set<String>,
        availableTypes: List<String>
    ): Map<String, Any> {
        return mapOf(
            "action" to "generateDailyMission",
            "app" to "English+",
            "schemaVersion" to AiSecurityContract.AI_SECURITY_SCHEMA_VERSION,
            "classCode" to classCode,
            "studentName" to studentName,
            "moodLabel" to moodLabel,
            "minutes" to minutes,
            "challengeWanted" to challengeWanted,
            "preferredTypes" to preferredTypes.toList(),
            "availableTypes" to availableTypes,
            "security" to AiSecurityContract.proxyPayloadMetadata(classCode, "android-client")
        )
    }
}
