package tw.edu.citizenaction.soracompanion.model

import tw.edu.citizenaction.soracompanion.auth.AuthContract

enum class SupportTarget { AiCoach, HumanHandoff, ReadingBreakdown, Recovery }

object UserFlowContract {
    const val TYPE_CHOICE = "選擇題"
    const val TYPE_FILL_BLANK = "填空題"
    const val TYPE_CLOZE = "克漏字"
    const val TYPE_READING = "閱讀理解"
    const val TYPE_TRANSLATION = "翻譯/句子重組"

    val questionTypes = listOf(TYPE_CHOICE, TYPE_FILL_BLANK, TYPE_CLOZE, TYPE_READING, TYPE_TRANSLATION)
    val defaultPreferredQuestionTypes = setOf(TYPE_CHOICE, TYPE_FILL_BLANK)

    fun bottomNavLabels(role: Role): List<String> {
        return when (normalizedRole(role)) {
            Role.Student -> listOf("首頁", "練習", "支持", "地圖", "我的")
            Role.Teacher -> listOf("今日", "學生", "接力", "報告", "題庫")
            Role.Volunteer -> listOf("今日", "接力", "學生", "同步", "腳本")
            Role.Mentor -> listOf("今日", "接力", "學生", "同步", "腳本")
        }
    }

    fun roleForAuthLabel(roleLabel: String): Role {
        return when (AuthContract.normalizeRole(roleLabel)) {
            AuthContract.ROLE_TEACHER -> Role.Teacher
            AuthContract.ROLE_VOLUNTEER -> Role.Volunteer
            else -> Role.Student
        }
    }

    fun normalizedRole(role: Role): Role {
        return if (role == Role.Mentor) Role.Volunteer else role
    }

    fun isStaffRole(role: Role): Boolean = normalizedRole(role) != Role.Student

    fun isTeacherRole(role: Role): Boolean = normalizedRole(role) == Role.Teacher

    fun canUseTeacherTool(role: Role, screen: Screen): Boolean {
        if (!isTeacherRole(role)) return false
        return screen == Screen.Report ||
            screen == Screen.QuestionBank ||
            screen == Screen.StudentManager
    }

    fun canUseVolunteerTool(role: Role, screen: Screen): Boolean {
        if (normalizedRole(role) != Role.Volunteer) return false
        return screen == Screen.MentorScript ||
            screen == Screen.SyncCenter
    }

    fun rosterSubtitle(role: Role): String {
        return when (normalizedRole(role)) {
            Role.Teacher -> "先看班級風險與需要接住的學生。"
            Role.Volunteer -> "先看分派給你的接力學生與下一步。"
            else -> "先看自己的任務與支持訊息。"
        }
    }

    fun studentDetailActionTitle(role: Role): String {
        return when (normalizedRole(role)) {
            Role.Teacher -> "老師回覆"
            Role.Volunteer -> "志工陪練"
            else -> "下一步"
        }
    }

    fun roleTitle(role: Role): String {
        return when (normalizedRole(role)) {
            Role.Student -> "學生端"
            Role.Teacher -> "老師端"
            Role.Volunteer -> "志工端"
            Role.Mentor -> "志工端"
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
            "AI 陪伴", "AI 拆解" -> SupportTarget.AiCoach
            "閱讀拆解" -> SupportTarget.ReadingBreakdown
            "復原任務" -> SupportTarget.Recovery
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
