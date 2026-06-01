package tw.edu.citizenaction.soracompanion

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Bundle
import android.text.InputType
import android.view.Gravity
import android.view.View
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.ScrollView
import java.io.File
import org.json.JSONArray
import org.json.JSONObject
import tw.edu.citizenaction.soracompanion.ai.AiSupportResult
import tw.edu.citizenaction.soracompanion.ai.AiProxyClient
import tw.edu.citizenaction.soracompanion.ai.OpenAiClient
import tw.edu.citizenaction.soracompanion.auth.AuthClient
import tw.edu.citizenaction.soracompanion.auth.AuthContract
import tw.edu.citizenaction.soracompanion.auth.AuthSession
import tw.edu.citizenaction.soracompanion.cloud.CloudBackendClient
import tw.edu.citizenaction.soracompanion.cloud.CloudSyncResult
import tw.edu.citizenaction.soracompanion.cloud.QuestionBankContract
import tw.edu.citizenaction.soracompanion.data.PrototypeRepository
import tw.edu.citizenaction.soracompanion.model.ActionItem
import tw.edu.citizenaction.soracompanion.model.AiScenario
import tw.edu.citizenaction.soracompanion.model.AppState
import tw.edu.citizenaction.soracompanion.model.Breakpoint
import tw.edu.citizenaction.soracompanion.model.CollaborationNote
import tw.edu.citizenaction.soracompanion.model.DesignPrinciple
import tw.edu.citizenaction.soracompanion.model.InterventionStep
import tw.edu.citizenaction.soracompanion.model.JourneyStep
import tw.edu.citizenaction.soracompanion.model.LearningContract
import tw.edu.citizenaction.soracompanion.model.LearningModule
import tw.edu.citizenaction.soracompanion.model.LocalAccount
import tw.edu.citizenaction.soracompanion.model.Metric
import tw.edu.citizenaction.soracompanion.model.MistakeRecord
import tw.edu.citizenaction.soracompanion.model.MentorCheck
import tw.edu.citizenaction.soracompanion.model.Mood
import tw.edu.citizenaction.soracompanion.model.OfflinePack
import tw.edu.citizenaction.soracompanion.model.OfflineSyncItem
import tw.edu.citizenaction.soracompanion.model.HandoffPriority
import tw.edu.citizenaction.soracompanion.model.HelpRequestOption
import tw.edu.citizenaction.soracompanion.model.Question
import tw.edu.citizenaction.soracompanion.model.QuestionBankItem
import tw.edu.citizenaction.soracompanion.model.ReflectionPrompt
import tw.edu.citizenaction.soracompanion.model.Role
import tw.edu.citizenaction.soracompanion.model.Screen
import tw.edu.citizenaction.soracompanion.model.StudyTask
import tw.edu.citizenaction.soracompanion.model.StudentRow
import tw.edu.citizenaction.soracompanion.model.SyncRecord
import tw.edu.citizenaction.soracompanion.model.SupportMessage
import tw.edu.citizenaction.soracompanion.model.TeacherAction
import tw.edu.citizenaction.soracompanion.model.WeeklySignal
import tw.edu.citizenaction.soracompanion.state.PrototypeStateStore
import tw.edu.citizenaction.soracompanion.ui.UiKit
import tw.edu.citizenaction.soracompanion.ui.UiKit.ColorToken

class MainActivity : Activity() {
    private lateinit var root: LinearLayout
    private lateinit var ui: UiKit
    private lateinit var stateStore: PrototypeStateStore

    private var role = Role.Student
    private var screen = Screen.Home
    private var mood = Mood.Okay
    private var minutes = 5
    private var wrongAttempts = 0
    private var currentQuestionIndex = 0
    private var completedTasks = 3
    private var confidence = 46
    private var actionDoneCount = 0
    private var managedStudentCount = 5
    private var offlinePendingCount = 1
    private var selectedAccountName = "小安"
    private var mentorReplyCount = 0
    private var learningEventCount = 0
    private var repairedMistakeCount = 0
    private var customTaskCount = 0
    private var lastAnswerMessage = "還沒有作答，先從一題短任務開始。"
    private var lastSelectedAnswer = ""
    private var checkInCompleted = false
    private var practiceTimeConfirmed = false

