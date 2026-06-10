package tw.edu.citizenaction.soracompanion.qa

enum class StudentDataType {
    LearningRecord,
    EmotionalSupport,
    CollaborationNote,
    AiSupportContext,
    AccountAndClass
}

data class StudentDataPolicy(
    val type: StudentDataType,
    val sensitive: Boolean,
    val purpose: String,
    val allowedViewers: List<String>,
    val visibleToOtherStudents: Boolean,
    val retentionRule: String
)

data class PublicComparisonGuardrail(
    val allowPublicRanking: Boolean,
    val blockedTerms: List<String>
) {
    fun isPublicCopyAllowed(copy: String): Boolean {
        return blockedTerms.none { copy.contains(it, ignoreCase = true) }
    }
}

data class DataRightsPolicy(
    val studentFacingCopy: String,
    val supportedActions: List<String>
)

data class ApiKeyCommitGuard(
    val productionKeyAllowedOnDevice: Boolean,
    val forbiddenPatterns: List<Regex>
) {
    fun isForbiddenSecret(value: String): Boolean {
        return forbiddenPatterns.any { it.containsMatchIn(value) }
    }
}

data class ConsentSection(
    val audience: String,
    val mustTellUser: String,
    val requiredConsentItems: List<String>
)

data class InternalTestConsentPacket(
    val summary: String,
    val sections: List<ConsentSection>
)

data class DataLifecycleAction(
    val actionId: String,
    val owner: String,
    val staffProcedure: String,
    val studentFacingResult: String,
    val deadlineDays: Int
)

data class PlayDataSafetyEntry(
    val dataType: StudentDataType,
    val sensitive: Boolean,
    val purpose: String,
    val sharedWith: List<String>,
    val retentionSummary: String
)

data class PlayDataSafetyDraft(
    val entries: List<PlayDataSafetyEntry>,
    val deletionPath: String,
    val contactRoute: String
)

object PrivacyGovernanceContract {
    const val PRIVACY_GOVERNANCE_SCHEMA_VERSION = 14

    fun dataCatalog(): List<StudentDataPolicy> {
        return listOf(
            StudentDataPolicy(
                type = StudentDataType.LearningRecord,
                sensitive = true,
                purpose = "記錄學生學習練習、錯題修復與任務完成情況。",
                allowedViewers = listOf("學生本人", "授課老師", "課程團隊"),
                visibleToOtherStudents = false,
                retentionRule = "內測結束後依學生、家長或學校要求匯出或刪除。"
            ),
            StudentDataPolicy(
                type = StudentDataType.EmotionalSupport,
                sensitive = true,
                purpose = "支持學生在英文卡關或情緒低落時被老師與志工接住。",
                allowedViewers = listOf("學生本人", "授課老師", "指定志工", "課程團隊"),
                visibleToOtherStudents = false,
                retentionRule = "只保留完成接力與安全照護所需內容。"
            ),
            StudentDataPolicy(
                type = StudentDataType.CollaborationNote,
                sensitive = true,
                purpose = "讓老師與志工接續處理學生求助與陪練紀錄。",
                allowedViewers = listOf("授課老師", "指定志工", "課程團隊"),
                visibleToOtherStudents = false,
                retentionRule = "依班級內測週期定期檢視與刪除。"
            ),
            StudentDataPolicy(
                type = StudentDataType.AiSupportContext,
                sensitive = true,
                purpose = "產生低壓提示、錯題詳解與每日任務建議。",
                allowedViewers = listOf("學生本人", "授課老師", "安全後端"),
                visibleToOtherStudents = false,
                retentionRule = "避免送出不必要個資，後端僅保留服務稽核所需紀錄。"
            ),
            StudentDataPolicy(
                type = StudentDataType.AccountAndClass,
                sensitive = false,
                purpose = "判斷學生、老師、志工角色與班級權限。",
                allowedViewers = listOf("學生本人", "授課老師", "課程團隊"),
                visibleToOtherStudents = false,
                retentionRule = "帳號停用時一併移除或匿名化。"
            )
        )
    }

    fun publicComparisonGuardrail(): PublicComparisonGuardrail {
        return PublicComparisonGuardrail(
            allowPublicRanking = false,
            blockedTerms = listOf("排行榜", "排名第", "全班排名", "第一名", "最後一名", "輸給")
        )
    }

    fun dataRightsPolicy(): DataRightsPolicy {
        return DataRightsPolicy(
            studentFacingCopy = "你可以向老師或課程團隊要求匯出自己的學習資料、刪除內測紀錄，或停止使用 English+。",
            supportedActions = listOf("request_export", "request_delete", "request_opt_out")
        )
    }

    fun apiKeyCommitGuard(): ApiKeyCommitGuard {
        return ApiKeyCommitGuard(
            productionKeyAllowedOnDevice = false,
            forbiddenPatterns = listOf(
                Regex("""sk-[A-Za-z0-9_\-]{10,}"""),
                Regex("""sk-or-v1-[A-Za-z0-9_\-]{6,}"""),
                Regex("""(?i)(openai|openrouter|api)_?key\s*=\s*['"]?[^'"\s]+""")
            )
        )
    }

