package tw.edu.citizenaction.soracompanion.qa

data class DeploymentDecision(
    val id: String,
    val label: String,
    val owner: String,
    val userDecision: String,
    val implementationHandoff: String,
    val requiredForPublicLaunch: Boolean
)

data class BackendHandoffGate(
    val readyForProductionBackend: Boolean,
    val blockers: List<String>,
    val nextAction: String
)

data class SecurityRuleRequirement(
    val role: String,
    val allowedReads: List<String>,
    val allowedWrites: List<String>,
    val serverCheck: String
)

data class BackendEndpointSpec(
    val action: String,
    val method: String,
    val path: String,
    val requiredHeaders: List<String>,
    val requestFields: List<String>,
    val responseFields: List<String>,
    val authRequired: Boolean,
    val allowedRoles: List<String>,
    val description: String
)

data class BackendPayloadExample(
    val action: String,
    val schemaVersion: Int,
    val jsonBody: String,
    val validationNote: String
)

data class DeploymentRunbookStep(
    val order: Int,
    val title: String,
    val owner: String,
    val acceptanceCheck: String
)

object ProductionDeploymentContract {
    const val PRODUCTION_DEPLOYMENT_SCHEMA_VERSION = 2

    fun deploymentDecisionMatrix(): List<DeploymentDecision> {
        return listOf(
            DeploymentDecision(
                id = "auth-provider",
                label = "正式登入來源",
                owner = "user-or-school",
                userDecision = "選擇 Firebase、Google Sign-In 或校內帳號作為正式登入來源。",
                implementationHandoff = "提供專案設定、OAuth 允許網域、Android package name 與角色 claims 格式。",
                requiredForPublicLaunch = true
            ),
            DeploymentDecision(
                id = "cloud-database",
                label = "班級雲端資料庫",
                owner = "school",
                userDecision = "決定使用 Firestore、校內後端或其他 HTTPS 服務保存班級資料。",
                implementationHandoff = "提供同步 endpoint、資料保留政策、班級代碼格式與服務端錯誤回應格式。",
                requiredForPublicLaunch = true
            ),
            DeploymentDecision(
                id = "ai-proxy",
                label = "安全 AI 代理",
                owner = "team",
                userDecision = "決定 AI 請求由後端代理送出，手機不保存正式金鑰。",
                implementationHandoff = "提供 HTTPS proxy endpoint、允許的任務類型、速率限制與審計紀錄欄位。",
                requiredForPublicLaunch = true
            ),
            DeploymentDecision(
                id = "security-rules",
                label = "角色權限規則",
                owner = "school",
                userDecision = "確認學生、老師、志工能讀寫哪些班級資料。",
                implementationHandoff = "在後端用帳號 claims 驗證角色，不信任手機畫面或手動傳入的角色文字。",
                requiredForPublicLaunch = true
            ),
            DeploymentDecision(
                id = "question-bank-source",
                label = "正式題庫來源",
                owner = "user",
                userDecision = "確認會考難度題庫、授權與後續維護者。",
                implementationHandoff = "提供題目匯入格式、審題流程、版本欄位與撤題規則。",
                requiredForPublicLaunch = true
            ),
            DeploymentDecision(
                id = "release-signing",
                label = "上架簽章",
                owner = "user",
                userDecision = "建立並保存正式 release keystore，決定由誰負責 Play Console 發布。",
                implementationHandoff = "提供簽章流程、AAB 產物、測試名單與版本說明。",
                requiredForPublicLaunch = true
            )
        )
    }

    fun backendHandoffGate(
        authEndpoint: String,
        cloudEndpoint: String,
        aiProxyEndpoint: String,
        hasGoogleServicesJson: Boolean,
        hasRoleClaims: Boolean,
        hasPrivacyPolicyUrl: Boolean,
        hasServerHeldAiKey: Boolean,
        mobileStoresProductionKey: Boolean
    ): BackendHandoffGate {
        val blockers = buildList {
            if (!isProductionHttpsEndpoint(authEndpoint)) add("auth endpoint must use HTTPS")
            if (!isProductionHttpsEndpoint(cloudEndpoint)) add("cloud endpoint must use HTTPS")
            if (!isProductionHttpsEndpoint(aiProxyEndpoint)) add("AI proxy endpoint")
            if (!hasGoogleServicesJson) add("google-services.json")
            if (!hasRoleClaims) add("role claims")
            if (!hasPrivacyPolicyUrl) add("privacy policy URL")
            if (!hasServerHeldAiKey) add("server-held AI key")
            if (mobileStoresProductionKey) add("production AI key must not be stored on mobile")
        }
        val nextAction = when {
            mobileStoresProductionKey -> "先把正式 AI 金鑰移到後端代理，再開啟公開測試。"
            blockers.isEmpty() -> "可以進入正式後端連線測試與小規模封閉內測。"
            else -> "先補齊 ${blockers.joinToString("、")}，再接正式後端。"
        }
        return BackendHandoffGate(
            readyForProductionBackend = blockers.isEmpty(),
            blockers = blockers,
            nextAction = nextAction
        )
    }

