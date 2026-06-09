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
    const val MATERIALS_SCHEMA_VERSION = 12

    fun teacherBrief(): TeacherBrief {
        return TeacherBrief(
            title = "English+ 內測老師說明",
            talkingPoints = listOf(
                "English+ 的核心不是讓學生一直刷題，而是先接住情緒，再安排可以完成的英文小任務。",
                "學生會先完成簡短檢測，系統依照心情、時間、挑戰意願與題型偏好安排今日任務。",
                "答錯時，學生會看到清楚回饋；需要真人陪伴時，老師與志工可以看到求助脈絡並接力回覆。",
                "老師端先呈現班級優先序、學生求助、近期練習紀錄與回覆動作，不混入志工行政資訊。",
                "資料只用來安排下一步與支持，不做評分依據。",
                "系統不做公開排名，也不把情緒狀態當成比較學生的依據。"
            ),
            demoReminder = "展示順序：學生首頁、心情檢測、今日任務、內建提示、老師回覆、志工接力、同步中心與報告。"
        )
    }

    fun consentNotice(): ConsentNotice {
        return ConsentNotice(
            sections = linkedMapOf(
                "資料會怎麼使用" to "English+ 會保存學生的學習紀錄、求助內容、老師回覆與同步狀態，用來安排任務與提供支持。",
                "學生可以選擇什麼" to "學生可以選擇今天的心情、可用時間、是否挑戰較難題目，以及想練習的題型。",
                "老師與志工會看到什麼" to "老師與志工只會看到協助學生下一步所需的學習脈絡、求助原因與回覆紀錄。",
                "AI 使用說明" to "AI 只用於產生低壓提示、錯題詳解與接力摘要；公開使用前應改由安全後端保管服務憑證。",
                "退出與刪除" to "若學生或班級不再參與測試，應可匯出或刪除相關紀錄，並停止後續使用。"
            ),
            allowPublicRanking = false
        )
    }

    fun feedbackForm(): FeedbackForm {
        return FeedbackForm(
            title = "English+ 內測回饋表",
            questions = listOf(
                FeedbackQuestion("student", "今天的任務有沒有讓你知道下一步要做什麼？", "choice + short text"),
                FeedbackQuestion("student", "答錯後的回饋是否有幫助你繼續練習？", "choice + short text"),
                FeedbackQuestion("teacher", "老師端是否能快速看出哪位學生需要先接住？", "scale + note"),
                FeedbackQuestion("teacher", "學生詳情與回覆流程是否足夠清楚？", "scale + note"),
                FeedbackQuestion("volunteer", "志工端的陪伴腳本與接力摘要是否足以開始協助學生？", "scale + note")
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
                "built-in or AI message felt low-pressure",
                "sync/report state was understandable",
                "question bank level and skill were understandable"
            )
        )
    }
}
