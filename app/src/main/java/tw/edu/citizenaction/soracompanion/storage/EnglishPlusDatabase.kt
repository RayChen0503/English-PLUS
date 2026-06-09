package tw.edu.citizenaction.soracompanion.storage

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import tw.edu.citizenaction.soracompanion.model.AppState
import tw.edu.citizenaction.soracompanion.model.CollaborationNote
import tw.edu.citizenaction.soracompanion.model.LocalAccount
import tw.edu.citizenaction.soracompanion.model.Mood
import tw.edu.citizenaction.soracompanion.model.OfflineSyncItem
import tw.edu.citizenaction.soracompanion.model.Question
import tw.edu.citizenaction.soracompanion.model.QuestionBankItem

data class LearningEvent(
    val type: String,
    val title: String,
    val detail: String,
    val createdAt: Long = System.currentTimeMillis()
)

data class StorageSnapshot(
    val stateSaved: Boolean,
    val eventCount: Int,
    val latestEventTitle: String,
    val collaborationCount: Int = 0,
    val pendingSyncCount: Int = 0,
    val downloadedPackCount: Int = 0
)

class EnglishPlusDatabase(context: Context) : SQLiteOpenHelper(context, DB_NAME, null, DB_VERSION) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE app_state (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                mood TEXT NOT NULL,
                minutes INTEGER NOT NULL,
                confidence INTEGER NOT NULL,
                completed_tasks INTEGER NOT NULL,
                current_question_index INTEGER NOT NULL,
                action_done_count INTEGER NOT NULL,
                managed_student_count INTEGER NOT NULL,
                offline_pending_count INTEGER NOT NULL,
                selected_account_name TEXT NOT NULL,
                mentor_reply_count INTEGER NOT NULL,
                learning_event_count INTEGER NOT NULL,
                repaired_mistake_count INTEGER NOT NULL,
                custom_task_count INTEGER NOT NULL,
                updated_at INTEGER NOT NULL
            )
            """.trimIndent()
        )
        db.execSQL(
            """
            CREATE TABLE learning_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL,
                title TEXT NOT NULL,
                detail TEXT NOT NULL,
                created_at INTEGER NOT NULL
            )
            """.trimIndent()
        )
        createLocalAccountsTable(db)
        createCollaborationNotesTable(db)
        createOfflineSyncItemsTable(db)
        createQuestionBankTable(db)
    }

    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion < 2) {
            db.execSQL(
                """
                CREATE TABLE IF NOT EXISTS learning_events (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    type TEXT NOT NULL,
                    title TEXT NOT NULL,
                    detail TEXT NOT NULL,
                    created_at INTEGER NOT NULL
                )
                """.trimIndent()
            )
        }
        if (oldVersion < 3) {
            createLocalAccountsTable(db)
        }
        if (oldVersion < 4) {
            createCollaborationNotesTable(db)
        }
        if (oldVersion < 5) {
            createOfflineSyncItemsTable(db)
        }
        if (oldVersion < 6) {
            createQuestionBankTable(db)
        }
        if (oldVersion < 7) {
            addQuestionBankColumn(db, "review_state TEXT NOT NULL DEFAULT 'draft'")
            addQuestionBankColumn(db, "import_batch_id TEXT NOT NULL DEFAULT 'seed'")
        }
    }

    private fun createLocalAccountsTable(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS local_accounts (
                display_name TEXT PRIMARY KEY,
                role_label TEXT NOT NULL,
                class_code TEXT NOT NULL,
                login_state TEXT NOT NULL,
                last_used_at INTEGER NOT NULL DEFAULT 0
            )
            """.trimIndent()
        )
    }

    private fun createCollaborationNotesTable(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS collaboration_notes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                actor TEXT NOT NULL,
                role TEXT NOT NULL,
                target TEXT NOT NULL,
                note TEXT NOT NULL,
                status TEXT NOT NULL,
                created_at INTEGER NOT NULL
            )
            """.trimIndent()
        )
    }

    private fun createOfflineSyncItemsTable(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS offline_sync_items (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                category TEXT NOT NULL,
                detail TEXT NOT NULL,
                status TEXT NOT NULL,
                updated_at INTEGER NOT NULL
            )
            """.trimIndent()
        )
    }

    private fun createQuestionBankTable(db: SQLiteDatabase) {
        db.execSQL(
            """
            CREATE TABLE IF NOT EXISTS question_bank (
                id TEXT PRIMARY KEY,
                level TEXT NOT NULL,
                unit TEXT NOT NULL,
                skill TEXT NOT NULL,
                source TEXT NOT NULL,
                prompt TEXT NOT NULL,
                options TEXT NOT NULL,
                answer TEXT NOT NULL,
                explanation TEXT NOT NULL,
                concept TEXT NOT NULL,
                type TEXT NOT NULL,
                repair_hint TEXT NOT NULL,
                review_state TEXT NOT NULL DEFAULT 'draft',
                import_batch_id TEXT NOT NULL DEFAULT 'seed',
                updated_at INTEGER NOT NULL
            )
            """.trimIndent()
        )
    }

    private fun addQuestionBankColumn(db: SQLiteDatabase, columnSql: String) {
        try {
            db.execSQL("ALTER TABLE question_bank ADD COLUMN $columnSql")
        } catch (_: Exception) {
            // Existing installs may already have the column after a partial migration.
        }
    }

    fun loadState(): AppState? {
        readableDatabase.query(
            "app_state",
            null,
            "id = 1",
            null,
            null,
            null,
            null
        ).use { cursor ->
            if (!cursor.moveToFirst()) return null
            val moodName = cursor.getString(cursor.getColumnIndexOrThrow("mood"))
            val mood = Mood.values().firstOrNull { it.name == moodName } ?: Mood.Okay
            return AppState(
                mood = mood,
                minutes = cursor.getInt(cursor.getColumnIndexOrThrow("minutes")),
                confidence = cursor.getInt(cursor.getColumnIndexOrThrow("confidence")),
                completedTasks = cursor.getInt(cursor.getColumnIndexOrThrow("completed_tasks")),
                currentQuestionIndex = cursor.getInt(cursor.getColumnIndexOrThrow("current_question_index")),
                actionDoneCount = cursor.getInt(cursor.getColumnIndexOrThrow("action_done_count")),
                managedStudentCount = cursor.getInt(cursor.getColumnIndexOrThrow("managed_student_count")),
                offlinePendingCount = cursor.getInt(cursor.getColumnIndexOrThrow("offline_pending_count")),
                selectedAccountName = cursor.getString(cursor.getColumnIndexOrThrow("selected_account_name")),
                mentorReplyCount = cursor.getInt(cursor.getColumnIndexOrThrow("mentor_reply_count")),
                learningEventCount = cursor.getInt(cursor.getColumnIndexOrThrow("learning_event_count")),
                repairedMistakeCount = cursor.getInt(cursor.getColumnIndexOrThrow("repaired_mistake_count")),
                customTaskCount = cursor.getInt(cursor.getColumnIndexOrThrow("custom_task_count"))
            )
        }
    }

    fun saveState(state: AppState) {
        val values = ContentValues().apply {
            put("id", 1)
            put("mood", state.mood.name)
            put("minutes", state.minutes)
            put("confidence", state.confidence)
            put("completed_tasks", state.completedTasks)
            put("current_question_index", state.currentQuestionIndex)
            put("action_done_count", state.actionDoneCount)
            put("managed_student_count", state.managedStudentCount)
            put("offline_pending_count", state.offlinePendingCount)
            put("selected_account_name", state.selectedAccountName)
            put("mentor_reply_count", state.mentorReplyCount)
            put("learning_event_count", state.learningEventCount)
            put("repaired_mistake_count", state.repairedMistakeCount)
            put("custom_task_count", state.customTaskCount)
            put("updated_at", System.currentTimeMillis())
        }
        writableDatabase.insertWithOnConflict("app_state", null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun addLearningEvent(event: LearningEvent) {
        val values = ContentValues().apply {
            put("type", event.type)
            put("title", event.title)
            put("detail", event.detail)
            put("created_at", event.createdAt)
        }
        writableDatabase.insert("learning_events", null, values)
    }

    fun seedAccounts(defaultAccounts: List<LocalAccount>) {
        val db = writableDatabase
        defaultAccounts.forEach { account ->
            val values = ContentValues().apply {
                put("display_name", account.displayName)
                put("role_label", account.roleLabel)
                put("class_code", account.classCode)
                put("login_state", account.loginState)
                put("last_used_at", 0L)
            }
            db.insertWithOnConflict("local_accounts", null, values, SQLiteDatabase.CONFLICT_REPLACE)
        }
    }

    fun loadAccounts(defaultAccounts: List<LocalAccount>): List<LocalAccount> {
        seedAccounts(defaultAccounts)
        return readableDatabase.query(
            "local_accounts",
            arrayOf("display_name", "role_label", "class_code", "login_state"),
            null,
            null,
            null,
            null,
            "role_label ASC, display_name ASC"
        ).use { cursor ->
            val accounts = mutableListOf<LocalAccount>()
            while (cursor.moveToNext()) {
                accounts.add(
                    LocalAccount(
                        displayName = cursor.getString(cursor.getColumnIndexOrThrow("display_name")),
                        roleLabel = cursor.getString(cursor.getColumnIndexOrThrow("role_label")),
                        classCode = cursor.getString(cursor.getColumnIndexOrThrow("class_code")),
                        loginState = cursor.getString(cursor.getColumnIndexOrThrow("login_state"))
                    )
                )
            }
            accounts.ifEmpty { defaultAccounts }
        }
    }

    fun markAccountUsed(displayName: String) {
        val values = ContentValues().apply {
            put("last_used_at", System.currentTimeMillis())
        }
        writableDatabase.update("local_accounts", values, "display_name = ?", arrayOf(displayName))
    }

    fun saveAccount(account: LocalAccount) {
        val values = ContentValues().apply {
            put("display_name", account.displayName)
            put("role_label", account.roleLabel)
            put("class_code", account.classCode)
            put("login_state", account.loginState)
            put("last_used_at", System.currentTimeMillis())
        }
        writableDatabase.insertWithOnConflict("local_accounts", null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun addCollaborationNote(note: CollaborationNote) {
        val values = ContentValues().apply {
            put("actor", note.actor)
            put("role", note.role)
            put("target", note.target)
            put("note", note.note)
            put("status", note.status)
            put("created_at", note.createdAt)
        }
        writableDatabase.insert("collaboration_notes", null, values)
    }

    fun loadCollaborationNotes(limit: Int = 12): List<CollaborationNote> {
        return readableDatabase.query(
            "collaboration_notes",
            arrayOf("actor", "role", "target", "note", "status", "created_at"),
            null,
            null,
            null,
            null,
            "created_at DESC, id DESC",
            limit.toString()
        ).use { cursor ->
            val notes = mutableListOf<CollaborationNote>()
            while (cursor.moveToNext()) {
                notes.add(
                    CollaborationNote(
                        actor = cursor.getString(cursor.getColumnIndexOrThrow("actor")),
                        role = cursor.getString(cursor.getColumnIndexOrThrow("role")),
                        target = cursor.getString(cursor.getColumnIndexOrThrow("target")),
                        note = cursor.getString(cursor.getColumnIndexOrThrow("note")),
                        status = cursor.getString(cursor.getColumnIndexOrThrow("status")),
                        createdAt = cursor.getLong(cursor.getColumnIndexOrThrow("created_at"))
                    )
                )
            }
            notes
        }
    }

    fun addOfflineSyncItem(item: OfflineSyncItem) {
        val values = ContentValues().apply {
            put("title", item.title)
            put("category", item.category)
            put("detail", item.detail)
            put("status", item.status)
            put("updated_at", item.updatedAt)
        }
        writableDatabase.insert("offline_sync_items", null, values)
    }

    fun loadOfflineSyncItems(limit: Int = 16): List<OfflineSyncItem> {
        return readableDatabase.query(
            "offline_sync_items",
            arrayOf("title", "category", "detail", "status", "updated_at"),
            null,
            null,
            null,
            null,
            "updated_at DESC, id DESC",
            limit.toString()
        ).use { cursor ->
            val items = mutableListOf<OfflineSyncItem>()
            while (cursor.moveToNext()) {
                items.add(
                    OfflineSyncItem(
                        title = cursor.getString(cursor.getColumnIndexOrThrow("title")),
                        category = cursor.getString(cursor.getColumnIndexOrThrow("category")),
                        detail = cursor.getString(cursor.getColumnIndexOrThrow("detail")),
                        status = cursor.getString(cursor.getColumnIndexOrThrow("status")),
                        updatedAt = cursor.getLong(cursor.getColumnIndexOrThrow("updated_at"))
                    )
                )
            }
            items
        }
    }

    fun seedQuestionBank(items: List<QuestionBankItem>) {
        if (questionBankCount() >= items.size) return
        items.forEach { saveQuestionBankItem(it) }
    }

    fun saveQuestionBankItem(item: QuestionBankItem) {
        val values = ContentValues().apply {
            put("id", item.id)
            put("level", item.level)
            put("unit", item.unit)
            put("skill", item.skill)
            put("source", item.source)
            put("prompt", item.question.prompt)
            put("options", item.question.options.joinToString("||"))
            put("answer", item.question.answer)
            put("explanation", item.question.explanation)
            put("concept", item.question.concept)
            put("type", item.question.type)
            put("repair_hint", item.question.repairHint)
            put("review_state", item.reviewState)
            put("import_batch_id", item.importBatchId)
            put("updated_at", item.updatedAt)
        }
        writableDatabase.insertWithOnConflict("question_bank", null, values, SQLiteDatabase.CONFLICT_REPLACE)
    }

    fun loadQuestionBank(limit: Int = 1_500): List<QuestionBankItem> {
        return readableDatabase.query(
            "question_bank",
            arrayOf("id", "level", "unit", "skill", "source", "prompt", "options", "answer", "explanation", "concept", "type", "repair_hint", "review_state", "import_batch_id", "updated_at"),
            null,
            null,
            null,
            null,
            "level ASC, unit ASC, skill ASC, id ASC",
            limit.toString()
        ).use { cursor ->
            val items = mutableListOf<QuestionBankItem>()
            while (cursor.moveToNext()) {
                items.add(
                    QuestionBankItem(
                        id = cursor.getString(cursor.getColumnIndexOrThrow("id")),
                        level = cursor.getString(cursor.getColumnIndexOrThrow("level")),
                        unit = cursor.getString(cursor.getColumnIndexOrThrow("unit")),
                        skill = cursor.getString(cursor.getColumnIndexOrThrow("skill")),
                        source = cursor.getString(cursor.getColumnIndexOrThrow("source")),
                        question = Question(
                            prompt = cursor.getString(cursor.getColumnIndexOrThrow("prompt")),
                            options = cursor.getString(cursor.getColumnIndexOrThrow("options")).split("||"),
                            answer = cursor.getString(cursor.getColumnIndexOrThrow("answer")),
                            explanation = cursor.getString(cursor.getColumnIndexOrThrow("explanation")),
                            concept = cursor.getString(cursor.getColumnIndexOrThrow("concept")),
                            type = cursor.getString(cursor.getColumnIndexOrThrow("type")),
                            repairHint = cursor.getString(cursor.getColumnIndexOrThrow("repair_hint"))
                        ),
                        updatedAt = cursor.getLong(cursor.getColumnIndexOrThrow("updated_at")),
                        reviewState = cursor.getString(cursor.getColumnIndexOrThrow("review_state")),
                        importBatchId = cursor.getString(cursor.getColumnIndexOrThrow("import_batch_id"))
                    )
                )
            }
            items
        }
    }

    fun loadLearningEvents(limit: Int = 20): List<LearningEvent> {
        return readableDatabase.query(
            "learning_events",
            arrayOf("type", "title", "detail", "created_at"),
            null,
            null,
            null,
            null,
            "created_at DESC, id DESC",
            limit.toString()
        ).use { cursor ->
            val events = mutableListOf<LearningEvent>()
            while (cursor.moveToNext()) {
                events.add(
                    LearningEvent(
                        type = cursor.getString(cursor.getColumnIndexOrThrow("type")),
                        title = cursor.getString(cursor.getColumnIndexOrThrow("title")),
                        detail = cursor.getString(cursor.getColumnIndexOrThrow("detail")),
                        createdAt = cursor.getLong(cursor.getColumnIndexOrThrow("created_at"))
                    )
                )
            }
            events
        }
    }

    fun markOfflineSyncItemsSynced() {
        val values = ContentValues().apply {
            put("status", "已同步")
            put("updated_at", System.currentTimeMillis())
        }
        writableDatabase.update("offline_sync_items", values, "status != ?", arrayOf("已下載"))
    }

    fun pendingSyncCount(): Int {
        return readableDatabase.rawQuery(
            "SELECT COUNT(*) FROM offline_sync_items WHERE status != ? AND status != ?",
            arrayOf("已同步", "已下載")
        ).use { cursor ->
            if (cursor.moveToFirst()) cursor.getInt(0) else 0
        }
    }

    fun downloadedPackTitles(): Set<String> {
        return readableDatabase.rawQuery(
            "SELECT DISTINCT title FROM offline_sync_items WHERE category = ? AND status = ?",
            arrayOf("離線任務包", "已下載")
        ).use { cursor ->
            val titles = mutableSetOf<String>()
            while (cursor.moveToNext()) titles.add(cursor.getString(0))
            titles
        }
    }

    private fun accountCount(): Int {
        return readableDatabase.rawQuery("SELECT COUNT(*) FROM local_accounts", null).use { cursor ->
            if (cursor.moveToFirst()) cursor.getInt(0) else 0
        }
    }

    private fun questionBankCount(): Int {
        return readableDatabase.rawQuery("SELECT COUNT(*) FROM question_bank", null).use { cursor ->
            if (cursor.moveToFirst()) cursor.getInt(0) else 0
        }
    }

    fun snapshot(): StorageSnapshot {
        val stateSaved = loadState() != null
        val eventCount = readableDatabase.rawQuery("SELECT COUNT(*) FROM learning_events", null).use { cursor ->
            if (cursor.moveToFirst()) cursor.getInt(0) else 0
        }
        val latest = readableDatabase.rawQuery(
            "SELECT title FROM learning_events ORDER BY created_at DESC, id DESC LIMIT 1",
            null
        ).use { cursor ->
            if (cursor.moveToFirst()) cursor.getString(0) else "尚未寫入事件"
        }
        val collaborationCount = readableDatabase.rawQuery("SELECT COUNT(*) FROM collaboration_notes", null).use { cursor ->
            if (cursor.moveToFirst()) cursor.getInt(0) else 0
        }
        val pendingSyncCount = pendingSyncCount()
        val downloadedPackCount = downloadedPackTitles().size
        return StorageSnapshot(stateSaved, eventCount, latest, collaborationCount, pendingSyncCount, downloadedPackCount)
    }

    companion object {
        private const val DB_NAME = "english_plus_local.db"
        private const val DB_VERSION = 7
    }
}