    fun securityRulesOutline(): List<SecurityRuleRequirement> {
        return listOf(
            SecurityRuleRequirement(
                role = "學生",
                allowedReads = listOf("own learning records", "own support thread", "assigned mission", "class question bank metadata"),
                allowedWrites = listOf("own learning events", "own mood check-in", "own help requests", "own mission completions"),
                serverCheck = "Server verifies auth.uid maps to the same student document and class before read or write."
            ),
            SecurityRuleRequirement(
                role = "老師",
                allowedReads = listOf("class roster", "student learning summaries", "collaboration notes", "reports", "question bank"),
                allowedWrites = listOf("teacher replies", "student support status", "question bank", "class reports"),
                serverCheck = "Server verifies teacher claim and class membership before class-scoped read or write."
            ),
            SecurityRuleRequirement(
                role = "志工",
                allowedReads = listOf("assigned handoff queue", "student support context", "mentor script", "sync status"),
                allowedWrites = listOf("handoff notes", "volunteer replies", "support completion state"),
                serverCheck = "Server verifies volunteer claim, assignment scope, and class membership before writing handoff records."
            )
        )
    }

    fun backendEndpointManifest(): List<BackendEndpointSpec> {
        return listOf(
            BackendEndpointSpec(
                action = "healthCheck",
                method = "GET",
                path = "/health",
                requiredHeaders = emptyList(),
                requestFields = emptyList(),
                responseFields = listOf("status", "schemaVersion", "serverTime"),
                authRequired = false,
                allowedRoles = emptyList(),
                description = "Verifies that the school backend is reachable before enabling remote flows."
            ),
            BackendEndpointSpec(
                action = "login",
                method = "POST",
                path = "/auth/login",
                requiredHeaders = listOf("Content-Type"),
                requestFields = listOf("schemaVersion", "app", "classCode", "account", "credentialProof", "provider"),
                responseFields = listOf("token", "displayName", "classCode", "roleClaims", "expiresAt"),
                authRequired = false,
                allowedRoles = emptyList(),
                description = "Exchanges a school account or identity proof for role claims used by English+."
            ),
            BackendEndpointSpec(
                action = "pushSync",
                method = "POST",
                path = "/sync/push",
                requiredHeaders = listOf("Authorization", "Content-Type"),
                requestFields = listOf("schemaVersion", "classId", "userId", "collections", "payload", "lastLocalUpdateAt"),
                responseFields = listOf("accepted", "serverCursor", "conflicts", "retryAfter"),
                authRequired = true,
                allowedRoles = listOf("學生", "老師", "志工"),
                description = "Uploads local learning, mission, and collaboration records to the class space."
            ),
            BackendEndpointSpec(
                action = "fetchSync",
                method = "POST",
                path = "/sync/fetch",
                requiredHeaders = listOf("Authorization", "Content-Type"),
                requestFields = listOf("schemaVersion", "classId", "userId", "cursor", "collections"),
                responseFields = listOf("serverCursor", "records", "deletedIds", "serverTime"),
                authRequired = true,
                allowedRoles = listOf("學生", "老師", "志工"),
                description = "Fetches class-scoped updates while respecting the user's role and assignment."
            ),
            BackendEndpointSpec(
                action = "aiSupport",
                method = "POST",
                path = "/ai/support",
                requiredHeaders = listOf("Authorization", "Content-Type"),
                requestFields = listOf("schemaVersion", "taskType", "role", "classId", "studentContext", "learningContext"),
                responseFields = listOf("message", "suggestedMission", "safetyFlags", "usedModel"),
                authRequired = true,
                allowedRoles = listOf("學生", "老師", "志工"),
                description = "Runs daily mission, wrong-answer, and support suggestions through a server-held model key."
            ),
            BackendEndpointSpec(
                action = "questionBankImport",
                method = "POST",
                path = "/question-bank/import",
                requiredHeaders = listOf("Authorization", "Content-Type"),
                requestFields = listOf("questionBankSchemaVersion", "classId", "importBatch", "items", "reviewState"),
                responseFields = listOf("acceptedCount", "rejectedCount", "reviewRequired", "importId"),
                authRequired = true,
                allowedRoles = listOf("老師"),
                description = "Lets teachers or content maintainers import reviewed English+ question sets."
            )
        )
    }

