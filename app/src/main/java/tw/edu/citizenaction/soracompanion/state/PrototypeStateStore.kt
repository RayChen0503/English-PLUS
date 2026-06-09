package tw.edu.citizenaction.soracompanion.state

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import tw.edu.citizenaction.soracompanion.auth.AuthContract
import tw.edu.citizenaction.soracompanion.auth.AuthSession
import tw.edu.citizenaction.soracompanion.ai.AiSecurityContract
import tw.edu.citizenaction.soracompanion.cloud.CloudDataContract
import tw.edu.citizenaction.soracompanion.cloud.CollaborationSyncContract
import tw.edu.citizenaction.soracompanion.cloud.QuestionBankContract
import tw.edu.citizenaction.soracompanion.model.AppState
import tw.edu.citizenaction.soracompanion.model.CollaborationNote
import tw.edu.citizenaction.soracompanion.model.LocalAccount
import tw.edu.citizenaction.soracompanion.model.Mood
import tw.edu.citizenaction.soracompanion.model.OfflineSyncItem
import tw.edu.citizenaction.soracompanion.model.Question
import tw.edu.citizenaction.soracompanion.model.QuestionBankItem
import tw.edu.citizenaction.soracompanion.storage.EnglishPlusDatabase
import tw.edu.citizenaction.soracompanion.storage.LearningEvent
import tw.edu.citizenaction.soracompanion.storage.StorageSnapshot

class PrototypeStateStore(context: Context) {
    private val prefs = context.getSharedPreferences("sora_companion_state", Context.MODE_PRIVATE)
    private val database = EnglishPlusDatabase(context.applicationContext)

    fun load(): AppState {
        database.loadState()?.let { return it }
        val migrated = loadLegacyPrefs()
        database.saveState(migrated)
        database.addLearningEvent(
            LearningEvent(
                type = "migration",
                title = "已建立本機資料庫",
                detail = "從舊版展示狀態建立 English+ SQLite 本機資料。"
            )
        )
        return migrated
    }

    fun save(state: AppState) {
        database.saveState(state)
    }

    fun recordEvent(type: String, title: String, detail: String) {
        database.addLearningEvent(LearningEvent(type, title, detail))
    }

    fun localAccounts(defaultAccounts: List<LocalAccount>): List<LocalAccount> {
        return database.loadAccounts(defaultAccounts)
    }

    fun markAccountUsed(displayName: String) {
        database.markAccountUsed(displayName)
    }

    fun saveRemoteAuthEndpoint(url: String) {
        prefs.edit().putString("remote_auth_endpoint", url.trim()).apply()
    }

    fun remoteAuthEndpoint(): String {
        return prefs.getString("remote_auth_endpoint", "")?.trim().orEmpty()
    }

    fun hasRemoteAuthEndpoint(): Boolean {
        val url = remoteAuthEndpoint()
        return AuthContract.isValidEndpoint(url)
    }

    fun saveAuthSession(session: AuthSession) {
        val roleLabel = AuthContract.normalizeRole(session.roleLabel)
        val tokenPreview = if (session.token.length > 8) {
            "${session.token.take(4)}...${session.token.takeLast(4)}"
        } else if (session.token.isBlank()) {
            "未回傳 token"
        } else {
            "已保存"
        }
        prefs.edit()
            .putString("remote_auth_display_name", session.displayName)
            .putString("remote_auth_role_label", roleLabel)
            .putString("remote_auth_class_code", session.classCode)
            .putString("remote_auth_token", session.token)
            .putString("remote_auth_token_preview", tokenPreview)
            .putString("remote_auth_provider", session.provider)
            .apply()
        database.saveAccount(
            LocalAccount(
                displayName = session.displayName,
                roleLabel = roleLabel,
                classCode = session.classCode,
                loginState = "雲端登入：${session.provider} / $tokenPreview"
            )
        )
    }

    fun authSessionSummary(): String {
        val name = prefs.getString("remote_auth_display_name", "")?.trim().orEmpty()
        if (name.isBlank()) return "尚未完成雲端登入"
        val role = prefs.getString("remote_auth_role_label", "")?.trim().orEmpty()
        val classCode = prefs.getString("remote_auth_class_code", "")?.trim().orEmpty()
        val token = prefs.getString("remote_auth_token_preview", "")?.trim().orEmpty()
        val provider = prefs.getString("remote_auth_provider", "")?.trim().orEmpty()
        return "$name｜$role\n$classCode\n$provider｜$token"
    }

    fun addCollaborationNote(note: CollaborationNote) {
        database.addCollaborationNote(note)
    }

    fun addCollaborationNotes(notes: List<CollaborationNote>) {
        notes.forEach { database.addCollaborationNote(it) }
    }

    fun addUniqueCollaborationNotes(notes: List<CollaborationNote>): Int {
        val existingKeys = database.loadCollaborationNotes(200)
            .map { it.collaborationKey() }
            .toMutableSet()
        var importedCount = 0
        notes.forEach { note ->
            val key = note.collaborationKey()
            if (!existingKeys.contains(key)) {
                database.addCollaborationNote(note)
                existingKeys.add(key)
                importedCount += 1
            }
        }
        return importedCount
    }

