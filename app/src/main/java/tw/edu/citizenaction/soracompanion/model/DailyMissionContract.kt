package tw.edu.citizenaction.soracompanion.model

data class DailyMissionProgress(
    val done: Int,
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
        seed: Int
    ): List<Question> {
        val safeGoal = requestedGoal.coerceAtLeast(1)
        val selectedTypes = preferredTypes.ifEmpty { UserFlowContract.defaultPreferredQuestionTypes }
        val typedItems = bankItems.filter { it.question.type in selectedTypes }
        val sourceItems = if (typedItems.isNotEmpty()) typedItems else bankItems
        val bankQuestions = sourceItems
            .distinctBy { it.question.prompt }
            .sortedWith(
                compareBy(
                    { UserFlowContract.levelWeight(it.level, challengeWanted) },
                    { it.question.type },
                    { it.id }
                )
            )
            .map { it.question }

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
