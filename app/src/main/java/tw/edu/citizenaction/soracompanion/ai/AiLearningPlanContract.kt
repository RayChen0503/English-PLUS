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
        val safeAvailableTypes = availableTypes.ifEmpty { listOf("選擇題") }
        val selectedTypes = preferredTypes
            .filter { it in safeAvailableTypes }
            .ifEmpty { safeAvailableTypes.take(2) }
        val isLowPressure = moodLabel.contains("低落") ||
            moodLabel.contains("不穩") ||
            !challengeWanted
        val routeLabel = if (isLowPressure) "低壓修復" else "挑戰路線"
        val typeText = selectedTypes.joinToString("、").ifBlank { "選擇題" }
        val message = if (isLowPressure) {
            "今天先做 $questionGoal 題$typeText，把任務縮小到可以開始的程度。"
        } else {
            "今天做 $questionGoal 題$typeText，答對後可以再進自由練習挑戰。"
        }
        return AiDailyMissionPlan(
            routeLabel = routeLabel,
            questionGoal = questionGoal,
            recommendedTypes = selectedTypes,
            studentMessage = message,
            handoffHint = "如果卡住，English+ 會先提供提示；仍需要陪伴時再整理給老師或志工。"
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