    fun collaborationNotes(limit: Int = 12): List<CollaborationNote> {
        return database.loadCollaborationNotes(limit)
    }

    fun collaborationPayload(classCode: String): JSONObject {
        val state = load()
        val accounts = database.loadAccounts(emptyList())
        val selectedAccount = accounts.firstOrNull { it.displayName == state.selectedAccountName }
        val scope = CloudDataContract.buildScope(
            classCode = selectedAccount?.classCode ?: classCode,
            accountName = state.selectedAccountName,
            roleLabel = selectedAccount?.roleLabel ?: AuthContract.ROLE_STUDENT
        )
        val metadata = CollaborationSyncContract.buildCollaborationSyncMetadata(scope, pushFirst = true)
        return JSONObject()
            .put("schemaVersion", CloudDataContract.SCHEMA_VERSION)
            .put("collaborationSchemaVersion", CollaborationSyncContract.COLLABORATION_SCHEMA_VERSION)
            .put("app", "English+")
            .put("classCode", classCode)
            .put("classId", scope.classId)
            .put("userId", scope.userId)
            .put("roleLabel", scope.roleLabel)
            .put("collectionPath", scope.collaborationCollectionPath)
            .put("syncMetadata", JSONObject(metadata))
            .put("exportedAt", System.currentTimeMillis())
            .put("collaborationNotes", JSONArray(database.loadCollaborationNotes(30).map { note ->
                JSONObject()
                    .put("eventId", CollaborationSyncContract.eventId(note))
                    .put("actor", note.actor)
                    .put("role", note.role)
                    .put("target", note.target)
                    .put("note", note.note)
                    .put("status", note.status)
                    .put("createdAt", note.createdAt)
            }))
    }

    fun addOfflineSyncItem(item: OfflineSyncItem) {
        database.addOfflineSyncItem(item)
    }

    fun offlineSyncItems(limit: Int = 16): List<OfflineSyncItem> {
        return database.loadOfflineSyncItems(limit)
    }

    fun seedQuestionBank(items: List<QuestionBankItem>) {
        database.seedQuestionBank(items)
    }

    fun questionBankItems(limit: Int = 1_500): List<QuestionBankItem> {
        return database.loadQuestionBank(limit)
    }

    fun questionBankQuestions(): List<Question> {
        return database.loadQuestionBank(1_500).map { it.question }
    }

    fun markOfflineSyncItemsSynced() {
        database.markOfflineSyncItemsSynced()
    }

    fun pendingSyncCount(): Int = database.pendingSyncCount()

    fun downloadedPackTitles(): Set<String> = database.downloadedPackTitles()

    fun saveCloudBackendUrl(url: String) {
        prefs.edit().putString("cloud_backend_url", url.trim()).apply()
    }

    fun cloudBackendUrl(): String {
        return prefs.getString("cloud_backend_url", "")?.trim().orEmpty()
    }

    fun hasCloudBackend(): Boolean {
        val url = cloudBackendUrl()
        return url.startsWith("https://") || url.startsWith("http://")
    }

