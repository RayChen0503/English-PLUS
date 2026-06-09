package tw.edu.citizenaction.soracompanion.model

enum class SupportTarget { AiCoach, HumanHandoff, ReadingBreakdown, Recovery }

object UserFlowContract {
    val questionTypes = listOf("選擇題", "填空題", "克漏字", "閱讀理解", "翻譯/句子重組")
    val defaultPreferredQuestionTypes = setOf("選擇題", "填空題")

    fun bottomNavLabels(role: Role): List<String> {
        return if (role == Role.Student) {
            listOf("首頁", "練習", "支持", "地圖", "檔案")
        } else {
            listOf("今日", "學生", "接力", "同步", "報告")
        }
    }

    fun requiredCheckInQuestions(): List<String> = listOf(
        "今天的心情量表",
        "今天有足夠的時間練習英文嗎",
        "今天會想要挑戰更難的題目嗎",
        "想要多練習哪幾種題型"
    )

    fun moodFromScale(scale: Int): Mood {
        return when (scale.coerceIn(1, 5)) {
            1, 2 -> Mood.Low
            5 -> Mood.Good
            else -> Mood.Okay
        }
    }

    fun moodScaleForMood(mood: Mood): Int {
        return when (mood) {
            Mood.Low -> 2
            Mood.Okay -> 3
            Mood.Good -> 5
        }
    }

    fun minutesFromTimeScale(scale: Int): Int {
        return when (scale.coerceIn(1, 5)) {
            1, 2 -> 3
            3 -> 5
            4 -> 8
            else -> 12
        }
    }

    fun timeScaleForMinutes(minutes: Int): Int {
        return when {
            minutes <= 3 -> 2
            minutes <= 5 -> 3
            minutes <= 8 -> 4
            else -> 5
        }
    }

    fun questionGoal(minutes: Int): Int {
        return when {
            minutes <= 3 -> 1
            minutes <= 5 -> 2
            minutes <= 8 -> 3
            else -> 4
        }
    }

    fun supportTarget(route: String): SupportTarget {
        return when (route) {
            "AI 陪伴", "AI 先處理" -> SupportTarget.AiCoach
            "閱讀拆解" -> SupportTarget.ReadingBreakdown
            "復原模式" -> SupportTarget.Recovery
            else -> SupportTarget.HumanHandoff
        }
    }

    fun levelWeight(level: String, challengeWanted: Boolean): Int {
        val normalized = level.uppercase()
        val base = when {
            normalized.startsWith("B2") -> 5
            normalized.startsWith("B1") -> 4
            normalized.startsWith("A2") -> 3
            else -> 2
        }
        return if (challengeWanted) -base else base
    }
}