    private val student = PrototypeRepository.student
    private val modules = PrototypeRepository.modules
    private var questions = PrototypeRepository.questions
    private val roster = PrototypeRepository.roster
    private val studyTasks = PrototypeRepository.studyTasks
    private val supportMessages = PrototypeRepository.supportMessages
    private val weeklySignals = PrototypeRepository.weeklySignals
    private val mistakeRecords = PrototypeRepository.mistakeRecords
    private val offlinePacks = PrototypeRepository.offlinePacks
    private val mentorChecks = PrototypeRepository.mentorChecks
    private val handoffPriorities = PrototypeRepository.handoffPriorities
    private val journeySteps = PrototypeRepository.journeySteps
    private val interventionSteps = PrototypeRepository.interventionSteps
    private val designPrinciples = PrototypeRepository.designPrinciples
    private val helpRequestOptions = PrototypeRepository.helpRequestOptions
    private val learningContracts = PrototypeRepository.learningContracts
    private val reflectionPrompts = PrototypeRepository.reflectionPrompts
    private val teacherActions = PrototypeRepository.teacherActions
    private val syncRecords = PrototypeRepository.syncRecords
    private val defaultAccounts = PrototypeRepository.localAccounts
    private val aiScenarios = PrototypeRepository.aiScenarios
    private val breakpoints: MutableList<Breakpoint> = PrototypeRepository.initialBreakpoints()
    private var collaborationNotes: List<CollaborationNote> = emptyList()
    private var offlineSyncItems: List<OfflineSyncItem> = emptyList()
    private var downloadedPackTitles: Set<String> = emptySet()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ui = UiKit(this)
        stateStore = PrototypeStateStore(this)
        restoreState()
        renderRoleGateway()
    }

    private fun restoreState() {
        stateStore.seedQuestionBank(PrototypeRepository.questionBankItems)
        questions = stateStore.questionBankQuestions().ifEmpty { PrototypeRepository.questions }
        val saved = stateStore.load()
        mood = saved.mood
        minutes = saved.minutes
        confidence = saved.confidence
        completedTasks = saved.completedTasks
        currentQuestionIndex = saved.currentQuestionIndex.coerceIn(0, questions.lastIndex)
        actionDoneCount = saved.actionDoneCount
        managedStudentCount = saved.managedStudentCount
        offlinePendingCount = saved.offlinePendingCount
        selectedAccountName = saved.selectedAccountName
        role = if (AuthContract.isStudentRole(currentAccount().roleLabel)) Role.Student else Role.Mentor
        mentorReplyCount = saved.mentorReplyCount
        learningEventCount = saved.learningEventCount
        repairedMistakeCount = saved.repairedMistakeCount
        customTaskCount = saved.customTaskCount
        collaborationNotes = stateStore.collaborationNotes()
        refreshOfflineSyncState()
    }

    private fun persistState() {
        stateStore.save(AppState(mood, minutes, confidence, completedTasks, currentQuestionIndex, actionDoneCount, managedStudentCount, offlinePendingCount, selectedAccountName, mentorReplyCount, learningEventCount, repairedMistakeCount, customTaskCount))
    }

    private fun recordLearningEvent(type: String, title: String, detail: String) {
        stateStore.recordEvent(type, title, detail)
    }

    private fun addCollaborationNote(actor: String, roleLabel: String, target: String, note: String, status: String) {
        stateStore.addCollaborationNote(
            CollaborationNote(
                actor = actor,
                role = roleLabel,
                target = target,
                note = note,
                status = status
            )
        )
        collaborationNotes = stateStore.collaborationNotes()
        stateStore.addOfflineSyncItem(
            OfflineSyncItem(
                title = "協作紀錄：$target",
                category = "真人接力",
                detail = note,
                status = "待上傳"
            )
        )
        refreshOfflineSyncState()
        learningEventCount += 1
        recordLearningEvent("collaboration", "$actor 更新 $target", note)
        persistState()
    }

    private fun addOfflineSyncItem(title: String, category: String, detail: String, status: String = "待上傳") {
        stateStore.addOfflineSyncItem(OfflineSyncItem(title, category, detail, status))
        refreshOfflineSyncState()
        persistState()
    }

    private fun refreshOfflineSyncState() {
        offlineSyncItems = stateStore.offlineSyncItems()
        downloadedPackTitles = stateStore.downloadedPackTitles()
        offlinePendingCount = stateStore.pendingSyncCount()
    }

    private fun isNetworkAvailable(): Boolean {
        val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = manager.activeNetwork ?: return false
        val capabilities = manager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private fun syncReadinessText(): String {
        val networkText = if (isNetworkAvailable()) "網路可用" else "目前離線"
        val backendText = if (stateStore.hasCloudBackend()) "後端端點已設定" else "尚未設定後端端點"
        val pendingText = "待補傳 $offlinePendingCount 筆"
        return "$networkText\n$backendText\n$pendingText"
    }

    private fun accountList(): List<LocalAccount> = stateStore.localAccounts(defaultAccounts)

    private fun currentAccount(): LocalAccount {
        return accountList().firstOrNull { it.displayName == selectedAccountName }
            ?: accountList().first()
    }

    private fun selectAccount(account: LocalAccount) {
        selectedAccountName = account.displayName
        role = if (AuthContract.isStudentRole(account.roleLabel)) Role.Student else Role.Mentor
        stateStore.markAccountUsed(account.displayName)
        persistState()
        recordLearningEvent("account_login", "切換登入：${account.displayName}", "角色：${account.roleLabel}｜班級/群組：${account.classCode}")
    }

    private fun resetStudentFlow() {
        checkInCompleted = false
        practiceTimeConfirmed = false
    }

    private fun renderStudentTaskEntry() {
        when {
            !checkInCompleted -> renderCheckIn()
            !practiceTimeConfirmed -> renderPracticeTimeSetup()
            else -> renderTaskQueue()
        }
    }

    private fun renderStudentSupportEntry() {
        if (!checkInCompleted) renderCheckIn() else renderBreakpoints()
    }

    private fun renderStudentMapEntry() {
        if (!practiceTimeConfirmed) renderPracticeTimeSetup() else renderMap()
    }

    private fun renderRoleGateway() {
        screen = Screen.Home
        shell("English+", "先選擇今天的使用身分")
        hero("今天你要用哪一端？", "學生端先接住情緒，再進入短練習；老師/志工端先看需要接力的學生與下一步。")
        root.addView(roleEntryCard(
            label = "學生端",
            title = "我今天要練英文",
            detail = "進入後會先做一個很短的情緒檢測。完成後，才會出現今日任務、作題時間和學習地圖。",
            fill = ColorToken.PrimarySoft,
            actionText = "進入學生端"
        ) {
            val studentAccount = accountList().firstOrNull { AuthContract.isStudentRole(it.roleLabel) } ?: currentAccount()
            selectAccount(studentAccount)
            resetStudentFlow()
            renderHome()
        })
        root.addView(roleEntryCard(
            label = "老師/志工端",
            title = "我要看學生狀態",
            detail = "這裡是接力工作台，只顯示班級訊號、需要關懷的學生、陪伴建議與任務指派，不混用學生學習地圖。",
            fill = ColorToken.SuccessSoft,
            actionText = "進入老師/志工端"
        ) {
            val mentorAccount = accountList().firstOrNull { AuthContract.isStaffRole(it.roleLabel) } ?: currentAccount()
            selectAccount(mentorAccount)
            resetStudentFlow()
            renderHome()
        })
        root.addView(card("目前展示帳號", "${currentAccount().displayName}｜${currentAccount().roleLabel}\n也可以進入後到帳號中心切換班級或登入方式。", ColorToken.Card))
        root.addView(ui.secondaryButton("帳號與班級資料") { renderAccountCenter() })
    }

    private fun renderHome() {
        screen = Screen.Home
        shell("English+", if (role == Role.Student) "學生端" else "老師/志工端")
        if (role == Role.Student) {
            hero("先完成心情檢測", "English+ 會先知道你今天的狀態，再安排作題時間與英文短任務。")
        } else {
            hero("先看需要接力的人", "老師/志工端聚焦班級訊號、學生卡點與下一步陪伴，不顯示學生個人學習地圖。")
        }
        if (role == Role.Student) {
            studentHome()
        } else {
            mentorHome()
            bottomNav()
        }
    }

    private fun studentHome() {
        root.addView(classContextCard())
        root.addView(studentFirstStepCard())
        root.addView(flowStrip("心情檢測", "選練習時間", "開始短任務", "答題回饋"))
        root.addView(lockedStudentPreviewCard())
        section("學生端只保留自己的事")
        root.addView(card("這裡不顯示老師工作台", "學生端首頁先處理「我今天能不能開始」。學習地圖、錯題與支援會在完成心情檢測後，依序出現在練習流程裡。", ColorToken.PrimarySoft))
        root.addView(ui.secondaryButton("帳號與班級資料") { renderAccountCenter() })
        root.addView(ui.secondaryButton("回到身分選擇") { renderRoleGateway() })
    }

    private fun mentorHome() {
        root.addView(classContextCard())
        root.addView(mentorDailyCommandCard())
        root.addView(mentorPriorityStudentCard())
        root.addView(mentorWorkflowCard())
        section("今天的工作入口")
        root.addView(actionGrid(
            ActionItem("學生證據", "先看誰需要介入") { renderTeacherLearningEvidence() },
            ActionItem("待辦處理", "照順序完成接力") { renderActionQueue() },
            ActionItem("協作同步", "確認雲端與本機") { renderSyncCenter() },
            ActionItem("週報摘要", "回看班級趨勢") { renderWeeklyReport() }
        ))
        section("本週班級訊號")
        weeklySignals.take(3).forEach { root.addView(signalCard(it)) }
        root.addView(mentorOperationsSummaryCard())
        root.addView(ui.secondaryButton("回到身分選擇") { renderRoleGateway() })
    }

    private fun renderProfile() {
        screen = Screen.Profile
        shell("學生學習檔案", "讓老師更快理解學生，而不是只看分數")
        root.addView(card("基本資料", "${student.name}｜${student.age} 歲｜${student.location}｜${student.grade}\n目標：${student.goal}", ColorToken.PrimarySoft))
        root.addView(card("限制條件", student.constraint, ColorToken.WarningSoft))
        root.addView(card("學習偏好", student.learningStyle, ColorToken.SuccessSoft))
        root.addView(card("支持需求", student.supportNeed, ColorToken.VioletSoft))
        root.addView(ui.primaryButton("依照檔案產生今日任務") { renderTaskQueue() })
        bottomNav()
    }

    private fun renderAccountCenter() {
        screen = Screen.Account
        val account = currentAccount()
        shell("登入與班級資料", "本機展示帳號與雲端登入可並存")
        root.addView(card("目前登入", "${account.displayName}｜${account.roleLabel}\n班級/群組：${account.classCode}\n${account.loginState}", ColorToken.PrimarySoft))
        root.addView(accountReadinessCard())
        root.addView(remoteAuthStatusCard())
        root.addView(remoteAuthLoginCard())
        accountList().forEach { root.addView(accountCard(it)) }
        root.addView(ui.secondaryButton("切換到老師/志工端") {
            val teacher = accountList().firstOrNull { AuthContract.isStaffRole(it.roleLabel) } ?: account
            selectAccount(teacher)
            renderHome()
        })
        bottomNav()
    }

    private fun renderRemoteLoginProgress(username: String, password: String, classCode: String) {
        screen = Screen.Account
        val endpoint = stateStore.remoteAuthEndpoint()
        if (!stateStore.hasRemoteAuthEndpoint()) {
            shell("尚未設定正式登入端點", "先貼上 Firebase Auth 包裝 API 或校內登入 API")
            root.addView(card("目前狀態", "沒有登入端點時，系統仍使用本機展示帳號。", ColorToken.WarningSoft))
            root.addView(remoteAuthLoginCard())
            root.addView(ui.secondaryButton("回帳號中心") { renderAccountCenter() })
            bottomNav()
            return
        }
        shell("正在登入", "呼叫正式登入端點驗證帳號")
        root.addView(card("登入端點", endpoint, ColorToken.PrimarySoft))
        root.addView(card("登入帳號", "$username\n班級/群組：${classCode.ifBlank { "未填" }}", ColorToken.Card))
        bottomNav()

        Thread {
            try {
                val session = AuthClient(endpoint).login(username, password, classCode)
                runOnUiThread { renderRemoteLoginSuccess(session) }
            } catch (error: Exception) {
                runOnUiThread { renderRemoteLoginFailure(error.message ?: "未知錯誤") }
            }
        }.start()
    }

    private fun renderRemoteLoginSuccess(session: AuthSession) {
        stateStore.saveAuthSession(session)
        selectedAccountName = session.displayName
        role = if (AuthContract.isStudentRole(session.roleLabel)) Role.Student else Role.Mentor
        persistState()
        addOfflineSyncItem("雲端登入成功：${session.displayName}", "正式登入", "角色 ${session.roleLabel} / 班級 ${session.classCode}", "已同步")
        recordLearningEvent("remote_login", "雲端登入成功", "${session.displayName} / ${session.roleLabel} / ${session.classCode}")
        shell("雲端登入成功", "正式帳號已寫入本機帳號清單")
        root.addView(card("登入結果", stateStore.authSessionSummary(), ColorToken.SuccessSoft))
        root.addView(ui.primaryButton("進入首頁") { renderHome() })
        root.addView(ui.secondaryButton("回帳號中心") { renderAccountCenter() })
        bottomNav()
    }

    private fun renderRemoteLoginFailure(message: String) {
        recordLearningEvent("remote_login_failed", "雲端登入失敗", message)
        shell("雲端登入失敗", "本機展示帳號仍可使用")
        root.addView(card("錯誤訊息", message, ColorToken.WarningSoft))
        root.addView(card("備援策略", "正式版可以在這裡加入 Firebase Auth、Google 登入或校內 SSO。現在先保留本機帳號，避免展示流程中斷。", ColorToken.Card))
        root.addView(ui.primaryButton("回帳號中心") { renderAccountCenter() })
        bottomNav()
    }

    private fun roleLabel(): String = if (role == Role.Student) "學生端" else "老師/志工端"

    private fun renderLearningContract() {
        screen = Screen.Contract
        shell("今日學習契約", "先約定任務邊界，再開始學習")
        root.addView(card("為什麼需要契約？", "偏鄉學生常遇到時間零碎、挫折累積、求助成本高。學習契約讓學生知道今天只要做到哪裡，也讓老師知道平台不會用排行榜或大量題目壓迫學生。", ColorToken.PrimarySoft))
        learningContracts.forEach { root.addView(contractCard(it)) }
        root.addView(ui.primaryButton("我接受今天的低壓任務") { renderTaskQueue() })
        root.addView(ui.secondaryButton("先做心情檢測") { renderCheckIn() })
        bottomNav()
    }

    private fun renderJourney() {
        screen = Screen.Journey
        shell("完整使用旅程", "從不敢開始，到完成修復，再回到學習")
        root.addView(card("這不是一般題庫流程", "English+ 的主流程不是「打開就考試」，而是先判斷學生能不能承受今天的任務，再決定 AI 或真人要在哪裡介入。", ColorToken.PrimarySoft))
        journeySteps.forEachIndexed { index, item ->
            root.addView(journeyCard(index + 1, item))
        }
        root.addView(ui.primaryButton("查看情緒斷點處理流程") { renderInterventionFlow() })
        root.addView(ui.secondaryButton("回今日任務") { renderTaskQueue() })
        bottomNav()
    }

    private fun renderInterventionFlow() {
        screen = Screen.Intervention
        shell("情緒斷點處理流程", "把挫折訊號轉成可以被修復的設計動作")
        root.addView(card("斷點不是失敗", "平台要避免學生因為一次錯題就離開，所以每個斷點都要有觸發條件、介入動作、學生看得懂的語句，以及可交給老師的證據。", ColorToken.WarningSoft))
        interventionSteps.forEach { root.addView(interventionCard(it)) }
        root.addView(ui.primaryButton("生成志工接力摘要") { renderHandoff() })
        bottomNav()
    }

    private fun renderDesignPrinciples() {
        screen = Screen.Mentor
        shell("產品設計原則", "把課程提案翻成可被檢核的功能")
        root.addView(card("v0.6 檢核方向", "這頁用來確認我們做的不是單純英文練習 app，而是面向偏鄉學生、情緒斷點與雙軌接力的學習平台。", ColorToken.PrimarySoft))
        designPrinciples.forEach { root.addView(principleCard(it)) }
        root.addView(ui.secondaryButton("查看 English+ 設計系統") { renderDesignSystem() })
        root.addView(ui.primaryButton("查看 OPPM 品質檢核") { renderMentorChecks() })
        bottomNav()
    }

    private fun renderDesignSystem() {
        screen = Screen.DesignSystem
        shell("English+ 設計系統", "把目前 UI 收斂成可檢查、可延伸、可交接的產品規格")
        root.addView(card(
            "設計方向",
            "English+ 不是考試壓力型題庫，而是低壓、清楚、有接力感的偏鄉英語學習工具。所有畫面先讓學生知道今天做什麼，再讓老師與志工看見可行動的證據。",
            ColorToken.PrimarySoft
        ))
        root.addView(metricRow(
            Metric("圓角", "8dp", ColorToken.Primary),
            Metric("基準間距", "8pt", ColorToken.Success),
            Metric("觸控高度", "48+", ColorToken.Accent)
        ))
        section("色彩 token")
        root.addView(designTokenCard("Ink", ColorToken.Ink, "主要標題與重要資訊，避免整頁太淡而失去方向感。", ColorToken.Ink))
        root.addView(designTokenCard("Primary", ColorToken.Primary, "主要行動、目前所在狀態、可繼續前進的提示。", ColorToken.Primary))
        root.addView(designTokenCard("Accent", ColorToken.Accent, "時間、節奏、短任務提醒，不當作危險警示使用。", ColorToken.Accent))
        root.addView(designTokenCard("Success / Warning / Danger", "${ColorToken.Success} / ${ColorToken.Warning} / ${ColorToken.Danger}", "用於學習修復、待追蹤、需要真人接力的狀態。", ColorToken.Success))
        section("字級與資訊層級")
        root.addView(designSpecCard("Screen title", "28sp bold", "每頁只保留一個主標題，回答使用者現在在哪裡。", ColorToken.PrimarySoft))
        root.addView(designSpecCard("Card title", "17-20sp bold", "卡片標題要能單獨掃讀，讓老師快速找出斷點與下一步。", ColorToken.Card))
        root.addView(designSpecCard("Body copy", "15sp / line +4dp", "學生端文字保持短句，避免大段說明造成第二次挫折。", ColorToken.Card))
        section("元件規格")
        root.addView(designSpecCard("Primary button", "52dp min height", "只放最推薦的下一步，例如開始任務、生成摘要、匯出報告。", ColorToken.PrimarySoft))
        root.addView(designSpecCard("Secondary button", "48dp min height", "用於替代路徑與回到前一個工作區，不搶走主行動。", ColorToken.Card))
        root.addView(designSpecCard("Status pill", "12sp / soft fill", "標示狀態，不用長句解釋功能；顏色要對應真實風險。", ColorToken.SuccessSoft))
        root.addView(designSpecCard("Information card", "20dp padding", "一張卡只承載一個判斷：情緒、任務、斷點、接力或報告證據。", ColorToken.Card))
        section("螢幕檢核清單")
        root.addView(card(
            "手機優先",
            "先檢查 360dp 與 412dp 寬度：按鈕文字不能截斷、底部導覽不能擠壓、卡片不能互相包卡片、長中文要能自然換行。",
            ColorToken.WarningSoft
        ))
        root.addView(card(
            "產品一致性",
            "學生端維持低壓與短任務；老師/志工端維持證據、接力、追蹤。任何新功能都要先判斷放在哪一軌，不混在同一張卡裡。",
            ColorToken.VioletSoft
        ))
        root.addView(ui.primaryButton("回產品設計原則") { renderDesignPrinciples() })
        root.addView(ui.secondaryButton("回首頁") { renderHome() })
        bottomNav()
    }

    private fun renderTaskQueue() {
        if (role == Role.Student && !checkInCompleted) {
            renderCheckIn()
            return
        }
        if (role == Role.Student && !practiceTimeConfirmed) {
            renderPracticeTimeSetup()
            return
        }
        screen = Screen.Lesson
        shell("今天先做這個", "把英文練習縮到現在做得到的一小步")
        root.addView(currentTaskFocus())
        root.addView(taskRouteCard())
        root.addView(ui.secondaryButton("查看今日學習契約") { renderLearningContract() })
        section("做完第一步後")
        studyTasks.drop(1).forEach { root.addView(taskCard(it)) }
        if (customTaskCount > 0) {
            section("老師新增任務")
            repeat(customTaskCount) { index ->
                root.addView(taskCard(StudyTask("志工接力任務 ${index + 1}", 3, "低", "由老師端依斷點新增，完成後會回寫週報。", "老師指派")))
            }
        }
        root.addView(ui.secondaryButton("新增一個低壓自訂任務") {
            customTaskCount += 1
            addOfflineSyncItem("老師新增低壓任務", "任務設定", "新增 1 個志工接力低壓任務，待同步到老師端。")
            persistState()
            renderTaskQueue()
        })
        root.addView(ui.primaryButton("開始第一個任務") { renderLesson() })
        bottomNav()
    }

    private fun renderCheckIn() {
        screen = Screen.CheckIn
        shell("心情與時間檢測", "從狀態開始，而不是一進來就考試")
        root.addView(checkInIntroCard())
        section("今天的狀態")
        Mood.values().forEach { item ->
            root.addView(moodChoiceCard(item.label, item.description, item.color, item == mood) {
                mood = item
                minutes = item.defaultMinutes
                confidence = (confidence + item.confidenceDelta).coerceIn(0, 100)
                persistState()
                renderCheckIn()
            })
        }
        root.addView(selectedMoodResponse())
        root.addView(checkInGateCard())
        root.addView(ui.primaryButton("完成心情檢測，下一步選時間") {
            checkInCompleted = true
            persistState()
            renderPracticeTimeSetup()
        })
        root.addView(ui.secondaryButton("先回學生首頁") { renderHome() })
        bottomNav()
    }

    private fun renderPracticeTimeSetup() {
        screen = Screen.CheckIn
        shell("選擇今天練習時間", "先決定做多久，再開始作題")
        root.addView(practiceTimeIntroCard())
        section("今天能用多久？")
        listOf(3, 5, 8, 12).forEach { value ->
            root.addView(durationChoice(value, value == minutes) {
                minutes = value
                persistState()
                renderPracticeTimeSetup()
            })
        }
        root.addView(planPreviewCard())
        root.addView(ui.primaryButton("確認時間，查看今日任務") {
            practiceTimeConfirmed = true
            persistState()
            renderTaskQueue()
        })
        root.addView(ui.secondaryButton("回心情檢測調整狀態") {
            checkInCompleted = false
            practiceTimeConfirmed = false
            renderCheckIn()
        })
        bottomNav()
    }

    private fun renderLesson() {
        screen = Screen.Lesson
        val q = questions[currentQuestionIndex]
        shell("今日短任務", "一題一概念，避免二度挫折")
        root.addView(lessonFocusCard())
        root.addView(questionCard(q))
        root.addView(lessonSupportCard())
        root.addView(lessonExitCard())
        root.addView(ui.secondaryButton("我想直接求助") { renderHelpRequest() })
        root.addView(ui.secondaryButton("改做復原任務") { renderRecoveryMode() })
        bottomNav()
    }

    private fun renderRecoveryMode() {
        screen = Screen.Lesson
        shell("復原任務", "狀態不好時也能完成的一小步")
        root.addView(card("為什麼切換？", "當心情低落或連續答錯時，平台會把原本任務縮成更小的復原任務，避免直接退出。", ColorToken.WarningSoft))
        root.addView(card("復原任務內容", "只判斷一件事：He 要搭配 is。\n完成後就可以休息，也會算進學習地圖。", ColorToken.PrimarySoft))
        root.addView(ui.primaryButton("完成復原任務") {
            completedTasks += 1
            confidence = (confidence + 2).coerceAtMost(100)
            persistState()
            renderSuccess(questions.first())
        })
        root.addView(ui.secondaryButton("交給志工接力") { renderHelpRequest() })
        bottomNav()
    }

    private fun answer(option: String) {
        val q = questions[currentQuestionIndex]
        if (option == q.answer) {
            completedTasks += 1
            confidence = (confidence + 4).coerceAtMost(100)
            learningEventCount += 1
            if (wrongAttempts > 0) repairedMistakeCount += 1
            wrongAttempts = 0
            lastSelectedAnswer = option
            lastAnswerMessage = "答對了：${q.explanation}"
            currentQuestionIndex = (currentQuestionIndex + 1) % questions.size
            addOfflineSyncItem("答題完成：${q.concept}", "學習事件", q.explanation)
            persistState()
            recordLearningEvent("answer_correct", "完成微任務：${q.concept}", q.explanation)
            renderSuccess(q)
        } else {
            wrongAttempts += 1
            confidence = (confidence - 1).coerceAtLeast(0)
            learningEventCount += 1
            lastSelectedAnswer = option
            lastAnswerMessage = "你選了 $option。${q.explanation}"
            addOfflineSyncItem("答題卡住：${q.concept}", "學習事件", "學生選擇 $option，需要保留修復提示。")
            persistState()
            recordLearningEvent("answer_wrong", "答題卡住：${q.concept}", "學生選擇 $option；平台保留修復提示與支持出口。")
            if (wrongAttempts >= 3) {
                breakpoints.add(0, Breakpoint("今日新斷點：${q.concept}", "高", "同一題連續答錯 3 次", "AI 已停止加題並改派修復任務。", "請志工用同一概念帶 2 題，不追加作業。"))
                wrongAttempts = 0
                renderBreakpoints()
            } else {
                renderAiCoach()
            }
        }
    }

    private fun renderSuccess(q: Question) {
        screen = Screen.Lesson
        shell("答對了", "先確認結果，再決定下一步")
        root.addView(successSummaryCard(q))
        root.addView(card("下一步", "系統會把這次成功記錄為「句型修復」進度，不需要一次補完整章。", ColorToken.PrimarySoft))
        root.addView(ui.primaryButton("做一個 20 秒反思") { renderReflection() })
        root.addView(ui.primaryButton("繼續下一題") { renderLesson() })
        root.addView(ui.secondaryButton("回學習地圖") { renderMap() })
        bottomNav()
    }

    private fun renderReflection() {
        screen = Screen.Reflection
        shell("課後 20 秒反思", "把完成感留下來，而不是只留下分數")
        root.addView(card("反思目的", "這不是檢討，而是讓學生把今天完成的那一小步說清楚。老師端之後看到的也會是修復證據，而不只是錯題。", ColorToken.SuccessSoft))
        reflectionPrompts.forEach { root.addView(reflectionCard(it)) }
        root.addView(ui.secondaryButton("略過，回學習地圖") { renderMap() })
        bottomNav()
    }

    private fun handleReflection(prompt: ReflectionPrompt) {
        confidence = (confidence + prompt.confidenceDelta).coerceIn(0, 100)
        lastAnswerMessage = prompt.platformResponse
        learningEventCount += 1
        addOfflineSyncItem("課後反思：${prompt.title}", "反思紀錄", prompt.studentChoice)
        persistState()
        recordLearningEvent("reflection", prompt.title, prompt.studentChoice)
        renderReflectionSaved(prompt)
    }

    private fun renderReflectionSaved(prompt: ReflectionPrompt) {
        screen = Screen.Reflection
        shell("反思已保存", "把今天的小進步放回週報")
        root.addView(card("學生選擇", prompt.studentChoice, ColorToken.PrimarySoft))
        root.addView(card("平台回應", prompt.platformResponse, ColorToken.SuccessSoft))
        root.addView(card("目前信心值", "$confidence%｜下次會從同一個斷點繼續，而不是直接加難度。", ColorToken.Card))
        root.addView(card("已寫入學習紀錄", "學習事件：${learningEventCount} 筆\n修復紀錄：${repairedMistakeCount} 筆\n待同步：${offlinePendingCount} 筆", ColorToken.PrimarySoft))
        root.addView(ui.primaryButton("回學習地圖") { renderMap() })
        bottomNav()
    }

    private fun renderAiCoach() {
        screen = Screen.AiCoach
        val q = questions[currentQuestionIndex]
        shell("還沒答對", "先看清楚答案差在哪裡，再重新嘗試")
        root.addView(answerResultCard(false, q, lastSelectedAnswer))
        root.addView(supportStepCard("01", "我看見你卡在這裡", q.prompt, ColorToken.WarningSoft, ColorToken.Warning))
        root.addView(supportStepCard("02", "先把概念拆小", "${q.explanation}\n現在只要先記住這一個規則，不需要一次背完 am / is / are。", ColorToken.VioletSoft, ColorToken.Primary))
        root.addView(supportStepCard("03", "你可以選下一步", "回到同一題再試一次；如果仍然不舒服，English+ 會幫你把狀況整理給志工。", ColorToken.PrimarySoft, ColorToken.Success))
        root.addView(ui.primaryButton("回題目再試一次") { renderLesson() })
        root.addView(ui.secondaryButton("交給志工接力") { renderHelpRequest() })
        bottomNav()
    }

    private fun renderHelpRequest() {
        screen = Screen.HelpRequest
        shell("主動求助", "讓學生用自己的話說出卡住的原因")
        root.addView(helpIntroCard())
        root.addView(flowStrip("說出卡點", "平台分流", "下一步"))
        helpRequestOptions.forEach { root.addView(helpOptionCard(it)) }
        root.addView(ui.secondaryButton("我還是想先自己試一題") { renderLesson() })
        bottomNav()
    }

    private fun handleHelpRequest(option: HelpRequestOption) {
        lastAnswerMessage = option.studentText
        recordLearningEvent("help_request", option.reason, option.platformAction)
        when (option.route) {
            "AI 先處理" -> renderAiCoach()
            "復原模式" -> {
                mood = Mood.Low
                minutes = 3
                persistState()
                renderRecoveryMode()
            }
            "離線任務" -> renderOfflinePacks()
            else -> {
                breakpoints.add(0, Breakpoint(option.reason, "高", option.studentText, option.platformAction, "志工先肯定狀態，再用同一概念做低壓陪練。"))
                renderHandoff()
            }
        }
    }

    private fun renderBreakpoints() {
        screen = Screen.Breakpoints
        shell("支持中心", "把卡關變成 English+ 可以接住的訊號")
        root.addView(card("支持原則", "連續錯題、停留過久、重複退出都不是懲罰理由，而是調整任務與安排陪伴的訊號。", ColorToken.WarningSoft))
        breakpoints.forEach { root.addView(breakpointCard(it)) }
        root.addView(ui.secondaryButton("看看平台會怎麼支持我") { renderInterventionFlow() })
        root.addView(ui.primaryButton("整理狀況給志工接力") { renderHandoff() })
        bottomNav()
    }

    private fun renderHandoff() {
        screen = Screen.Handoff
        shell("雲端志工接力", "把真人時間用在最值得的地方")
        root.addView(preparedHandoffCard())
        root.addView(card("學生摘要", "${student.name}｜${student.location}｜${student.goal}\n目前心情：${mood.label}\n今日任務時間：${minutes} 分鐘", ColorToken.PrimarySoft))
        root.addView(card("斷點摘要", "${breakpoints.first().title}\n證據：${breakpoints.first().evidence}\nAI 已做：${breakpoints.first().aiAction}", ColorToken.WarningSoft))
        root.addView(card("建議陪伴語", "你願意回來做修復任務已經很好。今天我們只看一個規則，先不追完整進度。", ColorToken.SuccessSoft))
        root.addView(card("協作狀態", "志工回覆：${mentorReplyCount} 則\n協作紀錄：${collaborationNotes.size} 筆\n待同步：${offlinePendingCount} 件", ColorToken.Card))
        root.addView(remoteCollaborationStatusCard())
        recentCollaborationNotes(3).forEach { root.addView(collaborationNoteCard(it)) }
        root.addView(ui.secondaryButton("志工回覆並寫入接力紀錄") {
            mentorReplyCount += 1
            actionDoneCount = (actionDoneCount + 1).coerceAtMost(teacherActions.size)
            addCollaborationNote(
                actor = "Emily",
                roleLabel = "雲端志工",
                target = student.name,
                note = "已回覆學生：先肯定願意回來，再陪練 He is / They are 各 2 題，不追加新作業。",
                status = "已回覆"
            )
            renderHandoff()
        })
        root.addView(ui.primaryButton("查看陪伴腳本") { renderMentorScript() })
        bottomNav()
    }

    private fun renderMap() {
        if (role == Role.Mentor) {
            renderTeacherLearningEvidence()
            return
        }
        if (!practiceTimeConfirmed) {
            renderPracticeTimeSetup()
            return
        }
        screen = Screen.Map
        shell("我的學習地圖", "只顯示下一步，不把後台功能丟給學生")
        root.addView(studentRouteStatusCard())
        root.addView(card("本週總覽", "完成微任務：$completedTasks\n信心值：$confidence%\n目前重點：${modules[1].title}", ColorToken.PrimarySoft))
        root.addView(card("地圖規則", "你會先看到已解鎖的下一步。題庫、週報、同步與設計系統由老師端管理，學生端只保留今天需要的任務與回饋。", ColorToken.SuccessSoft))
        root.addView(ui.primaryButton("繼續今天任務") { renderTaskQueue() })
        modules.forEach { root.addView(moduleCard(it)) }
        section("學習紀錄時間線")
        root.addView(timelineCard("今日答題紀錄", "已累積 ${learningEventCount} 筆學習事件，包含答題、反思、求助與修復。", ColorToken.Primary))
        root.addView(timelineCard("錯題修復", "已完成 ${repairedMistakeCount} 筆錯題修復；老師端只看到需要協助的摘要。", ColorToken.Success))
        root.addView(timelineCard("下一次進入", "會先回到心情檢測，再依狀態安排任務，不會直接塞滿所有功能。", ColorToken.Accent))
        section("錯題修復紀錄")
        mistakeRecords.forEach { root.addView(mistakeCard(it)) }
        section("陪伴時間線")
        supportMessages.forEach { root.addView(messageCard(it)) }
        root.addView(ui.secondaryButton("看可選練習") { renderQuestionBank() })
        root.addView(ui.secondaryButton("需要支持") { renderStudentSupportEntry() })
        bottomNav()
    }

    private fun renderTeacherLearningEvidence() {
        screen = Screen.Roster
        shell("學習證據", "老師看班級訊號，不共用學生個人地圖")
        root.addView(card("老師端視角", "這裡整理學生完成檢測、練習、錯題修復與求助的證據。老師不操作學生的學習地圖，而是判斷誰需要被接住。", ColorToken.PrimarySoft))
        root.addView(metricRow(
            Metric("學習事件", "$learningEventCount", ColorToken.Primary),
            Metric("錯題修復", "$repairedMistakeCount", ColorToken.Success),
            Metric("待同步", "$offlinePendingCount", if (offlinePendingCount > 0) ColorToken.Warning else ColorToken.Success)
        ))
        root.addView(card("目前班級觀察", "${student.name} 已完成情緒檢測與短任務路徑；若連續錯題或低信心，會進入接力優先序。", ColorToken.SuccessSoft))
        section("學生證據摘要")
        currentRoster().forEach { row -> root.addView(studentLearningEvidenceCard(row)) }
        root.addView(ui.primaryButton("回學生列表") { renderRoster() })
        root.addView(ui.secondaryButton("查看接力優先序") { renderHandoffBoard() })
        bottomNav()
    }

    private fun renderQuestionBank() {
        if (role == Role.Student) {
            renderStudentPracticeCatalog()
            return
        }
        screen = Screen.QuestionBank
        val bankItems = stateStore.questionBankItems()
        val skillCounts = bankItems.groupingBy { it.skill }.eachCount()
        val levelCounts = bankItems.groupingBy { it.level }.eachCount()
        shell("正式題庫中心", "依程度、單元、技能管理 English+ 題目")
        root.addView(questionBankSummaryCard())
        root.addView(metricRow(
            Metric("題目", "${bankItems.size} 題", ColorToken.Primary),
            Metric("技能", "${skillCounts.size} 類", ColorToken.Success),
            Metric("程度", levelCounts.keys.joinToString("/").ifBlank { "A1" }, ColorToken.Accent)
        ))
        root.addView(card("題庫導入狀態", "目前練習流程已改由 SQLite 題庫載入。這一版先建立正式題庫資料表、種子題、分類檢視與後續後台/API 匯入接口的資料結構。", ColorToken.PrimarySoft))
        root.addView(card(
            "第五輪正式題庫規則",
            "題庫已加入 schema v${QuestionBankContract.QUESTION_BANK_SCHEMA_VERSION}、importId、審核狀態與匯入批次。老師端可以發布正式題目；學生端維持唯讀，避免未審題目進入練習。",
            ColorToken.SuccessSoft
        ))
        section("技能分類")
        skillCounts.forEach { (skill, count) ->
            root.addView(timelineCard(skill, "$count 題｜可作為老師後台篩選與分級派題依據", ColorToken.Primary))
        }
        section("題目清單")
        bankItems.take(18).forEach { root.addView(questionBankItemCard(it)) }
        root.addView(ui.primaryButton("用目前題庫開始練習") {
            currentQuestionIndex = currentQuestionIndex.coerceIn(0, questions.lastIndex)
            renderLesson()
        })
        root.addView(ui.secondaryButton("回學習地圖") { renderMap() })
        bottomNav()
    }

    private fun renderStudentPracticeCatalog() {
        if (!practiceTimeConfirmed) {
            renderPracticeTimeSetup()
            return
        }
        screen = Screen.QuestionBank
        val bankItems = stateStore.questionBankItems()
        val recommended = bankItems.filter { it.skill.contains("文法") || it.skill.contains("閱讀") }.take(6)
        shell("可選練習", "學生只看到與今天路徑相關的題型")
        root.addView(studentRouteStatusCard())
        root.addView(card("開放規則", "這裡不是完整後台題庫。English+ 只開放和今天狀態相符的題型，避免學生一開始被大量題目淹沒。", ColorToken.PrimarySoft))
        root.addView(metricRow(
            Metric("今日時間", "$minutes 分", ColorToken.Primary),
            Metric("目前心情", mood.label, ColorToken.Success),
            Metric("可挑戰", "${recommended.size} 組", ColorToken.Accent)
        ))
        recommended.forEach { root.addView(studentPracticeOptionCard(it)) }
        root.addView(ui.primaryButton("回今天任務") { renderTaskQueue() })
        root.addView(ui.secondaryButton("回我的地圖") { renderMap() })
        bottomNav()
    }

    private fun renderOfflinePacks() {
        screen = Screen.Map
        shell("離線任務包", "降低家庭網路與碎片時間限制")
        refreshOfflineSyncState()
        root.addView(card("設計原因", "偏鄉學生不一定有穩定網路或完整一小時。任務包以 3-8 分鐘為單位，先下載、可離線練習。", ColorToken.PrimarySoft))
        root.addView(metricRow(
            Metric("可下載", "${offlinePacks.size} 包", ColorToken.Primary),
            Metric("已下載", "${downloadedPackTitles.size} 包", ColorToken.Success),
            Metric("待補傳", "${offlinePendingCount} 件", if (offlinePendingCount > 0) ColorToken.Warning else ColorToken.Success)
        ))
        offlinePacks.forEach { root.addView(offlinePackCard(it)) }
        section("同步狀態")
        offlineSyncItems.take(4).ifEmpty {
            syncRecords.map { OfflineSyncItem(it.title, "展示同步", it.detail, it.status) }
        }.forEach { root.addView(offlineSyncItemCard(it)) }
        root.addView(ui.primaryButton("補傳 1 筆待同步紀錄") {
            addOfflineSyncItem(
                title = "手動補傳檢查",
                category = "同步測試",
                detail = "模擬網路恢復後補傳最新學習紀錄。",
                status = "已同步"
            )
            renderSyncCenter()
        })
        root.addView(ui.secondaryButton("查看同步中心") { renderSyncCenter() })
        root.addView(ui.primaryButton("回今日任務") { renderTaskQueue() })
        bottomNav()
    }

    private fun renderSyncCenter() {
        screen = Screen.SyncCenter
        shell("離線同步中心", "模擬網路不穩時的資料保存與補傳")
        refreshOfflineSyncState()
        root.addView(storageStatusCard())
        root.addView(cloudBackendStatusCard())
        root.addView(cloudBackendSettingsCard())
        root.addView(smartSyncStatusCard())
        root.addView(metricRow(
            Metric("待上傳", "${offlinePendingCount} 件", if (offlinePendingCount > 0) ColorToken.Warning else ColorToken.Success),
            Metric("已下載", "${downloadedPackTitles.size} 包", ColorToken.Success),
            Metric("佇列", "${offlineSyncItems.size} 筆", ColorToken.Primary)
        ))
        root.addView(card("同步策略", "學生離線時仍可完成短任務；網路恢復後，微任務、反思、志工接力摘要會補傳。正式版可接 Room/Firebase，目前先用本機狀態模擬。", ColorToken.PrimarySoft))
        offlineSyncItems.ifEmpty {
            syncRecords.map { OfflineSyncItem(it.title, "展示同步", it.detail, it.status) }
        }.forEach { root.addView(offlineSyncItemCard(it)) }
        root.addView(card("本機待同步明細", "學習事件：${learningEventCount} 筆\n志工回覆：${mentorReplyCount} 則\n協作紀錄：${collaborationNotes.size} 筆\n老師新增任務：${customTaskCount} 個", ColorToken.Card))
        root.addView(ui.primaryButton("全部標記為已同步") {
            stateStore.markOfflineSyncItemsSynced()
            refreshOfflineSyncState()
            persistState()
            recordLearningEvent("sync", "本機紀錄已標記同步", "展示版將待同步數歸零，資料仍保留在 SQLite。")
            renderSyncCenter()
        })
        root.addView(ui.primaryButton("智慧同步：檢查網路並補傳") { renderSmartSyncProgress() })
        root.addView(ui.secondaryButton("同步到雲端後端") { renderCloudSyncProgress() })
        bottomNav()
    }

    private fun renderSmartSyncProgress() {
        screen = Screen.SyncCenter
        refreshOfflineSyncState()
        val endpoint = stateStore.cloudBackendUrl()
        val networkReady = isNetworkAvailable()
        if (!networkReady || !stateStore.hasCloudBackend()) {
            val reason = when {
                !networkReady -> "目前沒有可用網路，已保留待補傳佇列。"
                else -> "尚未設定雲端後端 URL，已保留待補傳佇列。"
            }
            addOfflineSyncItem("智慧同步等待補傳", "真同步", reason, "待上傳")
            recordLearningEvent("smart_sync_waiting", "智慧同步等待補傳", reason)
            shell("智慧同步等待補傳", "資料仍保留在本機 SQLite")
            root.addView(card("同步暫停", "$reason\n\n${syncReadinessText()}", ColorToken.WarningSoft))
            root.addView(cloudBackendSettingsCard())
            offlineSyncItems.take(6).forEach { root.addView(offlineSyncItemCard(it)) }
            root.addView(ui.primaryButton("回同步中心") { renderSyncCenter() })
            bottomNav()
            return
        }

        shell("智慧同步進行中", "網路與後端端點皆可用，正在補傳本機佇列")
        root.addView(card("真同步檢查通過", "網路可用\n端點：$endpoint\n待補傳：$offlinePendingCount 筆", ColorToken.PrimarySoft))
        root.addView(card("補傳內容", "學習紀錄、協作紀錄、題庫摘要、離線佇列與目前學生狀態會一起包成 JSON 送出。", ColorToken.Card))
        bottomNav()

        Thread {
            try {
                val payload = stateStore.cloudSyncPayload(currentAccount().classCode)
                    .put("syncMode", "smart_retry")
                    .put("networkCheckedAt", System.currentTimeMillis())
                val result = CloudBackendClient(endpoint).sync(payload)
                runOnUiThread { renderSmartSyncResult(result) }
            } catch (error: Exception) {
                runOnUiThread {
                    addOfflineSyncItem("智慧同步補傳失敗", "真同步", error.message ?: "未知錯誤", "待上傳")
                    recordLearningEvent("smart_sync_failed", "智慧同步補傳失敗", error.message ?: "未知錯誤")
                    renderCloudSyncFailure(error.message ?: "未知錯誤")
                }
            }
        }.start()
    }

    private fun renderSmartSyncResult(result: CloudSyncResult) {
        screen = Screen.SyncCenter
        stateStore.markOfflineSyncItemsSynced()
        addOfflineSyncItem("智慧同步補傳完成", "真同步", "後端回應 ${result.statusCode}，本機待補傳佇列已標記完成。", "已同步")
        refreshOfflineSyncState()
        recordLearningEvent("smart_sync_success", "智慧同步補傳完成", "HTTP ${result.statusCode}")
        shell("智慧同步完成", "本機佇列已補傳到雲端後端")
        root.addView(card("同步成功", "HTTP ${result.statusCode}\n目前待補傳：$offlinePendingCount 筆", ColorToken.SuccessSoft))
        root.addView(card("後端回應", result.responseText.ifBlank { "後端未回傳內容" }, ColorToken.Card))
        root.addView(ui.primaryButton("回同步中心") { renderSyncCenter() })
        bottomNav()
    }

    private fun renderCloudSyncProgress() {
        screen = Screen.SyncCenter
        val endpoint = stateStore.cloudBackendUrl()
        if (!stateStore.hasCloudBackend()) {
            shell("尚未設定雲端後端", "先貼上 Firebase Cloud Function 或校內 API 的 HTTPS URL")
            root.addView(card("目前狀態", "尚未設定雲端端點，因此資料仍只會保存在本機 SQLite。", ColorToken.WarningSoft))
            root.addView(cloudBackendSettingsCard())
            root.addView(ui.secondaryButton("回同步中心") { renderSyncCenter() })
            bottomNav()
            return
        }

        shell("正在同步雲端", "將本機 SQLite 摘要打包成 JSON POST 到後端")
        root.addView(card("同步端點", endpoint, ColorToken.PrimarySoft))
        root.addView(card("同步內容", "App 狀態、學習事件、協作紀錄、離線同步佇列會一起送出。", ColorToken.Card))
        bottomNav()

        Thread {
            try {
                val payload = stateStore.cloudSyncPayload(currentAccount().classCode)
                val result = CloudBackendClient(endpoint).sync(payload)
                runOnUiThread { renderCloudSyncResult(result) }
            } catch (error: Exception) {
                runOnUiThread {
                    recordLearningEvent("cloud_sync_failed", "雲端同步失敗", error.message ?: "未知錯誤")
                    renderCloudSyncFailure(error.message ?: "未知錯誤")
                }
            }
        }.start()
    }

    private fun renderCloudSyncResult(result: CloudSyncResult) {
        screen = Screen.SyncCenter
        stateStore.markOfflineSyncItemsSynced()
        refreshOfflineSyncState()
        recordLearningEvent("cloud_sync", "雲端後端同步完成", "HTTP ${result.statusCode} / ${result.responseText.take(160)}")
        persistState()
        shell("雲端同步完成", "後端已接收 English+ 本機資料摘要")
        root.addView(card("後端回應", "HTTP ${result.statusCode}\n${result.responseText.ifBlank { "後端未回傳內容" }}", ColorToken.SuccessSoft))
        root.addView(card("同步後狀態", "待補傳：${offlinePendingCount} 件\n同步佇列：${offlineSyncItems.size} 筆", ColorToken.Card))
        root.addView(ui.primaryButton("回同步中心") { renderSyncCenter() })
        bottomNav()
    }

    private fun renderCloudSyncFailure(message: String) {
        screen = Screen.SyncCenter
        shell("雲端同步失敗", "本機資料已保留，可稍後重試")
        root.addView(card("錯誤訊息", message, ColorToken.WarningSoft))
        root.addView(card("備援策略", "同步失敗不會清掉本機 SQLite 與待同步佇列。正式版可加入背景重試、登入權杖與失敗通知。", ColorToken.Card))
        root.addView(ui.primaryButton("回同步中心") { renderSyncCenter() })
        bottomNav()
    }

    private fun renderRoster() {
        screen = Screen.Roster
        shell("學生證據", "先看風險與最新狀態，再決定要不要介入")
        root.addView(card("列表用途", "這是老師/志工端的班級觀察頁，不是學生自己的學習地圖。點學生卡片可看接力資料；看整體學習證據可進入證據面板。", ColorToken.PrimarySoft))
        root.addView(metricRow(
            Metric("管理中", "${currentRoster().size} 位", ColorToken.Primary),
            Metric("高風險", "${currentRoster().count { it.risk == "高" }} 位", ColorToken.Danger),
            Metric("可自學", "${currentRoster().count { it.risk == "低" }} 位", ColorToken.Success)
        ))
        currentRoster().forEach { row -> root.addView(studentRowCard(row)) }
        root.addView(ui.primaryButton("查看班級學習證據") { renderTeacherLearningEvidence() })
        root.addView(ui.primaryButton("查看 ${student.name} 的斷點") { renderBreakpoints() })
        root.addView(ui.secondaryButton("查看接力優先序") { renderHandoffBoard() })
        bottomNav()
    }

    private fun renderStudentDetail(row: StudentRow) {
        screen = Screen.StudentDetail
        shell("${row.name} 的接力資料", "用一頁讓老師知道現在要不要介入")
        root.addView(metricRow(
            Metric("風險", row.risk, if (row.risk == "高") ColorToken.Danger else ColorToken.Warning),
            Metric("狀態", if (row.risk == "低") "可自學" else "需追蹤", ColorToken.Primary),
            Metric("接力", if (row.risk == "高") "今日" else "本週", ColorToken.Success)
        ))
        root.addView(card("目前斷點", row.issue, if (row.risk == "高") ColorToken.WarningSoft else ColorToken.PrimarySoft))
        root.addView(card("最新狀態", row.status, ColorToken.Card))
        root.addView(card("學習證據", "最近任務：${studyTasks.first().title}\n答題事件：${learningEventCount} 筆\n錯題修復：${repairedMistakeCount} 筆\n目前信心：$confidence%", ColorToken.PrimarySoft))
        root.addView(card("老師下一步", if (row.risk == "高") "先用陪伴腳本降低挫折，再只帶同一概念兩題。" else "保留低壓任務，觀察是否願意回來完成。", ColorToken.SuccessSoft))
        root.addView(ui.primaryButton("查看接力腳本") { renderMentorScript() })
        root.addView(ui.secondaryButton("回學生列表") { renderRoster() })
        bottomNav()
    }

    private fun renderHandoffBoard() {
        screen = Screen.Mentor
        shell("接力優先序", "把有限的真人時間安排到最需要的地方")
        root.addView(card("排序規則", "高風險情緒斷點 > 連續錯題 > 重複退出 > 一般複習。AI 可處理低風險，真人處理高價值斷點。", ColorToken.PrimarySoft))
        root.addView(flowStrip("確認學生", "分派負責人", "回填紀錄", "同步週報"))
        root.addView(remoteCollaborationStatusCard())
        handoffPriorities.forEach { root.addView(priorityCard(it)) }
        section("最新協作紀錄")
        recentCollaborationNotes(4).forEach { root.addView(collaborationNoteCard(it)) }
        root.addView(ui.secondaryButton("分享最新老師報告") { shareTeacherReport(buildDemoReportText()) })
        root.addView(ui.secondaryButton("查看待辦處理佇列") { renderActionQueue() })
        root.addView(ui.primaryButton("查看陪伴腳本") { renderMentorScript() })
        bottomNav()
    }

    private fun renderActionQueue() {
        screen = Screen.ActionQueue
        shell("待辦處理佇列", "把志工、老師、小組各自要做的事排清楚")
        root.addView(metricRow(
            Metric("待辦", "${teacherActions.size} 件", ColorToken.Warning),
            Metric("已處理", "${actionDoneCount} 件", ColorToken.Success),
            Metric("協作", "${collaborationNotes.size} 筆", ColorToken.Primary)
        ))
        root.addView(card("處理規則", "先完成高風險學生，再處理協作與報告。每完成一件事，系統都會寫入協作紀錄，方便下一位老師或志工接續。", ColorToken.PrimarySoft))
        root.addView(flowStrip("看待辦", "處理一件", "寫入紀錄", "同步"))
        root.addView(remoteCollaborationStatusCard())
        teacherActions.forEach { root.addView(teacherActionCard(it)) }
        root.addView(ui.primaryButton("標記一件待辦已處理") {
            actionDoneCount = (actionDoneCount + 1).coerceAtMost(teacherActions.size)
            addCollaborationNote(
                actor = currentAccount().displayName,
                roleLabel = currentAccount().roleLabel,
                target = "待辦處理佇列",
                note = "已處理 1 件待辦，下一步交由負責人依摘要接力。",
                status = "已處理"
            )
            renderActionQueue()
        })
        root.addView(ui.primaryButton("查看接力優先序") { renderHandoffBoard() })
        bottomNav()
    }

    private fun renderRemoteCollaborationSync(pushFirst: Boolean) {
        screen = Screen.ActionQueue
        if (!stateStore.hasCloudBackend()) {
            shell("尚未設定協作後端", "多人協作需要先在同步中心設定雲端端點")
            root.addView(card("目前狀態", "沒有後端 URL 時，協作紀錄只會保存在本機 SQLite。", ColorToken.WarningSoft))
            root.addView(ui.primaryButton("前往同步中心設定") { renderSyncCenter() })
            root.addView(ui.secondaryButton("回接力優先序") { renderHandoffBoard() })
            bottomNav()
            return
        }

        shell("同步多人協作", if (pushFirst) "先推送本機協作，再拉取遠端更新" else "正在拉取遠端協作紀錄")
        root.addView(card("協作後端", stateStore.cloudBackendUrl(), ColorToken.PrimarySoft))
        root.addView(card("同步班級", currentAccount().classCode, ColorToken.Card))
        root.addView(card(
            "第四輪同步規則",
            "協作紀錄會以 eventId 去重；同一筆接力在不同裝置更新時，保留 createdAt 較新的版本。學生端不能建立正式接力紀錄，老師/志工端可以寫入。",
            ColorToken.VioletSoft
        ))
        bottomNav()

        Thread {
            try {
                val client = CloudBackendClient(stateStore.cloudBackendUrl())
                if (pushFirst) {
                    client.pushCollaboration(stateStore.collaborationPayload(currentAccount().classCode))
                }
                val response = client.fetchCollaboration(currentAccount().classCode, 0L)
                val imported = importRemoteCollaborationNotes(response)
                runOnUiThread { renderRemoteCollaborationResult(imported) }
            } catch (error: Exception) {
                runOnUiThread { renderRemoteCollaborationFailure(error.message ?: "未知錯誤") }
            }
        }.start()
    }

    private fun renderRemoteCollaborationResult(importedCount: Int) {
        collaborationNotes = stateStore.collaborationNotes()
        recordLearningEvent("collaboration_sync", "多人協作同步完成", "匯入 $importedCount 筆遠端協作紀錄。")
        shell("多人協作同步完成", "已更新老師/志工接力紀錄")
        root.addView(card("同步結果", "匯入遠端協作紀錄：$importedCount 筆\n目前本機協作紀錄：${collaborationNotes.size} 筆", ColorToken.SuccessSoft))
        recentCollaborationNotes(5).forEach { root.addView(collaborationNoteCard(it)) }
        root.addView(ui.primaryButton("回接力優先序") { renderHandoffBoard() })
        bottomNav()
    }

    private fun renderRemoteCollaborationFailure(message: String) {
        recordLearningEvent("collaboration_sync_failed", "多人協作同步失敗", message)
        shell("多人協作同步失敗", "本機協作資料已保留")
        root.addView(card("錯誤訊息", message, ColorToken.WarningSoft))
        root.addView(card("備援策略", "協作同步失敗時，老師與志工仍可先用本機紀錄展示流程；等網路或後端恢復後再同步。", ColorToken.Card))
        root.addView(ui.primaryButton("回接力優先序") { renderHandoffBoard() })
        bottomNav()
    }

    private fun renderStudentManager() {
        screen = Screen.StudentManager
        shell("學生資料管理", "本機原型先模擬新增學生、分組與追蹤狀態")
        root.addView(classContextCard())
        root.addView(metricRow(
            Metric("管理學生", "${managedStudentCount} 位", ColorToken.Primary),
            Metric("高風險", "1 位", ColorToken.Danger),
            Metric("已處理待辦", "${actionDoneCount} 件", ColorToken.Success)
        ))
        root.addView(card("目前限制", "這裡還沒有正式資料庫，但已把老師端需要的管理概念做成可操作原型：新增展示學生、切換追蹤狀態、查看接力工作。", ColorToken.PrimarySoft))
        currentRoster().forEach { root.addView(studentRowCard(it)) }
        root.addView(ui.primaryButton("新增 1 位展示學生") {
            managedStudentCount += 1
            addOfflineSyncItem("新增展示學生", "老師端資料", "新增學生後需同步到班級學生名單。")
            persistState()
            renderStudentManager()
        })
        root.addView(ui.secondaryButton("查看待辦處理佇列") { renderActionQueue() })
        bottomNav()
    }

    private fun currentRoster(): List<StudentRow> {
        if (managedStudentCount <= roster.size) return roster.take(managedStudentCount)
        val extra = (roster.size + 1..managedStudentCount).map { index ->
            StudentRow("新增學生$index", if (index % 2 == 0) "中" else "低", "待建立學習檔案", "剛加入班級，尚未完成第一次檢測")
        }
        return roster + extra
    }

    private fun renderAiLab() {
        screen = Screen.AiLab
        shell("AI 提示實驗室", "可切換真 OpenAI API 與本機模擬")
        root.addView(openAiStatusCard())
        root.addView(card("第六輪 API 安全", "正式遠端 AI 只走 HTTPS 後端代理；手機端 Key 僅作開發展示 fallback，不能作為上架方案。", ColorToken.WarningSoft))
        root.addView(aiProxyEndpointCard())
        root.addView(openAiKeyEntryCard())
        root.addView(card("使用方式", "設定 OpenAI API Key 後可呼叫 Responses API 產生診斷、學生語氣回饋與志工接力摘要。沒有 Key 或網路失敗時，仍會保留本機模擬。", ColorToken.WarningSoft))
        aiScenarios.forEach { root.addView(aiScenarioCard(it)) }
        root.addView(ui.primaryButton("呼叫真 AI 生成回饋") { renderLiveAiFeedback() })
        root.addView(ui.secondaryButton("改用本機模擬生成") { renderGeneratedAiFeedback() })
        bottomNav()
    }

    private fun openAiStatusCard(): View {
        val hasKey = stateStore.hasOpenAiApiKey()
        val box = ui.container(
            if (hasKey) ColorToken.SuccessSoft else ColorToken.WarningSoft,
            ColorToken.Border
        )
        box.addView(ui.statusPill(if (hasKey) "真 AI 已啟用" else "本機模擬模式", if (hasKey) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label(if (hasKey) "OpenAI API Key 已儲存在本機" else "尚未設定 OpenAI API Key", 18, ColorToken.Ink, true).apply {
            layoutParams = ui.fullWidthParams()
        })
        box.addView(ui.body(
            if (hasKey) {
                "按下「呼叫真 AI」時會送出目前題目、情緒狀態與錯題次數；如果網路或 API 失敗，會自動回到本機模擬。"
            } else {
                "目前不會連線到外部 AI。你可以先用展示模式，或在下方貼上 OpenAI API Key 後啟用真 AI 回饋。"
            }
        ))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun aiProxyEndpointCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label("AI Proxy 端點", 18, ColorToken.Ink, true))
        box.addView(ui.body("正式版建議用後端代理保存 OpenAI Key。手機只送學習脈絡到 HTTPS API，不直接持有正式 Key。"))
        val input = EditText(this).apply {
            hint = "https://example.com/api/english-plus/ai"
            setText(stateStore.aiProxyEndpoint())
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
            setSingleLine(true)
            textSize = 15f
            setTextColor(Color.parseColor(ColorToken.Ink))
            setHintTextColor(Color.parseColor(ColorToken.Muted))
            background = ui.rounded(ColorToken.Surface, ColorToken.Border)
            setPadding(ui.dp(14), ui.dp(12), ui.dp(14), ui.dp(12))
            layoutParams = ui.fullWidthParams()
        }
        box.addView(input)
        box.addView(ui.primaryButton("儲存 AI Proxy 端點") {
            stateStore.saveAiProxyEndpoint(input.text.toString())
            recordLearningEvent("ai_proxy_config", "已更新 AI Proxy 端點", stateStore.aiProxyEndpoint().ifBlank { "已清空" })
            renderAiLab()
        })
        box.addView(ui.secondaryButton("清除 AI Proxy 端點") {
            stateStore.saveAiProxyEndpoint("")
            recordLearningEvent("ai_proxy_config", "已清除 AI Proxy 端點", "AI 實驗室會回到本機 Key 或本機模擬。")
            renderAiLab()
        })
        return ui.margins(box, 0, 0, 0, 12)
    }

    private fun openAiKeyEntryCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label("OpenAI Key 設定", 18, ColorToken.Ink, true))
        box.addView(ui.body("Key 只會存在這台裝置的私人設定中，不會寫進 GitHub。課堂展示時可以留空，系統會使用本機模擬。"))

        val input = EditText(this).apply {
            hint = if (stateStore.hasOpenAiApiKey()) "已設定，可貼上新 Key 覆蓋" else "貼上 sk- 開頭的 API Key"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            setSingleLine(true)
            textSize = 15f
            setTextColor(Color.parseColor(ColorToken.Ink))
            setHintTextColor(Color.parseColor(ColorToken.Muted))
            background = ui.rounded(ColorToken.Surface, ColorToken.Border)
            setPadding(ui.dp(14), ui.dp(12), ui.dp(14), ui.dp(12))
            layoutParams = ui.fullWidthParams()
        }
        box.addView(input)

        box.addView(ui.primaryButton("儲存並啟用真 AI") {
            val key = input.text.toString().trim()
            if (key.startsWith("sk-")) {
                stateStore.saveOpenAiApiKey(key)
                recordLearningEvent("ai_config", "已更新 OpenAI API Key", "真 AI 模式已可在 AI 提示實驗室呼叫。")
            } else {
                recordLearningEvent("ai_config", "OpenAI API Key 未更新", "輸入內容不是 sk- 開頭，維持原本設定。")
            }
            renderAiLab()
        })
        box.addView(ui.secondaryButton("清除 Key，改用本機模擬") {
            stateStore.saveOpenAiApiKey("")
            recordLearningEvent("ai_config", "已清除 OpenAI API Key", "AI 提示實驗室已回到本機模擬模式。")
            renderAiLab()
        })
        return ui.margins(box, 0, 0, 0, 12)
    }

    private fun renderLiveAiFeedback() {
        val decision = stateStore.aiSecurityDecision(productionMode = true)
        if (!decision.canCallRemoteAi) {
            recordLearningEvent("ai_security_fallback", "Remote AI blocked by security contract", decision.warning)
            renderGeneratedAiFeedback("第六輪 API 安全檢查：${decision.warning}\n已改用本機模擬，不會從手機端送出正式 OpenAI Key。")
            return
        }
        val apiKey = stateStore.openAiApiKey()
        if (!stateStore.hasAiProxyEndpoint() && !stateStore.hasOpenAiApiKey()) {
            recordLearningEvent("ai_fallback", "未設定 OpenAI API Key", "使用本機 AI 模擬回饋。")
            renderGeneratedAiFeedback("尚未設定 OpenAI API Key，已改用本機模擬。")
            return
        }
        val q = questions[currentQuestionIndex]
        screen = Screen.AiLab
        shell("AI 生成中", "正在呼叫 OpenAI Responses API")
        root.addView(card("請稍候", "English+ 正在把目前題目、情緒狀態與錯題次數送出，產生短回饋與接力摘要。", ColorToken.PrimarySoft))
        bottomNav()
        Thread {
            try {
                val result = if (stateStore.hasAiProxyEndpoint()) {
                    AiProxyClient(stateStore.aiProxyEndpoint()).generateSupport(
                        question = q.prompt,
                        concept = q.concept,
                        answerContext = q.repairHint,
                        moodLabel = mood.label,
                        wrongAttempts = wrongAttempts,
                        classCode = currentAccount().classCode
                    )
                } else {
                    OpenAiClient(apiKey).generateSupport(
                    question = q.prompt,
                    concept = q.concept,
                    answerContext = q.repairHint,
                    moodLabel = mood.label,
                    wrongAttempts = wrongAttempts
                )
                }
                runOnUiThread { renderLiveAiResult(result) }
            } catch (error: Exception) {
                runOnUiThread {
                    recordLearningEvent("ai_fallback", "OpenAI 呼叫失敗", error.message ?: "未知錯誤")
                    renderGeneratedAiFeedback("OpenAI 呼叫失敗，已改用本機模擬：${error.message ?: "未知錯誤"}")
                }
            }
        }.start()
    }

    private fun renderLiveAiResult(result: AiSupportResult) {
        screen = Screen.AiLab
        shell("AI 生成結果", result.source)
        root.addView(card("診斷", result.diagnosis, ColorToken.WarningSoft))
        root.addView(card("給學生的話", result.studentFeedback, ColorToken.SuccessSoft))
        root.addView(card("給志工的摘要", result.handoffSummary, ColorToken.Card))
        recordLearningEvent("ai_live", "OpenAI 生成回饋", result.diagnosis)
        root.addView(ui.primaryButton("回今日任務") { renderLesson() })
        root.addView(ui.secondaryButton("回 AI 提示實驗室") { renderAiLab() })
        bottomNav()
    }

    private fun renderGeneratedAiFeedback(notice: String? = null) {
        screen = Screen.AiLab
        val q = questions[currentQuestionIndex]
        shell("AI 生成結果模擬", "依目前題型與錯題狀態產生個人化回饋")
        notice?.let { root.addView(card("真 AI 狀態", it, ColorToken.WarningSoft)) }
        root.addView(card("輸入資料", "${q.prompt}\n題型：${q.type}\n目前錯誤次數：$wrongAttempts", ColorToken.PrimarySoft))
        root.addView(card("診斷", aiDiagnosis(q), ColorToken.WarningSoft))
        root.addView(card("給學生的話", aiStudentFeedback(q), ColorToken.SuccessSoft))
        root.addView(card("給志工的摘要", aiHandoffSummary(q), ColorToken.Card))
        root.addView(ui.secondaryButton("把這次 AI 摘要存入待辦") {
            actionDoneCount = actionDoneCount.coerceAtMost(teacherActions.size)
            learningEventCount += 1
            addOfflineSyncItem("AI 摘要待辦：${q.concept}", "AI 接力摘要", aiHandoffSummary(q))
            persistState()
            recordLearningEvent("ai_local", "本機 AI 模擬回饋", aiDiagnosis(q))
            renderGeneratedAiFeedback()
        })
        root.addView(ui.primaryButton("回今日任務") { renderLesson() })
        bottomNav()
    }

    private fun aiDiagnosis(question: Question): String {
        return when (question.type) {
            "閱讀題" -> "學生可能不是完全看不懂，而是長句切分壓力高。先找主詞，再找動詞。"
            "聽力題" -> "學生需要先抓關鍵字，不適合一次要求完整翻譯。"
            "字彙題" -> "學生需要把單字和情境連起來，而不是只背中文意思。"
            else -> "學生可能卡在「${question.concept}」。先不要加題，先給一個可重試的小提示。"
        }
    }

    private fun aiStudentFeedback(question: Question): String {
        return if (mood == Mood.Low) {
            "今天狀態比較低，先記一個提示就好：${question.repairHint}"
        } else {
            question.repairHint
        }
    }

    private fun aiHandoffSummary(question: Question): String {
        return "學生在「${question.concept}」出現不穩，題型為${question.type}。建議真人只用同題型陪練 2 題，避免一次混入新規則。"
    }

    private fun renderMentorScript() {
        screen = Screen.Mentor
        shell("志工陪伴腳本", "降低志工準備成本，也避免學生被再次打擊")
        root.addView(card("開場 30 秒", "先肯定：你願意回來做修復任務已經很好。今天我們只看一個規則，不看整章。", ColorToken.SuccessSoft))
        root.addView(card("引導問題", "1. He 是一個人還是很多人？\n2. 一個人通常搭配 is 還是 are？\n3. 你可以自己造一句 He is 嗎？", ColorToken.PrimarySoft))
        root.addView(card("結束紀錄", "能完成 2 題再加 They are；如果仍卡住，記錄為高優先斷點，不追加作業。", ColorToken.WarningSoft))
        root.addView(ui.secondaryButton("使用腳本並留下志工紀錄") {
            mentorReplyCount += 1
            addCollaborationNote(
                actor = "Emily",
                roleLabel = "雲端志工",
                target = student.name,
                note = "已使用陪伴腳本完成一次低壓接力；學生能先回答 He is，暫不加新題型。",
                status = "腳本已用"
            )
            renderMentorScript()
        })
        root.addView(ui.primaryButton("回老師工作台") {
            role = Role.Mentor
            renderHome()
        })
        bottomNav()
    }

    private fun renderWeeklyReport() {
        screen = Screen.Report
        shell("本週學習週報", "用進步證據取代排名壓力")
        refreshOfflineSyncState()
        root.addView(metricRow(
            Metric("微任務", "${completedTasks} 個", ColorToken.Primary),
            Metric("斷點修復", "2 個", ColorToken.Success),
            Metric("求助", "1 次", ColorToken.Warning)
        ))
        root.addView(reportShowcaseCard())
        weeklySignals.forEach { root.addView(signalCard(it)) }
        root.addView(card("給學生看的話", "你這週不是沒有進步，而是把問題縮小了。能說出 He is，就是修復英文斷層的一步。", ColorToken.SuccessSoft))
        root.addView(card("給老師/mentor 的摘要", "學生對完整測驗仍焦慮，但願意完成 3-5 分鐘任務。建議下週維持低壓短任務與志工接力。\n\n本週協作紀錄：${collaborationNotes.size} 筆，志工回覆：${mentorReplyCount} 則。", ColorToken.PrimarySoft))
        section("接力證據")
        recentCollaborationNotes(4).forEach { root.addView(collaborationNoteCard(it)) }
        root.addView(ui.primaryButton("匯出展示報告") { renderExportReport() })
        root.addView(ui.secondaryButton("查看 OPPM 檢核指標") { renderMentorChecks() })
        bottomNav()
    }

    private fun renderExportReport() {
        screen = Screen.Report
        refreshOfflineSyncState()
        val reportText = buildDemoReportText()
        val file = writeDemoReport(reportText)
        shell("展示報告已產生", "把產品原型成果整理成可交給老師/評審的文字摘要")
        root.addView(card("匯出檔案", file.absolutePath, ColorToken.SuccessSoft))
        root.addView(card("報告內容預覽", reportText, ColorToken.Card))
        root.addView(ui.secondaryButton("回本週學習週報") { renderWeeklyReport() })
        root.addView(ui.primaryButton("查看 OPPM 品質檢核") { renderMentorChecks() })
        bottomNav()
    }

    private fun renderMentorChecks() {
        screen = Screen.Report
        shell("OPPM 品質檢核", "把原型對齊課程與 mentor 評估")
        root.addView(card("檢核目的", "這頁不是給學生看的，而是給小組、mentor、老師確認產品方向是否符合提案目標。", ColorToken.PrimarySoft))
        root.addView(reportShowcaseCard())
        mentorChecks.forEach { root.addView(mentorCheckCard(it)) }
        root.addView(card("下一步", "目前 1-6 輪功能已形成完整可操作原型。下一階段最需要驗證的是：志工是否願意使用摘要接力、老師是否覺得斷點紀錄有用、學生是否願意在低壓任務中回來。", ColorToken.WarningSoft))
        root.addView(ui.primaryButton("匯出展示報告") { renderExportReport() })
        bottomNav()
    }

    private fun reportShowcaseCard(): View {
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.statusPill("v0.6 成果", ColorToken.Primary))
        box.addView(ui.label("English+ 可操作產品原型", 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(
            "目前已完成真實資料儲存、本機登入班級、真 AI 串接、老師/志工協作、離線同步與展示報告。展示重點不是題庫量，而是情緒斷點如何被 AI 接住，再交給真人低壓接力。"
        ))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun buildDemoReportText(): String {
        val snapshot = stateStore.storageSnapshot()
        val latestCollaboration = collaborationNotes.firstOrNull()?.note ?: "尚未建立真人接力紀錄。"
        val latestSync = offlineSyncItems.firstOrNull()?.let { "${it.title} / ${it.status}" } ?: "尚未建立同步佇列。"
        return """
            English+ 偏鄉學生雙軌學習平台展示報告

            一、產品定位
            English+ 是面向偏鄉國中生的低壓英文學習原型。平台核心不是大量刷題，而是先辨識學生的情緒斷點，把英文任務縮小，再由 AI 與真人志工雙軌接力。

            二、目前可展示功能
            1. 真實資料儲存：SQLite 已保存 App 狀態、學習事件、帳號、協作紀錄與同步佇列。
            2. 登入與班級：本機展示帳號可切換學生、志工、老師，保留班級/群組代碼。
            3. 真 AI 串接：AI 提示實驗室可設定 OpenAI API Key；沒有 Key 或失敗時回到本機模擬。
            4. 老師/志工協作：志工回覆、陪伴腳本、老師待辦處理會寫入協作紀錄。
            5. 離線與同步：任務包下載、答題、反思、AI 摘要與協作會進入待同步佇列。
            6. 報告展示：本頁可輸出給老師/評審看的文字摘要。

            三、本週展示資料
            學生：${student.name} / ${student.location} / ${student.goal}
            心情狀態：${mood.label}
            今日任務時間：${minutes} 分鐘
            微任務完成：${completedTasks} 個
            信心值：${confidence}%
            錯題修復：${repairedMistakeCount} 筆
            學習事件：${snapshot.eventCount} 筆
            協作紀錄：${snapshot.collaborationCount} 筆
            待補傳同步：${snapshot.pendingSyncCount} 筆
            已下載離線包：${snapshot.downloadedPackCount} 包

            四、情緒斷點處理
            目前主要斷點：${breakpoints.first().title}
            斷點證據：${breakpoints.first().evidence}
            AI 已做處理：${breakpoints.first().aiAction}
            真人接力建議：${breakpoints.first().mentorAction}

            五、最新接力與同步
            最新協作：$latestCollaboration
            最新同步項目：$latestSync

            六、下一階段建議
            1. 將 SQLite 資料層升級為 Room。
            2. 用 Firebase 或校內後端做真帳號與雲端同步。
            3. 將 OpenAI API Key 移到後端代理，不由手機端保存正式 Key。
            4. 用真實學生訪談驗證：低壓任務、志工摘要、情緒斷點是否真的降低放棄感。
        """.trimIndent()
    }

    private fun writeDemoReport(reportText: String): File {
        val targetDir = getExternalFilesDir(null) ?: filesDir
        val file = File(targetDir, "english_plus_demo_report.txt")
        file.writeText(reportText, Charsets.UTF_8)
        writeDemoReportHtml(reportText)
        recordLearningEvent("report_export", "已匯出展示報告", file.absolutePath)
        addOfflineSyncItem("展示報告匯出", "報告資料", "已產生 english_plus_demo_report.txt，待正式版上傳到雲端或分享給老師。")
        return file
    }

    private fun writeDemoReportHtml(reportText: String): File {
        val targetDir = getExternalFilesDir(null) ?: filesDir
        val file = File(targetDir, "english_plus_teacher_report.html")
        file.writeText(buildDemoReportHtml(reportText), Charsets.UTF_8)
        recordLearningEvent("report_export_html", "已匯出 HTML 老師報告", file.absolutePath)
        return file
    }

    private fun buildDemoReportHtml(reportText: String): String {
        val escaped = reportText
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
        return """
            <!doctype html>
            <html lang="zh-Hant">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>English+ Teacher Report</title>
              <style>
                body { font-family: sans-serif; margin: 32px; color: #102033; line-height: 1.65; }
                header { border-bottom: 3px solid #246BFD; margin-bottom: 24px; padding-bottom: 16px; }
                h1 { margin: 0 0 8px; font-size: 28px; }
                .meta { color: #64748b; font-size: 14px; }
                pre { white-space: pre-wrap; background: #f8fafc; border: 1px solid #dbe3ef; border-radius: 12px; padding: 18px; }
                .note { margin-top: 18px; color: #475569; font-size: 13px; }
              </style>
            </head>
            <body>
              <header>
                <h1>English+ 老師週報</h1>
                <div class="meta">學生：${student.name}｜班級：${currentAccount().classCode}</div>
              </header>
              <pre>$escaped</pre>
              <div class="note">此 HTML 可由瀏覽器列印成 PDF；正式版可改由後端產生 PDF、Word 與老師後台報表。</div>
            </body>
            </html>
        """.trimIndent()
    }

    private fun shareTeacherReport(reportText: String) {
        val share = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_SUBJECT, "English+ 老師週報")
            putExtra(Intent.EXTRA_TEXT, reportText)
        }
        startActivity(Intent.createChooser(share, "分享 English+ 老師週報"))
    }

    private fun shell(title: String, subtitle: String) {
        val scroll = ScrollView(this)
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(ui.dp(16), ui.dp(24), ui.dp(16), ui.dp(24))
            background = ui.solid(ColorToken.Surface)
        }
        scroll.addView(root)
        setContentView(scroll)
        root.addView(ui.eyebrow("${navigationArea()} / English+"))
        root.addView(ui.label(title, 28, ColorToken.Ink, true).apply { setPadding(0, ui.dp(8), 0, ui.dp(4)) })
        root.addView(ui.body(subtitle, ColorToken.Muted))
        root.addView(ui.space(16))
    }

    private fun hero(title: String, text: String) {
        val box = ui.container(ColorToken.Ink, ColorToken.Ink)
        val brand = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.TOP
        }
        val identity = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        identity.addView(ui.label("English+", 18, "#FFFFFF", true))
        identity.addView(ui.label("偏鄉學生雙軌學習平台", 13, "#C7DAD6", true).apply {
            setPadding(0, ui.dp(4), 0, 0)
        })
        brand.addView(identity, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        brand.addView(ui.label("雙軌陪伴", 12, "#F7D8C0", true).apply {
            gravity = Gravity.CENTER
            setPadding(ui.dp(10), ui.dp(6), ui.dp(10), ui.dp(6))
            background = ui.rounded("#274A60", "#365C73")
        })
        box.addView(brand)
        box.addView(ui.space(20))
        box.addView(ui.label(title, 23, "#FFFFFF", true))
        box.addView(ui.body(text, "#D6E6E3").apply { setPadding(0, ui.dp(8), 0, 0) })
        box.addView(ui.label(roleLabel(), 13, "#F7D8C0", true).apply { setPadding(0, ui.dp(12), 0, 0) })
        root.addView(ui.margins(box, 0, 8, 0, 16))
    }

    private fun roleSwitch(): View {
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        row.addView(ui.chipButton("學生端", role == Role.Student) {
            val studentAccount = accountList().firstOrNull { AuthContract.isStudentRole(it.roleLabel) } ?: currentAccount()
            selectAccount(studentAccount)
            renderHome()
        })
        row.addView(ui.chipButton("老師/志工端", role == Role.Mentor) {
            val mentorAccount = accountList().firstOrNull { AuthContract.isStaffRole(it.roleLabel) } ?: currentAccount()
            selectAccount(mentorAccount)
            renderHome()
        })
        return ui.margins(row, 0, 8, 0, 16)
    }

    private fun roleEntryCard(
        label: String,
        title: String,
        detail: String,
        fill: String,
        actionText: String,
        action: () -> Unit
    ): View {
        val color = if (label == "學生端") ColorToken.Primary else ColorToken.Success
        val box = ui.sectionBand(fill)
        box.addView(ui.statusPill(label, color))
        box.addView(ui.label(title, 22, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(detail, "#334155"))
        box.addView(ui.primaryButton(actionText) { action() })
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun mentorDailyCommandCard(): View {
        val box = ui.sectionBand(ColorToken.PrimarySoft)
        box.addView(ui.statusPill("今日工作台", ColorToken.Primary))
        box.addView(ui.label("先處理最需要人的一位", 23, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("老師端不再把所有功能攤在首頁。English+ 先整理班級訊號，再把今天最值得真人接力的下一步放到最前面。", "#334155"))
        box.addView(metricRow(
            Metric("待關懷", "2 位", ColorToken.Warning),
            Metric("高風險", "1 位", ColorToken.Danger),
            Metric("可處理", "15 分", ColorToken.Success)
        ))
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun mentorPriorityStudentCard(): View {
        val box = ui.container(ColorToken.WarningSoft, ColorToken.Warning)
        box.addView(ui.statusPill("第一優先", ColorToken.Danger))
        box.addView(ui.label("${student.name}｜需要真人接力", 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("最新訊號：${breakpoints[0].evidence}", "#334155"))
        box.addView(ui.body("建議：先確認情緒狀態，再安排同概念低壓陪練。", ColorToken.Danger).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        box.addView(ui.primaryButton("處理這位學生") { renderStudentDetail(currentRoster().first()) })
        box.addView(ui.secondaryButton("查看接力優先序") { renderHandoffBoard() })
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun mentorWorkflowCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("工作順序", ColorToken.Success))
        box.addView(ui.label("看訊號 → 分派 → 回填 → 週報", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(flowStrip("學生證據", "待辦接力", "協作同步", "週報回饋"))
        box.addView(ui.body("每個入口都對應一個老師任務，不再讓老師從學生地圖或題庫後台裡找功能。", "#334155"))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun mentorOperationsSummaryCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("操作摘要", ColorToken.Primary))
        box.addView(metricRow(
            Metric("已處理", "$actionDoneCount", ColorToken.Success),
            Metric("志工回覆", "$mentorReplyCount", ColorToken.Primary),
            Metric("新增任務", "$customTaskCount", ColorToken.Accent)
        ))
        box.addView(ui.body("這些紀錄會進入週報與同步佇列，方便老師下次回來時直接接續處理。", "#334155"))
        box.addView(ui.secondaryButton("AI 提示實驗室") { renderAiLab() })
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun studentFirstStepCard(): View {
        val box = ui.sectionBand(ColorToken.Card)
        box.addView(ui.eyebrow("今天先做這一步"))
        box.addView(ui.label("1 分鐘心情檢測", 24, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(8), 0, ui.dp(4))
        })
        box.addView(ui.body("完成後，English+ 才會依你的狀態開啟練習時間、今日任務和題目。今天如果累，也會先改成復原任務。", "#334155"))
        box.addView(metricRow(
            Metric("目前心情", mood.label, mood.color),
            Metric("預設時間", "${minutes} 分", ColorToken.Accent),
            Metric("信心", "$confidence%", ColorToken.Success)
        ))
        box.addView(ui.primaryButton("開始心情檢測") { renderCheckIn() })
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun lockedStudentPreviewCard(): View {
        val box = ui.container(ColorToken.Surface, ColorToken.Border)
        box.addView(ui.statusPill("完成檢測後開啟", ColorToken.Muted))
        box.addView(ui.label("接下來才會出現", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("選擇作題時間\n今日英文短任務\n答題結果與 AI 提示\n個人學習地圖與錯題修復", "#5F7287"))
        return ui.margins(box, 0, 0, 0, 12)
    }

    private fun bottomNav() {
        root.addView(ui.space(16))
        val nav = ui.container(ColorToken.Card, ColorToken.Border).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(ui.dp(8), ui.dp(8), ui.dp(8), ui.dp(8))
        }
        if (role == Role.Student) {
            nav.addView(navDestination("H", "首頁", screen == Screen.Home || screen == Screen.Account) { renderHome() }, ui.weightParams())
            nav.addView(navDestination("C", "檢測", screen == Screen.CheckIn) { renderCheckIn() }, ui.weightParams())
            nav.addView(navDestination("T", "任務", screen == Screen.Lesson || screen == Screen.AiCoach || screen == Screen.Contract || screen == Screen.Reflection) { renderStudentTaskEntry() }, ui.weightParams())
            nav.addView(navDestination("S", "支持", screen == Screen.Breakpoints || screen == Screen.Handoff || screen == Screen.Intervention || screen == Screen.HelpRequest) { renderStudentSupportEntry() }, ui.weightParams())
            nav.addView(navDestination("M", "地圖", screen == Screen.Map || screen == Screen.Report || screen == Screen.Journey || screen == Screen.QuestionBank) { renderStudentMapEntry() }, ui.weightParams())
        } else {
            nav.addView(navDestination("W", "今日", screen == Screen.Home || screen == Screen.Account) { renderHome() }, ui.weightParams())
            nav.addView(navDestination("R", "學生", screen == Screen.Roster || screen == Screen.StudentDetail || screen == Screen.StudentManager) { renderRoster() }, ui.weightParams())
            nav.addView(navDestination("Q", "接力", screen == Screen.ActionQueue || screen == Screen.Handoff || screen == Screen.Breakpoints || screen == Screen.Mentor) { renderActionQueue() }, ui.weightParams())
            nav.addView(navDestination("Y", "同步", screen == Screen.SyncCenter || screen == Screen.AiLab) { renderSyncCenter() }, ui.weightParams())
            nav.addView(navDestination("P", "報告", screen == Screen.Report) { renderWeeklyReport() }, ui.weightParams())
        }
        root.addView(ui.margins(nav, 0, 0, 0, 8))
    }

    private fun navigationArea(): String = when (screen) {
        Screen.Home, Screen.Account -> "首頁"
        Screen.Lesson, Screen.AiCoach, Screen.Contract, Screen.Reflection -> "任務"
        Screen.Breakpoints, Screen.Handoff, Screen.Intervention, Screen.HelpRequest -> "支持"
        Screen.Profile -> "檔案"
        else -> "地圖"
    }

    private fun navDestination(mark: String, label: String, selected: Boolean, action: () -> Unit): View {
        val fill = if (selected) ColorToken.PrimarySoft else ColorToken.Card
        val stroke = if (selected) ColorToken.Primary else ColorToken.Border
        val box = ui.container(fill, stroke).apply {
            gravity = Gravity.CENTER
            setPadding(ui.dp(4), ui.dp(8), ui.dp(4), ui.dp(8))
            setOnClickListener { action() }
        }
        box.addView(ui.label(mark, 13, if (selected) ColorToken.Primary else ColorToken.Muted, true).apply {
            gravity = Gravity.CENTER
            setPadding(ui.dp(8), ui.dp(4), ui.dp(8), ui.dp(4))
            background = ui.rounded(if (selected) ColorToken.Card else ColorToken.Surface, stroke)
        })
        box.addView(ui.label(label, 12, if (selected) ColorToken.Ink else ColorToken.Muted, true).apply {
            gravity = Gravity.CENTER
            setPadding(0, ui.dp(4), 0, 0)
        })
        return box
    }

    private fun actionGrid(a: ActionItem, b: ActionItem, c: ActionItem, d: ActionItem): View {
        val outer = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val row1 = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        val row2 = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        row1.addView(actionCard(a), ui.weightParams())
        row1.addView(actionCard(b), ui.weightParams())
        row2.addView(actionCard(c), ui.weightParams())
        row2.addView(actionCard(d), ui.weightParams())
        outer.addView(row1)
        outer.addView(row2)
        return outer
    }

    private fun actionCard(item: ActionItem): View {
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.statusPill("GO", ColorToken.Accent))
        box.addView(ui.space(8))
        box.addView(ui.label(item.title, 16, ColorToken.Ink, true))
        box.addView(ui.body(item.subtitle, ColorToken.Muted).apply { setPadding(0, ui.dp(4), 0, 0) })
        box.setOnClickListener { item.action() }
        return ui.margins(box, 4, 4, 4, 4)
    }

    private fun nextActionCard(): View {
        val task = studyTasks.first()
        val box = ui.sectionBand(ColorToken.Card)
        box.addView(ui.eyebrow("今天先做這個"))
        box.addView(ui.label(task.title, 22, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(8), 0, ui.dp(4))
        })
        box.addView(ui.body(task.reason, "#334155"))
        box.addView(metricRow(
            Metric("心情", mood.label, mood.color),
            Metric("任務", "${minutes} 分", ColorToken.Accent),
            Metric("信心", "$confidence%", ColorToken.Success)
        ))
        box.addView(ui.primaryButton("開始這個任務") { renderTaskQueue() })
        box.addView(ui.secondaryButton("我想先調整今天狀態") { renderCheckIn() })
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun progressRhythmCard(): View {
        val totalSteps = 6
        val todayProgress = (completedTasks % totalSteps).coerceAtLeast(1)
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("今日節奏", ColorToken.Primary))
        box.addView(ui.label("小步驟 ${todayProgress} / $totalSteps", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = totalSteps
            progress = todayProgress
            setPadding(0, ui.dp(8), 0, ui.dp(8))
        })
        box.addView(ui.body("你已完成 $completedTasks 個微任務。下一步先把今天最小的一題做完。", "#334155"))
        return ui.margins(box, 0, 0, 0, 12)
    }

    private fun trackEntry(
        label: String,
        title: String,
        detail: String,
        fill: String,
        actionText: String,
        action: () -> Unit
    ): View {
        val box = ui.container(fill, ColorToken.Border)
        box.addView(ui.statusPill(label, if (label == "支持軌") ColorToken.Accent else ColorToken.Primary))
        box.addView(ui.label(title, 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(detail, "#334155"))
        box.addView(ui.secondaryButton(actionText) { action() })
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun checkInIntroCard(): View {
        val box = ui.sectionBand(ColorToken.AccentSoft)
        box.addView(ui.statusPill("CHECK IN", ColorToken.Accent))
        box.addView(ui.label("先讓平台知道今天的你", 21, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("心情不是額外步驟，它會幫你把任務縮到今天還做得到的大小。", "#334155"))
        box.addView(metricRow(
            Metric("建議", mood.planName, mood.color),
            Metric("時間", "${minutes} 分", ColorToken.Primary),
            Metric("狀態", "$confidence%", ColorToken.Success)
        ))
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun selectedMoodResponse(): View {
        val fill = if (mood == Mood.Low) ColorToken.WarningSoft else ColorToken.SuccessSoft
        val color = if (mood == Mood.Low) ColorToken.Warning else ColorToken.Success
        val response = if (mood == Mood.Low) {
            "English+ 會先縮短任務、保留求助出口，今天只做一小步也算完成。"
        } else {
            "English+ 會依你現在的狀態安排任務長度，讓開始比硬撐更容易。"
        }
        val box = ui.container(fill, ColorToken.Border)
        box.addView(ui.statusPill("平台回應", color))
        box.addView(ui.label("你選的是：${mood.label}", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(response, "#334155"))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun checkInGateCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("下一步才選時間", ColorToken.Primary))
        box.addView(ui.label("先確認狀態，再決定練多久", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("這一頁只做心情檢測。English+ 不會在同一屏塞任務、地圖和作題入口，避免一開始就太亂。", "#334155"))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun practiceTimeIntroCard(): View {
        val box = ui.sectionBand(ColorToken.PrimarySoft)
        box.addView(ui.statusPill("STEP 2", ColorToken.Primary))
        box.addView(ui.label("依照 ${mood.label} 安排今天的量", 21, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("你剛剛完成了心情檢測。現在只要選今天願意投入的時間，下一頁才會出現今日任務。", "#334155"))
        box.addView(metricRow(
            Metric("狀態", mood.planName, mood.color),
            Metric("建議", "${mood.defaultMinutes} 分", ColorToken.Accent),
            Metric("信心", "$confidence%", ColorToken.Success)
        ))
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun planPreviewCard(): View {
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.statusPill("今日小計畫", ColorToken.Primary))
        box.addView(ui.label(mood.planName, 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("任務時間：${minutes} 分鐘\n回饋方式：先提示、再修復，不用排行榜刺激。", "#334155"))
        box.addView(ui.body("完成後可以再回來記下感受，讓下一次更貼近你。", ColorToken.Success).apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        if (mood == Mood.Low) {
            box.addView(ui.divider())
            box.addView(ui.body("今天先慢一點也可以。若短任務還是卡住，平台會保留求助與接力出口。", ColorToken.Warning))
        }
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun supportStepCard(step: String, title: String, detail: String, fill: String, color: String): View {
        val box = ui.container(fill, ColorToken.Border)
        box.addView(ui.statusPill(step, color))
        box.addView(ui.label(title, 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(detail, "#334155"))
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun helpIntroCard(): View {
        val box = ui.sectionBand(ColorToken.SuccessSoft)
        box.addView(ui.statusPill("可以開口", ColorToken.Success))
        box.addView(ui.label("求助不是失敗，是選下一種支持", 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("English+ 會先分流：能由 AI 立即拆小的就先陪你試，需要真人時才把脈絡整理好交出去。", "#334155"))
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun preparedHandoffCard(): View {
        val box = ui.sectionBand(ColorToken.SuccessSoft)
        box.addView(ui.statusPill("已整理", ColorToken.Success))
        box.addView(ui.label("你不用再重講一次卡在哪", 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("English+ 已把心情狀態、任務長度、斷點證據和 AI 做過的處理一起整理，讓志工從陪伴開始。", "#334155"))
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun storageStatusCard(): View {
        val snapshot = stateStore.storageSnapshot()
        val stateText = if (snapshot.stateSaved) "已保存" else "尚未建立"
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Border)
        box.addView(ui.statusPill("本機資料庫", ColorToken.Success))
        box.addView(ui.label("學習紀錄已寫入手機", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("狀態", stateText, ColorToken.Success),
            Metric("事件", "${snapshot.eventCount} 筆", ColorToken.Primary),
            Metric("待補傳", "${snapshot.pendingSyncCount} 筆", if (snapshot.pendingSyncCount > 0) ColorToken.Warning else ColorToken.Success)
        ))
        box.addView(ui.body("最新紀錄：${snapshot.latestEventTitle}\n協作紀錄：${snapshot.collaborationCount} 筆｜離線包：${snapshot.downloadedPackCount} 包", "#334155"))
        box.addView(ui.body("目前先存在 SQLite；同步中心會把待補傳資料整理成佇列，之後可接 Firebase 或校內後端。", ColorToken.Muted).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun questionBankSummaryCard(): View {
        val bankItems = stateStore.questionBankItems()
        val skillCount = bankItems.map { it.skill }.distinct().size
        val unitCount = bankItems.map { it.unit }.distinct().size
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Border)
        box.addView(ui.statusPill("題庫已本機化", ColorToken.Success))
        box.addView(ui.label("English+ 正式題庫骨架", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("題目", "${bankItems.size} 題", ColorToken.Primary),
            Metric("單元", "$unitCount 組", ColorToken.Accent),
            Metric("技能", "$skillCount 類", ColorToken.Success)
        ))
        box.addView(ui.body("練習題已從展示清單升級為 SQLite 題庫，保留 level、unit、skill、source 欄位，後續可接分級題庫或老師後台匯入。", "#334155"))
        box.addView(ui.secondaryButton("打開題庫中心") { renderQuestionBank() })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun questionBankItemCard(item: QuestionBankItem): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(item.question.prompt, 16, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(item.level, ColorToken.Primary))
        box.addView(top)
        box.addView(ui.body("${item.unit}｜${item.skill}｜${item.source}｜${item.reviewState}", ColorToken.Muted).apply { setPadding(0, ui.dp(7), 0, 0) })
        box.addView(ui.body("答案：${item.question.answer}\n提示：${item.question.repairHint}", "#334155"))
        box.setOnClickListener {
            val index = questions.indexOfFirst { it.prompt == item.question.prompt && it.answer == item.question.answer }
            if (index >= 0) {
                currentQuestionIndex = index
                renderLesson()
            }
        }
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun cloudBackendStatusCard(): View {
        val hasBackend = stateStore.hasCloudBackend()
        val box = ui.container(if (hasBackend) ColorToken.SuccessSoft else ColorToken.WarningSoft, ColorToken.Border)
        box.addView(ui.statusPill(if (hasBackend) "雲端後端已設定" else "尚未接雲端", if (hasBackend) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label(if (hasBackend) "可同步到後端 API" else "目前仍是本機 SQLite 模式", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(
            if (hasBackend) {
                "目前端點：${stateStore.cloudBackendUrl()}\n按下同步後會以 JSON POST 傳送本機摘要。"
            } else {
                "貼上 Firebase Cloud Function、校內 API 或測試 webhook URL 後，就能把本機資料送到雲端。"
            },
            "#334155"
        ))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun smartSyncStatusCard(): View {
        val networkReady = isNetworkAvailable()
        val backendReady = stateStore.hasCloudBackend()
        val ready = networkReady && backendReady
        val box = ui.container(if (ready) ColorToken.SuccessSoft else ColorToken.WarningSoft, ColorToken.Border)
        box.addView(ui.statusPill(if (ready) "真同步可執行" else "同步需補件", if (ready) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label("智慧同步檢查", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(syncReadinessText(), "#334155"))
        box.addView(ui.body("按下智慧同步時，English+ 會先檢查網路與後端 URL；失敗就保留待補傳，成功才把本機佇列標記為已同步。", ColorToken.Muted).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun cloudBackendSettingsCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label("雲端後端設定", 18, ColorToken.Ink, true))
        box.addView(ui.body("支援任何可接收 JSON POST 的 HTTPS/HTTP 端點。Firebase Cloud Functions、學校後端 API、測試 webhook 都可以。"))
        val input = EditText(this).apply {
            hint = "https://example.com/api/english-plus/sync"
            setText(stateStore.cloudBackendUrl())
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
            setSingleLine(true)
            textSize = 15f
            setTextColor(Color.parseColor(ColorToken.Ink))
            setHintTextColor(Color.parseColor(ColorToken.Muted))
            background = ui.rounded(ColorToken.Surface, ColorToken.Border)
            setPadding(ui.dp(14), ui.dp(12), ui.dp(14), ui.dp(12))
            layoutParams = ui.fullWidthParams()
        }
        box.addView(input)
        box.addView(ui.primaryButton("儲存雲端端點") {
            stateStore.saveCloudBackendUrl(input.text.toString())
            recordLearningEvent("cloud_backend_config", "已更新雲端後端端點", stateStore.cloudBackendUrl().ifBlank { "已清空" })
            renderSyncCenter()
        })
        box.addView(ui.secondaryButton("清除端點，保留本機模式") {
            stateStore.saveCloudBackendUrl("")
            recordLearningEvent("cloud_backend_config", "已清除雲端後端端點", "回到純本機 SQLite 模式。")
            renderSyncCenter()
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun classContextCard(): View {
        val account = currentAccount()
        val fill = if (AuthContract.isStudentRole(account.roleLabel)) ColorToken.PrimarySoft else ColorToken.SuccessSoft
        val color = if (AuthContract.isStudentRole(account.roleLabel)) ColorToken.Primary else ColorToken.Success
        val box = ui.container(fill, ColorToken.Border)
        box.addView(ui.statusPill(if (stateStore.hasRemoteAuthEndpoint()) "正式登入準備" else "展示登入", color))
        box.addView(ui.label("${account.displayName}｜${account.roleLabel}", 17, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("班級/群組代碼：${account.classCode}", "#334155"))
        box.addView(ui.body("可用本機展示帳號，也可在帳號中心接校內/Firebase 登入端點。", ColorToken.Muted).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun remoteAuthStatusCard(): View {
        val hasEndpoint = stateStore.hasRemoteAuthEndpoint()
        val box = ui.container(if (hasEndpoint) ColorToken.SuccessSoft else ColorToken.WarningSoft, ColorToken.Border)
        box.addView(ui.statusPill(if (hasEndpoint) "正式登入端點已設定" else "本機展示登入", if (hasEndpoint) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label(if (hasEndpoint) "可呼叫校內/Firebase 登入 API" else "尚未接正式登入服務", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("${stateStore.authSessionSummary()}\n\n端點：${stateStore.remoteAuthEndpoint().ifBlank { "尚未設定" }}", "#334155"))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun accountReadinessCard(): View {
        val accounts = accountList()
        val studentCount = accounts.count { AuthContract.isStudentRole(it.roleLabel) }
        val staffCount = accounts.count { AuthContract.isStaffRole(it.roleLabel) }
        val endpointState = if (stateStore.hasRemoteAuthEndpoint()) "已設定" else "待設定"
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("第二輪帳號正式化", ColorToken.Primary))
        box.addView(ui.label("角色與登入狀態", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(
            "學生帳號：$studentCount\n老師/志工帳號：$staffCount\n正式登入端點：$endpointState\n支援路線：Firebase Auth、Google Sign-In、校內 SSO 後端代理",
            "#334155"
        ))
        box.addView(ui.body(
            "目前仍保留 demo mode，避免沒有 Firebase 專案時展示流程中斷；正式上線時，demo 帳號會降級為測試模式。",
            ColorToken.Muted
        ).apply { setPadding(0, ui.dp(8), 0, 0) })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun remoteAuthLoginCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label("正式登入設定", 18, ColorToken.Ink, true))
        box.addView(ui.body("支援 Firebase Auth 包裝 API、Google 登入後端或校內帳號 API。後端需接受 JSON：username、password、classCode，回傳 displayName、roleLabel、classCode、token。"))

        val endpointInput = EditText(this).apply {
            hint = "https://example.com/api/auth/login"
            setText(stateStore.remoteAuthEndpoint())
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_URI
            setSingleLine(true)
            textSize = 15f
            setTextColor(Color.parseColor(ColorToken.Ink))
            setHintTextColor(Color.parseColor(ColorToken.Muted))
            background = ui.rounded(ColorToken.Surface, ColorToken.Border)
            setPadding(ui.dp(14), ui.dp(12), ui.dp(14), ui.dp(12))
            layoutParams = ui.fullWidthParams()
        }
        val usernameInput = EditText(this).apply {
            hint = "帳號 / email / 學號"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS
            setSingleLine(true)
            textSize = 15f
            setTextColor(Color.parseColor(ColorToken.Ink))
            setHintTextColor(Color.parseColor(ColorToken.Muted))
            background = ui.rounded(ColorToken.Surface, ColorToken.Border)
            setPadding(ui.dp(14), ui.dp(12), ui.dp(14), ui.dp(12))
            layoutParams = ui.fullWidthParams()
        }
        val passwordInput = EditText(this).apply {
            hint = "密碼"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            setSingleLine(true)
            textSize = 15f
            setTextColor(Color.parseColor(ColorToken.Ink))
            setHintTextColor(Color.parseColor(ColorToken.Muted))
            background = ui.rounded(ColorToken.Surface, ColorToken.Border)
            setPadding(ui.dp(14), ui.dp(12), ui.dp(14), ui.dp(12))
            layoutParams = ui.fullWidthParams()
        }
        val classInput = EditText(this).apply {
            hint = "班級/群組代碼，例如 YILAN-CHENGZHI-8A"
            setText(currentAccount().classCode)
            inputType = InputType.TYPE_CLASS_TEXT
            setSingleLine(true)
            textSize = 15f
            setTextColor(Color.parseColor(ColorToken.Ink))
            setHintTextColor(Color.parseColor(ColorToken.Muted))
            background = ui.rounded(ColorToken.Surface, ColorToken.Border)
            setPadding(ui.dp(14), ui.dp(12), ui.dp(14), ui.dp(12))
            layoutParams = ui.fullWidthParams()
        }
        box.addView(endpointInput)
        box.addView(usernameInput)
        box.addView(passwordInput)
        box.addView(classInput)
        box.addView(ui.primaryButton("儲存端點並登入") {
            stateStore.saveRemoteAuthEndpoint(endpointInput.text.toString())
            renderRemoteLoginProgress(
                username = usernameInput.text.toString().trim(),
                password = passwordInput.text.toString(),
                classCode = classInput.text.toString().trim()
            )
        })
        box.addView(ui.secondaryButton("只儲存登入端點") {
            stateStore.saveRemoteAuthEndpoint(endpointInput.text.toString())
            recordLearningEvent("remote_auth_config", "已更新正式登入端點", stateStore.remoteAuthEndpoint().ifBlank { "已清空" })
            renderAccountCenter()
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun currentTaskFocus(): View {
        val task = studyTasks.first()
        val box = ui.sectionBand(ColorToken.PrimarySoft)
        box.addView(ui.statusPill("現在先做", ColorToken.Accent))
        box.addView(ui.label(task.title, 23, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("時間", "${task.minutes} 分", ColorToken.Primary),
            Metric("概念", "1 個", ColorToken.Success),
            Metric("完成", "答一題", ColorToken.Accent)
        ))
        box.addView(ui.body("你不用先看完整任務表。English+ 先把最適合現在的第一步放在這裡。", "#334155"))
        box.addView(ui.body("排序原因：${task.reason}", ColorToken.Primary).apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        box.addView(ui.body("路徑來源：心情檢測 ${mood.label} → ${minutes} 分鐘 → 今日第一題。", ColorToken.Success).apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        box.addView(ui.primaryButton("開始第一題") { renderLesson() })
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun taskRouteCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("今日安排", ColorToken.Primary))
        box.addView(ui.label("先修復，再往前", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("目前可用 ${minutes} 分鐘，平台依「${mood.planName}」先排低壓修復；等第一題站穩，再決定要不要加挑戰。", "#334155"))
        box.addView(flowStrip("第一題", "即時回饋", "完成或支持"))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun lessonFocusCard(): View {
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.statusPill("任務目標", ColorToken.Primary))
        box.addView(ui.label("先完成一題，再決定下一步", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("這裡只修一個概念。你先看懂題目、選一次，English+ 會立刻給可修復的回饋。", "#334155"))
        box.addView(ui.body("答錯會改變支持路徑，不會把你推進更難的題目。", ColorToken.Success).apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        box.addView(ui.body("題目來源：今日任務路徑，而不是直接從完整題庫隨機抽題。", ColorToken.Primary).apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun lessonSupportCard(): View {
        val fill = if (wrongAttempts > 0) ColorToken.WarningSoft else ColorToken.Card
        val box = ui.container(fill, ColorToken.Border)
        box.addView(ui.statusPill("即時狀態", if (wrongAttempts > 0) ColorToken.Warning else ColorToken.Success))
        box.addView(metricRow(
            Metric("題目", "${currentQuestionIndex + 1}/${questions.size}", ColorToken.Primary),
            Metric("卡住", "$wrongAttempts/3", if (wrongAttempts > 0) ColorToken.Warning else ColorToken.Success),
            Metric("信心", "$confidence%", ColorToken.Accent)
        ))
        box.addView(ui.body(lastAnswerMessage, "#334155"))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun lessonExitCard(): View {
        val fill = if (wrongAttempts > 0) ColorToken.WarningSoft else ColorToken.SuccessSoft
        val color = if (wrongAttempts > 0) ColorToken.Warning else ColorToken.Success
        val message = if (wrongAttempts > 0) {
            "有點卡住時，可以先讓 AI 拆小，或直接改成復原任務。"
        } else {
            "現在可以直接作答；需要時，支持出口一直都在。"
        }
        val box = ui.container(fill, ColorToken.Border)
        box.addView(ui.statusPill("支持出口", color))
        box.addView(ui.label("不用硬撐同一條路", 17, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(message, "#334155"))
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun successSummaryCard(question: Question): View {
        val box = ui.sectionBand(ColorToken.SuccessSoft)
        box.addView(ui.statusPill("答對", ColorToken.Success))
        box.addView(ui.label("答對了，這一題完成", 24, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("你的答案：${question.answer}\n${question.explanation}", "#334155"))
        box.addView(metricRow(
            Metric("任務", "$completedTasks", ColorToken.Primary),
            Metric("信心", "$confidence%", ColorToken.Success),
            Metric("結果", "正確", ColorToken.Success)
        ))
        box.addView(ui.body("下一步已開啟：可以進下一題，也可以先做 20 秒反思把完成感留下來。", ColorToken.Primary))
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun answerResultCard(isCorrect: Boolean, question: Question, selectedAnswer: String): View {
        val fill = if (isCorrect) ColorToken.SuccessSoft else ColorToken.WarningSoft
        val color = if (isCorrect) ColorToken.Success else ColorToken.Warning
        val title = if (isCorrect) "答對了" else "還沒答對"
        val subtitle = if (isCorrect) "這一題已經完成。" else "你選的答案和正確答案不同。"
        val box = ui.sectionBand(fill)
        box.addView(ui.statusPill(if (isCorrect) "正確" else "需要修復", color))
        box.addView(ui.label(title, 26, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(subtitle, "#334155"))
        box.addView(metricRow(
            Metric("你的答案", selectedAnswer.ifBlank { "未記錄" }, color),
            Metric("正確答案", question.answer, ColorToken.Success),
            Metric("狀態", if (isCorrect) "完成" else "再試一次", color)
        ))
        box.addView(ui.body("為什麼：${question.explanation}", "#334155").apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun contractPreviewCard(contract: LearningContract): View {
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Border)
        box.addView(ui.label("今日學習契約", 14, ColorToken.Success, true))
        box.addView(ui.label(contract.title, 18, ColorToken.Ink, true).apply { setPadding(0, ui.dp(6), 0, ui.dp(3)) })
        box.addView(ui.body(contract.studentPromise, "#334155"))
        box.setOnClickListener { renderLearningContract() }
        return ui.margins(box, 0, 8, 0, 10)
    }

    private fun accountCard(account: LocalAccount): View {
        val box = ui.container(if (account.displayName == selectedAccountName) ColorToken.PrimarySoft else ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(account.displayName, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(account.roleLabel, if (account.roleLabel == "學生") ColorToken.Primary else ColorToken.Success))
        box.addView(top)
        box.addView(ui.body("班級/群組代碼：${account.classCode}", "#334155").apply { setPadding(0, ui.dp(7), 0, 0) })
        box.addView(ui.body(account.loginState, ColorToken.Muted))
        box.setOnClickListener {
            selectAccount(account)
            renderAccountCenter()
        }
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun aiScenarioCard(scenario: AiScenario): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label(scenario.title, 17, ColorToken.Ink, true))
        box.addView(ui.body("輸入：${scenario.input}", ColorToken.Muted).apply { setPadding(0, ui.dp(7), 0, 0) })
        box.addView(ui.body("診斷：${scenario.diagnosis}", "#334155"))
        box.addView(ui.body("學生回饋：${scenario.feedback}", ColorToken.Primary))
        box.addView(ui.body("接力摘要：${scenario.handoffSummary}", ColorToken.Success))
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun contractCard(contract: LearningContract): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label(contract.title, 18, ColorToken.Ink, true))
        box.addView(ui.divider())
        box.addView(ui.body("學生承諾：${contract.studentPromise}", "#334155"))
        box.addView(ui.body("平台承諾：${contract.platformPromise}", ColorToken.Primary).apply { setPadding(0, ui.dp(6), 0, 0) })
        box.addView(ui.body("真人接力：${contract.mentorPromise}", ColorToken.Success).apply { setPadding(0, ui.dp(6), 0, 0) })
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun reflectionCard(prompt: ReflectionPrompt): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label(prompt.title, 17, ColorToken.Ink, true))
        box.addView(ui.body(prompt.studentChoice, ColorToken.Muted).apply { setPadding(0, ui.dp(6), 0, 0) })
        box.addView(ui.body("平台回應：${prompt.platformResponse}", "#334155").apply { setPadding(0, ui.dp(6), 0, 0) })
        box.setOnClickListener { handleReflection(prompt) }
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun timelineCard(title: String, detail: String, color: String): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.statusPill("紀錄", color))
        top.addView(ui.label(title, 16, ColorToken.Ink, true).apply {
            setPadding(ui.dp(10), 0, 0, 0)
        }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        box.addView(top)
        box.addView(ui.body(detail, "#334155").apply { setPadding(0, ui.dp(8), 0, 0) })
        return ui.margins(box, 0, 7, 0, 7)
    }

    private fun teacherActionCard(action: TeacherAction): View {
        val index = teacherActions.indexOf(action)
        val completed = index in 0 until actionDoneCount
        val color = when (action.status) {
            "今日待處理" -> ColorToken.Danger
            "本週追蹤" -> ColorToken.Warning
            else -> ColorToken.Primary
        }
        val box = ui.container(if (completed) ColorToken.SuccessSoft else if (action.status == "今日待處理") ColorToken.WarningSoft else ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(action.title, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(if (completed) "已完成" else action.status, if (completed) ColorToken.Success else color))
        box.addView(top)
        box.addView(ui.body("負責：${action.owner}｜期限：${action.due}", ColorToken.Muted).apply { setPadding(0, ui.dp(7), 0, 0) })
        box.addView(ui.body("證據：${action.evidence}", "#334155"))
        box.addView(ui.body("下一步：${action.nextStep}", ColorToken.Success))
        if (!completed) {
            box.setOnClickListener {
                actionDoneCount = (index + 1).coerceAtLeast(actionDoneCount + 1).coerceAtMost(teacherActions.size)
                addCollaborationNote(
                    actor = action.owner,
                    roleLabel = "接力負責人",
                    target = action.title,
                    note = "已依據證據處理：${action.nextStep}",
                    status = "待辦已完成"
                )
                renderActionQueue()
            }
        }
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun recentCollaborationNotes(limit: Int): List<CollaborationNote> {
        val notes = collaborationNotes.take(limit)
        if (notes.isNotEmpty()) return notes
        return listOf(
            CollaborationNote(
                actor = "系統",
                role = "展示資料",
                target = student.name,
                note = "尚未建立真人接力紀錄。可以從雲端志工接力、陪伴腳本或待辦佇列新增。",
                status = "待建立"
            )
        )
    }

    private fun remoteCollaborationStatusCard(): View {
        val hasBackend = stateStore.hasCloudBackend()
        val box = ui.container(if (hasBackend) ColorToken.SuccessSoft else ColorToken.WarningSoft, ColorToken.Border)
        box.addView(ui.statusPill(if (hasBackend) "多人協作可同步" else "本機協作模式", if (hasBackend) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label(if (hasBackend) "老師/志工紀錄可推送與拉取" else "尚未設定協作後端", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(
            if (hasBackend) {
                "目前使用同步中心的雲端端點：${stateStore.cloudBackendUrl()}\n可推送本機協作並拉取遠端協作 feed。"
            } else {
                "先到同步中心貼上後端 URL，才能讓老師與志工跨裝置看到彼此的協作紀錄。"
            },
            "#334155"
        ))
        box.addView(ui.primaryButton(if (hasBackend) "推送並拉取協作紀錄" else "前往同步中心設定") {
            if (hasBackend) renderRemoteCollaborationSync(pushFirst = true) else renderSyncCenter()
        })
        box.addView(ui.secondaryButton("只拉取遠端協作") {
            renderRemoteCollaborationSync(pushFirst = false)
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun importRemoteCollaborationNotes(response: JSONObject): Int {
        val notes = response.optJSONArray("collaborationNotes")
            ?: response.optJSONArray("notes")
            ?: response.optJSONObject("payload")?.optJSONArray("collaborationNotes")
            ?: JSONArray()
        val imported = mutableListOf<CollaborationNote>()
        for (index in 0 until notes.length()) {
            val item = notes.optJSONObject(index) ?: continue
            imported.add(
                CollaborationNote(
                    actor = item.optString("actor", "遠端使用者"),
                    role = item.optString("role", item.optString("roleLabel", "協作者")),
                    target = item.optString("target", currentAccount().classCode),
                    note = item.optString("note", item.optString("content", "遠端協作紀錄")),
                    status = item.optString("status", "遠端同步"),
                    createdAt = item.optLong("createdAt", System.currentTimeMillis())
                )
            )
        }
        val importedCount = stateStore.addUniqueCollaborationNotes(imported)
        if (importedCount > 0) {
            addOfflineSyncItem("遠端協作匯入", "多人協作", "已匯入 ${imported.size} 筆遠端老師/志工紀錄。", "已同步")
        }
        return importedCount
    }

    private fun collaborationNoteCard(note: CollaborationNote): View {
        val color = when (note.status) {
            "已回覆", "腳本已用", "待辦已完成" -> ColorToken.Success
            "已處理" -> ColorToken.Primary
            else -> ColorToken.Warning
        }
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(note.actor, 16, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(note.status, color))
        box.addView(top)
        box.addView(ui.body("${note.role}｜對象：${note.target}", ColorToken.Muted).apply { setPadding(0, ui.dp(7), 0, 0) })
        box.addView(ui.body(note.note, "#334155"))
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun syncCard(record: SyncRecord): View {
        val color = when (record.status) {
            "已同步" -> ColorToken.Success
            "待回覆" -> ColorToken.Warning
            else -> ColorToken.Primary
        }
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(record.title, 16, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(record.status, color))
        box.addView(top)
        box.addView(ui.body(record.detail, "#334155").apply { setPadding(0, ui.dp(7), 0, 0) })
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun offlineSyncItemCard(item: OfflineSyncItem): View {
        val color = when (item.status) {
            "已同步", "已下載" -> ColorToken.Success
            "待上傳" -> ColorToken.Warning
            else -> ColorToken.Primary
        }
        val fill = if (item.status == "待上傳") ColorToken.WarningSoft else ColorToken.Card
        val box = ui.container(fill, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(item.title, 16, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(item.status, color))
        box.addView(top)
        box.addView(ui.body("${item.category}｜${item.detail}", "#334155").apply { setPadding(0, ui.dp(7), 0, 0) })
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun flowStrip(vararg steps: String): View {
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.label("今日服務路徑", 14, ColorToken.Muted, true))
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        steps.forEachIndexed { index, step ->
            val node = LinearLayout(this).apply {
                orientation = LinearLayout.VERTICAL
                gravity = Gravity.CENTER
                setPadding(ui.dp(4), ui.dp(8), ui.dp(4), ui.dp(8))
            }
            node.addView(ui.statusPill("${index + 1}", if (index == 0) ColorToken.Accent else if (index <= 1) ColorToken.Primary else ColorToken.Success))
            node.addView(ui.label(step, 12, ColorToken.Ink, true).apply {
                gravity = Gravity.CENTER
                setPadding(0, ui.dp(4), 0, 0)
            })
            row.addView(node, ui.weightParams())
        }
        box.addView(row)
        return ui.margins(box, 0, 8, 0, 10)
    }

    private fun questionCard(question: Question): View {
        val box = ui.sectionBand(ColorToken.Card)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.statusPill("題目 ${currentQuestionIndex + 1}", ColorToken.Accent))
        top.addView(ui.label(question.type, 14, ColorToken.Muted, true).apply {
            setPadding(ui.dp(10), ui.dp(3), 0, 0)
        }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill("一個概念", ColorToken.Success))
        box.addView(top)
        box.addView(ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = questions.size
            progress = currentQuestionIndex + 1
            setPadding(0, ui.dp(12), 0, ui.dp(8))
        })
        box.addView(ui.label(questionInstruction(question), 14, ColorToken.Primary, true))
        box.addView(ui.label(question.prompt, 27, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(12))
        })
        box.addView(ui.body(question.repairHint, ColorToken.Muted).apply {
            setPadding(0, 0, 0, ui.dp(8))
        })
        question.options.forEach { option ->
            box.addView(ui.secondaryButton(option) { answer(option) })
        }
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun questionInstruction(question: Question): String {
        return when (question.type) {
            "填空題" -> "讀完整句，選出最適合放入空格的答案"
            "克漏字" -> "先看空格前後文，再選出最自然的答案"
            "閱讀理解" -> "先看題目問什麼，再回文字找線索"
            "翻譯/句子重組" -> "比較語序與句意，選出最自然的英文"
            else -> "先選出最適合的答案"
        }
    }

    private fun moduleCard(module: LearningModule): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(module.title, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(module.status, ColorToken.Primary))
        box.addView(top)
        box.addView(ui.body(module.subtitle, ColorToken.Muted))
        box.addView(ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = module.progress
            setPadding(0, ui.dp(8), 0, ui.dp(6))
        })
        box.addView(ui.body("${module.progress}%｜${module.nextStep}", "#334155"))
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun studentRouteStatusCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("學生路徑", ColorToken.Primary))
        box.addView(ui.label("情緒檢測完成後，才進入練習與地圖", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(flowStrip(
            if (checkInCompleted) "已檢測" else "先檢測",
            if (practiceTimeConfirmed) "${minutes} 分鐘" else "選時間",
            "今日任務",
            "我的地圖"
        ))
        box.addView(ui.body("目前狀態：${mood.label}｜可用 $minutes 分鐘｜信心 $confidence%。頁面只顯示下一步需要的內容。", "#334155"))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun studentPracticeOptionCard(item: QuestionBankItem): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(item.skill, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(item.level, ColorToken.Accent))
        box.addView(top)
        box.addView(ui.body("${item.unit}｜${item.question.type}", ColorToken.Muted).apply { setPadding(0, ui.dp(6), 0, 0) })
        box.addView(ui.body(item.question.prompt.take(90), "#334155").apply { setPadding(0, ui.dp(6), 0, 0) })
        box.addView(ui.body("點選後會進入今日任務答題，不會開啟老師端題庫管理。", ColorToken.Success).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        box.setOnClickListener { renderLesson() }
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun studentLearningEvidenceCard(row: StudentRow): View {
        val fill = if (row.risk == "高") ColorToken.WarningSoft else ColorToken.Card
        val riskColor = when (row.risk) {
            "高" -> ColorToken.Danger
            "中" -> ColorToken.Warning
            else -> ColorToken.Success
        }
        val box = ui.container(fill, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(row.name, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill("證據 ${row.risk}", riskColor))
        box.addView(top)
        box.addView(ui.body("學習訊號：${row.status}", "#334155").apply { setPadding(0, ui.dp(7), 0, 0) })
        box.addView(ui.body("老師判讀：${row.issue}", ColorToken.Muted))
        box.addView(ui.body(if (row.risk == "高") "建議：今日安排真人接力。" else "建議：保留學生自己的任務節奏。", riskColor).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        box.setOnClickListener { renderStudentDetail(row) }
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun taskCard(task: StudyTask): View {
        val fill = when (task.status) {
            "今日優先" -> ColorToken.PrimarySoft
            "待解鎖" -> ColorToken.VioletSoft
            else -> ColorToken.Card
        }
        val box = ui.container(fill, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(task.title, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill("${task.minutes} 分鐘", ColorToken.Primary))
        box.addView(top)
        box.addView(ui.body("難度：${task.difficulty}｜${task.status}", ColorToken.Muted))
        box.addView(ui.body(task.reason, "#334155"))
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun journeyCard(index: Int, item: JourneyStep): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.statusPill("0$index", ColorToken.Primary))
        top.addView(ui.label(item.stage, 18, ColorToken.Ink, true).apply {
            setPadding(ui.dp(10), 0, 0, 0)
        }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        box.addView(top)
        box.addView(ui.divider())
        box.addView(ui.body("學生感受：${item.studentFeeling}", ColorToken.Muted))
        box.addView(ui.body("平台回應：${item.platformResponse}", "#334155").apply { setPadding(0, ui.dp(6), 0, 0) })
        box.addView(ui.body("接力規則：${item.handoffRule}", ColorToken.Success).apply { setPadding(0, ui.dp(6), 0, 0) })
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun interventionCard(item: InterventionStep): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill(item.trigger, ColorToken.Warning))
        box.addView(ui.label(item.designAction, 17, ColorToken.Ink, true).apply { setPadding(0, ui.dp(10), 0, ui.dp(4)) })
        box.addView(ui.body("學生看到：${item.studentCopy}", ColorToken.Primary))
        box.addView(ui.body("設計證據：${item.evidence}", ColorToken.Muted).apply { setPadding(0, ui.dp(6), 0, 0) })
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun principleCard(item: DesignPrinciple): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label(item.title, 18, ColorToken.Ink, true))
        box.addView(ui.body(item.detail, "#334155").apply { setPadding(0, ui.dp(6), 0, 0) })
        box.addView(ui.body("原型證據：${item.productProof}", ColorToken.Success).apply { setPadding(0, ui.dp(6), 0, 0) })
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun helpOptionCard(option: HelpRequestOption): View {
        val routeColor = when (option.route) {
            "志工接力" -> ColorToken.Danger
            "復原模式" -> ColorToken.Warning
            "離線任務" -> ColorToken.Accent
            else -> ColorToken.Primary
        }
        val routeFill = when (option.route) {
            "志工接力" -> ColorToken.WarningSoft
            "復原模式" -> ColorToken.WarningSoft
            "離線任務" -> ColorToken.AccentSoft
            else -> ColorToken.PrimarySoft
        }
        val box = ui.container(routeFill, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(option.reason, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(option.route, routeColor))
        box.addView(top)
        box.addView(ui.body(option.studentText, ColorToken.Muted).apply { setPadding(0, ui.dp(8), 0, 0) })
        box.addView(ui.divider())
        box.addView(ui.body("接下來：${option.platformAction}", "#334155"))
        box.addView(ui.body("點一下，English+ 會先把這條支持路徑打開。", routeColor).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        box.setOnClickListener { handleHelpRequest(option) }
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun studentRowCard(row: StudentRow): View {
        val fill = if (row.risk == "高") ColorToken.WarningSoft else ColorToken.Card
        val riskColor = when (row.risk) {
            "高" -> ColorToken.Danger
            "中" -> ColorToken.Warning
            else -> ColorToken.Success
        }
        val box = ui.container(fill, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(row.name, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill("風險 ${row.risk}", riskColor))
        box.addView(top)
        box.addView(ui.body("斷點：${row.issue}", "#334155").apply { setPadding(0, ui.dp(7), 0, 0) })
        box.addView(ui.body("狀態：${row.status}", ColorToken.Muted))
        box.setOnClickListener { renderStudentDetail(row) }
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun mistakeCard(record: MistakeRecord): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(record.concept, 16, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(record.status, if (record.status == "待接力") ColorToken.Warning else ColorToken.Primary))
        box.addView(top)
        box.addView(ui.body("錯誤型態：${record.wrongPattern}", "#334155"))
        box.addView(ui.body("修復步驟：${record.repairStep}", ColorToken.Success))
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun offlinePackCard(pack: OfflinePack): View {
        val downloaded = downloadedPackTitles.contains(pack.title)
        val box = ui.container(if (downloaded) ColorToken.SuccessSoft else ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(pack.title, 16, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(if (downloaded) "已下載" else pack.size, if (downloaded) ColorToken.Success else ColorToken.Muted))
        box.addView(top)
        box.addView(ui.body("預估時間：${pack.duration}", ColorToken.Primary))
        box.addView(ui.body(pack.content, "#334155"))
        box.setOnClickListener {
            if (!downloadedPackTitles.contains(pack.title)) {
                addOfflineSyncItem(
                    title = pack.title,
                    category = "離線任務包",
                    detail = "已下載 ${pack.size}，可在網路不穩時完成 ${pack.duration} 任務。",
                    status = "已下載"
                )
                recordLearningEvent("offline_pack", "已下載 ${pack.title}", pack.content)
                renderOfflinePacks()
            }
        }
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun messageCard(message: SupportMessage): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(message.sender, 16, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(message.time, ColorToken.Muted))
        box.addView(top)
        box.addView(ui.body(message.content, "#334155"))
        box.addView(ui.body("類型：${message.tone}", ColorToken.Success))
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun signalCard(signal: WeeklySignal): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(signal.label, 16, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.label(signal.value, 16, signal.color, true))
        box.addView(top)
        box.addView(ui.body(signal.note, ColorToken.Muted))
        return ui.margins(box, 0, 6, 0, 6)
    }

    private fun priorityCard(item: HandoffPriority): View {
        val fill = if (item.urgency == "高") ColorToken.WarningSoft else ColorToken.Card
        val box = ui.container(fill, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(item.title, 16, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(item.urgency, if (item.urgency == "高") ColorToken.Danger else ColorToken.Warning))
        box.addView(top)
        box.addView(ui.body("負責：${item.owner}", ColorToken.Muted))
        box.addView(ui.body("下一步：${item.nextAction}", ColorToken.Success))
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun mentorCheckCard(item: MentorCheck): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(item.label, 16, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.label(item.status, 14, item.color, true))
        box.addView(top)
        box.addView(ui.body(item.note, "#334155"))
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun breakpointCard(item: Breakpoint): View {
        val fill = if (item.severity == "高") ColorToken.WarningSoft else ColorToken.Card
        val box = ui.container(fill, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(item.title, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(item.severity, if (item.severity == "高") ColorToken.Danger else ColorToken.Warning))
        box.addView(top)
        box.addView(ui.body("證據：${item.evidence}", "#334155"))
        box.addView(ui.body("AI：${item.aiAction}", "#475569"))
        box.addView(ui.body("真人接力：${item.mentorAction}", ColorToken.Success))
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun designTokenCard(name: String, value: String, role: String, color: String): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val swatch = View(this).apply {
            background = ui.rounded(color, color)
            layoutParams = LinearLayout.LayoutParams(ui.dp(44), ui.dp(44)).apply {
                setMargins(0, 0, ui.dp(12), 0)
            }
        }
        row.addView(swatch)
        val textGroup = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        textGroup.addView(ui.label(name, 17, ColorToken.Ink, true))
        textGroup.addView(ui.body(value, ColorToken.Muted))
        row.addView(textGroup, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        box.addView(row)
        box.addView(ui.body(role, "#334155").apply { setPadding(0, ui.dp(10), 0, 0) })
        return ui.margins(box, 0, 6, 0, 8)
    }

    private fun designSpecCard(title: String, spec: String, usage: String, fill: String): View {
        val box = ui.container(fill, ColorToken.Border)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        top.addView(ui.label(title, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(spec, ColorToken.Primary))
        box.addView(top)
        box.addView(ui.body(usage, "#334155").apply { setPadding(0, ui.dp(10), 0, 0) })
        return ui.margins(box, 0, 6, 0, 8)
    }

    private fun metricRow(a: Metric, b: Metric, c: Metric): View {
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        listOf(a, b, c).forEach { row.addView(metricCard(it), ui.weightParams()) }
        return row
    }

    private fun metricCard(metric: Metric): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border).apply {
            setPadding(ui.dp(12), ui.dp(16), ui.dp(12), ui.dp(16))
        }
        box.addView(ui.label(metric.label, 12, ColorToken.Muted, true))
        box.addView(ui.label(metric.value, 20, metric.color, true).apply { setPadding(0, ui.dp(4), 0, 0) })
        return ui.margins(box, 4, 4, 4, 4)
    }

    private fun choiceCard(title: String, subtitle: String, color: String, action: () -> Unit): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label(title, 17, color, true))
        box.addView(ui.body(subtitle, ColorToken.Muted))
        box.setOnClickListener { action() }
        return ui.margins(box, 0, 6, 0, 6)
    }

    private fun moodChoiceCard(title: String, subtitle: String, color: String, selected: Boolean, action: () -> Unit): View {
        val fill = if (selected) ColorToken.SuccessSoft else ColorToken.Card
        val box = ui.container(fill, if (selected) color else ColorToken.Border)
        box.addView(ui.statusPill(if (selected) "已選擇" else "感受", color))
        box.addView(ui.label(title, 18, color, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(subtitle, ColorToken.Muted))
        box.setOnClickListener { action() }
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun durationChoice(value: Int, selected: Boolean, action: () -> Unit): View {
        val box = ui.container(if (selected) ColorToken.AccentSoft else ColorToken.Card, if (selected) ColorToken.Accent else ColorToken.Border)
        box.addView(ui.statusPill(if (selected) "目前節奏" else "可選時間", if (selected) ColorToken.Accent else ColorToken.Primary))
        box.addView(ui.label("${value} 分鐘", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(if (selected) "這是現在的任務長度。" else "切換成這個長度，平台會重新調整今天任務。", ColorToken.Muted))
        box.setOnClickListener { action() }
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun card(title: String, text: String, fill: String): View {
        val box = ui.container(fill, ColorToken.Border)
        box.addView(ui.label(title, 17, ColorToken.Ink, true))
        box.addView(ui.body(text, "#334155").apply { setPadding(0, ui.dp(8), 0, 0) })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun section(text: String) {
        root.addView(ui.label(text, 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(24), 0, ui.dp(8))
        })
    }
}