    fun backendPayloadExamples(): List<BackendPayloadExample> {
        return listOf(
            BackendPayloadExample(
                action = "deployment",
                schemaVersion = PRODUCTION_DEPLOYMENT_SCHEMA_VERSION,
                jsonBody = """{"schemaVersion":$PRODUCTION_DEPLOYMENT_SCHEMA_VERSION,"app":"English+","environment":"internal-test","androidPackage":"tw.edu.citizenaction.soracompanion"}""",
                validationNote = "Used by the team to verify that the backend and Android build agree on environment and package."
            ),
            BackendPayloadExample(
                action = "login",
                schemaVersion = PRODUCTION_DEPLOYMENT_SCHEMA_VERSION,
                jsonBody = """{"schemaVersion":$PRODUCTION_DEPLOYMENT_SCHEMA_VERSION,"app":"English+","classCode":"YILAN-8A","account":"student@example.edu","credentialProof":"one-time-code-or-provider-token","provider":"school"}""",
                validationNote = "Real credentials must be exchanged server-side and never stored in the sample."
            ),
            BackendPayloadExample(
                action = "pushSync",
                schemaVersion = PRODUCTION_DEPLOYMENT_SCHEMA_VERSION,
                jsonBody = """{"schemaVersion":4,"classId":"YILAN-8A","userId":"xiao-an","collections":["learningEvents","collaborationNotes"],"payload":{"records":[]},"lastLocalUpdateAt":1700000000000}""",
                validationNote = "Payload follows the app sync schema and must be authorized by class and role."
            ),
            BackendPayloadExample(
                action = "aiSupport",
                schemaVersion = PRODUCTION_DEPLOYMENT_SCHEMA_VERSION,
                jsonBody = """{"schemaVersion":$PRODUCTION_DEPLOYMENT_SCHEMA_VERSION,"taskType":"dailyMission","role":"學生","classId":"YILAN-8A","studentContext":{"mood":3,"minutes":5},"learningContext":{"preferredTypes":["克漏字","翻譯"]}}""",
                validationNote = "The server holds model credentials and returns only the generated learning support."
            ),
            BackendPayloadExample(
                action = "questionBankImport",
                schemaVersion = PRODUCTION_DEPLOYMENT_SCHEMA_VERSION,
                jsonBody = """{"questionBankSchemaVersion":3,"classId":"YILAN-8A","importBatch":"exam-style-001","items":[],"reviewState":"teacher-review"}""",
                validationNote = "Question sets require source review and teacher-only publish permission."
            )
        )
    }

    fun deploymentRunbook(): List<DeploymentRunbookStep> {
        return listOf(
            DeploymentRunbookStep(
                order = 1,
                title = "本機驗證與版本凍結",
                owner = "team",
                acceptanceCheck = "Gradle test, debug build, lint, and GitHub clean status all pass before external credentials are added."
            ),
            DeploymentRunbookStep(
                order = 2,
                title = "HTTPS 後端健康檢查",
                owner = "school",
                acceptanceCheck = "The /health endpoint returns schemaVersion, status, and serverTime over HTTPS."
            ),
            DeploymentRunbookStep(
                order = 3,
                title = "角色 claims 與班級權限",
                owner = "school",
                acceptanceCheck = "Student, teacher, and volunteer claims map to the same permissions as the tested contract."
            ),
            DeploymentRunbookStep(
                order = 4,
                title = "AI 後端代理",
                owner = "team",
                acceptanceCheck = "Model credentials stay on the server and the Android app receives only generated support text."
            ),
            DeploymentRunbookStep(
                order = 5,
                title = "封閉內測與回收機制",
                owner = "user",
                acceptanceCheck = "Internal testers, privacy contact, opt-out path, and rollback commit are documented before sharing the app."
            )
        )
    }

    private fun isProductionHttpsEndpoint(endpoint: String): Boolean {
        val value = endpoint.trim()
        return value.startsWith("https://") && value.length > "https://".length
    }
}
