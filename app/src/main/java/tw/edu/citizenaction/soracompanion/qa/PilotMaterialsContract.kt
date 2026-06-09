package tw.edu.citizenaction.soracompanion.qa

data class TeacherBrief(
    val title: String,
    val talkingPoints: List<String>,
    val demoReminder: String
)

data class ConsentNotice(
    val sections: Map<String, String>,
    val allowPublicRanking: Boolean
)

data class FeedbackQuestion(
    val audience: String,
    val question: String,
    val responseType: String
)

data class FeedbackForm(
    val title: String,
    val questions: List<FeedbackQuestion>
)

data class ObservationSheet(
    val title: String,
    val fields: List<String>
)

object PilotMaterialsContract {
    const val MATERIALS_SCHEMA_VERSION = 11

    fun teacherBrief(): TeacherBrief {
        return TeacherBrief(
            title = "English+ 教室內測老師簡報",
            talkingPoints = listOf(
                "English+ 不是排名工具，而是幫學生在卡關時被接住。",
                "學生先做 3-5 分鐘短任務；錯題會變成修復線索，不會變成公開懲罰。",
                "AI 負責把錯題拆小；老師與志工負責處理需要真人陪伴的情緒斷點。",
                "內測時請觀察學生是否願意回來做下一題，而不只看答對率。",
                "所有回饋都以支持、修復、接力為主，不公開比較學生。"
            ),
            demoReminder = "Start with student home, then task, AI fallback, handoff, sync, question bank, and report."
        )
    }

    fun consentNotice(): ConsentNotice {
        return ConsentNotice(
            sections = linkedMapOf(
                "資料會用在哪裡" to "內測資料只用於理解學生學習狀態、情緒斷點、錯題修復與老師/志工接力。",
                "誰可以看到" to "學生本人、授課老師、指定志工與課程團隊可查看必要資料；不公開給其他學生比較。",
                "資料權利" to "學生或家長可要求匯出自己的學習資料、刪除內測紀錄，或停止使用 English+。",
                "退出方式" to "學生或家長可要求停止使用，並請老師或課程團隊協助移除或匿名化使用資料。",
                "AI 使用說明" to "AI 只用於產生低壓提示與修復建議；正式版不得把正式 OpenAI Key 放在手機端。",
                "不公開排名" to "English+ 不公開比較學生，也不把學生情緒斷點視為失敗。"
            ),
            allowPublicRanking = false
        )
    }

    fun feedbackForm(): FeedbackForm {
        return FeedbackForm(
            title = "English+ 內測回饋表",
            questions = listOf(
                FeedbackQuestion("student", "你打開 App 後，是否很快知道今天先做什麼？", "choice + short text"),
                FeedbackQuestion("student", "當你答錯或卡住時，提示是否讓你比較敢繼續？", "choice + short text"),
                FeedbackQuestion("teacher", "你是否能在一分鐘內看懂學生下一步需要什麼？", "scale + note"),
                FeedbackQuestion("teacher", "報告與接力摘要是否足夠支持教學判斷？", "scale + note"),
                FeedbackQuestion("volunteer", "志工是否能根據摘要直接陪學生完成下一小步？", "scale + note")
            )
        )
    }

    fun observationSheet(): ObservationSheet {
        return ObservationSheet(
            title = "English+ 內測觀察表",
            fields = listOf(
                "student returned after support",
                "student understood next small task",
                "teacher next action identified",
                "handoff summary understandable",
                "AI/local fallback message felt low-pressure",
                "sync/report state was understandable",
                "question bank level and skill were understandable"
            )
        )
    }
}