    fun firebaseSecurityRequirements(): List<String> {
        return listOf(
            "Use Firebase Auth role claims to separate student, teacher, volunteer, and admin actions.",
            "Every learning record, support thread, and report must include classId for scoped reads.",
            "Student records must deny other students from reading emotional-support and answer history data.",
            "Teacher and volunteer writes must create an audit trail with actor id, role, target student, and timestamp.",
            "Cloud Functions should proxy AI calls so production API keys never ship in the Android app."
        )
    }

    fun internalTestConsentPacket(): InternalTestConsentPacket {
        return InternalTestConsentPacket(
            summary = "English+ 內測只收集完成學習支持所需資料；學生可退出，並可要求匯出或刪除內測紀錄。",
            sections = listOf(
                ConsentSection(
                    audience = "學生",
                    mustTellUser = "你會用 English+ 練英文、完成今日任務，也可以在卡住時請老師或志工協助。",
                    requiredConsentItems = listOf("知道會保存自己的練習紀錄", "知道可要求協助或停止使用", "知道不會公開和同學比較排名")
                ),
                ConsentSection(
                    audience = "家長/監護人",
                    mustTellUser = "本內測會保存孩子的學習進度、求助紀錄與老師回覆，用於課堂支持與專題評估。",
                    requiredConsentItems = listOf("同意參與內測", "知道可要求匯出或刪除資料", "知道資料不作公開排名")
                ),
                ConsentSection(
                    audience = "老師",
                    mustTellUser = "老師可查看班級學習狀態、學生求助與回覆紀錄，並需避免將敏感內容外流。",
                    requiredConsentItems = listOf("確認班級使用範圍", "確認資料最小化原則", "確認回覆與報告不揭露不必要個資")
                ),
                ConsentSection(
                    audience = "志工",
                    mustTellUser = "志工只查看被指派的陪練脈絡，留下接力紀錄，不處理班級行政或完整成績資料。",
                    requiredConsentItems = listOf("同意只使用指派資料", "同意不截取或外傳學生內容", "同意遵守接力腳本與保密原則")
                ),
                ConsentSection(
                    audience = "學校/課程團隊",
                    mustTellUser = "團隊需指定資料負責人、測試期間、刪除窗口與事故聯絡方式。",
                    requiredConsentItems = listOf("指定資料窗口", "確認測試起訖", "確認事故通報與刪除流程")
                )
            )
        )
    }

    fun dataLifecycleRunbook(): List<DataLifecycleAction> {
        return listOf(
            DataLifecycleAction(
                actionId = "export-student-data",
                owner = "課程團隊",
                staffProcedure = "確認申請人身分後，匯出該學生的學習紀錄、任務紀錄與支援串摘要。",
                studentFacingResult = "你會收到自己的學習資料摘要與可讀格式紀錄。",
                deadlineDays = 14
            ),
            DataLifecycleAction(
                actionId = "delete-test-records",
                owner = "學校管理者",
                staffProcedure = "確認刪除範圍，移除本機與雲端的內測紀錄，保留必要稽核摘要。",
                studentFacingResult = "你的內測紀錄會被刪除或匿名化，之後不再用於報告。",
                deadlineDays = 30
            ),
            DataLifecycleAction(
                actionId = "opt-out",
                owner = "老師",
                staffProcedure = "停止安排該學生使用 English+，並改用課堂既有紙本或口頭支持方式。",
                studentFacingResult = "你可以停止使用 English+，並改用老師安排的其他練習方式。",
                deadlineDays = 7
            ),
            DataLifecycleAction(
                actionId = "incident-review",
                owner = "課程團隊",
                staffProcedure = "凍結相關紀錄，通知資料窗口，檢查是否有未授權截圖、外傳或帳號誤用。",
                studentFacingResult = "若資料使用出現問題，老師或團隊會說明處理狀況與後續保護措施。",
                deadlineDays = 3
            )
        )
    }

    fun playDataSafetyDraft(): PlayDataSafetyDraft {
        return PlayDataSafetyDraft(
            entries = dataCatalog().map { policy ->
                PlayDataSafetyEntry(
                    dataType = policy.type,
                    sensitive = policy.sensitive,
                    purpose = policy.purpose,
                    sharedWith = when (policy.type) {
                        StudentDataType.AiSupportContext -> listOf("安全後端", "授課老師")
                        StudentDataType.EmotionalSupport -> listOf("授課老師", "指定志工", "課程團隊")
                        StudentDataType.CollaborationNote -> listOf("授課老師", "指定志工", "課程團隊")
                        StudentDataType.LearningRecord -> listOf("學生本人", "授課老師", "課程團隊")
                        StudentDataType.AccountAndClass -> listOf("學生本人", "授課老師", "課程團隊")
                    },
                    retentionSummary = policy.retentionRule
                )
            },
            deletionPath = "學生、家長或學校可向老師或課程團隊提出刪除內測紀錄要求。",
            contactRoute = "主要聯絡窗口為授課老師；正式上架前需補公開隱私政策網址與信箱。"
        )
    }
}