    fun cloudSyncPayload(deviceLabel: String): JSONObject {
        val state = load()
        val snapshot = storageSnapshot()
        val accounts = database.loadAccounts(emptyList())
        val selectedAccount = accounts.firstOrNull { it.displayName == state.selectedAccountName }
        val scope = CloudDataContract.buildScope(
            classCode = selectedAccount?.classCode ?: deviceLabel,
            accountName = state.selectedAccountName,
            roleLabel = selectedAccount?.roleLabel ?: AuthContract.ROLE_STUDENT
        )
        val metadata = CloudDataContract.buildSyncMetadata(scope, deviceLabel)
        val questionBankItems = database.loadQuestionBank()
        val questionBankMetadata = QuestionBankContract.buildQuestionBankMetadata(scope, questionBankItems)
        val payload = JSONObject()
            .put("schemaVersion", CloudDataContract.SCHEMA_VERSION)
            .put("questionBankSchemaVersion", QuestionBankContract.QUESTION_BANK_SCHEMA_VERSION)
            .put("app", "English+")
            .put("deviceLabel", deviceLabel)
            .put("classId", scope.classId)
            .put("userId", scope.userId)
            .put("roleLabel", scope.roleLabel)
            .put("cloudPaths", JSONObject()
                .put("class", scope.classDocumentPath)
                .put("student", scope.studentDocumentPath)
                .put("collaboration", scope.collaborationCollectionPath)
                .put("questionBank", scope.questionBankCollectionPath)
            )
            .put("collections", JSONArray(CloudDataContract.syncedCollections))
            .put("metadata", JSONObject(metadata))
            .put("questionBankMetadata", JSONObject(questionBankMetadata))
            .put("exportedAt", System.currentTimeMillis())
            .put(
                "state",
                JSONObject()
                    .put("mood", state.mood.label)
                    .put("minutes", state.minutes)
                    .put("confidence", state.confidence)
                    .put("completedTasks", state.completedTasks)
                    .put("currentQuestionIndex", state.currentQuestionIndex)
                    .put("selectedAccountName", state.selectedAccountName)
                    .put("mentorReplyCount", state.mentorReplyCount)
                    .put("repairedMistakeCount", state.repairedMistakeCount)
                    .put("customTaskCount", state.customTaskCount)
            )
            .put(
                "snapshot",
                JSONObject()
                    .put("eventCount", snapshot.eventCount)
                    .put("collaborationCount", snapshot.collaborationCount)
                    .put("pendingSyncCount", snapshot.pendingSyncCount)
                    .put("downloadedPackCount", snapshot.downloadedPackCount)
                    .put("latestEventTitle", snapshot.latestEventTitle)
            )
            .put("learningEvents", JSONArray(database.loadLearningEvents().map { event ->
                JSONObject()
                    .put("type", event.type)
                    .put("title", event.title)
                    .put("detail", event.detail)
                    .put("createdAt", event.createdAt)
            }))
            .put("questionBank", JSONArray(questionBankItems.map { item ->
                JSONObject()
                    .put("importId", QuestionBankContract.importId(scope, item))
                    .put("id", item.id)
                    .put("level", item.level)
                    .put("unit", item.unit)
                    .put("skill", item.skill)
                    .put("source", item.source)
                    .put("reviewState", item.reviewState)
                    .put("importBatchId", item.importBatchId)
                    .put("prompt", item.question.prompt)
                    .put("options", JSONArray(item.question.options))
                    .put("answer", item.question.answer)
                    .put("explanation", item.question.explanation)
                    .put("concept", item.question.concept)
                    .put("type", item.question.type)
                    .put("repairHint", item.question.repairHint)
                    .put("updatedAt", item.updatedAt)
            }))
            .put("collaborationNotes", JSONArray(database.loadCollaborationNotes().map { note ->
                JSONObject()
                    .put("actor", note.actor)
                    .put("role", note.role)
                    .put("target", note.target)
                    .put("note", note.note)
                    .put("status", note.status)
                    .put("createdAt", note.createdAt)
            }))
            .put("offlineSyncItems", JSONArray(database.loadOfflineSyncItems().map { item ->
                JSONObject()
                    .put("title", item.title)
                    .put("category", item.category)
                    .put("detail", item.detail)
                    .put("status", item.status)
                    .put("updatedAt", item.updatedAt)
            }))
        return payload
    }

    fun saveOpenAiApiKey(apiKey: String) {
        prefs.edit().putString("openai_api_key", apiKey.trim()).apply()
    }

    fun openAiApiKey(): String {
        return prefs.getString("openai_api_key", "")?.trim().orEmpty()
    }

    fun hasOpenAiApiKey(): Boolean = openAiApiKey().startsWith("sk-")

    fun aiSecurityDecision(productionMode: Boolean = true) =
        AiSecurityContract.evaluate(aiProxyEndpoint(), openAiApiKey(), productionMode)

    fun saveAiProxyEndpoint(url: String) {
        prefs.edit().putString("ai_proxy_endpoint", url.trim()).apply()
    }

    fun aiProxyEndpoint(): String {
        return prefs.getString("ai_proxy_endpoint", "")?.trim().orEmpty()
    }

    fun hasAiProxyEndpoint(): Boolean {
        val url = aiProxyEndpoint()
        return url.startsWith("https://") || url.startsWith("http://")
    }

    fun storageSnapshot(): StorageSnapshot = database.snapshot()

    private fun loadLegacyPrefs(): AppState {
        val moodName = prefs.getString("mood", Mood.Okay.name) ?: Mood.Okay.name
        val mood = Mood.values().firstOrNull { it.name == moodName } ?: Mood.Okay
        return AppState(
            mood = mood,
            minutes = prefs.getInt("minutes", mood.defaultMinutes),
            confidence = prefs.getInt("confidence", 46),
            completedTasks = prefs.getInt("completedTasks", 3),
            currentQuestionIndex = prefs.getInt("currentQuestionIndex", 0),
            actionDoneCount = prefs.getInt("actionDoneCount", 0),
            managedStudentCount = prefs.getInt("managedStudentCount", 5),
            offlinePendingCount = prefs.getInt("offlinePendingCount", 1),
            selectedAccountName = prefs.getString("selectedAccountName", "林家豪") ?: "林家豪",
            mentorReplyCount = prefs.getInt("mentorReplyCount", 0),
            learningEventCount = prefs.getInt("learningEventCount", 0),
            repairedMistakeCount = prefs.getInt("repairedMistakeCount", 0),
            customTaskCount = prefs.getInt("customTaskCount", 0)
        )
    }

    private fun CollaborationNote.collaborationKey(): String {
        return CollaborationSyncContract.eventId(this)
    }
}
