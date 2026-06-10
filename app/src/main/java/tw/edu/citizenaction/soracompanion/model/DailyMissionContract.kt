package tw.edu.citizenaction.soracompanion.model

import tw.edu.citizenaction.soracompanion.cloud.QuestionBankContract

data class DailyMissionProgress(
    val done: Int,
    val isComplete: Boolean
)

data class DailyMissionSummary(
    val title: String,
    val description: String,
    val routeLabel: String,
    val progressRule: String
)

data class DailyMissionCompletionCopy(
    val title: String,
    val body: String,
    val nextAction: String
)

data class DailyMissionProgressCopy(
    val title: String,
    val body: String,
    val percent: Int,
    val remaining: Int,
    val isComplete: Boolean
)

object DailyMissionContract {
    fun goalForMinutes(minutes: Int): Int = UserFlowContract.questionGoal(minutes)

    fun shouldShowProgress(inDailyMission: Boolean, goal: Int): Boolean {
        return inDailyMission && goal > 0
    }

    fun remaining(goal: Int, done: Int): Int {
        return (goal - done).coerceAtLeast(0)
    }

    fun progressPercent(goal: Int, done: Int): Int {
        if (goal <= 0) return 0
        val boundedDone = done.coerceIn(0, goal)
        return ((boundedDone.toDouble() / goal.toDouble()) * 100).toInt()
    }

    fun progressAfterAnswer(done: Int, goal: Int, isCorrect: Boolean): DailyMissionProgress {
        val nextDone = if (isCorrect) {
            (done + 1).coerceAtMost(goal.coerceAtLeast(0))
        } else {
            done.coerceAtLeast(0)
        }
        return DailyMissionProgress(
            done = nextDone,
            isComplete = goal > 0 && nextDone >= goal
        )
    }

    fun progressCopy(inDailyMission: Boolean, goal: Int, done: Int): DailyMissionProgressCopy? {
        if (!shouldShowProgress(inDailyMission, goal)) return null
        val safeGoal = goal.coerceAtLeast(1)
        val safeDone = done.coerceIn(0, safeGoal)
        val remaining = remaining(safeGoal, safeDone)
        val body = if (remaining == 0) {
            "已完成 $safeDone/$safeGoal 題，今日任務達標。"
        } else {
            "已完成 $safeDone/$safeGoal 題，還剩 $remaining 題。"
        }
        return DailyMissionProgressCopy(
            title = "今日題目任務",
            body = body,
            percent = progressPercent(safeGoal, safeDone),
            remaining = remaining,
            isComplete = remaining == 0
        )
    }

    fun summary(
        minutes: Int,
        goal: Int,
        preferredTypes: Set<String>,
        challengeWanted: Boolean
    ): DailyMissionSummary {
        val safeGoal = goal.coerceAtLeast(1)
        val types = preferredTypes.ifEmpty { UserFlowContract.defaultPreferredQuestionTypes }
            .joinToString("、")
        val safeMinutes = minutes.coerceAtLeast(1)
        val routeLabel = if (challengeWanted) "挑戰路線" else "低壓修復"
        return DailyMissionSummary(
            title = "完成 $safeGoal 題小任務",
            description = "今天用 $safeMinutes 分鐘練$types，答對才會推進進度。",
            routeLabel = routeLabel,
            progressRule = "只計算今日題目任務；自由練習不會改變進度。"
        )
    }

    fun completionCopy(goal: Int, done: Int): DailyMissionCompletionCopy {
        val safeGoal = goal.coerceAtLeast(1)
        val safeDone = done.coerceIn(0, safeGoal)
        return DailyMissionCompletionCopy(
            title = "今日任務完成",
            body = "你已經完成今天的題目任務：$safeDone/$safeGoal 題。可以先休息，也可以改成自由練習繼續挑戰。",
            nextAction = "自由練習不會影響今日進度。"
        )
    }

    fun nextCursor(currentCursor: Int, questionCount: Int): Int {
        if (questionCount <= 0) return 0
        return (currentCursor + 1).coerceAtMost(questionCount - 1)
    }

    fun selectQuestions(
        bankItems: List<QuestionBankItem>,
        fallbackQuestions: List<Question>,
        requestedGoal: Int,
        preferredTypes: Set<String>,
        challengeWanted: Boolean,
        seed: Int,
        recentlySeenPrompts: Set<String> = emptySet()
    ): List<Question> {
        val safeGoal = requestedGoal.coerceAtLeast(1)
        val selectedTypes = preferredTypes.ifEmpty { UserFlowContract.defaultPreferredQuestionTypes }
        val bankQuestions = QuestionBankContract.sessionCandidates(
            items = bankItems,
            preferredTypes = selectedTypes,
            recentlySeenPrompts = recentlySeenPrompts,
            challengeWanted = challengeWanted
        ).map { it.question }

        val fallback = fallbackQuestions.distinctBy { it.prompt }
        val candidates = (bankQuestions + fallback)
            .distinctBy { it.prompt }

        if (candidates.isEmpty()) return emptyList()

        val start = seed.floorMod(candidates.size)
        val rotated = candidates.drop(start) + candidates.take(start)
        return rotated.take(safeGoal.coerceAtMost(rotated.size))
    }

    private fun Int.floorMod(divisor: Int): Int {
        if (divisor <= 0) return 0
        return ((this % divisor) + divisor) % divisor
    }
}
