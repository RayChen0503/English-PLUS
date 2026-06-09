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

object PrivacyGovernanceContract {
    const val PRIVACY_GOVERNANCE_SCHEMA_VERSION = 13

    fun dataCatalog(): List<StudentDataPolicy> {
        return listOf(
            StudentDataPolicy(
                type = StudentDataType.LearningRecord,
                sensitive = true,
                purpose = "記錄學生練習、錯題修復與任務完成情況。",
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
}
