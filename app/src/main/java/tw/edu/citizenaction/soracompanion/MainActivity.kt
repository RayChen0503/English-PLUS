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
import tw.edu.citizenaction.soracompanion.ai.AiDailyTaskPlan
import tw.edu.citizenaction.soracompanion.ai.AiQuestionBankOption
import tw.edu.citizenaction.soracompanion.ai.AiSupportResult
import tw.edu.citizenaction.soracompanion.ai.AiProxyClient
import tw.edu.citizenaction.soracompanion.ai.OpenAiClient
import tw.edu.citizenaction.soracompanion.ai.OpenRouterClient
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
import tw.edu.citizenaction.soracompanion.model.CheckInOption
import tw.edu.citizenaction.soracompanion.model.CheckInQuestion
import tw.edu.citizenaction.soracompanion.model.CheckInResult
import tw.edu.citizenaction.soracompanion.model.CollaborationNote
import tw.edu.citizenaction.soracompanion.model.DailyTaskProgress
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
    private var currentScrollView: ScrollView? = null
    private var pageFrame: LinearLayout? = null
    private var pendingScrollY: Int? = null

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
    private var todayAnsweredFirstQuestion = false
    private var todayReflected = false
    private var selectedPracticeLevel = "推薦"
    private var selectedPracticeType = "全部題型"
    private var selectedPracticeTypes = setOf("全部題型")
    private var aiDailyPlanTitle = ""
    private var aiDailyPlanMessage = ""
    private var aiDailyPlanItemIds: List<String> = emptyList()
    private var aiDailyPlanSource = ""
    private var aiReflectionFeedback = ""
    private var aiMapRouteSuggestion = ""
    private var aiPracticeTypeSuggestion = ""
    private val checkInAnswers = mutableMapOf<String, String>()

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
        checkInAnswers.clear()
        todayAnsweredFirstQuestion = false
        todayReflected = false
    }

    private fun renderStudentTaskEntry() {
        when {
            !checkInCompleted -> renderCheckIn()
            !practiceTimeConfirmed -> confirmPracticeTimeAndPlanToday()
            else -> renderTaskQueue()
        }
    }

    private fun renderStudentSupportEntry() {
        if (!checkInCompleted) renderCheckIn() else renderBreakpoints()
    }

    private fun renderStudentMapEntry() {
        when {
            !checkInCompleted -> renderCheckIn()
            !practiceTimeConfirmed -> confirmPracticeTimeAndPlanToday()
            else -> renderMap()
        }
    }

    private fun renderRoleGateway() {
        screen = Screen.Home
        shell("English+", "選擇入口")
        hero("今天要用哪一端？", "學生先進入短任務；老師/志工先進入接力工作台。")
        root.addView(roleEntryCard(
            label = "學生",
            title = "我是學生",
            detail = "先做 4 題內的狀態檢測，再進入今天的英文任務與學習地圖。",
            fill = ColorToken.PrimarySoft,
            actionText = "進入學生端"
        ) {
            renderRoleLogin(Role.Student)
        })
        root.addView(roleEntryCard(
            label = "老師 / 志工",
            title = "我是老師或志工",
            detail = "先看需要真人接力的學生，再處理待辦、同步與週報。",
            fill = ColorToken.SuccessSoft,
            actionText = "進入老師端"
        ) {
            renderRoleLogin(Role.Mentor)
        })
    }

    private fun renderRoleLogin(targetRole: Role) {
        screen = Screen.Account
        val isStudent = targetRole == Role.Student
        val accounts = accountList().filter {
            if (isStudent) AuthContract.isStudentRole(it.roleLabel) else AuthContract.isStaffRole(it.roleLabel)
        }
        shell("English+", if (isStudent) "學生登入" else "老師/志工登入")
        hero(if (isStudent) "選擇學生帳號" else "選擇老師或志工帳號", if (isStudent) "登入後先做心情檢測，再開始今天任務。" else "登入後直接進入今日接力工作台。")
        accounts.forEach { root.addView(accountLoginCard(it)) }
        root.addView(ui.secondaryButton("回到身分選擇") { renderRoleGateway() })
        bottomNav()
    }

    private fun renderHome() {
        screen = Screen.Home
        val flow = currentRoleFlow()
        shell("English+", flow.roleLabel)
        hero(flow.homeTitle, flow.homeSubtitle)
        if (role == Role.Student) {
            studentHome()
        } else {
            mentorHome()
            bottomNav()
        }
    }

    private fun studentHome() {
        root.addView(studentStatusHeader())
        root.addView(studentTodayQuestCard())
        root.addView(studentLearningPathCard())
        root.addView(studentQuickPracticeCard())
        bottomNav()
    }

    private fun mentorHome() {
        root.addView(mentorCommandCenterCard())
        root.addView(mentorPriorityStudentCard())
        root.addView(mentorRouteCard())
        root.addView(mentorWorkspaceEntrancesCard())
        root.addView(mentorSignalStripCard())
        root.addView(ui.secondaryButton("回到身分選擇") { renderRoleGateway() })
        bottomNav()
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

    private fun currentRoleFlow() = PrototypeRepository.roleFlowSpec(role)

    private fun roleLabel(): String = currentRoleFlow().roleLabel

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
        root.addView(studentStatusHeader())
        root.addView(studentTodayQuestCard())
        root.addView(dailyAiTaskPlanCard())
        root.addView(studentAiPracticePreferenceCard())
        root.addView(studentQuickPracticeCard())
        if (customTaskCount > 0) {
            section("老師新增任務")
            repeat(customTaskCount) { index ->
                root.addView(taskCard(StudyTask("志工接力任務 ${index + 1}", 3, "低", "由老師端依斷點新增，完成後會回寫週報。", "老師指派")))
            }
        }
        bottomNav()
    }

    private fun renderCheckIn() {
        screen = Screen.CheckIn
        shell("心情檢測", "4 題內完成")
        val checkInQuestions = PrototypeRepository.emotionalCheckInQuestions
        val answeredCount = checkInQuestions.count { isCheckInQuestionAnswered(it.id) }
        val complete = checkInQuestions.all { isCheckInQuestionAnswered(it.id) }
        val result = if (complete) PrototypeRepository.evaluateEmotionalCheckIn(checkInAnswers) else null
        root.addView(checkInIntroCard())
        root.addView(checkInProgressCard(checkInQuestions.size, answeredCount, result))
        checkInQuestions.forEachIndexed { index, question ->
            root.addView(checkInQuestionCard(index + 1, question))
        }
        result?.let { root.addView(checkInResultCard(it)) }
        if (complete && result != null) {
            root.addView(ui.primaryButton("完成檢測，產生今日任務") {
                applyCheckInResult(result)
                renderCheckInAiSupport(result)
            })
        } else {
            root.addView(card("還差 ${checkInQuestions.size - answeredCount} 題", "完成後會依照時間、挑戰意願與題型偏好安排任務。", ColorToken.Card))
        }
        root.addView(ui.secondaryButton("先回學生首頁") { renderHome() })
        bottomNav()
    }

    private fun applyCheckInResult(result: CheckInResult) {
        mood = result.mood
        minutes = result.recommendedMinutes
        confidence = result.confidence
        checkInCompleted = true
        practiceTimeConfirmed = false
        lastAnswerMessage = result.supportMessage
        selectedPracticeLevel = when {
            result.challengeWanted -> "進階挑戰 B1"
            result.route == "repair" -> "弱點修復"
            else -> "推薦"
        }
        selectedPracticeTypes = if (result.preferredQuestionTypes.isNotEmpty()) result.preferredQuestionTypes.toSet() else setOf("全部題型")
        selectedPracticeType = selectedPracticeTypes.firstOrNull() ?: "全部題型"
        if (result.route == "relay") {
            breakpoints.add(0, Breakpoint("今日需要陪伴", "高", "心情檢測顯示學生希望老師或志工知道", "先改成低壓題與支持出口。", "請老師/志工確認學生是否需要陪練。"))
        }
        addOfflineSyncItem("心情檢測：${result.title}", "情緒檢測", result.nextStep)
        recordLearningEvent("check_in", result.title, "${result.route} / ${result.supportMessage}")
        persistState()
    }


    private fun renderCheckInAiSupport(result: CheckInResult) {
        if (!hasTrueAiRoute()) {
            renderCheckInAiSupportFallback(result, "目前尚未啟用外部 AI，English+ 先用內建規則陪你完成今天的第一步。")
            return
        }
        screen = Screen.CheckIn
        shell("AI 情緒支持", "正在呼叫 ${aiRouteLabel()}")
        root.addView(card("請稍候", "English+ 正在根據你的心情、時間、挑戰意願與題型偏好產生今天的支持語。", ColorToken.PrimarySoft))
        bottomNav()
        Thread {
            try {
                val support = generateRemoteCheckInSupport(result)
                runOnUiThread { renderCheckInAiSupportResult(result, support) }
            } catch (error: Exception) {
                runOnUiThread {
                    recordLearningEvent("ai_fallback", "情緒支持真 AI 呼叫失敗", error.message ?: "未知錯誤")
                    renderCheckInAiSupportFallback(result, "真 AI 呼叫失敗，已改用本機備援：${error.message ?: "未知錯誤"}")
                }
            }
        }.start()
    }

    private fun renderCheckInAiSupportResult(result: CheckInResult, support: AiSupportResult) {
        screen = Screen.CheckIn
        shell("AI 情緒支持", "真 AI 已回覆")
        root.addView(checkInResultCard(result))
        root.addView(aiSourceStatusCard("真 AI 已啟用", support.source, ColorToken.Success))
        root.addView(card("今天狀態分析", support.diagnosis, ColorToken.WarningSoft))
        root.addView(card("給你的話", support.studentFeedback, ColorToken.SuccessSoft))
        root.addView(card("老師/志工摘要", support.handoffSummary, ColorToken.Card))
        addOfflineSyncItem("AI 情緒支持：${result.title}", "真 AI 情緒支持", support.handoffSummary)
        recordLearningEvent("ai_emotional_support", "真 AI 情緒支持", support.diagnosis)
        root.addView(ui.primaryButton("產生今日任務") { confirmPracticeTimeAndPlanToday() })
        root.addView(ui.secondaryButton("重新做心情檢測") {
            checkInCompleted = false
            practiceTimeConfirmed = false
            renderCheckIn()
        })
        bottomNav()
    }

    private fun renderCheckInAiSupportFallback(result: CheckInResult, notice: String) {
        screen = Screen.CheckIn
        shell("AI 情緒支持", "先用 English+ 內建輔助")
        root.addView(card("目前使用內建輔助", notice, ColorToken.WarningSoft))
        root.addView(checkInResultCard(result))
        root.addView(card("給你的話", result.supportMessage, ColorToken.SuccessSoft))
        root.addView(card("今天先這樣做", result.nextStep, ColorToken.PrimarySoft))
        root.addView(ui.primaryButton("產生今日任務") { confirmPracticeTimeAndPlanToday() })
        root.addView(ui.secondaryButton("設定 OpenRouter 真 AI") { renderAiLab() })
        bottomNav()
    }

    private fun studentAiPracticePreferenceCard(): View {
        val hasSuggestion = aiPracticeTypeSuggestion.isNotBlank()
        val box = ui.container(if (hasSuggestion) ColorToken.PrimarySoft else ColorToken.Surface, ColorToken.Border)
        box.addView(ui.statusPill(if (hasSuggestion) "題型已調整" else "題型建議", if (hasSuggestion) ColorToken.Primary else ColorToken.Muted))
        box.addView(ui.label(if (hasSuggestion) aiPracticeTypeSuggestion else "先依心情檢測安排題型", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(
            if (hasSuggestion) {
                "English+ 會優先用這個題型安排練習；如果你覺得太簡單或太難，可以到練習中心重新選。"
            } else {
                "完成反思後，AI 會依答題狀態修正題型偏好。"
            },
            "#334155"
        ))
        if (hasSuggestion) box.addView(ui.secondaryButton("看這類題型") { renderStudentPracticeCatalog() })
        return ui.margins(box, 0, 0, 0, 12)
    }
    private fun confirmPracticeTimeAndPlanToday() {
        practiceTimeConfirmed = true
        todayAnsweredFirstQuestion = false
        todayReflected = false
        aiDailyPlanItemIds = emptyList()
        aiDailyPlanTitle = ""
        aiDailyPlanMessage = ""
        aiDailyPlanSource = ""
        persistState()
        renderAiDailyPlanThenTaskQueue()
    }
    private fun renderPracticeTimeSetup() {
        confirmPracticeTimeAndPlanToday()
    }

    private fun renderAiDailyPlanThenTaskQueue() {
        val candidates = dailyPlanCandidateItems(stateStore.questionBankItems())
        if (candidates.isEmpty()) {
            aiDailyPlanTitle = "今日任務"
            aiDailyPlanMessage = "目前沒有可用題庫，先回到今日任務。"
            aiDailyPlanItemIds = emptyList()
            aiDailyPlanSource = "Local fallback"
            renderTaskQueue()
            return
        }
        if (!stateStore.hasOpenRouterApiKey()) {
            applyLocalDailyTaskPlan(candidates, "目前尚未啟用 OpenRouter 真 AI，先用 English+ 內建規則依照你的心情、時間與題型偏好排序。")
            renderTaskQueue()
            return
        }
        screen = Screen.Lesson
        shell("AI 安排今日任務", "正在從題庫挑選今天最適合的題目")
        root.addView(card("請稍候", "English+ 正在根據你的心情量表、可用時間、挑戰意願與題型偏好，從現有題庫挑出今日任務。", ColorToken.PrimarySoft))
        bottomNav()
        Thread {
            try {
                val plan = OpenRouterClient(
                    apiKey = stateStore.openRouterApiKey(),
                    model = stateStore.openRouterModel().ifBlank { OpenRouterClient.DEFAULT_MODEL }
                ).generateDailyTaskPlan(
                    routeTitle = dailyPlanRouteTitle(),
                    nextStep = "用 ${minutes} 分鐘完成 ${targetDailyQuestionCount()} 題，先穩定再挑戰。",
                    moodLabel = mood.label,
                    minutes = minutes,
                    confidence = confidence,
                    challengeWanted = selectedPracticeLevel.contains("B1") || selectedPracticeLevel.contains("挑戰"),
                    preferredTypes = selectedPracticeTypes.filter { it != "全部題型" },
                    targetQuestionCount = targetDailyQuestionCount(),
                    questionBank = candidates.map { item ->
                        AiQuestionBankOption(
                            id = item.id,
                            level = item.level,
                            questionType = normalizedQuestionType(item),
                            concept = item.question.concept,
                            skill = item.skill,
                            challengeScore = item.challengeScore,
                            estimatedSeconds = item.estimatedSeconds
                        )
                    }
                )
                runOnUiThread {
                    applyAiDailyTaskPlan(plan, candidates)
                    renderTaskQueue()
                }
            } catch (error: Exception) {
                runOnUiThread {
                    recordLearningEvent("ai_daily_plan_fallback", "AI 每日任務失敗", error.message ?: "未知錯誤")
                    applyLocalDailyTaskPlan(candidates, "真 AI 排任務失敗，已改用本機推薦：${error.message ?: "未知錯誤"}")
                    renderTaskQueue()
                }
            }
        }.start()
    }

    private fun dailyPlanRouteTitle(): String {
        return when {
            mood == Mood.Low -> "低壓修復"
            confidence >= 70 -> "挑戰進階"
            confidence <= 45 -> "基礎補強"
            else -> "穩定練習"
        }
    }

    private fun targetDailyQuestionCount(): Int {
        return when {
            minutes <= 3 -> 3
            minutes <= 5 -> 4
            minutes <= 8 -> 5
            else -> 7
        }
    }

    private fun dailyPlanCandidateItems(items: List<QuestionBankItem>): List<QuestionBankItem> {
        val typeFiltered = if (selectedPracticeTypes.contains("全部題型")) {
            items
        } else {
            items.filter { selectedPracticeTypes.contains(normalizedQuestionType(it)) }
        }
        val levelFiltered = typeFiltered.filter { item ->
            when {
                selectedPracticeLevel.contains("B1") -> item.level == "B1" || item.difficultyBand == "challenge"
                selectedPracticeLevel.contains("A2") -> item.level == "A2" || item.difficultyBand == "cap-standard"
                selectedPracticeLevel.contains("A1") || selectedPracticeLevel.contains("修復") -> item.level == "A1" || item.recommendationTags.contains("repair")
                else -> true
            }
        }.ifEmpty { typeFiltered.ifEmpty { items } }
        val adaptive = PrototypeRepository.adaptivePracticeRecommendations(
            current = null,
            wasCorrect = confidence >= 60,
            confidence = confidence,
            moodLabel = mood.name,
            wrongAttempts = wrongAttempts,
            limit = 30
        ).filter { candidate -> levelFiltered.any { it.id == candidate.id } }
        val ranked = levelFiltered.sortedWith(
            compareByDescending<QuestionBankItem> { selectedPracticeTypes.contains(normalizedQuestionType(it)) }
                .thenByDescending { if (selectedPracticeLevel.contains("B1")) it.challengeScore else 6 - it.challengeScore }
                .thenBy { it.estimatedSeconds }
        )
        return (adaptive + ranked).distinctBy { it.id }.take(80)
    }

    private fun applyAiDailyTaskPlan(plan: AiDailyTaskPlan, candidates: List<QuestionBankItem>) {
        val byId = candidates.associateBy { it.id }
        val aiSelected = plan.recommendedItemIds.mapNotNull { byId[it] }.distinctBy { it.id }
        val fillItems = candidates.filterNot { candidate -> aiSelected.any { it.id == candidate.id } }
        val selected = (aiSelected + fillItems)
            .take(targetDailyQuestionCount())
        aiDailyPlanTitle = plan.title.ifBlank { "今日 AI 任務" }
        aiDailyPlanMessage = buildString {
            append(plan.studentMessage.ifBlank { "依照你的狀態，先完成這一小組英文練習。" })
            if (aiSelected.size < targetDailyQuestionCount()) {
                append("\n\nAI 回傳 ${aiSelected.size} 題，English+ 已用同一批候選題補足今日題數。")
            }
        }
        aiDailyPlanItemIds = selected.map { it.id }
        aiDailyPlanSource = if (aiSelected.isNotEmpty()) plan.source else "${plan.source} + local fill"
        recordLearningEvent("ai_daily_plan", aiDailyPlanTitle, "source=$aiDailyPlanSource / items=${aiDailyPlanItemIds.joinToString(",")}")
    }

    private fun applyLocalDailyTaskPlan(candidates: List<QuestionBankItem>, message: String) {
        val selected = candidates.take(targetDailyQuestionCount())
        aiDailyPlanTitle = "今日推薦任務"
        aiDailyPlanMessage = message
        aiDailyPlanItemIds = selected.map { it.id }
        aiDailyPlanSource = "Local recommendation"
    }
    private fun renderLesson() {
        screen = Screen.Lesson
        val q = questions[currentQuestionIndex]
        shell("第 ${currentQuestionIndex + 1} 題", "完成今天下一個小關卡")
        root.addView(lessonSessionHeader(q))
        root.addView(questionCard(q))
        root.addView(lessonActionStrip())
        bottomNav()
    }

    private fun renderRecoveryMode() {
        screen = Screen.Lesson
        shell("復原任務", "狀態不好時也能完成的一小步")
        root.addView(card("為什麼切換？", "當心情低落或連續答錯時，平台會把原本任務縮成更小的復原任務，避免直接退出。", ColorToken.WarningSoft))
        root.addView(card("復原任務內容", "只判斷一件事：He 要搭配 is。\n完成後就可以休息，也會算進學習地圖。", ColorToken.PrimarySoft))
        root.addView(ui.primaryButton("完成復原任務") {
            completedTasks += 1
            todayAnsweredFirstQuestion = true
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
            todayAnsweredFirstQuestion = true
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
        shell("答對了", "先確認結果，再選下一步")
        root.addView(successSummaryCard(q))
        root.addView(adaptiveNextStepCard(q, true))
        root.addView(ui.primaryButton("做 20 秒反思") { renderReflection() })
        root.addView(ui.secondaryButton("繼續下一題") { renderLesson() })
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
        todayReflected = true
        applyAiReflectionAndRouteUpdate(prompt)
        addOfflineSyncItem("課後反思：${prompt.title}", "反思紀錄", prompt.studentChoice)
        persistState()
        recordLearningEvent("reflection", prompt.title, prompt.studentChoice)
        renderReflectionSaved(prompt)
    }

    private fun applyAiReflectionAndRouteUpdate(prompt: ReflectionPrompt) {
        val currentQuestion = questions.getOrNull(currentQuestionIndex)
        val suggestedType = aiSuggestedPracticeType(currentQuestion)
        selectedPracticeTypes = setOf(suggestedType)
        selectedPracticeType = suggestedType
        selectedPracticeLevel = when {
            wrongAttempts > 0 || confidence < 45 -> "基礎 A1"
            prompt.confidenceDelta >= 4 || confidence >= 70 -> "進階挑戰 B1"
            else -> "標準 A2"
        }
        aiReflectionFeedback = when {
            wrongAttempts > 0 || confidence < 45 -> "AI 判斷你今天需要先修復一個小概念，不急著加難度。"
            prompt.confidenceDelta >= 4 || confidence >= 70 -> "AI 判斷你已經準備好挑戰更高一點的題型，但仍會保留支持節點。"
            else -> "AI 判斷你適合維持穩定節奏，先把今天的題型做熟。"
        }
        aiPracticeTypeSuggestion = "建議題型：$suggestedType"
        aiMapRouteSuggestion = when (selectedPracticeLevel) {
            "基礎 A1" -> "地圖已調整為修復路線：先做短題，確認一個概念真的懂。"
            "進階挑戰 B1" -> "地圖已解鎖挑戰路線：可以進入較長閱讀、克漏字或句子重組。"
            else -> "地圖已調整為穩定路線：維持 A2 會考基準題型。"
        }
        recordLearningEvent("ai_reflection_route", aiReflectionFeedback, "$aiPracticeTypeSuggestion / $aiMapRouteSuggestion")
    }

    private fun aiSuggestedPracticeType(question: Question?): String {
        val currentType = question?.let { normalizedLessonType(it) }
        return when {
            wrongAttempts > 0 && currentType != null -> currentType
            selectedPracticeTypes.isNotEmpty() && !selectedPracticeTypes.contains("全部題型") -> selectedPracticeTypes.first()
            confidence >= 70 -> "閱讀理解"
            confidence < 45 -> "選擇題"
            currentType != null -> currentType
            else -> "填空題"
        }
    }

    private fun renderReflectionSaved(prompt: ReflectionPrompt) {
        screen = Screen.Reflection
        shell("反思已保存", "把今天的小進步放回週報")
        root.addView(card("學生選擇", prompt.studentChoice, ColorToken.PrimarySoft))
        root.addView(card("平台回應", prompt.platformResponse, ColorToken.SuccessSoft))
        root.addView(card("AI 反思回饋", aiReflectionFeedback.ifBlank { "English+ 已依照你的反思更新下一步路徑。" }, ColorToken.WarningSoft))
        root.addView(card("學習地圖更新", "${aiMapRouteSuggestion.ifBlank { "維持目前學習路線。" }}\n${aiPracticeTypeSuggestion.ifBlank { "題型維持原設定。" }}", ColorToken.SuccessSoft))
        root.addView(todayProgressCard())
        root.addView(card("目前信心值", "$confidence%｜下次會從同一個斷點繼續，而不是直接加難度。", ColorToken.Card))
        root.addView(card("已寫入學習紀錄", "學習事件：${learningEventCount} 筆\n修復紀錄：${repairedMistakeCount} 筆\n待同步：${offlinePendingCount} 筆", ColorToken.PrimarySoft))
        root.addView(ui.primaryButton("回學習地圖") { renderMap() })
        bottomNav()
    }

    private fun hasTrueAiRoute(): Boolean {
        val decision = stateStore.aiSecurityDecision(productionMode = false)
        return decision.canCallRemoteAi && (stateStore.hasAiProxyEndpoint() || stateStore.hasOpenRouterApiKey() || stateStore.hasOpenAiApiKey())
    }

    private fun aiRouteLabel(): String {
        return when {
            stateStore.hasAiProxyEndpoint() -> "HTTPS AI Proxy"
            stateStore.hasOpenRouterApiKey() -> "OpenRouter ${stateStore.openRouterModel()}"
            stateStore.hasOpenAiApiKey() -> "OpenAI Responses API"
            else -> "本機備援"
        }
    }

    private fun generateRemoteQuestionSupport(q: Question): AiSupportResult {
        return when {
            stateStore.hasAiProxyEndpoint() -> AiProxyClient(stateStore.aiProxyEndpoint()).generateSupport(
                question = q.prompt,
                concept = "${q.concept}｜${q.type}",
                answerContext = wrongAnswerAiContext(q),
                moodLabel = mood.label,
                wrongAttempts = wrongAttempts,
                classCode = currentAccount().classCode
            )
            stateStore.hasOpenRouterApiKey() -> OpenRouterClient(
                apiKey = stateStore.openRouterApiKey(),
                model = stateStore.openRouterModel()
            ).generateSupport(
                question = q.prompt,
                concept = "${q.concept}｜${q.type}",
                answerContext = wrongAnswerAiContext(q),
                moodLabel = mood.label,
                wrongAttempts = wrongAttempts
            )
            else -> OpenAiClient(stateStore.openAiApiKey()).generateSupport(
                question = q.prompt,
                concept = "${q.concept}｜${q.type}",
                answerContext = wrongAnswerAiContext(q),
                moodLabel = mood.label,
                wrongAttempts = wrongAttempts
            )
        }
    }

    private fun wrongAnswerAiContext(q: Question): String {
        val selected = lastSelectedAnswer.ifBlank { "學生尚未提供選項" }
        return """
            題型：${q.type}
            學生剛剛選：$selected
            正確答案：${q.answer}
            標準解釋：${q.explanation}
            修復提示：${q.repairHint}
            請聚焦在學生為什麼可能選錯，以及下一步只要修復哪一個小概念。
        """.trimIndent()
    }

    private fun generateRemoteCheckInSupport(result: CheckInResult): AiSupportResult {
        val preferred = result.preferredQuestionTypes.ifEmpty { selectedPracticeTypes.filter { it != "全部題型" } }
        return when {
            stateStore.hasAiProxyEndpoint() -> AiProxyClient(stateStore.aiProxyEndpoint()).generateSupport(
                question = "心情檢測結果：${result.title}",
                concept = "情緒支持與今日任務節奏",
                answerContext = "${result.nextStep}\n偏好題型：${preferred.joinToString("、")}",
                moodLabel = mood.label,
                wrongAttempts = 0,
                classCode = currentAccount().classCode
            )
            stateStore.hasOpenRouterApiKey() -> OpenRouterClient(
                apiKey = stateStore.openRouterApiKey(),
                model = stateStore.openRouterModel()
            ).generateEmotionalSupport(
                routeTitle = result.title,
                nextStep = result.nextStep,
                moodLabel = mood.label,
                minutes = result.recommendedMinutes,
                confidence = result.confidence,
                challengeWanted = result.challengeWanted,
                preferredTypes = preferred
            )
            else -> OpenAiClient(stateStore.openAiApiKey()).generateSupport(
                question = "心情檢測結果：${result.title}",
                concept = "情緒支持與今日任務節奏",
                answerContext = result.nextStep,
                moodLabel = mood.label,
                wrongAttempts = 0
            )
        }
    }
    private fun renderAiCoach() {
        if (hasTrueAiRoute()) {
            renderLiveAiCoach()
        } else {
            renderLocalAiCoach()
        }
    }

    private fun renderLiveAiCoach() {
        screen = Screen.AiCoach
        val q = questions[currentQuestionIndex]
        shell("錯題詳解", "正在呼叫 ${aiRouteLabel()}")
        root.addView(answerResultCard(false, q, lastSelectedAnswer))
        root.addView(card("AI 生成中", "English+ 正在根據這一題、你的選項、正確答案與目前心情產生個人化提示。", ColorToken.PrimarySoft))
        bottomNav()
        Thread {
            try {
                val support = generateRemoteQuestionSupport(q)
                runOnUiThread { renderAiCoachResult(q, support) }
            } catch (error: Exception) {
                runOnUiThread {
                    recordLearningEvent("ai_fallback", "錯題真 AI 呼叫失敗", error.message ?: "未知錯誤")
                    renderLocalAiCoach("真 AI 呼叫失敗，已改用本機備援：${error.message ?: "未知錯誤"}")
                }
            }
        }.start()
    }

    private fun renderAiCoachResult(q: Question, support: AiSupportResult) {
        screen = Screen.AiCoach
        shell("錯題詳解", "真 AI 已回覆")
        root.addView(answerResultCard(false, q, lastSelectedAnswer))
        root.addView(aiSourceStatusCard("真 AI 詳解", support.source, ColorToken.Success))
        root.addView(card("看懂錯在哪", support.diagnosis, ColorToken.WarningSoft))
        root.addView(card("下一步提示", support.studentFeedback, ColorToken.SuccessSoft))
        root.addView(card("老師/志工摘要", support.handoffSummary, ColorToken.Card))
        root.addView(adaptiveNextStepCard(q, false))
        addOfflineSyncItem("AI 錯題詳解：${q.concept}", "真 AI 錯題支持", support.handoffSummary)
        recordLearningEvent("ai_wrong_answer_support", "真 AI 錯題支持：${q.concept}", support.diagnosis)
        root.addView(ui.primaryButton("回題目再試一次") { renderLesson() })
        root.addView(ui.secondaryButton("交給志工接力") { renderHelpRequest() })
        bottomNav()
    }

    private fun renderLocalAiCoach(notice: String? = null) {
        screen = Screen.AiCoach
        val q = questions[currentQuestionIndex]
        shell("錯題詳解", "使用 English+ 內建輔助")
        notice?.let { root.addView(aiSourceStatusCard("目前使用內建輔助", it, ColorToken.Warning)) }
        root.addView(answerResultCard(false, q, lastSelectedAnswer))
        root.addView(supportStepCard("01", "我看見你卡在這裡", q.prompt, ColorToken.WarningSoft, ColorToken.Warning))
        root.addView(supportStepCard("02", "先把概念拆小", "${q.explanation}\n現在只要先記住這一個規則，不需要一次背完 am / is / are。", ColorToken.VioletSoft, ColorToken.Primary))
        root.addView(supportStepCard("03", "你可以選下一步", "回到同一題再試一次；如果仍然不舒服，English+ 會幫你把狀況整理給志工。", ColorToken.PrimarySoft, ColorToken.Success))
        root.addView(adaptiveNextStepCard(q, false))
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
        if (!checkInCompleted) return renderCheckIn()
        if (!practiceTimeConfirmed) return confirmPracticeTimeAndPlanToday()
        screen = Screen.Map
        shell("學習地圖", "看目前位置和下一關")
        root.addView(studentMapStatusCard())
        root.addView(studentAiRouteInsightCard())
        root.addView(studentMapPathCard())
        root.addView(studentMapNextActionCard())
        root.addView(studentMapSupportCard())
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
        root.addView(teacherProgressSnapshotCard())
        root.addView(card("目前班級觀察", "${student.name} 已完成情緒檢測與短任務路徑；若連續錯題或低信心，會進入接力優先序。", ColorToken.SuccessSoft))
        section("學生證據摘要")
        currentRoster().forEach { row -> root.addView(studentLearningEvidenceCard(row)) }
        root.addView(ui.secondaryButton("查看題庫審閱狀態") { renderQuestionBank() })
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
        val typeCounts = bankItems.groupingBy { it.questionType }.eachCount()
        val bandCounts = bankItems.groupingBy { it.difficultyBand }.eachCount()
        shell("正式題庫中心", "依程度、單元、技能管理 English+ 題目")
        root.addView(questionBankSummaryCard())
        root.addView(questionBankReviewDashboardCard())
        root.addView(metricRow(
            Metric("題目", "${bankItems.size} 題", ColorToken.Primary),
            Metric("題型", "${typeCounts.size} 類", ColorToken.Success),
            Metric("難度帶", "${bandCounts.size} 組", ColorToken.Accent)
        ))
        root.addView(card("第二輪題庫資料結構", "目前題庫已支援 difficultyBand、questionType、tags、recommendationTags、emotionalFit、estimatedSeconds、challengeScore、sourceYear。後續 1000 題會依這些欄位匯入，不再只靠題幹與答案硬塞。", ColorToken.PrimarySoft))
        root.addView(card(
            "正式題庫規則",
            "題庫 schema v${QuestionBankContract.QUESTION_BANK_SCHEMA_VERSION} 保留 importId、審核狀態、匯入批次與推薦 metadata。老師端可以發布正式題目；學生端維持唯讀，避免未審題目進入練習。",
            ColorToken.SuccessSoft
        ))
        section("難度與題型")
        bandCounts.forEach { (band, count) ->
            root.addView(timelineCard(band, "$count 題｜${levelCounts.keys.joinToString("/")}", ColorToken.Accent))
        }
        typeCounts.forEach { (type, count) ->
            root.addView(timelineCard(type, "$count 題｜可作為學生端題型篩選", ColorToken.Success))
        }
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
            confirmPracticeTimeAndPlanToday()
            return
        }
        screen = Screen.QuestionBank
        val bankItems = stateStore.questionBankItems()
        val recommended = recommendedPracticeItems(bankItems)
        val filtered = filteredPracticeItems(bankItems).ifEmpty { recommended }
        shell("練習中心", "選一個關卡開始")
        root.addView(practiceHubHeroCard(recommended))
        section("難度關卡")
        root.addView(practiceLevelLaunchCard("推薦", "今日推薦", "依照心情檢測與答題狀態安排", recommended.size, ColorToken.Primary) {
            selectedPracticeLevel = "推薦"
            selectedPracticeTypes = setOf("全部題型")
            selectedPracticeType = "全部題型"
            renderStudentPracticeCatalog()
        })
        root.addView(practiceLevelLaunchCard("基礎 A1", "基礎修復", "先把最常卡住的句型穩住", bankItems.count { it.level == "A1" || it.difficultyBand == "foundation" }, ColorToken.Success) {
            selectedPracticeLevel = "基礎 A1"
            renderStudentPracticeCatalog()
        })
        root.addView(practiceLevelLaunchCard("標準 A2", "會考標準", "練習常見文法、克漏字與短閱讀", bankItems.count { it.level == "A2" || it.difficultyBand == "cap-standard" }, ColorToken.Accent) {
            selectedPracticeLevel = "標準 A2"
            renderStudentPracticeCatalog()
        })
        root.addView(practiceLevelLaunchCard("進階挑戰 B1", "進階挑戰", "給今天想挑戰難題的人", bankItems.count { it.level == "B1" || it.difficultyBand == "challenge" }, ColorToken.Warning) {
            selectedPracticeLevel = "進階挑戰 B1"
            renderStudentPracticeCatalog()
        })
        section("題型關卡")
        practiceTypeOptions(bankItems).filter { it != "全部題型" }.take(8).forEach { type ->
            val count = bankItems.count { normalizedQuestionType(it) == type }
            root.addView(practiceTypeLaunchCard(type, count, type == selectedPracticeType || selectedPracticeTypes.contains(type)) {
                selectedPracticeTypes = setOf(type)
                selectedPracticeType = type
                renderStudentPracticeCatalog()
            })
        }
        section("目前精選")
        filtered.take(10).forEach { root.addView(studentPracticeOptionCard(it)) }
        root.addView(ui.secondaryButton("回今天任務") { renderTaskQueue() })
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
        shell("學生證據", "先看誰需要接力")
        root.addView(teacherRosterHeaderCard())
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
        shell("接力優先序", "先處理最需要真人的一位")
        root.addView(mentorHandoffHeaderCard())
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
        shell("AI 設定", "啟用 OpenRouter 真 AI")
        root.addView(openAiStatusCard())
        root.addView(card("目前這一輪要做什麼", "先把 OpenRouter API Key 存在這台裝置，讓心情支持、錯題詳解與每日任務有機會呼叫真 AI。正式上架前仍建議改成後端代理，不把正式 Key 放手機。", ColorToken.PrimarySoft))
        root.addView(openRouterKeyEntryCard())
        root.addView(aiProxyEndpointCard())
        root.addView(openAiKeyEntryCard())
        root.addView(card("使用方式", "優先順序：HTTPS AI Proxy > OpenRouter free route > OpenAI Key > English+ 內建輔助。如果 Key 沒設定、額度用完或網路失敗，APP 會自動回到內建輔助。", ColorToken.WarningSoft))
        aiScenarios.forEach { root.addView(aiScenarioCard(it)) }
        root.addView(ui.primaryButton("呼叫真 AI 生成回饋") { renderLiveAiFeedback() })
        root.addView(ui.secondaryButton("改用本機模擬生成") { renderGeneratedAiFeedback() })
        bottomNav()
    }

    private fun openAiStatusCard(): View {
        val hasRemoteAi = stateStore.hasAiProxyEndpoint() || stateStore.hasOpenRouterApiKey() || stateStore.hasOpenAiApiKey()
        val provider = when {
            stateStore.hasAiProxyEndpoint() -> "HTTPS AI Proxy"
            stateStore.hasOpenRouterApiKey() -> "OpenRouter / ${stateStore.openRouterModel()}"
            stateStore.hasOpenAiApiKey() -> "OpenAI Responses API"
            else -> "本機備援"
        }
        val box = ui.container(
            if (hasRemoteAi) ColorToken.SuccessSoft else ColorToken.WarningSoft,
            ColorToken.Border
        )
        box.addView(ui.statusPill(if (hasRemoteAi) "真 AI 已啟用" else "本機備援模式", if (hasRemoteAi) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label("目前 AI 路線：$provider", 18, ColorToken.Ink, true).apply {
            layoutParams = ui.fullWidthParams()
        })
        box.addView(metricRow(
            Metric("OpenRouter", if (stateStore.hasOpenRouterApiKey()) "已設定" else "未設定", if (stateStore.hasOpenRouterApiKey()) ColorToken.Success else ColorToken.Warning),
            Metric("Key", stateStore.openRouterKeyPreview(), if (stateStore.hasOpenRouterApiKey()) ColorToken.Success else ColorToken.Muted),
            Metric("模型", stateStore.openRouterModel(), ColorToken.Primary)
        ))
        box.addView(ui.body(
            if (hasRemoteAi) {
                "按下「呼叫真 AI」時會送出目前題目、情緒狀態與錯題次數；如果網路或 API 失敗，會自動回到本機備援。"
            } else {
                "目前不會連線到外部 AI。你可以先用展示模式，或在下方貼上 OpenRouter API Key 後啟用真 AI。"
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

    private fun openRouterKeyEntryCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label("OpenRouter Key 設定", 18, ColorToken.Ink, true))
        box.addView(ui.body("內測原型使用。Key 只存在這台裝置私人設定，不會寫進 GitHub。貼上後，APP 會優先使用 OpenRouter 產生 AI 回覆。"))
        box.addView(metricRow(
            Metric("Key", stateStore.openRouterKeyPreview(), if (stateStore.hasOpenRouterApiKey()) ColorToken.Success else ColorToken.Warning),
            Metric("模型", stateStore.openRouterModel(), ColorToken.Primary),
            Metric("狀態", if (stateStore.hasOpenRouterApiKey()) "可啟用" else "待設定", if (stateStore.hasOpenRouterApiKey()) ColorToken.Success else ColorToken.Warning)
        ))

        val keyInput = EditText(this).apply {
            hint = if (stateStore.hasOpenRouterApiKey()) "已設定，可貼上新 Key 覆蓋" else "貼上 sk-or- 開頭的 OpenRouter API Key"
            inputType = InputType.TYPE_CLASS_TEXT or InputType.TYPE_TEXT_VARIATION_PASSWORD
            setSingleLine(true)
            textSize = 15f
            setTextColor(Color.parseColor(ColorToken.Ink))
            setHintTextColor(Color.parseColor(ColorToken.Muted))
            background = ui.rounded(ColorToken.Surface, ColorToken.Border)
            setPadding(ui.dp(14), ui.dp(12), ui.dp(14), ui.dp(12))
            layoutParams = ui.fullWidthParams()
        }
        box.addView(keyInput)

        val modelInput = EditText(this).apply {
            hint = OpenRouterClient.DEFAULT_MODEL
            setText(stateStore.openRouterModel())
            inputType = InputType.TYPE_CLASS_TEXT
            setSingleLine(true)
            textSize = 15f
            setTextColor(Color.parseColor(ColorToken.Ink))
            setHintTextColor(Color.parseColor(ColorToken.Muted))
            background = ui.rounded(ColorToken.Surface, ColorToken.Border)
            setPadding(ui.dp(14), ui.dp(12), ui.dp(14), ui.dp(12))
            layoutParams = ui.fullWidthParams()
        }
        box.addView(ui.body("模型", ColorToken.Muted).apply { setPadding(0, ui.dp(10), 0, ui.dp(4)) })
        box.addView(modelInput)

        box.addView(ui.primaryButton("儲存並啟用 OpenRouter 真 AI") {
            val key = keyInput.text.toString().trim()
            val model = modelInput.text.toString().trim().ifBlank { OpenRouterClient.DEFAULT_MODEL }
            if (OpenRouterClient.isLikelyOpenRouterKey(key)) {
                stateStore.saveOpenRouterApiKey(key)
                stateStore.saveOpenRouterModel(model)
                recordLearningEvent("ai_config", "已更新 OpenRouter API Key", "模型：$model")
            } else if (key.isBlank() && stateStore.hasOpenRouterApiKey()) {
                stateStore.saveOpenRouterModel(model)
                recordLearningEvent("ai_config", "已更新 OpenRouter 模型", "沿用既有 Key；模型：$model")
            } else {
                stateStore.saveOpenRouterModel(model)
                recordLearningEvent("ai_config", "OpenRouter API Key 未更新", "請貼上 sk-or- 開頭的 OpenRouter API Key；模型設定已保存為 $model。")
            }
            renderAiLab()
        })
        box.addView(ui.secondaryButton("清除 OpenRouter Key") {
            stateStore.saveOpenRouterApiKey("")
            recordLearningEvent("ai_config", "已清除 OpenRouter API Key", "AI 提示實驗室會回到代理、OpenAI Key 或本機備援。")
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
        val decision = stateStore.aiSecurityDecision(productionMode = false)
        if (!decision.canCallRemoteAi) {
            recordLearningEvent("ai_security_fallback", "Remote AI blocked by security contract", decision.warning)
            renderGeneratedAiFeedback("AI 安全檢查：${decision.warning}\n已改用本機備援。")
            return
        }
        if (!stateStore.hasAiProxyEndpoint() && !stateStore.hasOpenRouterApiKey() && !stateStore.hasOpenAiApiKey()) {
            recordLearningEvent("ai_fallback", "未設定真 AI Key", "使用本機 AI 備援回饋。")
            renderGeneratedAiFeedback("尚未設定 OpenRouter 或 OpenAI API Key，已改用本機備援。")
            return
        }
        val q = questions[currentQuestionIndex]
        screen = Screen.AiLab
        val routeLabel = when {
            stateStore.hasAiProxyEndpoint() -> "HTTPS AI Proxy"
            stateStore.hasOpenRouterApiKey() -> "OpenRouter ${stateStore.openRouterModel()}"
            else -> "OpenAI Responses API"
        }
        shell("AI 生成中", "正在呼叫 $routeLabel")
        root.addView(card("請稍候", "English+ 正在把目前題目、情緒狀態與錯題次數送出，產生短回饋與接力摘要。", ColorToken.PrimarySoft))
        bottomNav()
        Thread {
            try {
                val result = when {
                    stateStore.hasAiProxyEndpoint() -> AiProxyClient(stateStore.aiProxyEndpoint()).generateSupport(
                        question = q.prompt,
                        concept = q.concept,
                        answerContext = q.repairHint,
                        moodLabel = mood.label,
                        wrongAttempts = wrongAttempts,
                        classCode = currentAccount().classCode
                    )
                    stateStore.hasOpenRouterApiKey() -> OpenRouterClient(
                        apiKey = stateStore.openRouterApiKey(),
                        model = stateStore.openRouterModel()
                    ).generateSupport(
                        question = q.prompt,
                        concept = q.concept,
                        answerContext = q.repairHint,
                        moodLabel = mood.label,
                        wrongAttempts = wrongAttempts
                    )
                    else -> OpenAiClient(stateStore.openAiApiKey()).generateSupport(
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
                    recordLearningEvent("ai_fallback", "真 AI 呼叫失敗", error.message ?: "未知錯誤")
                    renderGeneratedAiFeedback("真 AI 呼叫失敗，已改用本機備援：${error.message ?: "未知錯誤"}")
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
        recordLearningEvent("ai_live", "真 AI 生成回饋", result.diagnosis)
        root.addView(ui.primaryButton("回今日任務") { renderLesson() })
        root.addView(ui.secondaryButton("回 AI 提示實驗室") { renderAiLab() })
        bottomNav()
    }

    private fun renderGeneratedAiFeedback(notice: String? = null) {
        screen = Screen.AiLab
        val q = questions[currentQuestionIndex]
        shell("AI 生成結果備援", "依目前題型與錯題狀態產生個人化回饋")
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
        val frame = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = ui.solid(ColorToken.Surface)
        }
        val scroll = ScrollView(this)
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(ui.dp(16), ui.dp(24), ui.dp(16), ui.dp(20))
            background = ui.solid(ColorToken.Surface)
        }
        pageFrame = frame
        currentScrollView = scroll
        scroll.addView(root)
        frame.addView(scroll, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        setContentView(frame)
        pendingScrollY?.let { y ->
            scroll.post {
                scroll.scrollTo(0, y)
                pendingScrollY = null
            }
        }
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
        if (detail.isNotBlank()) {
            box.addView(ui.body(detail, "#334155"))
        }
        box.addView(ui.primaryButton(actionText) { action() })
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun mentorCommandCenterCard(): View {
        val roster = currentRoster()
        val highRisk = roster.count { it.risk == "高" }
        val middleRisk = roster.count { it.risk == "中" }
        val pending = (teacherActions.size - actionDoneCount).coerceAtLeast(0)
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Primary)
        box.addView(ui.statusPill("老師工作台", ColorToken.Primary))
        box.addView(ui.label("今天先接住 $highRisk 位學生", 24, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("先看高風險，再派待辦；低風險學生保留自己的學習節奏。", "#334155"))
        box.addView(metricRow(
            Metric("高風險", "$highRisk 位", if (highRisk > 0) ColorToken.Danger else ColorToken.Success),
            Metric("追蹤", "$middleRisk 位", ColorToken.Warning),
            Metric("待辦", "$pending 件", if (pending > 0) ColorToken.Warning else ColorToken.Success)
        ))
        box.addView(ui.primaryButton("查看第一優先學生") { renderStudentDetail(roster.first()) })
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun mentorRouteCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("今日順序", ColorToken.Success))
        box.addView(ui.label("看訊號，再接力", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(flowStrip("學生證據", "指派待辦", "回填紀錄", "同步週報"))
        box.addView(ui.body("這個流程只給老師／志工端使用，學生端不會看到接力資料。", ColorToken.Muted))
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun mentorWorkspaceEntrancesCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("工作入口", ColorToken.Primary))
        box.addView(ui.label("選一件事開始處理", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(6))
        })
        box.addView(actionGrid(
            ActionItem("學生證據", "看風險與斷點") { renderRoster() },
            ActionItem("接力優先序", "分派真人協助") { renderHandoffBoard() },
            ActionItem("待辦處理", "完成回填紀錄") { renderActionQueue() },
            ActionItem("週報摘要", "輸出班級報告") { renderWeeklyReport() }
        ))
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun mentorSignalStripCard(): View {
        val box = ui.container(ColorToken.Surface, ColorToken.Border)
        box.addView(ui.statusPill("班級訊號", ColorToken.Accent))
        weeklySignals.take(2).forEach { signal ->
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                setPadding(0, ui.dp(8), 0, ui.dp(8))
            }
            val text = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
            text.addView(ui.label(signal.label, 16, ColorToken.Ink, true))
            text.addView(ui.body(signal.note, ColorToken.Muted))
            row.addView(text, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
            row.addView(ui.statusPill(signal.value, signal.color))
            box.addView(row)
        }
        box.addView(ui.secondaryButton("查看同步中心") { renderSyncCenter() })
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun teacherRosterHeaderCard(): View {
        val roster = currentRoster()
        val highRisk = roster.count { it.risk == "高" }
        val lowRisk = roster.count { it.risk == "低" }
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Primary)
        box.addView(ui.statusPill("班級雷達", ColorToken.Primary))
        box.addView(ui.label("先看紅色風險卡", 21, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("管理中", "${roster.size} 位", ColorToken.Primary),
            Metric("高風險", "$highRisk 位", if (highRisk > 0) ColorToken.Danger else ColorToken.Success),
            Metric("可自學", "$lowRisk 位", ColorToken.Success)
        ))
        box.addView(ui.body("點學生卡片即可進入接力資料。", "#334155"))
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun mentorHandoffHeaderCard(): View {
        val urgent = handoffPriorities.count { it.urgency == "高" }
        val pending = (teacherActions.size - actionDoneCount).coerceAtLeast(0)
        val box = ui.container(ColorToken.WarningSoft, ColorToken.Warning)
        box.addView(ui.statusPill("真人接力", ColorToken.Warning))
        box.addView(ui.label("先處理 $urgent 個高優先斷點", 21, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(flowStrip("確認學生", "分派負責人", "回填紀錄", "同步週報"))
        box.addView(metricRow(
            Metric("高優先", "$urgent 件", if (urgent > 0) ColorToken.Danger else ColorToken.Success),
            Metric("待辦", "$pending 件", ColorToken.Warning),
            Metric("協作", "${collaborationNotes.size} 筆", ColorToken.Primary)
        ))
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun aiSourceStatusCard(title: String, detail: String, color: String): View {
        val box = ui.container(if (color == ColorToken.Success) ColorToken.SuccessSoft else ColorToken.WarningSoft, color)
        box.addView(ui.statusPill(title, color))
        box.addView(ui.body(detail, "#334155").apply { setPadding(0, ui.dp(8), 0, 0) })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun mentorDailyCommandCard(): View {
        val box = ui.sectionBand(ColorToken.PrimarySoft)
        box.addView(ui.statusPill("今日工作台", ColorToken.Primary))
        box.addView(ui.label("先處理最需要人的一位", 23, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("先看風險最高的學生，再安排今天的接力。", "#334155"))
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

    private fun studentStatusHeader(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val titleRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val titleStack = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        titleStack.addView(ui.label("English+", 22, ColorToken.Ink, true))
        titleStack.addView(ui.body("今天只要完成下一個小關卡", ColorToken.Muted))
        titleRow.addView(titleStack, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        titleRow.addView(ui.statusPill("${completedTasks} 天", ColorToken.Accent))
        titleRow.addView(ui.statusPill("${confidence}%", ColorToken.Success))
        box.addView(titleRow)
        box.addView(ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = confidence.coerceIn(0, 100)
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun studentTodayQuestCard(): View {
        val title = if (!checkInCompleted) "先做 4 題狀態檢測" else "開始今天的英文小任務"
        val detail = if (!checkInCompleted) {
            "完成後 English+ 會依照心情、時間與想練的題型安排任務。"
        } else {
            "預計 ${minutes} 分鐘，先做一題剛好的題目；卡住時會有 AI 回饋或真人接力。"
        }
        val actionText = when {
            !checkInCompleted -> "開始檢測"
            !practiceTimeConfirmed -> "產生任務"
            else -> "開始第一題"
        }
        val action = when {
            !checkInCompleted -> ({ renderCheckIn() })
            !practiceTimeConfirmed -> ({ confirmPracticeTimeAndPlanToday() })
            else -> ({ renderLesson() })
        }
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Primary)
        box.addView(ui.statusPill("今日主線", ColorToken.Primary))
        box.addView(ui.label(title, 23, ColorToken.Ink, true).apply { setPadding(0, ui.dp(12), 0, ui.dp(6)) })
        box.addView(ui.body(detail, "#334155"))
        box.addView(metricRow(
            Metric("時間", "${minutes} 分", ColorToken.Accent),
            Metric("題數", "${targetDailyQuestionCount()} 題", ColorToken.Primary),
            Metric("狀態", mood.label, mood.color)
        ))
        box.addView(ui.primaryButton(actionText) { action.invoke() })
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun studentLearningPathCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("學習路徑", ColorToken.Success))
        box.addView(ui.label("沿著路徑往下完成", 19, ColorToken.Ink, true).apply { setPadding(0, ui.dp(10), 0, ui.dp(4)) })
        box.addView(pathNode("1", "心情檢測", if (checkInCompleted) "已完成" else "目前關卡", checkInCompleted, !checkInCompleted) { renderCheckIn() })
        box.addView(pathNode("2", "AI 安排今日任務", if (practiceTimeConfirmed) "已完成" else "下一步", practiceTimeConfirmed, checkInCompleted && !practiceTimeConfirmed) { confirmPracticeTimeAndPlanToday() })
        box.addView(pathNode("3", "短題練習", if (todayAnsweredFirstQuestion) "已完成" else "待開始", todayAnsweredFirstQuestion, practiceTimeConfirmed && !todayAnsweredFirstQuestion) { renderTaskQueue() })
        box.addView(pathNode("4", "反思與學習地圖", if (todayReflected) "已完成" else "完成後開啟", todayReflected, todayAnsweredFirstQuestion && !todayReflected) { renderReflection() })
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun studentMapStatusCard(): View {
        val completedSteps = listOf(checkInCompleted, practiceTimeConfirmed, todayAnsweredFirstQuestion, todayReflected).count { it }
        val totalSteps = 5
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Primary)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val titleStack = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        titleStack.addView(ui.statusPill("今日地圖", ColorToken.Primary))
        titleStack.addView(ui.label("你在第 ${completedSteps.coerceAtLeast(1)} 關", 24, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        titleStack.addView(ui.body("先完成亮起來的下一關，再決定要不要挑戰更難題。", "#334155"))
        top.addView(titleStack, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill("${confidence}%", if (confidence >= 60) ColorToken.Success else ColorToken.Warning))
        box.addView(top)
        box.addView(ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = totalSteps
            progress = completedSteps.coerceIn(1, totalSteps)
            setPadding(0, ui.dp(12), 0, ui.dp(8))
        })
        box.addView(flowStrip(
            mood.label,
            "${minutes} 分",
            selectedPracticeLevel,
            "${targetDailyQuestionCount()} 題"
        ))
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun studentAiRouteInsightCard(): View {
        val hasInsight = aiReflectionFeedback.isNotBlank() || aiMapRouteSuggestion.isNotBlank() || aiPracticeTypeSuggestion.isNotBlank()
        val box = ui.container(if (hasInsight) ColorToken.SuccessSoft else ColorToken.Surface, if (hasInsight) ColorToken.Success else ColorToken.Border)
        box.addView(ui.statusPill(if (hasInsight) "AI 已更新路線" else "AI 路線建議", if (hasInsight) ColorToken.Success else ColorToken.Muted))
        box.addView(ui.label(if (hasInsight) "下一步已依反思調整" else "完成反思後會更新", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(
            if (hasInsight) {
                listOf(aiReflectionFeedback, aiMapRouteSuggestion, aiPracticeTypeSuggestion)
                    .filter { it.isNotBlank() }
                    .joinToString("\n")
            } else {
                "完成今日題目和 20 秒反思後，English+ 會依照信心、錯題與題型偏好調整學習地圖。"
            },
            "#334155"
        ))
        if (hasInsight) {
            box.addView(ui.secondaryButton("依建議選題") { renderStudentPracticeCatalog() })
        }
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun studentMapPathCard(): View {
        val challengeUnlocked = todayReflected || confidence >= 65 || selectedPracticeLevel.contains("B1")
        val supportActive = wrongAttempts > 0 || confidence < 45
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("主線路徑", ColorToken.Success))
        box.addView(ui.label("照著亮起的關卡往下走", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(pathNode("1", "狀態檢測", "已完成，今天的任務已依狀態生成", true, false) { renderCheckIn() })
        box.addView(pathNode("2", "今日任務", "已選定 ${minutes} 分鐘、${targetDailyQuestionCount()} 題", practiceTimeConfirmed, false) { renderTaskQueue() })
        box.addView(pathNode("3", "第一題練習", if (todayAnsweredFirstQuestion) "已開始累積答題紀錄" else "下一關：先完成一題", todayAnsweredFirstQuestion, !todayAnsweredFirstQuestion) { renderTaskQueue() })
        box.addView(pathNode("4", "反思整理", if (todayReflected) "已完成今日反思" else "完成一題後解鎖", todayReflected, todayAnsweredFirstQuestion && !todayReflected) { renderReflection() })
        box.addView(pathNode("5", "挑戰關卡", if (challengeUnlocked) "可挑戰 $selectedPracticeLevel 題組" else "信心到 65% 或完成反思後開啟", false, challengeUnlocked) { renderStudentPracticeCatalog() })
        box.addView(pathNode("S", "支持節點", if (supportActive) "已亮起：可以找 AI 或老師協助" else "卡住時會自動亮起", false, supportActive) { renderStudentSupportEntry() })
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun studentMapNextActionCard(): View {
        val title: String
        val detail: String
        val actionText: String
        val action: () -> Unit
        when {
            !todayAnsweredFirstQuestion -> {
                title = "下一關：完成第一題"
                detail = "先做一題剛好的練習，答完會立刻看到正確與錯誤回饋。"
                actionText = "開始今日任務"
                action = { renderTaskQueue() }
            }
            !todayReflected -> {
                title = "下一關：整理今天的斷點"
                detail = "把剛剛的錯題、卡住原因或信心變化記下來，學習地圖才會往下一關推進。"
                actionText = "開始反思"
                action = { renderReflection() }
            }
            confidence >= 65 || selectedPracticeLevel.contains("B1") -> {
                title = "下一關：挑戰更難題型"
                detail = "目前狀態可以往進階題、閱讀題或克漏字走；如果卡住，支持節點會接住。"
                actionText = "選擇挑戰題"
                action = { renderStudentPracticeCatalog() }
            }
            else -> {
                title = "下一關：穩定多練一組"
                detail = "先用 A1/A2 題型把基礎穩住，等信心提高後再解鎖挑戰關卡。"
                actionText = "去練習中心"
                action = { renderStudentPracticeCatalog() }
            }
        }
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Success)
        box.addView(ui.statusPill("下一步", ColorToken.Success))
        box.addView(ui.label(title, 21, ColorToken.Ink, true).apply { setPadding(0, ui.dp(10), 0, ui.dp(4)) })
        box.addView(ui.body(detail, "#334155"))
        box.addView(ui.primaryButton(actionText) { action.invoke() })
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun studentMapSupportCard(): View {
        val needsSupport = wrongAttempts > 0 || confidence < 45
        val box = ui.container(if (needsSupport) ColorToken.WarningSoft else ColorToken.Surface, if (needsSupport) ColorToken.Warning else ColorToken.Border)
        box.addView(ui.statusPill(if (needsSupport) "支持已亮起" else "可選支援", if (needsSupport) ColorToken.Warning else ColorToken.Primary))
        box.addView(ui.label(if (needsSupport) "先修復，再往前" else "卡住時再打開", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(
            if (needsSupport) "系統偵測到卡住或信心偏低，可以先看 AI 說明、錯題提示或交給老師/志工接力。"
            else "這裡不打擾主線任務；只有需要陪伴、錯題卡住或想問人時再使用。",
            "#334155"
        ))
        box.addView(ui.secondaryButton("打開支持") { renderStudentSupportEntry() })
        return ui.margins(box, 0, 0, 0, 12)
    }

    private fun pathNode(number: String, title: String, state: String, done: Boolean, active: Boolean, action: () -> Unit): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, ui.dp(8), 0, ui.dp(8))
            if (active || done) setOnClickListener { action() }
        }
        val color = when {
            done -> ColorToken.Success
            active -> ColorToken.Primary
            else -> ColorToken.Muted
        }
        row.addView(ui.label(if (done) "✓" else number, 16, "#FFFFFF", true).apply {
            gravity = Gravity.CENTER
            setPadding(ui.dp(10), ui.dp(7), ui.dp(10), ui.dp(7))
            background = ui.rounded(color, color)
        })
        val text = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        text.addView(ui.label(title, 16, ColorToken.Ink, true))
        text.addView(ui.body(state, ColorToken.Muted))
        row.addView(text, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f).apply { leftMargin = ui.dp(12) })
        if (active) row.addView(ui.statusPill("開始", ColorToken.Primary))
        return row
    }

    private fun studentQuickPracticeCard(): View {
        val box = ui.container(ColorToken.Surface, ColorToken.Border)
        box.addView(ui.statusPill("快速入口", ColorToken.Accent))
        box.addView(ui.label("想自己挑題也可以", 18, ColorToken.Ink, true).apply { setPadding(0, ui.dp(10), 0, ui.dp(4)) })
        box.addView(ui.body("依難度與題型挑戰更多題目；主線任務仍會保留。", ColorToken.Muted))
        box.addView(ui.secondaryButton("打開練習中心") { renderStudentPracticeCatalog() })
        return ui.margins(box, 0, 8, 0, 12)
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
        val labels = currentRoleFlow().navLabels
        val nav = ui.container(ColorToken.Card, ColorToken.Border).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(ui.dp(8), ui.dp(8), ui.dp(8), ui.dp(8))
        }
        if (role == Role.Student) {
            nav.addView(navDestination(navMark(labels[0]), labels[0], screen == Screen.Home || screen == Screen.Account) { renderHome() }, ui.weightParams())
            nav.addView(navDestination(navMark(labels[1]), labels[1], screen == Screen.CheckIn) { renderCheckIn() }, ui.weightParams())
            nav.addView(navDestination(navMark(labels[2]), labels[2], screen == Screen.Lesson || screen == Screen.AiCoach || screen == Screen.Contract || screen == Screen.Reflection || screen == Screen.QuestionBank) { renderStudentTaskEntry() }, ui.weightParams())
            nav.addView(navDestination(navMark(labels[3]), labels[3], screen == Screen.Breakpoints || screen == Screen.Handoff || screen == Screen.Intervention || screen == Screen.HelpRequest) { renderStudentSupportEntry() }, ui.weightParams())
            nav.addView(navDestination(navMark(labels[4]), labels[4], screen == Screen.Map || screen == Screen.Journey) { renderStudentMapEntry() }, ui.weightParams())
        } else {
            nav.addView(navDestination(navMark(labels[0]), labels[0], screen == Screen.Home || screen == Screen.Account) { renderHome() }, ui.weightParams())
            nav.addView(navDestination(navMark(labels[1]), labels[1], screen == Screen.Roster || screen == Screen.StudentDetail || screen == Screen.StudentManager || screen == Screen.QuestionBank) { renderRoster() }, ui.weightParams())
            nav.addView(navDestination(navMark(labels[2]), labels[2], screen == Screen.ActionQueue || screen == Screen.Handoff || screen == Screen.Breakpoints || screen == Screen.Mentor) { renderActionQueue() }, ui.weightParams())
            nav.addView(navDestination(navMark(labels[3]), labels[3], screen == Screen.SyncCenter || screen == Screen.AiLab) { renderSyncCenter() }, ui.weightParams())
            nav.addView(navDestination(navMark(labels[4]), labels[4], screen == Screen.Report) { renderWeeklyReport() }, ui.weightParams())
        }
        pageFrame?.addView(ui.margins(nav, 8, 0, 8, 8)) ?: root.addView(ui.margins(nav, 0, 0, 0, 8))
    }

    private fun navMark(label: String): String {
        return when (label) {
            "首頁" -> "首"
            "檢測" -> "檢"
            "任務" -> "練"
            "支持" -> "助"
            "地圖" -> "圖"
            "今日" -> "今"
            "學生" -> "生"
            "接力" -> "接"
            "同步" -> "雲"
            "報告" -> "報"
            else -> label.take(1)
        }
    }

    private fun navigationArea(): String {
        val labels = currentRoleFlow().navLabels
        return if (role == Role.Student) {
            when (screen) {
                Screen.Home, Screen.Account -> labels[0]
                Screen.CheckIn -> labels[1]
                Screen.Lesson, Screen.AiCoach, Screen.Contract, Screen.Reflection, Screen.QuestionBank -> labels[2]
                Screen.Breakpoints, Screen.Handoff, Screen.Intervention, Screen.HelpRequest -> labels[3]
                else -> labels[4]
            }
        } else {
            when (screen) {
                Screen.Home, Screen.Account -> labels[0]
                Screen.Roster, Screen.StudentDetail, Screen.StudentManager, Screen.QuestionBank -> labels[1]
                Screen.ActionQueue, Screen.Handoff, Screen.Breakpoints, Screen.Mentor -> labels[2]
                Screen.SyncCenter, Screen.AiLab -> labels[3]
                else -> labels[4]
            }
        }
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
        box.addView(ui.statusPill("約 1 分鐘", ColorToken.Accent))
        box.addView(ui.label("先看今天適合怎麼練", 21, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("只回答 4 題。心情、時間、挑戰意願與題型偏好會直接改變今天的練習路線。", "#334155"))
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun checkInProgressCard(total: Int, answered: Int, result: CheckInResult?): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("檢測進度", if (answered == total) ColorToken.Success else ColorToken.Primary))
        box.addView(metricRow(
            Metric("已完成", "$answered/$total", if (answered == total) ColorToken.Success else ColorToken.Primary),
            Metric("預估", "1 分鐘", ColorToken.Accent),
            Metric("路線", result?.title ?: "待判讀", result?.mood?.color ?: ColorToken.Muted)
        ))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun checkInQuestionCard(index: Int, question: CheckInQuestion): View {
        val selectedIds = selectedCheckInOptionIds(question.id)
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("第 $index 題", if (selectedIds.isEmpty()) ColorToken.Primary else ColorToken.Success))
        box.addView(ui.label(question.title, 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(question.prompt, ColorToken.Muted))
        question.options.forEach { option ->
            box.addView(checkInOptionCard(question, option, option.id in selectedIds))
        }
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun selectedCheckInOptionIds(questionId: String): Set<String> {
        return checkInAnswers[questionId]
            ?.split(",")
            ?.map { it.trim() }
            ?.filter { it.isNotEmpty() }
            ?.toSet()
            ?: emptySet()
    }

    private fun isCheckInQuestionAnswered(questionId: String): Boolean {
        return selectedCheckInOptionIds(questionId).isNotEmpty()
    }

    private fun updateCheckInAnswer(question: CheckInQuestion, option: CheckInOption) {
        if (question.id == "practice_types") {
            val selected = selectedCheckInOptionIds(question.id).toMutableSet()
            if (selected.contains(option.id)) selected.remove(option.id) else selected.add(option.id)
            if (selected.isEmpty()) checkInAnswers.remove(question.id) else checkInAnswers[question.id] = selected.joinToString(",")
        } else {
            checkInAnswers[question.id] = option.id
        }
        pendingScrollY = currentScrollView?.scrollY ?: 0
        renderCheckIn()
    }

    private fun checkInOptionCard(question: CheckInQuestion, option: CheckInOption, selected: Boolean): View {
        val color = when (option.routeHint) {
            "challenge" -> ColorToken.Success
            "relay" -> ColorToken.Warning
            "repair" -> ColorToken.Accent
            else -> ColorToken.Primary
        }
        val box = ui.container(if (selected) ColorToken.PrimarySoft else ColorToken.Surface, if (selected) color else ColorToken.Border)
        box.addView(ui.statusPill(if (selected) "已選" else if (question.id == "practice_types") "可複選" else "選項", color))
        box.addView(ui.label(option.label, 16, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(8), 0, ui.dp(2))
        })
        box.addView(ui.body(option.helper, ColorToken.Muted))
        box.setOnClickListener {
            updateCheckInAnswer(question, option)
        }
        return ui.margins(box, 0, 8, 0, 4)
    }

    private fun checkInResultCard(result: CheckInResult): View {
        val box = ui.container(if (result.route == "relay" || result.route == "repair") ColorToken.WarningSoft else ColorToken.SuccessSoft, ColorToken.Border)
        box.addView(ui.statusPill("今日路線", result.mood.color))
        box.addView(ui.label(result.title, 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(result.nextStep, "#334155"))
        box.addView(metricRow(
            Metric("信心", "${result.confidence}%", result.mood.color),
            Metric("建議", "${result.recommendedMinutes} 分", ColorToken.Accent),
            Metric("狀態", result.route, ColorToken.Primary)
        ))
        box.addView(ui.body(result.supportMessage, ColorToken.Muted).apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 12)
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
        val typeCount = bankItems.map { it.questionType }.distinct().size
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Border)
        box.addView(ui.statusPill("題庫已本機化", ColorToken.Success))
        box.addView(ui.label("English+ 正式題庫骨架", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("題目", "${bankItems.size} 題", ColorToken.Primary),
            Metric("題型", "$typeCount 類", ColorToken.Accent),
            Metric("技能", "$skillCount 類", ColorToken.Success)
        ))
        box.addView(ui.body("練習題已從展示清單升級為 SQLite 題庫，保留 level、unit、skill、source 與推薦 metadata。後續可接 1000 題分級題庫或老師後台匯入。單元：$unitCount 組。", "#334155"))
        box.addView(ui.secondaryButton("打開題庫中心") { renderQuestionBank() })
        return ui.margins(box, 0, 8, 0, 12)
    }


    private fun todayProgress(): DailyTaskProgress {
        return PrototypeRepository.dailyTaskProgress(
            checkInCompleted = checkInCompleted,
            practiceTimeConfirmed = practiceTimeConfirmed,
            answeredFirstQuestion = todayAnsweredFirstQuestion,
            reflected = todayReflected,
            selectedMinutes = minutes
        )
    }

    private fun todayProgressCard(): View {
        val progress = todayProgress()
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        top.addView(ui.statusPill("今日進度", ColorToken.Primary))
        top.addView(ui.label("${progress.progressPercent}%", 18, ColorToken.Primary, true).apply {
            gravity = Gravity.RIGHT
        }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        box.addView(top)
        box.addView(ui.label(progress.currentStep, 22, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(progress.nextAction, "#334155"))
        box.addView(ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            this.progress = progress.progressPercent
            setPadding(0, ui.dp(10), 0, ui.dp(8))
            layoutParams = ui.fullWidthParams()
        })
        box.addView(ui.body("還剩 ${progress.remainingSteps} 步｜約 ${progress.remainingMinutes} 分鐘｜今天總流程 ${progress.totalSteps} 步", ColorToken.Primary).apply {
            setPadding(0, ui.dp(4), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun todayStepListCard(): View {
        val progress = todayProgress()
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label("今天會照這個順序走", 18, ColorToken.Ink, true))
        progress.steps.forEachIndexed { index, step ->
            val done = index < progress.completedSteps
            val current = index == progress.completedSteps && progress.remainingSteps > 0
            box.addView(todayStepRow(index + 1, step, done, current))
        }
        return ui.margins(box, 0, 6, 0, 12)
    }

    private fun todayStepRow(index: Int, title: String, done: Boolean, current: Boolean): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, ui.dp(8), 0, ui.dp(4))
        }
        val color = when {
            done -> ColorToken.Success
            current -> ColorToken.Accent
            else -> ColorToken.Muted
        }
        val state = when {
            done -> "完成"
            current -> "現在"
            else -> "待做"
        }
        row.addView(ui.statusPill("$index", color))
        row.addView(ui.label(title, 16, ColorToken.Ink, true).apply {
            setPadding(ui.dp(10), 0, 0, 0)
        }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        row.addView(ui.label(state, 14, color, true))
        return row
    }
    private fun questionBankReviewDashboardCard(): View {
        val summary = PrototypeRepository.teacherQuestionBankReviewSummary()
        val typeLine = summary.typeCounts.entries.joinToString("、") { "${it.key}:${it.value}" }.take(110)
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.statusPill("老師審閱儀表板", ColorToken.Primary))
        box.addView(ui.label("先看能不能派題，再看題型缺口", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("已審", "${summary.approvedItems}", ColorToken.Success),
            Metric("待審", "${summary.draftItems}", ColorToken.Warning),
            Metric("挑戰題", "${summary.challengeItems}", ColorToken.Accent)
        ))
        box.addView(ui.body("修復題：${summary.repairItems} 題｜題型分布：$typeLine", "#334155"))
        box.addView(ui.body("派題建議：學生端優先使用已審與修復標籤題；挑戰題適合信心 70% 以上或已完成同概念修復者。", ColorToken.Primary).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun questionBankItemCard(item: QuestionBankItem): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(item.question.prompt, 16, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(item.level, ColorToken.Primary))
        box.addView(top)
        box.addView(ui.body("${item.unit}｜${item.skill}｜${item.source}｜${item.reviewState}", ColorToken.Muted).apply { setPadding(0, ui.dp(7), 0, 0) })
        box.addView(ui.body("題型：${item.questionType}｜難度帶：${item.difficultyBand}｜挑戰分：${item.challengeScore}｜建議情緒：${item.emotionalFit}", ColorToken.Primary))
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
        box.addView(ui.statusPill(if (AuthContract.isStudentRole(account.roleLabel)) "學生" else "老師 / 志工", color))
        box.addView(ui.label("${account.displayName}｜${account.roleLabel}", 17, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(account.classCode, "#334155"))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun remoteAuthStatusCard(): View {
        val hasEndpoint = stateStore.hasRemoteAuthEndpoint()
        val box = ui.container(if (hasEndpoint) ColorToken.SuccessSoft else ColorToken.WarningSoft, ColorToken.Border)
        box.addView(ui.statusPill(if (hasEndpoint) "登入服務已連線" else "使用快速登入", if (hasEndpoint) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label(if (hasEndpoint) "可使用校內帳號登入" else "目前可用預設帳號登入", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(stateStore.authSessionSummary(), "#334155"))
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

    private fun practiceCenterEntryCard(): View {
        val bankItems = stateStore.questionBankItems()
        val challengeCount = bankItems.count { it.difficultyBand == "challenge" || it.level == "B1" }
        val typeCount = bankItems.map { normalizedQuestionType(it) }.distinct().size
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("練習中心", ColorToken.Accent))
        box.addView(ui.label("想挑戰難一點，可以自己選題", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("目前題庫", "${bankItems.size}", ColorToken.Primary),
            Metric("題型", "$typeCount", ColorToken.Success),
            Metric("進階題", "$challengeCount", ColorToken.Accent)
        ))
        box.addView(ui.body("這一輪先把入口改成可選難度與題型；後續大量題庫會直接接到同一個分類系統。", "#334155"))
        box.addView(ui.primaryButton("打開練習中心") { renderStudentPracticeCatalog() })
        return ui.margins(box, 0, 8, 0, 12)
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
        box.addView(ui.statusPill("正確", ColorToken.Success))
        box.addView(ui.label("做得好，這題完成了", 24, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(answerCompareStrip("你的答案", question.answer, "正確答案", question.answer, ColorToken.Success))
        box.addView(ui.body("解析：${question.explanation}", "#334155").apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        box.addView(metricRow(
            Metric("完成", "$completedTasks", ColorToken.Primary),
            Metric("信心", "$confidence%", ColorToken.Success),
            Metric("狀態", "通過", ColorToken.Success)
        ))
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun answerResultCard(isCorrect: Boolean, question: Question, selectedAnswer: String): View {
        val fill = if (isCorrect) ColorToken.SuccessSoft else ColorToken.WarningSoft
        val color = if (isCorrect) ColorToken.Success else ColorToken.Warning
        val title = if (isCorrect) "答對了" else "先看這裡"
        val subtitle = if (isCorrect) "你選到了正確答案。" else "你剛剛選的答案還差一點，下面先把差異講清楚。"
        val box = ui.sectionBand(fill)
        box.addView(ui.statusPill(if (isCorrect) "正確" else "需要修復", color))
        box.addView(ui.label(title, 26, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(subtitle, "#334155"))
        box.addView(answerCompareStrip(
            "你的答案",
            selectedAnswer.ifBlank { "尚未選擇" },
            "正確答案",
            question.answer,
            color
        ))
        box.addView(ui.body("解析：${question.explanation}", "#334155").apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun answerCompareStrip(leftLabel: String, leftValue: String, rightLabel: String, rightValue: String, accent: String): View {
        val same = leftValue == rightValue
        val box = ui.container(ColorToken.Card, accent)
        box.addView(metricRow(
            Metric(leftLabel, leftValue, accent),
            Metric(rightLabel, rightValue, ColorToken.Success),
            Metric("判讀", if (same) "一致" else "不同", if (same) ColorToken.Success else ColorToken.Warning)
        ))
        return ui.margins(box, 0, 8, 0, 8)
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

    private fun accountLoginCard(account: LocalAccount): View {
        val isStudent = AuthContract.isStudentRole(account.roleLabel)
        val box = ui.container(if (isStudent) ColorToken.PrimarySoft else ColorToken.SuccessSoft, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(account.displayName, 20, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(account.roleLabel, if (isStudent) ColorToken.Primary else ColorToken.Success))
        box.addView(top)
        box.addView(ui.body("班級/群組：${account.classCode}", "#334155").apply { setPadding(0, ui.dp(8), 0, 0) })
        box.addView(ui.body(if (isStudent) "進入後先做狀態檢測，再開始今日任務。" else "進入後先看接力工作台與高風險學生。", ColorToken.Muted))
        box.addView(ui.primaryButton(if (isStudent) "登入學生端" else "登入老師端") {
            selectAccount(account)
            resetStudentFlow()
            renderHome()
        })
        return ui.margins(box, 0, 8, 0, 12)
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

    private fun lessonSessionHeader(question: Question): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        top.addView(ui.statusPill("${currentQuestionIndex + 1}/${questions.size}", ColorToken.Accent))
        top.addView(ui.label(normalizedLessonType(question), 16, ColorToken.Ink, true).apply {
            setPadding(ui.dp(10), 0, 0, 0)
        }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill("${confidence}%", ColorToken.Success))
        box.addView(top)
        box.addView(ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = questions.size
            progress = currentQuestionIndex + 1
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        return ui.margins(box, 0, 4, 0, 10)
    }

    private fun questionCard(question: Question): View {
        val box = ui.sectionBand(ColorToken.Card)
        box.addView(ui.statusPill("一題一概念", ColorToken.Primary))
        box.addView(ui.label(questionInstruction(question), 16, ColorToken.Primary, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(6))
        })
        box.addView(ui.label(question.prompt, 28, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(8), 0, ui.dp(14))
        })
        question.options.forEachIndexed { index, option ->
            box.addView(answerOptionCard(index, option))
        }
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun answerOptionCard(index: Int, option: String): View {
        val row = ui.container(ColorToken.Surface, ColorToken.Border).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(ui.dp(12), ui.dp(12), ui.dp(12), ui.dp(12))
            setOnClickListener { answer(option) }
        }
        val label = ('A'.code + index).toChar().toString()
        row.addView(ui.label(label, 15, ColorToken.Primary, true).apply {
            gravity = Gravity.CENTER
            setPadding(ui.dp(10), ui.dp(7), ui.dp(10), ui.dp(7))
            background = ui.rounded(ColorToken.PrimarySoft, ColorToken.Primary)
        })
        row.addView(ui.label(option, 17, ColorToken.Ink, true).apply {
            setPadding(ui.dp(12), 0, 0, 0)
        }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        return ui.margins(row, 0, 6, 0, 6)
    }

    private fun lessonActionStrip(): View {
        val box = ui.container(ColorToken.Surface, ColorToken.Border)
        box.addView(ui.statusPill("卡住也可以", ColorToken.Accent))
        box.addView(ui.body("不確定時可以先選一個答案；答錯會看到修復提示，不會直接結束。", ColorToken.Muted))
        box.addView(ui.secondaryButton("我想求助") { renderHelpRequest() })
        box.addView(ui.secondaryButton("改做復原任務") { renderRecoveryMode() })
        return ui.margins(box, 0, 6, 0, 12)
    }

    private fun normalizedLessonType(question: Question): String {
        return when {
            question.type.contains("cloze") || question.type.contains("克漏") -> "克漏字"
            question.type.contains("reading") || question.type.contains("閱讀") -> "閱讀理解"
            question.type.contains("fill") || question.type.contains("填") -> "填空題"
            question.type.contains("translation") || question.type.contains("翻") -> "翻譯/句子重組"
            else -> "選擇題"
        }
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

    private fun practiceHubHeroCard(items: List<QuestionBankItem>): View {
        val first = items.firstOrNull()
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Primary)
        box.addView(ui.statusPill("今日推薦", ColorToken.Primary))
        box.addView(ui.label("從這裡開始最剛好", 22, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("English+ 會依照你的心情檢測、信心值和偏好題型，推薦今天最適合的一組題目。", "#334155"))
        box.addView(metricRow(
            Metric("難度", selectedPracticeLevel, ColorToken.Primary),
            Metric("題型", selectedPracticeTypes.joinToString("、"), ColorToken.Success),
            Metric("題數", "${items.size}", ColorToken.Accent)
        ))
        first?.let { item ->
            box.addView(ui.primaryButton("開始推薦題") { startPracticeItem(item) })
        }
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun practiceLevelLaunchCard(levelValue: String, title: String, detail: String, count: Int, color: String, action: () -> Unit): View {
        val selected = selectedPracticeLevel == levelValue
        val box = ui.container(if (selected) ColorToken.PrimarySoft else ColorToken.Card, if (selected) ColorToken.Primary else ColorToken.Border)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        top.addView(ui.label(title, 18, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(if (selected) "目前" else "$count 題", if (selected) ColorToken.Primary else color))
        box.addView(top)
        box.addView(ui.body(detail, ColorToken.Muted).apply { setPadding(0, ui.dp(6), 0, 0) })
        box.setOnClickListener { action() }
        return ui.margins(box, 0, 6, 0, 8)
    }

    private fun practiceTypeLaunchCard(type: String, count: Int, selected: Boolean, action: () -> Unit): View {
        val box = ui.container(if (selected) ColorToken.SuccessSoft else ColorToken.Surface, if (selected) ColorToken.Success else ColorToken.Border)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        top.addView(ui.label(type, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(if (selected) "已選" else "$count 題", if (selected) ColorToken.Success else ColorToken.Muted))
        box.addView(top)
        box.addView(ui.body(practiceTypeHint(type), ColorToken.Muted).apply { setPadding(0, ui.dp(6), 0, 0) })
        box.setOnClickListener { action() }
        return ui.margins(box, 0, 6, 0, 8)
    }

    private fun practiceTypeHint(type: String): String {
        return when {
            type.contains("克漏") -> "練上下文判斷與文法選擇。"
            type.contains("閱讀") -> "練短文理解、主旨與細節。"
            type.contains("填") -> "練單句文法與關鍵字。"
            type.contains("翻") -> "練句子重組與中英轉換。"
            else -> "練會考常見選擇題。"
        }
    }
    private fun studentPracticeOptionCard(item: QuestionBankItem): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        top.addView(ui.label(item.skill, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(item.level, ColorToken.Accent))
        box.addView(top)
        box.addView(ui.body("${normalizedQuestionType(item)}｜挑戰 ${item.challengeScore}｜約 ${item.estimatedSeconds} 秒", ColorToken.Muted).apply { setPadding(0, ui.dp(6), 0, 0) })
        box.addView(ui.body(item.question.prompt.take(90), "#334155").apply { setPadding(0, ui.dp(6), 0, 0) })
        box.addView(ui.secondaryButton("開始這題") { startPracticeItem(item) })
        box.setOnClickListener { startPracticeItem(item) }
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun practiceFilterChip(label: String, selected: Boolean, action: () -> Unit): View {
        val fill = if (selected) ColorToken.PrimarySoft else ColorToken.Card
        val stroke = if (selected) ColorToken.Primary else ColorToken.Border
        val box = ui.container(fill, stroke)
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        row.addView(ui.label(label, 16, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        row.addView(ui.statusPill(if (selected) "已選" else "選擇", if (selected) ColorToken.Primary else ColorToken.Muted))
        box.addView(row)
        box.setOnClickListener { action() }
        return ui.margins(box, 0, 6, 0, 6)
    }

    private fun dailyAiTaskPlanCard(): View {
        val itemsById = stateStore.questionBankItems().associateBy { it.id }
        val plannedItems = aiDailyPlanItemIds.mapNotNull { itemsById[it] }
        val isTrueAi = aiDailyPlanSource.contains("OpenRouter")
        val box = ui.container(if (isTrueAi) ColorToken.SuccessSoft else ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.statusPill(if (isTrueAi) "真 AI 已生成" else "內建推薦", if (isTrueAi) ColorToken.Success else ColorToken.Primary))
        box.addView(ui.label(aiDailyPlanTitle.ifBlank { "今日任務推薦" }, 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(aiDailyPlanMessage.ifBlank { "完成心情檢測與時間選擇後，系統會把今天要做的題目排成清楚順序。" }, "#334155"))
        box.addView(metricRow(
            Metric("時間", "${minutes} 分", ColorToken.Accent),
            Metric("題數", "${plannedItems.size} 題", ColorToken.Primary),
            Metric("來源", if (isTrueAi) "OpenRouter" else "內建", if (isTrueAi) ColorToken.Success else ColorToken.Warning)
        ))
        plannedItems.forEachIndexed { index, item ->
            box.addView(ui.secondaryButton("${index + 1}. ${item.level}｜${normalizedQuestionType(item)}｜${item.question.concept.take(18)}") {
                startPracticeItem(item)
            })
        }
        if (plannedItems.isEmpty()) {
            box.addView(ui.secondaryButton("產生今日任務") { confirmPracticeTimeAndPlanToday() })
        } else {
            box.addView(ui.secondaryButton(if (stateStore.hasOpenRouterApiKey()) "用真 AI 重新安排" else "重新安排今日任務") { confirmPracticeTimeAndPlanToday() })
        }
        return ui.margins(box, 0, 8, 0, 12)
    }
    private fun practiceRecommendationCard(items: List<QuestionBankItem>): View {
        val recommendedLevel = when {
            confidence >= 70 -> "B1 進階挑戰"
            confidence >= 50 -> "A2 會考基準"
            else -> "A1/A2 弱點修復"
        }
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Border)
        box.addView(ui.statusPill("系統推薦", ColorToken.Success))
        box.addView(ui.label(recommendedLevel, 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("根據目前心情、信心值與錯題紀錄，建議先從這一組開始；如果想挑戰，可以往下切換進階難度。", "#334155"))
        items.take(3).forEach { item ->
            box.addView(ui.secondaryButton("${item.level}｜${normalizedQuestionType(item)}｜挑戰 ${item.challengeScore}") {
                startPracticeItem(item)
            })
        }
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun adaptiveNextStepCard(question: Question, wasCorrect: Boolean): View {
        val current = questionBankItemFor(question)
        val recommendations = PrototypeRepository.adaptivePracticeRecommendations(
            current = current,
            wasCorrect = wasCorrect,
            confidence = confidence,
            moodLabel = mood.name,
            wrongAttempts = wrongAttempts
        )
        val fill = if (wasCorrect) ColorToken.SuccessSoft else ColorToken.WarningSoft
        val accent = if (wasCorrect) ColorToken.Success else ColorToken.Warning
        val title = if (wasCorrect) "適性推薦：可以往上挑戰" else "適性推薦：先做修復題"
        val detail = if (wasCorrect) {
            "你剛剛答對了，系統會優先給同題型或更高挑戰值的題目；如果信心還不高，會停在會考基準難度。"
        } else {
            "你剛剛還沒答對，系統會先給同概念、低壓或修復標籤的題目，避免直接跳到更難的文章題。"
        }
        val box = ui.container(fill, ColorToken.Border)
        box.addView(ui.statusPill("下一題不是固定順序", accent))
        box.addView(ui.label(title, 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(detail, "#334155"))
        current?.let {
            box.addView(metricRow(
                Metric("本題", normalizedQuestionType(it), ColorToken.Primary),
                Metric("挑戰", "${it.challengeScore}/6", accent),
                Metric("約", "${it.estimatedSeconds} 秒", ColorToken.Success)
            ))
        }
        recommendations.forEach { item ->
            box.addView(ui.secondaryButton("${item.level}｜${normalizedQuestionType(item)}｜挑戰 ${item.challengeScore}｜${item.skill.take(10)}") {
                startPracticeItem(item)
            })
        }
        box.addView(ui.secondaryButton("回練習中心自己挑題") { renderStudentPracticeCatalog() })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun questionBankItemFor(question: Question): QuestionBankItem? {
        return stateStore.questionBankItems().firstOrNull {
            it.question.prompt == question.prompt && it.question.answer == question.answer
        }
    }

    private fun practiceLevelOptions(items: List<QuestionBankItem>): List<String> {
        val base = mutableListOf("推薦", "全部難度", "弱點修復")
        if (items.any { it.level == "A1" }) base.add("基礎 A1")
        if (items.any { it.level == "A2" }) base.add("會考基準 A2")
        if (items.any { it.level == "B1" }) base.add("進階挑戰 B1")
        return base.distinct()
    }

    private fun practiceTypeOptions(items: List<QuestionBankItem>): List<String> {
        return listOf("全部題型") + items.map { normalizedQuestionType(it) }.distinct().sorted()
    }

    private fun filteredPracticeItems(items: List<QuestionBankItem>): List<QuestionBankItem> {
        return items.filter { item ->
            val levelMatch = when (selectedPracticeLevel) {
                "推薦" -> recommendedPracticeItems(items).contains(item)
                "全部難度" -> true
                "弱點修復" -> item.recommendationTags.contains("repair") || item.question.concept.contains("be") || item.question.concept.contains("文法") || item.skill.contains("文法")
                "基礎 A1" -> item.level == "A1" || item.difficultyBand == "foundation"
                "會考基準 A2" -> item.level == "A2" || item.difficultyBand == "cap-standard"
                "進階挑戰 B1" -> item.level == "B1" || item.difficultyBand == "challenge"
                else -> true
            }
            val typeMatch = selectedPracticeTypes.contains("全部題型") || selectedPracticeTypes.contains(normalizedQuestionType(item))
            levelMatch && typeMatch
        }
    }

    private fun recommendedPracticeItems(items: List<QuestionBankItem>): List<QuestionBankItem> {
        val plannedByAi = aiDailyPlanItemIds.mapNotNull { id -> items.firstOrNull { it.id == id } }
        val seed = PrototypeRepository.adaptivePracticeRecommendations(
            current = null,
            wasCorrect = confidence >= 60,
            confidence = confidence,
            moodLabel = mood.name,
            wrongAttempts = wrongAttempts,
            limit = 12
        ).filter { candidate -> items.any { it.id == candidate.id } }
        val combined = (plannedByAi + seed + items.take(12)).distinctBy { it.id }
        return combined.take(12)
    }

    private fun normalizedQuestionType(item: QuestionBankItem): String {
        val type = item.questionType.ifBlank { item.question.type }
        return when {
            type == "fill-blank" -> "填空題"
            type == "cloze" -> "克漏字"
            type == "reading" -> "閱讀理解"
            type == "translation-reorder" -> "翻譯/句子重組"
            type == "choice" -> "選擇題"
            type.contains("填空") -> "填空題"
            type.contains("克漏") -> "克漏字"
            type.contains("閱讀") || type.contains("讀") -> "閱讀理解"
            type.contains("翻譯") || type.contains("重組") -> "翻譯/句子重組"
            type.contains("選擇") -> "選擇題"
            else -> type.ifBlank { "選擇題" }
        }
    }

    private fun startPracticeItem(item: QuestionBankItem) {
        val index = questions.indexOfFirst {
            it.prompt == item.question.prompt && it.answer == item.question.answer
        }
        if (index >= 0) currentQuestionIndex = index
        wrongAttempts = 0
        lastSelectedAnswer = ""
        lastAnswerMessage = "已切換到 ${item.level}｜${normalizedQuestionType(item)}。先做這一題，再依結果推薦下一步。"
        renderLesson()
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

    private fun teacherProgressSnapshotCard(): View {
        val snapshot = PrototypeRepository.teacherProgressSnapshot(
            learningEvents = learningEventCount,
            repairedMistakes = repairedMistakeCount,
            confidence = confidence,
            pendingSync = offlinePendingCount
        )
        val color = if (snapshot.riskLabel == "需要接力") ColorToken.Warning else ColorToken.Success
        val box = ui.container(if (snapshot.riskLabel == "需要接力") ColorToken.WarningSoft else ColorToken.SuccessSoft, ColorToken.Border)
        box.addView(ui.statusPill(snapshot.riskLabel, color))
        box.addView(ui.label("目前判讀", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(snapshot.evidenceLine, "#334155"))
        box.addView(ui.body(snapshot.syncLine, ColorToken.Muted).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        box.addView(ui.body("下一步：${snapshot.nextAction}", color).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 12)
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
