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
    private var bottomNavAttached = false

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
    private var activePracticeItemIds: List<String> = emptyList()
    private var activePracticeItemIndex = -1
    private val completedDailyTaskItemIds = mutableSetOf<String>()
    private var aiDailyPlanSource = ""
    private var aiReflectionFeedback = ""
    private var aiMapRouteSuggestion = ""
    private var aiPracticeTypeSuggestion = ""
    private var recoveryTaskTitle = ""
    private var recoveryTaskDetail = ""
    private var recoveryTaskQuestionIndex: Int? = null
    private var preparedHelpSummary = ""
    private var latestTeacherAiSummary = ""
    private var latestVolunteerDraft = ""
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
        val backendText = if (stateStore.hasCloudBackend()) "雲端同步已開啟" else "雲端同步尚未開啟"
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
        if (checkInCompleted && practiceTimeConfirmed) renderTaskQueue() else renderStudentPracticeCatalog()
    }

    private fun renderStudentSupportEntry() {
        if (checkInCompleted) renderStudentRecoveryCenter() else renderStudentSupportBeforeCheckIn()
    }

    private fun renderStudentMapEntry() {
        if (checkInCompleted && practiceTimeConfirmed) renderMap() else renderStudentMapLocked()
    }

    private fun renderStudentSupportBeforeCheckIn() {
        screen = Screen.HelpRequest
        shell("支持", "可以先求助，也可以先做檢測")
        root.addView(card(
            "需要幫忙可以先說",
            "你還沒有完成今天的心情檢測，所以 English+ 還不能產生今日任務；但你仍然可以先進練習中心自由練習，或先做檢測讓系統安排任務。",
            ColorToken.PrimarySoft
        ))
        helpRequestOptions.take(3).forEach { root.addView(helpOptionCard(it)) }
        root.addView(ui.primaryButton("先做心情檢測") { renderCheckIn() })
        root.addView(ui.secondaryButton("自由練習") { renderStudentPracticeCatalog() })
        root.addView(ui.secondaryButton("回首頁") { renderHome() })
        bottomNav()
    }

    private fun renderStudentMapLocked() {
        screen = Screen.Map
        shell("學習地圖", "完成檢測後建立今日路線")
        root.addView(card(
            "今日地圖還沒建立",
            "學習地圖會根據心情檢測、可用時間與今日任務生成。你可以先自由練習；想看完整路線時，再完成心情檢測。",
            ColorToken.PrimarySoft
        ))
        root.addView(ui.primaryButton("開始心情檢測") { renderCheckIn() })
        root.addView(ui.secondaryButton("先去練習中心") { renderStudentPracticeCatalog() })
        bottomNav()
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
            detail = "老師看班級與派工；志工看今天要陪伴的學生與回填紀錄。",
            fill = ColorToken.SuccessSoft,
            actionText = "選擇工作帳號"
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
        shell("English+", if (isStudent) "學生登入" else "工作端登入")
        hero(
            if (isStudent) "選擇學生帳號" else "你今天是哪一種角色？",
            if (isStudent) {
                "登入後先做心情檢測，再開始今天任務。"
            } else {
                "老師進入班級工作台；志工進入接力陪伴流程。"
            }
        )
        accounts.forEach { root.addView(accountLoginCard(it)) }
        root.addView(ui.secondaryButton("回到身分選擇") { renderRoleGateway() })
        bottomNav()
    }

    private fun renderHome() {
        screen = Screen.Home
        val flow = currentRoleFlow()
        if (role == Role.Student) {
            shell("English+", flow.roleLabel)
            hero(flow.homeTitle, flow.homeSubtitle)
            studentHome()
        } else if (isVolunteerAccount()) {
            shell("English+", "志工端")
            hero("今天先陪一位學生", "先看摘要、照腳本陪練，再回填一句紀錄。")
            volunteerHome()
        } else {
            shell("English+", "老師端")
            hero("今天先看班級訊號", "先找出需要接力的學生，再分派待辦與整理週報。")
            teacherHome()
        }
    }

    private fun studentHome() {
        root.addView(studentTodayQuestCard())
        root.addView(studentQuickPracticeCard())
        bottomNav()
    }

    private fun teacherHome() {
        root.addView(teacherTodayOverviewCard())
        root.addView(teacherFirstPriorityCard())
        root.addView(teacherClassPulseCard())
        root.addView(teacherWorkQueueCard())
        root.addView(teacherReportShortcutCard())
        root.addView(ui.secondaryButton("回到身分選擇") { renderRoleGateway() })
        bottomNav()
    }

    private fun volunteerHome() {
        root.addView(volunteerFocusCard())
        root.addView(volunteerScriptPreviewCard())
        root.addView(volunteerActionEntrancesCard())
        root.addView(volunteerCompletionCard())
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
        shell("帳號與班級", "確認目前使用的角色與群組")
        root.addView(card("目前登入", "${account.displayName}｜${account.roleLabel}\n班級/群組：${account.classCode}\n${account.loginState}", ColorToken.PrimarySoft))
        root.addView(accountReadinessCard())
        root.addView(remoteAuthStatusCard())
        root.addView(remoteAuthLoginCard())
        accountList().forEach { root.addView(accountCard(it)) }
        root.addView(ui.secondaryButton("切換到工作端") {
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
            shell("帳號登入尚未連線", "目前先使用本機帳號")
            root.addView(card("目前狀態", "尚未連接學校帳號系統時，可以先使用本機帳號完成學生、老師與志工流程。", ColorToken.WarningSoft))
            root.addView(remoteAuthLoginCard())
            root.addView(ui.secondaryButton("回帳號中心") { renderAccountCenter() })
            bottomNav()
            return
        }
        shell("正在登入", "正在確認帳號")
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
        recordLearningEvent("remote_login_failed", "帳號登入失敗", message)
        shell("帳號登入失敗", "可以先使用本機帳號")
        root.addView(card("錯誤訊息", message, ColorToken.WarningSoft))
        root.addView(card("下一步", "目前仍可用本機帳號完成學生、老師與志工流程；帳號系統連線後再重新登入即可。", ColorToken.Card))
        root.addView(ui.primaryButton("回帳號中心") { renderAccountCenter() })
        bottomNav()
    }

    private fun currentRoleFlow() = PrototypeRepository.roleFlowSpec(role)

    private fun roleLabel(): String = currentRoleFlow().roleLabel

    private fun normalizedAccountRole(): String = AuthContract.normalizeRole(currentAccount().roleLabel)

    private fun isVolunteerAccount(): Boolean = normalizedAccountRole() == AuthContract.ROLE_VOLUNTEER

    private fun isTeacherAccount(): Boolean = normalizedAccountRole() == AuthContract.ROLE_TEACHER

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
        root.addView(card("產品檢核方向", "這頁用來確認我們做的不是單純英文練習 app，而是面向偏鄉學生、情緒斷點與雙軌接力的學習平台。", ColorToken.PrimarySoft))
        designPrinciples.forEach { root.addView(principleCard(it)) }
        root.addView(ui.secondaryButton("查看 English+ 設計系統") { renderDesignSystem() })
        root.addView(ui.primaryButton("查看產品檢核") { renderMentorChecks() })
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
        if (dailyTaskTotal() > 0) {
            root.addView(dailyTaskProgressCard())
        }
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
        val checkInQuestions = PrototypeRepository.emotionalCheckInQuestions
        val answeredCount = checkInQuestions.count { isCheckInQuestionAnswered(it.id) }
        val complete = checkInQuestions.all { isCheckInQuestionAnswered(it.id) }
        val result = if (complete) PrototypeRepository.evaluateEmotionalCheckIn(checkInAnswers) else null
        shell("心情檢測", "${(answeredCount + 1).coerceAtMost(checkInQuestions.size)} / ${checkInQuestions.size}")
        root.addView(checkInProgressCard(checkInQuestions.size, answeredCount, result))
        if (complete && result != null) {
            root.addView(dailyTaskReadyCard(result))
            root.addView(ui.primaryButton("開始今日任務") {
                applyCheckInResult(result)
                renderCheckInAiSupport(result)
            })
            root.addView(ui.secondaryButton("重新檢測") {
                checkInAnswers.clear()
                checkInCompleted = false
                practiceTimeConfirmed = false
                renderCheckIn()
            })
        } else {
            val currentIndex = checkInQuestions.indexOfFirst { !isCheckInQuestionAnswered(it.id) }.coerceAtLeast(0)
            root.addView(checkInQuestionCard(currentIndex + 1, checkInQuestions[currentIndex]))
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
            result.route == "repair" -> "基礎暖身"
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
            renderCheckInAiSupportFallback(result, "English+ 已依照你的狀態先排出今天能完成的一小步。")
            return
        }
        screen = Screen.CheckIn
        shell("今日建議", "正在整理你的學習節奏")
        root.addView(card("請稍候", "English+ 正在根據你的心情、時間、挑戰意願與題型偏好產生今天的支持語。", ColorToken.PrimarySoft))
        bottomNav()
        Thread {
            try {
                val support = generateRemoteCheckInSupport(result)
                runOnUiThread { renderCheckInAiSupportResult(result, support) }
            } catch (error: Exception) {
                runOnUiThread {
                    recordLearningEvent("ai_fallback", "情緒支持真 AI 呼叫失敗", error.message ?: "未知錯誤")
                    renderCheckInAiSupportFallback(result, "今天先用穩定的短任務開始，之後仍可以重新產生建議。")
                }
            }
        }.start()
    }

    private fun renderCheckInAiSupportResult(result: CheckInResult, support: AiSupportResult) {
        addOfflineSyncItem("AI 情緒支持：${result.title}", "真 AI 情緒支持", support.handoffSummary)
        recordLearningEvent("ai_emotional_support", "真 AI 情緒支持", support.diagnosis)
        confirmPracticeTimeAndPlanToday(support.studentFeedback.ifBlank { result.nextStep })
    }
    private fun renderCheckInAiSupportFallback(result: CheckInResult, notice: String) {
        confirmPracticeTimeAndPlanToday(notice)
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
    private fun confirmPracticeTimeAndPlanToday(seedMessage: String = "") {
        practiceTimeConfirmed = true
        todayAnsweredFirstQuestion = false
        todayReflected = false
        aiDailyPlanItemIds = emptyList()
        completedDailyTaskItemIds.clear()
        aiDailyPlanTitle = ""
        aiDailyPlanMessage = seedMessage
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
            applyLocalDailyTaskPlan(candidates, aiDailyPlanMessage.ifBlank { "English+ 已依照你的心情、時間與題型偏好，先排出今天可以開始的一組任務。" })
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
            mood == Mood.Low -> "先暖身"
            confidence >= 70 -> "挑戰進階"
            confidence <= 45 -> "基礎補強"
            else -> "穩定練習"
        }
    }

    private fun targetQuestionCountForMinutes(value: Int): Int {
        return when {
            value <= 3 -> 2
            value <= 5 -> 3
            value <= 8 -> 4
            else -> 5
        }
    }

    private fun targetDailyQuestionCount(): Int {
        return when {
            minutes <= 3 -> 2
            minutes <= 5 -> 3
            minutes <= 8 -> 4
            else -> 5
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
                selectedPracticeLevel.contains("A1") || selectedPracticeLevel.contains("暖身") || selectedPracticeLevel.contains("修復") -> item.level == "A1" || item.recommendationTags.contains("repair")
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
        return varyDailyCandidates(adaptive + ranked).take(180)
    }

    private fun dailyPlanVariationSeed(): Int {
        val minuteBucket = (System.currentTimeMillis() / 60000L).toInt()
        return minuteBucket xor
            (learningEventCount * 31) xor
            (completedTasks * 17) xor
            (confidence * 13) xor
            (minutes * 7) xor
            selectedPracticeLevel.hashCode() xor
            selectedPracticeTypes.joinToString("|").hashCode()
    }

    private fun varyDailyCandidates(items: List<QuestionBankItem>): List<QuestionBankItem> {
        val seed = dailyPlanVariationSeed()
        return items
            .distinctBy { "${it.question.prompt}｜${it.question.answer}" }
            .sortedWith(
                compareBy<QuestionBankItem> {
                    Math.floorMod((it.id + it.question.prompt + seed.toString()).hashCode(), 10_000)
                }.thenByDescending { selectedPracticeTypes.contains(normalizedQuestionType(it)) }
                    .thenByDescending { if (selectedPracticeLevel.contains("B1")) it.challengeScore else 6 - it.challengeScore }
                    .thenBy { it.estimatedSeconds }
            )
    }

    private fun applyAiDailyTaskPlan(plan: AiDailyTaskPlan, candidates: List<QuestionBankItem>) {
        val byId = candidates.associateBy { it.id }
        val aiSelected = plan.recommendedItemIds.mapNotNull { byId[it] }.distinctBy { it.id }
        val fillItems = varyDailyCandidates(candidates.filterNot { candidate -> aiSelected.any { it.id == candidate.id } })
        val aiAnchors = aiSelected.take(1)
        val selected = (aiAnchors + fillItems)
            .distinctBy { "${it.question.prompt}｜${it.question.answer}" }
            .take(targetDailyQuestionCount())
        aiDailyPlanTitle = plan.title.ifBlank { "今日 AI 任務" }
        aiDailyPlanMessage = buildString {
            append(plan.studentMessage.ifBlank { "依照你的狀態，先完成這一小組英文練習。" })
            if (aiSelected.size < targetDailyQuestionCount()) {
                append("\n\nAI 回傳 ${aiSelected.size} 題，English+ 已用同一批候選題補足今日題數。")
            }
        }
        aiDailyPlanItemIds = selected.map { it.id }
        completedDailyTaskItemIds.retainAll(aiDailyPlanItemIds.toSet())
        aiDailyPlanSource = if (aiSelected.isNotEmpty()) plan.source else "${plan.source} + local fill"
        recordLearningEvent("ai_daily_plan", aiDailyPlanTitle, "source=$aiDailyPlanSource / items=${aiDailyPlanItemIds.joinToString(",")}")
    }

    private fun applyLocalDailyTaskPlan(candidates: List<QuestionBankItem>, message: String) {
        val selected = varyDailyCandidates(candidates).take(targetDailyQuestionCount())
        aiDailyPlanTitle = "今日推薦任務"
        aiDailyPlanMessage = message
        aiDailyPlanItemIds = selected.map { it.id }
        completedDailyTaskItemIds.retainAll(aiDailyPlanItemIds.toSet())
        aiDailyPlanSource = "Local recommendation"
    }
    private fun renderLesson() {
        screen = Screen.Lesson
        val q = questions[currentQuestionIndex]
        shell("第 ${currentQuestionIndex + 1} 題", "完成今天下一個小關卡")
        root.addView(lessonSessionHeader(q))
        root.addView(questionCard(q))
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
        root.addView(ui.secondaryButton("我想請老師/志工幫忙") { renderHelpRequest() })
        bottomNav()
    }

    private fun answer(option: String) {
        val q = questions[currentQuestionIndex]
        if (option == q.answer) {
            val completedRecoveryTask = recoveryTaskQuestionIndex == currentQuestionIndex
            val dailyTaskItemId = questionBankItemFor(q)?.id
            if (dailyTaskItemId != null && aiDailyPlanItemIds.contains(dailyTaskItemId)) {
                completedDailyTaskItemIds.add(dailyTaskItemId)
            }
            val nextDailyTaskIndex = nextIncompleteDailyTaskQuestionIndex()
            val nextPracticeIndex = if (nextDailyTaskIndex == null) nextPracticeSessionQuestionIndex() else null
            completedTasks += 1
            confidence = (confidence + 4).coerceAtMost(100)
            learningEventCount += 1
            todayAnsweredFirstQuestion = true
            if (wrongAttempts > 0 || completedRecoveryTask) repairedMistakeCount += 1
            if (completedRecoveryTask) {
                recoveryTaskTitle = ""
                recoveryTaskDetail = ""
                recoveryTaskQuestionIndex = null
            }
            wrongAttempts = 0
            lastSelectedAnswer = option
            lastAnswerMessage = "答對了：${q.explanation}"
            currentQuestionIndex = nextDailyTaskIndex ?: nextPracticeIndex ?: ((currentQuestionIndex + 1) % questions.size)
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
            if (wrongAttempts >= 2) prepareRecoveryTask(q, option)
            addOfflineSyncItem("答題卡住：${q.concept}", "學習事件", "學生選擇 $option，需要保留修復提示。")
            persistState()
            recordLearningEvent("answer_wrong", "答題卡住：${q.concept}", "學生選擇 $option；平台保留修復提示與支持出口。")
            renderAiCoach()
        }
    }

    private fun renderSuccess(q: Question) {
        screen = Screen.Lesson
        shell("答對了", if (isDailyTaskComplete()) "今日任務完成" else "繼續下一個小關卡")
        root.addView(successSummaryCard(q))
        when {
            isDailyTaskComplete() -> {
                root.addView(dailyTaskCompletionCard())
                root.addView(ui.primaryButton("整理今天學到什麼") { renderReflection() })
                root.addView(ui.secondaryButton("自主加練一題") { renderStudentPracticeCatalog() })
                root.addView(ui.secondaryButton("回學習地圖") { renderMap() })
            }
            dailyTaskItemId(q) != null -> {
                root.addView(dailyTaskProgressCard())
                root.addView(ui.primaryButton("繼續下一題") { renderLesson() })
                root.addView(ui.secondaryButton("先看今日任務") { renderTaskQueue() })
            }
            else -> {
                root.addView(adaptiveNextStepCard(q, true))
                root.addView(ui.primaryButton("繼續練一題") { renderLesson() })
                root.addView(ui.secondaryButton("回練習中心") { renderStudentPracticeCatalog() })
            }
        }
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

    private fun prepareRecoveryTask(q: Question, selected: String) {
        recoveryTaskTitle = "補救任務：${q.concept}"
        recoveryTaskDetail = buildString {
            append("剛剛選了 $selected，先不要加新題。\n")
            append("先修復：${q.repairHint}\n")
            append("下一步：回到同一題，用正確規則再試一次。")
        }
        recoveryTaskQuestionIndex = currentQuestionIndex
        selectedPracticeLevel = "基礎暖身"
        selectedPracticeTypes = setOf(normalizedLessonType(q))
        selectedPracticeType = normalizedLessonType(q)
        aiPracticeTypeSuggestion = "建議先補：${normalizedLessonType(q)}"
        recordLearningEvent("recovery_task_created", recoveryTaskTitle, recoveryTaskDetail)
    }

    private fun startRecoveryTask() {
        recoveryTaskQuestionIndex?.let { index ->
            if (index in questions.indices) currentQuestionIndex = index
        }
        lastAnswerMessage = recoveryTaskDetail.ifBlank { "先回到剛剛卡住的概念，完成一題就算修復。" }
        renderLesson()
    }

    private fun renderReflectionSaved(prompt: ReflectionPrompt) {
        screen = Screen.Reflection
        shell("今天收尾完成", "把完成感留下來")
        val doneTitle = if (isDailyTaskComplete()) "今天的每日任務已收尾" else "今天的學習紀錄已保存"
        val doneDetail = if (isDailyTaskComplete()) {
            "你已完成今日題目，並留下 20 秒反思。今天的必要任務到這裡就可以結束。"
        } else {
            "你已留下反思紀錄。接下來可以回今日任務，把剩下的題目完成。"
        }
        root.addView(card(doneTitle, doneDetail, ColorToken.SuccessSoft))
        root.addView(card("你剛剛留下的反思", prompt.studentChoice, ColorToken.PrimarySoft))
        root.addView(card("English+ 給你的下一步", prompt.platformResponse, ColorToken.Card))
        val routeText = listOf(
            aiMapRouteSuggestion.ifBlank { "維持目前學習路線。" },
            aiPracticeTypeSuggestion.ifBlank { "題型維持原設定。" }
        ).joinToString("\n")
        root.addView(card("下次會怎麼接續", routeText, ColorToken.SuccessSoft))
        root.addView(metricRow(
            Metric("學習事件", "$learningEventCount", ColorToken.Primary),
            Metric("修復紀錄", "$repairedMistakeCount", ColorToken.Success),
            Metric("待同步", "$offlinePendingCount", if (offlinePendingCount > 0) ColorToken.Warning else ColorToken.Success)
        ))
        root.addView(ui.primaryButton(if (isDailyTaskComplete()) "回學習地圖看成果" else "回今日任務") {
            if (isDailyTaskComplete()) renderMap() else renderTaskQueue()
        })
        root.addView(ui.secondaryButton("到練習中心加練") { renderStudentPracticeCatalog() })
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
        shell("錯題詳解", "正在整理提示")
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
                    renderLocalAiCoach()
                }
            }
        }.start()
    }

    private fun renderAiCoachResult(q: Question, support: AiSupportResult) {
        screen = Screen.AiCoach
        shell("錯題提示", "看一個提示，再回去重試")
        root.addView(answerResultCard(false, q, lastSelectedAnswer))
        root.addView(card("先修一個小地方", support.studentFeedback.ifBlank { support.diagnosis }, ColorToken.SuccessSoft))
        root.addView(card("下一步", "回到同一題再試一次。答對才會推進今日任務進度；答錯不會扣分，只會再給你提示。", ColorToken.Card))
        root.addView(ui.primaryButton("回同一題重試") { renderLesson() })
        if (wrongAttempts >= 2) {
            root.addView(ui.secondaryButton("我想請人幫忙") { renderHelpRequest() })
        } else {
            root.addView(ui.secondaryButton("先回今日任務") { renderTaskQueue() })
        }
        addOfflineSyncItem("AI 錯題詳解：${q.concept}", "真 AI 錯題支持", support.handoffSummary)
        recordLearningEvent("ai_wrong_answer_support", "真 AI 錯題支持：${q.concept}", support.diagnosis)
        bottomNav()
    }

    private fun renderLocalAiCoach(notice: String? = null) {
        screen = Screen.AiCoach
        val q = questions[currentQuestionIndex]
        shell("錯題提示", "看一個提示，再回去重試")
        notice?.let { root.addView(card("先不用急", it, ColorToken.PrimarySoft)) }
        root.addView(answerResultCard(false, q, lastSelectedAnswer))
        root.addView(card("先修一個小地方", "${q.repairHint}\n\n解析：${q.explanation}", ColorToken.SuccessSoft))
        root.addView(card("下一步", "回到同一題再試一次。答對才會推進今日任務進度；答錯不會扣分，只會再給你提示。", ColorToken.Card))
        root.addView(ui.primaryButton("回同一題重試") { renderLesson() })
        if (wrongAttempts >= 2) {
            root.addView(ui.secondaryButton("我想請人幫忙") { renderHelpRequest() })
        } else {
            root.addView(ui.secondaryButton("先回今日任務") { renderTaskQueue() })
        }
        bottomNav()
    }

    private fun renderHelpRequest() {
        screen = Screen.HelpRequest
        shell("需要幫忙", "選一個最像現在狀態的選項")
        root.addView(helpIntroCard())
        helpRequestOptions.forEach { root.addView(helpOptionCard(it)) }
        root.addView(ui.primaryButton("先回同一題重試") { renderLesson() })
        root.addView(ui.secondaryButton("回今日任務") { renderTaskQueue() })
        bottomNav()
    }
    private fun handleHelpRequest(option: HelpRequestOption) {
        lastAnswerMessage = option.studentText
        preparedHelpSummary = buildPreparedHelpSummary(option)
        addOfflineSyncItem("求助摘要：${option.reason}", "老師/志工接力", preparedHelpSummary)
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
                breakpoints.add(0, Breakpoint(option.reason, "高", preparedHelpSummary, option.platformAction, "志工先肯定狀態，再用同一概念做低壓陪練。"))
                if (role == Role.Mentor) renderHandoff() else renderStudentHelpSubmitted()
            }
        }
    }

    private fun buildPreparedHelpSummary(option: HelpRequestOption? = null): String {
        val q = questions.getOrNull(currentQuestionIndex)
        val selected = lastSelectedAnswer.ifBlank { "尚未記錄選項" }
        val recovery = recoveryTaskDetail.ifBlank { "目前沒有額外補救任務；可先用一題低壓題確認概念。" }
        val route = option?.route ?: "接力"
        val reason = option?.reason ?: breakpoints.firstOrNull()?.title ?: "學生主動求助"
        val studentText = option?.studentText ?: lastAnswerMessage
        val concept = q?.concept ?: "目前題目"
        val prompt = q?.prompt ?: "尚未定位題目"
        val answer = q?.answer ?: "未記錄"
        return """
            學生：${student.name}｜班級/群組：${currentAccount().classCode}
            求助原因：$reason
            學生原話：$studentText
            分流路線：$route
            最近題目：$prompt
            概念：$concept
            學生剛剛選：$selected｜正確答案：$answer
            補救任務：$recovery
            建議接力：先肯定學生願意求助，再只帶同一概念 1-2 題，不追加新作業。
        """.trimIndent()
    }

    private fun renderBreakpoints() {
        if (role == Role.Student) {
            renderStudentRecoveryCenter()
            return
        }
        screen = Screen.Breakpoints
        shell("支持中心", "把卡關變成 English+ 可以接住的訊號")
        root.addView(card("支持原則", "連續錯題、停留過久、重複退出都不是懲罰理由，而是調整任務與安排陪伴的訊號。", ColorToken.WarningSoft))
        breakpoints.forEach { root.addView(breakpointCard(it)) }
        root.addView(ui.secondaryButton("看看平台會怎麼支持我") { renderInterventionFlow() })
        root.addView(ui.primaryButton("整理狀況給志工接力") { renderHandoff() })
        bottomNav()
    }

    private fun renderStudentRecoveryCenter() {
        screen = Screen.HelpRequest
        val q = questions.getOrNull(currentQuestionIndex)
        shell("卡住了嗎", "先看提示，再決定要不要求助")
        root.addView(card(
            "先不要換很多路線",
            "這裡只處理目前這一題。你可以看提示重試；如果已經試了好幾次，才把狀況整理給老師或志工。",
            ColorToken.PrimarySoft
        ))
        q?.let {
            root.addView(answerResultCard(false, it, lastSelectedAnswer))
            root.addView(card("現在先修這個概念", it.repairHint, ColorToken.SuccessSoft))
        }
        root.addView(ui.primaryButton("看提示後重試") { renderLesson() })
        if (wrongAttempts >= 2 || preparedHelpSummary.isNotBlank()) {
            root.addView(ui.secondaryButton("我想請人幫忙") { renderHelpRequest() })
        }
        root.addView(ui.secondaryButton("回今日任務") { renderTaskQueue() })
        bottomNav()
    }
    private fun renderStudentHelpSubmitted() {
        screen = Screen.HelpRequest
        shell("已送出求助", "你可以先回到自己的小任務")
        root.addView(card(
            "求助已整理好",
            "English+ 已把你卡住的題目、你選的答案和需要的陪伴方式整理給老師/志工。你現在不用看接力後台，可以先重試、做復原任務，或回今日任務。",
            ColorToken.SuccessSoft
        ))
        root.addView(card("你送出的內容", preparedHelpSummary, ColorToken.Card))
        root.addView(ui.primaryButton("回題目再試一次") { renderLesson() })
        root.addView(ui.secondaryButton("改做復原任務") { renderRecoveryMode() })
        root.addView(ui.secondaryButton("回今日任務") { renderTaskQueue() })
        bottomNav()
    }

    private fun renderHandoff() {
        if (role == Role.Student) {
            if (preparedHelpSummary.isBlank()) {
                renderStudentRecoveryCenter()
            } else {
                renderStudentHelpSubmitted()
            }
            return
        }
        if (isVolunteerAccount()) {
            renderVolunteerHandoffSummary()
            return
        }
        screen = Screen.Handoff
        if (preparedHelpSummary.isBlank()) preparedHelpSummary = buildPreparedHelpSummary()
        shell("接力紀錄", "把真人時間用在最需要的學生身上")
        root.addView(preparedHandoffCard())
        root.addView(card("學生摘要", "${student.name}｜${student.location}｜${student.goal}\n目前心情：${mood.label}\n今日任務時間：${minutes} 分鐘", ColorToken.PrimarySoft))
        root.addView(card("斷點摘要", "${breakpoints.first().title}\n證據：${breakpoints.first().evidence}\nAI 已做：${breakpoints.first().aiAction}", ColorToken.WarningSoft))
        root.addView(card("AI 整理交接摘要", preparedHelpSummary, ColorToken.PrimarySoft))
        root.addView(card("建議陪伴語", "你願意回來做修復任務已經很好。今天我們只看一個規則，先不追完整進度。", ColorToken.SuccessSoft))
        root.addView(card("協作狀態", "志工回覆：${mentorReplyCount} 則\n協作紀錄：${collaborationNotes.size} 筆\n待同步：${offlinePendingCount} 件", ColorToken.Card))
        root.addView(remoteCollaborationStatusCard())
        recentCollaborationNotes(3).forEach { root.addView(collaborationNoteCard(it)) }
        root.addView(ui.secondaryButton("寫入一則志工回覆") {
            mentorReplyCount += 1
            actionDoneCount = (actionDoneCount + 1).coerceAtMost(teacherActions.size)
            addCollaborationNote(
                actor = currentAccount().displayName,
                roleLabel = currentAccount().roleLabel,
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
        root.addView(studentMapPathCard())
        root.addView(studentMapNextActionCard())
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
        root.addView(aiQuestionBankLabelSummaryCard(bankItems))
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
        screen = Screen.QuestionBank
        val bankItems = stateStore.questionBankItems()
        val recommended = recommendedPracticeItems(bankItems)
        val filtered = filteredPracticeItems(bankItems).ifEmpty { recommended }
        shell("練習中心", "選一個關卡開始")
        root.addView(practiceHubHeroCard(recommended))
        root.addView(aiStudentPracticeLabelCard(recommended))
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
        filtered.take(10).forEach { root.addView(studentPracticeOptionCard(it, filtered)) }
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
            syncRecords.map { OfflineSyncItem(it.title, "同步紀錄", it.detail, it.status) }
        }.forEach { root.addView(offlineSyncItemCard(it)) }
        root.addView(ui.primaryButton("補傳 1 筆待同步紀錄") {
            addOfflineSyncItem(
                title = "手動補傳檢查",
                category = "同步紀錄",
                detail = "網路恢復後補傳最新學習紀錄。",
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
        shell("資料同步", "網路不穩時先保存，有網路再補傳")
        refreshOfflineSyncState()
        root.addView(storageStatusCard())
        root.addView(cloudBackendStatusCard())
        root.addView(smartSyncStatusCard())
        root.addView(aiSyncSummaryCard())
        root.addView(metricRow(
            Metric("待上傳", "${offlinePendingCount} 件", if (offlinePendingCount > 0) ColorToken.Warning else ColorToken.Success),
            Metric("已下載", "${downloadedPackTitles.size} 包", ColorToken.Success),
            Metric("佇列", "${offlineSyncItems.size} 筆", ColorToken.Primary)
        ))
        root.addView(card("同步策略", "學生離線時仍可完成短任務；網路恢復後，微任務、反思與志工接力摘要會補傳。", ColorToken.PrimarySoft))
        offlineSyncItems.ifEmpty {
            syncRecords.map { OfflineSyncItem(it.title, "同步紀錄", it.detail, it.status) }
        }.forEach { root.addView(offlineSyncItemCard(it)) }
        root.addView(card("本機待同步明細", "學習事件：${learningEventCount} 筆\n志工回覆：${mentorReplyCount} 則\n協作紀錄：${collaborationNotes.size} 筆\n老師新增任務：${customTaskCount} 個", ColorToken.Card))
        root.addView(ui.primaryButton("全部標記為已同步") {
            stateStore.markOfflineSyncItemsSynced()
            refreshOfflineSyncState()
            persistState()
            recordLearningEvent("sync", "本機紀錄已標記同步", "待同步數已歸零，資料仍保留在這台裝置。")
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
                else -> "雲端同步尚未開啟，已保留待補傳佇列。"
            }
            addOfflineSyncItem("智慧同步等待補傳", "真同步", reason, "待上傳")
            recordLearningEvent("smart_sync_waiting", "智慧同步等待補傳", reason)
            shell("智慧同步等待補傳", "資料仍保留在這台裝置")
            root.addView(card("同步暫停", "$reason\n\n${syncReadinessText()}", ColorToken.WarningSoft))
            offlineSyncItems.take(6).forEach { root.addView(offlineSyncItemCard(it)) }
            root.addView(ui.primaryButton("回同步中心") { renderSyncCenter() })
            bottomNav()
            return
        }

        shell("智慧同步進行中", "正在補傳本機佇列")
        root.addView(card("同步檢查通過", "網路可用\n待補傳：$offlinePendingCount 筆", ColorToken.PrimarySoft))
        root.addView(aiSyncSummaryCard())
        root.addView(card("補傳內容", "學習紀錄、協作紀錄、題庫摘要、離線佇列與目前學生狀態會一起送出。", ColorToken.Card))
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
        root.addView(card("AI 同步結論", buildAiSyncSummary(), ColorToken.SuccessSoft))
        root.addView(card("後端回應", result.responseText.ifBlank { "後端未回傳內容" }, ColorToken.Card))
        root.addView(ui.primaryButton("回同步中心") { renderSyncCenter() })
        bottomNav()
    }

    private fun renderCloudSyncProgress() {
        screen = Screen.SyncCenter
        val endpoint = stateStore.cloudBackendUrl()
        if (!stateStore.hasCloudBackend()) {
            shell("尚未開啟雲端同步", "資料仍會保留在這台裝置")
            root.addView(card("目前狀態", "雲端同步尚未開啟，因此資料會先安全保存在這台裝置。", ColorToken.WarningSoft))
            root.addView(ui.secondaryButton("回同步中心") { renderSyncCenter() })
            bottomNav()
            return
        }

        shell("正在同步雲端", "正在補傳學習與接力紀錄")
        root.addView(card("同步內容", "學習事件、協作紀錄與離線同步佇列會一起送出。", ColorToken.Card))
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
        root.addView(card("AI 同步結論", buildAiSyncSummary(), ColorToken.SuccessSoft))
        root.addView(card("同步後狀態", "待補傳：${offlinePendingCount} 件\n同步佇列：${offlineSyncItems.size} 筆", ColorToken.Card))
        root.addView(ui.primaryButton("回同步中心") { renderSyncCenter() })
        bottomNav()
    }

    private fun renderCloudSyncFailure(message: String) {
        screen = Screen.SyncCenter
        shell("雲端同步失敗", "本機資料已保留，可稍後重試")
        root.addView(card("錯誤訊息", message, ColorToken.WarningSoft))
        root.addView(card("下一步", "同步失敗不會清掉本機紀錄與待同步佇列；之後可以再重試。", ColorToken.Card))
        root.addView(card("AI 補傳建議", buildAiSyncSummary(), ColorToken.WarningSoft))
        root.addView(ui.primaryButton("回同步中心") { renderSyncCenter() })
        bottomNav()
    }

    private fun renderRoster() {
        screen = Screen.Roster
        shell("班級學生雷達", "先掃風險，再點進學生")
        root.addView(teacherRosterHeaderCard())
        section("需要先看的學生")
        currentRoster().filter { it.risk == "高" }.forEach { row -> root.addView(studentRowCard(row)) }
        section("持續追蹤")
        currentRoster().filter { it.risk == "中" }.forEach { row -> root.addView(studentRowCard(row)) }
        section("可保留自學節奏")
        currentRoster().filter { it.risk == "低" }.forEach { row -> root.addView(studentRowCard(row)) }
        root.addView(ui.primaryButton("查看接力優先序") { renderHandoffBoard() })
        root.addView(ui.secondaryButton("查看班級學習證據") { renderTeacherLearningEvidence() })
        bottomNav()
    }

    private fun renderStudentDetail(row: StudentRow) {
        screen = Screen.StudentDetail
        shell("${row.name} 的學生摘要", "判斷是否需要老師或志工介入")
        root.addView(studentDecisionHeaderCard(row))
        root.addView(relayStatusCard(row))
        root.addView(studentEvidenceTimelineCard(row))
        root.addView(teacherAiStudentSummaryCard(row))
        root.addView(studentTeacherNextStepCard(row))
        root.addView(ui.secondaryButton("回學生列表") { renderRoster() })
        bottomNav()
    }

    private fun renderHandoffBoard() {
        if (isVolunteerAccount()) {
            renderVolunteerHandoffSummary()
            return
        }
        screen = Screen.Mentor
        shell("接力優先序", "先處理最需要真人的一位")
        root.addView(mentorHandoffHeaderCard())
        root.addView(teacherAiBriefingCard())
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
        if (isVolunteerAccount()) {
            renderVolunteerRecord()
            return
        }
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
        root.addView(teacherAiBriefingCard())
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

    private fun renderVolunteerHandoffSummary() {
        screen = Screen.Handoff
        val target = volunteerTargetStudent()
        if (preparedHelpSummary.isBlank()) preparedHelpSummary = buildPreparedHelpSummary()
        latestTeacherAiSummary = buildTeacherAiSummary(target)
        latestVolunteerDraft = buildVolunteerReplyDraft(target)
        shell("接力摘要", "先看懂學生，再開始陪伴")
        root.addView(volunteerStepHeaderCard("第 1 步", "看懂今天要陪誰", "不用看完整後台，只要抓住學生卡在哪裡。"))
        root.addView(relayStatusCard(target))
        root.addView(card("學生狀況", "${target.name}｜${target.issue}\n${target.status}", ColorToken.WarningSoft))
        root.addView(card("老師整理給你的重點", latestTeacherAiSummary.lineSequence().take(4).joinToString("\n"), ColorToken.PrimarySoft))
        root.addView(card("可以直接說的第一句", latestVolunteerDraft, ColorToken.SuccessSoft))
        root.addView(flowStrip("看摘要", "照腳本陪練", "回填一句", "完成接力"))
        root.addView(ui.primaryButton("開始陪伴腳本") { renderMentorScript() })
        root.addView(ui.secondaryButton("先回志工首頁") { renderHome() })
        bottomNav()
    }

    private fun renderVolunteerRecord() {
        screen = Screen.ActionQueue
        val target = volunteerTargetStudent()
        shell("回填接力紀錄", "完成後老師就能接續追蹤")
        root.addView(volunteerStepHeaderCard("第 3 步", "留下今天陪伴結果", "不用寫長報告，只要讓下一位老師知道學生現在到哪裡。"))
        root.addView(relayStatusCard(target))
        root.addView(card("建議回填內容", "已陪 ${target.name} 看同一個概念 1-2 題；先肯定願意求助，沒有追加新作業。", ColorToken.PrimarySoft))
        root.addView(metricRow(
            Metric("志工回覆", "$mentorReplyCount", ColorToken.Success),
            Metric("協作紀錄", "${collaborationNotes.size}", ColorToken.Primary),
            Metric("待同步", "$offlinePendingCount", if (offlinePendingCount > 0) ColorToken.Warning else ColorToken.Success)
        ))
        root.addView(ui.primaryButton(if (isRelayCompleted(target)) "已完成，更新紀錄" else "完成接力並寫入紀錄") {
            completeVolunteerRelay(target)
        })
        if (isRelayCompleted(target)) {
            root.addView(card("已完成", "這次接力已留下紀錄。你可以同步資料，或回首頁等待下一位學生。", ColorToken.SuccessSoft))
        }
        root.addView(ui.secondaryButton("同步紀錄") { renderSyncCenter() })
        root.addView(ui.secondaryButton("回志工首頁") { renderHome() })
        bottomNav()
    }

    private fun renderRemoteCollaborationSync(pushFirst: Boolean) {
        screen = Screen.ActionQueue
        if (!stateStore.hasCloudBackend()) {
            shell("雲端協作尚未開啟", "協作紀錄會先保留在這台裝置")
            root.addView(card("目前狀態", "雲端協作尚未開啟時，老師與志工仍可先用本機紀錄接力。", ColorToken.WarningSoft))
            root.addView(ui.secondaryButton("回接力優先序") { renderHandoffBoard() })
            bottomNav()
            return
        }

        shell("同步多人協作", if (pushFirst) "先送出本機協作，再更新最新紀錄" else "正在更新最新協作紀錄")
        root.addView(card("同步班級", currentAccount().classCode, ColorToken.Card))
        root.addView(card(
            "同步規則",
            "同一筆接力紀錄若在不同裝置更新，系統會保留最新版本。學生端不會建立老師接力紀錄，老師與志工端可以回填。",
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
        root.addView(card("下一步", "協作同步失敗時，老師與志工仍可先用本機紀錄接力；等網路恢復後再同步。", ColorToken.Card))
        root.addView(ui.primaryButton("回接力優先序") { renderHandoffBoard() })
        bottomNav()
    }

    private fun renderStudentManager() {
        screen = Screen.StudentManager
        shell("學生資料管理", "新增學生、分組與追蹤狀態")
        root.addView(classContextCard())
        root.addView(metricRow(
            Metric("管理學生", "${managedStudentCount} 位", ColorToken.Primary),
            Metric("高風險", "1 位", ColorToken.Danger),
            Metric("已處理待辦", "${actionDoneCount} 件", ColorToken.Success)
        ))
        root.addView(card("管理方式", "老師可以先新增學生、切換追蹤狀態，並查看需要接力的學習紀錄。", ColorToken.PrimarySoft))
        currentRoster().forEach { root.addView(studentRowCard(it)) }
        root.addView(ui.primaryButton("新增 1 位學生") {
            managedStudentCount += 1
            addOfflineSyncItem("新增學生", "老師端資料", "新增學生後需同步到班級學生名單。")
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
        if (role == Role.Student) {
            renderStudentTaskEntry()
        } else {
            renderRoster()
        }
    }

    private fun renderDeveloperAiLab() {
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
        root.addView(ui.secondaryButton("改用本機備援生成") { renderGeneratedAiFeedback() })
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
                "目前不會連線到外部 AI。你可以先用本機備援，或在下方貼上 OpenRouter API Key 後啟用真 AI。"
            }
        ))
        return ui.margins(box, 0, 8, 0, 12)
    }
    private fun aiProxyEndpointCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label("AI Proxy 端點", 18, ColorToken.Ink, true))
        box.addView(ui.body("可用後端代理保存正式 Key。手機只送學習脈絡到 HTTPS API，不直接持有正式 Key。"))
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
            recordLearningEvent("ai_proxy_config", "已清除 AI Proxy 端點", "AI 實驗室會回到本機 Key 或本機備援。")
            renderAiLab()
        })
        return ui.margins(box, 0, 0, 0, 12)
    }

    private fun openRouterKeyEntryCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label("OpenRouter Key 設定", 18, ColorToken.Ink, true))
        box.addView(ui.body("Key 只存在這台裝置私人設定，不會寫進程式碼。貼上後，APP 會優先使用 OpenRouter 產生 AI 回覆。"))
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
        box.addView(ui.body("Key 只會存在這台裝置的私人設定中，不會寫進程式碼。暫時留空時，系統會使用本機備援。"))

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
        box.addView(ui.secondaryButton("清除 Key，改用本機備援") {
            stateStore.saveOpenAiApiKey("")
            recordLearningEvent("ai_config", "已清除 OpenAI API Key", "AI 提示實驗室已回到本機備援模式。")
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
            recordLearningEvent("ai_local", "本機 AI 備援回饋", aiDiagnosis(q))
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
        val target = volunteerTargetStudent()
        shell(if (isVolunteerAccount()) "陪伴腳本" else "志工陪伴腳本", if (isVolunteerAccount()) "照三步走，不追加壓力" else "降低志工準備成本，也避免學生被再次打擊")
        if (isVolunteerAccount()) {
            root.addView(volunteerStepHeaderCard("第 2 步", "陪 ${target.name} 修一個小概念", "今天不用教完整單元，只要陪學生回到題目。"))
        }
        root.addView(card("開場 30 秒", "先肯定：你願意回來做修復任務已經很好。今天我們只看一個規則，不看整章。", ColorToken.SuccessSoft))
        root.addView(card("引導問題", "1. He 是一個人還是很多人？\n2. 一個人通常搭配 is 還是 are？\n3. 你可以自己造一句 He is 嗎？", ColorToken.PrimarySoft))
        root.addView(card("結束紀錄", "能完成 2 題再加 They are；如果仍卡住，記錄為高優先斷點，不追加作業。", ColorToken.WarningSoft))
        root.addView(ui.primaryButton(if (isVolunteerAccount()) "已陪完，去回填紀錄" else "使用腳本並留下志工紀錄") {
            if (!isVolunteerAccount()) {
                mentorReplyCount += 1
            }
            addCollaborationNote(
                actor = currentAccount().displayName,
                roleLabel = currentAccount().roleLabel,
                target = target.name,
                note = "已使用陪伴腳本完成一次低壓接力；學生能先回答 He is，暫不加新題型。",
                status = if (isVolunteerAccount()) "陪伴中" else "腳本已用"
            )
            if (isVolunteerAccount()) renderVolunteerRecord() else renderMentorScript()
        })
        root.addView(ui.secondaryButton(if (isVolunteerAccount()) "回志工首頁" else "回老師工作台") {
            role = Role.Mentor
            renderHome()
        })
        bottomNav()
    }

    private fun renderWeeklyReport() {
        screen = Screen.Report
        shell("老師週報", "用可行動證據整理班級狀態")
        refreshOfflineSyncState()
        root.addView(teacherWeeklySummaryCard())
        root.addView(teacherWeeklyAttentionCard())
        root.addView(teacherWeeklyBreakpointCard())
        root.addView(teacherWeeklyRelayCard())
        root.addView(teacherWeeklySyncCard())
        section("最新接力紀錄")
        recentCollaborationNotes(4).forEach { root.addView(collaborationNoteCard(it)) }
        root.addView(ui.primaryButton("匯出老師週報") { renderExportReport() })
        root.addView(ui.secondaryButton("分享文字週報") { shareTeacherReport(buildDemoReportText()) })
        bottomNav()
    }

    private fun renderExportReport() {
        screen = Screen.Report
        refreshOfflineSyncState()
        val reportText = buildDemoReportText()
        val file = writeDemoReport(reportText)
        shell("老師週報已產生", "可分享給老師或列印成會議紀錄")
        root.addView(card("匯出檔案", file.absolutePath, ColorToken.SuccessSoft))
        root.addView(card("報告內容預覽", reportText, ColorToken.Card))
        root.addView(ui.primaryButton("分享文字週報") { shareTeacherReport(reportText) })
        root.addView(ui.secondaryButton("回老師週報") { renderWeeklyReport() })
        bottomNav()
    }

    private fun renderMentorChecks() {
        screen = Screen.Report
        shell("產品檢核", "確認 English+ 是否符合接力學習目標")
        root.addView(card("檢核目的", "這裡用來確認老師、志工與學生流程是否真的能接住卡關狀態。一般使用時可以直接回週報。", ColorToken.PrimarySoft))
        root.addView(reportShowcaseCard())
        mentorChecks.forEach { root.addView(mentorCheckCard(it)) }
        root.addView(card("下一步", "最需要驗證的是：志工是否能根據摘要直接陪學生、老師是否能用週報安排下週追蹤、學生是否願意回到低壓任務。", ColorToken.WarningSoft))
        root.addView(ui.primaryButton("回老師週報") { renderWeeklyReport() })
        bottomNav()
    }

    private fun reportShowcaseCard(): View {
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.statusPill("English+ 檢核", ColorToken.Primary))
        box.addView(ui.label("學生、老師、志工三端已可串接", 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(
            "目前重點不是排名或刷題量，而是學生卡住時能被辨識、被支持，並交給老師或志工低壓接力。"
        ))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun teacherWeeklySummaryCard(): View {
        val highRisk = currentRoster().count { it.risk == "高" }
        val middleRisk = currentRoster().count { it.risk == "中" }
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Primary)
        box.addView(ui.statusPill("本週總覽", ColorToken.Primary))
        box.addView(ui.label("先看需要接住的學生", 22, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("這份週報不排序學生，只整理老師下週要追蹤的訊號。", "#334155"))
        box.addView(metricRow(
            Metric("高風險", "$highRisk 位", if (highRisk > 0) ColorToken.Danger else ColorToken.Success),
            Metric("追蹤", "$middleRisk 位", ColorToken.Warning),
            Metric("已接力", "$mentorReplyCount 次", ColorToken.Success)
        ))
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun teacherWeeklyAttentionCard(): View {
        val target = currentRoster().firstOrNull { it.risk == "高" } ?: currentRoster().first()
        val (stage, stageColor, detail) = relayStage(target)
        val box = ui.container(if (target.risk == "高") ColorToken.WarningSoft else ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("優先學生", teacherRiskColor(target.risk)))
        box.addView(ui.label("${target.name}｜${target.issue}", 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("目前狀態：${target.status}", "#334155"))
        box.addView(ui.body("接力狀態：$stage。$detail", stageColor).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        box.addView(ui.primaryButton("查看學生摘要") { renderStudentDetail(target) })
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun teacherWeeklyBreakpointCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("錯題與斷點", ColorToken.Warning))
        box.addView(ui.label("下週先修這些，不加總題量", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(evidenceLine("主要斷點", breakpoints.first().title, ColorToken.Warning))
        box.addView(evidenceLine("錯題修復", "$repairedMistakeCount 筆", ColorToken.Success))
        box.addView(evidenceLine("信心狀態", "$confidence%", if (confidence < 45) ColorToken.Warning else ColorToken.Success))
        box.addView(ui.body("建議：下週先維持短任務，從同一概念 1 組題開始，不要一次混合太多題型。", "#334155").apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun teacherWeeklyRelayCard(): View {
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Success)
        box.addView(ui.statusPill("志工接力", ColorToken.Success))
        box.addView(ui.label(if (mentorReplyCount > 0) "本週已有接力紀錄" else "本週還需要安排一次接力", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("志工回覆", "$mentorReplyCount", ColorToken.Success),
            Metric("協作紀錄", "${collaborationNotes.size}", ColorToken.Primary),
            Metric("待辦完成", "$actionDoneCount", ColorToken.Warning)
        ))
        box.addView(ui.body(
            if (mentorReplyCount > 0) {
                "接力已有回填。老師下週要確認學生是否真的回到任務，而不是只看是否有人回覆。"
            } else {
                "目前真人接力紀錄不足，建議先把第一優先學生交給志工低壓陪練。"
            },
            "#334155"
        ).apply { setPadding(0, ui.dp(8), 0, 0) })
        box.addView(ui.secondaryButton("查看接力板") { renderHandoffBoard() })
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun teacherWeeklySyncCard(): View {
        val ready = offlinePendingCount == 0
        val box = ui.container(if (ready) ColorToken.SuccessSoft else ColorToken.WarningSoft, if (ready) ColorToken.Success else ColorToken.Warning)
        box.addView(ui.statusPill("週報資料狀態", if (ready) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label(if (ready) "資料已可整理週報" else "週報前先同步資料", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(buildAiSyncSummary(), "#334155"))
        box.addView(ui.secondaryButton("前往同步中心") { renderSyncCenter() })
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun aiWeeklyReportCard(): View {
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Success)
        box.addView(ui.statusPill("AI 週報判讀", ColorToken.Success))
        box.addView(ui.label("本週不是看排名，而是看有沒有被接住", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(buildAiWeeklyReportSummary(), "#334155"))
        box.addView(metricRow(
            Metric("修復", "$repairedMistakeCount 筆", ColorToken.Success),
            Metric("接力", "${collaborationNotes.size} 筆", ColorToken.Primary),
            Metric("待同步", "$offlinePendingCount 筆", if (offlinePendingCount > 0) ColorToken.Warning else ColorToken.Success)
        ))
        box.addView(ui.secondaryButton("匯出含 AI 判讀的週報") { renderExportReport() })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun aiSyncSummaryCard(): View {
        val ready = isNetworkAvailable() && stateStore.hasCloudBackend()
        val box = ui.container(if (ready) ColorToken.SuccessSoft else ColorToken.WarningSoft, ColorToken.Border)
        box.addView(ui.statusPill("AI 同步摘要", if (ready) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label(if (ready) "可以補傳，資料可交給雲端接手" else "先保留，之後再補傳", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(buildAiSyncSummary(), "#334155"))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun buildAiWeeklyReportSummary(): String {
        val progressTone = when {
            confidence >= 70 -> "學生已能承受較高挑戰，下週可加入閱讀或克漏字任務。"
            confidence >= 45 -> "學生目前適合維持短任務節奏，下週先把 A2 基準題型做穩。"
            else -> "學生信心偏低，下週應先用補救任務與真人接力降低挫折。"
        }
        val relayTone = if (collaborationNotes.isNotEmpty() || mentorReplyCount > 0) {
            "真人接力已有紀錄，建議老師追蹤回覆是否真的讓學生回到任務。"
        } else {
            "目前真人接力紀錄不足，建議至少安排一次志工低壓陪練。"
        }
        val syncTone = if (offlinePendingCount > 0) {
            "仍有 $offlinePendingCount 筆待補傳資料，週報前應先同步，避免老師看到舊狀態。"
        } else {
            "目前沒有待補傳資料，週報可視為本機最新狀態。"
        }
        return """
            學習判讀：$progressTone
            接力判讀：$relayTone
            同步判讀：$syncTone
            下週建議：先保留心情檢測與短任務，再依錯題補救紀錄選 1 組題型，不用增加總題量。
        """.trimIndent()
    }

    private fun buildAiSyncSummary(): String {
        val network = if (isNetworkAvailable()) "網路可用" else "網路不可用"
        val backend = if (stateStore.hasCloudBackend()) "雲端同步已開啟" else "雲端同步尚未開啟"
        val newest = offlineSyncItems.firstOrNull()?.let { "${it.title}（${it.status}）" } ?: "沒有待處理佇列"
        val action = when {
            offlinePendingCount == 0 -> "目前可先不用補傳；若剛匯出週報，建議再同步一次報告紀錄。"
            isNetworkAvailable() && stateStore.hasCloudBackend() -> "可以按智慧同步，把學習事件、AI 摘要與協作紀錄補傳。"
            !isNetworkAvailable() -> "先保留在這台裝置，等網路恢復後再補傳。"
            else -> "先確認雲端同步已開啟，再進行補傳。"
        }
        return """
            狀態：$network｜$backend
            待補傳：$offlinePendingCount 筆｜佇列：${offlineSyncItems.size} 筆
            最新項目：$newest
            建議動作：$action
        """.trimIndent()
    }

    private fun buildDemoReportText(): String {
        val snapshot = stateStore.storageSnapshot()
        val latestCollaboration = collaborationNotes.firstOrNull()?.note ?: "尚未建立真人接力紀錄。"
        val latestSync = offlineSyncItems.firstOrNull()?.let { "${it.title} / ${it.status}" } ?: "尚未建立同步佇列。"
        val aiWeeklyReport = buildAiWeeklyReportSummary()
        val aiSyncSummary = buildAiSyncSummary()
        val priorityStudent = currentRoster().firstOrNull { it.risk == "高" } ?: currentRoster().first()
        val highRiskCount = currentRoster().count { it.risk == "高" }
        val middleRiskCount = currentRoster().count { it.risk == "中" }
        val lowRiskCount = currentRoster().count { it.risk == "低" }
        val (relayStageLabel, _, relayStageDetail) = relayStage(priorityStudent)
        return """
            English+ 老師週報

            一、班級總覽
            班級/群組：${currentAccount().classCode}
            管理學生：${currentRoster().size} 位
            高風險：$highRiskCount 位
            持續追蹤：$middleRiskCount 位
            可自學：$lowRiskCount 位
            微任務完成：${completedTasks} 個
            錯題修復：${repairedMistakeCount} 筆
            學習事件：${snapshot.eventCount} 筆

            二、第一優先學生
            學生：${priorityStudent.name}
            斷點：${priorityStudent.issue}
            狀態：${priorityStudent.status}
            接力狀態：$relayStageLabel
            接力說明：$relayStageDetail

            三、學生狀態與任務資料
            目前示範學生：${student.name} / ${student.location} / ${student.goal}
            心情狀態：${mood.label}
            今日任務時間：${minutes} 分鐘
            信心值：${confidence}%
            已下載離線包：${snapshot.downloadedPackCount} 包

            四、AI 週報判讀
            $aiWeeklyReport

            五、錯題與情緒斷點
            目前主要斷點：${breakpoints.first().title}
            斷點證據：${breakpoints.first().evidence}
            AI 已做處理：${breakpoints.first().aiAction}
            真人接力建議：${breakpoints.first().mentorAction}

            六、最新接力與同步
            協作紀錄：${snapshot.collaborationCount} 筆
            志工回覆：$mentorReplyCount 次
            待補傳同步：${snapshot.pendingSyncCount} 筆
            最新協作：$latestCollaboration
            最新同步項目：$latestSync
            AI 同步判讀：$aiSyncSummary

            七、下週老師建議
            1. 先確認第一優先學生是否真的回到任務。
            2. 不增加總題量，先從同一概念 1 組題修復。
            3. 若接力尚未完成，先安排志工低壓陪練。
            4. 週報前先同步待補傳資料，避免老師看到舊狀態。
        """.trimIndent()
    }

    private fun writeDemoReport(reportText: String): File {
        val targetDir = getExternalFilesDir(null) ?: filesDir
        val file = File(targetDir, "english_plus_teacher_weekly_report.txt")
        file.writeText(reportText, Charsets.UTF_8)
        writeDemoReportHtml(reportText)
        recordLearningEvent("report_export", "已匯出老師週報", file.absolutePath)
        addOfflineSyncItem("老師週報匯出", "報告資料", "已產生 english_plus_teacher_weekly_report.txt，可上傳到雲端或分享給老師。")
        return file
    }

    private fun writeDemoReportHtml(reportText: String): File {
        val targetDir = getExternalFilesDir(null) ?: filesDir
        val file = File(targetDir, "english_plus_teacher_weekly_report.html")
        file.writeText(buildDemoReportHtml(reportText), Charsets.UTF_8)
        recordLearningEvent("report_export_html", "已匯出 HTML 老師週報", file.absolutePath)
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
              <div class="note">此 HTML 可由瀏覽器列印成 PDF，也可整理成 PDF、Word 或老師後台報表。</div>
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
        bottomNavAttached = false
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

    private fun teacherTodayOverviewCard(): View {
        val roster = currentRoster()
        val highRisk = roster.count { it.risk == "高" }
        val middleRisk = roster.count { it.risk == "中" }
        val pending = (teacherActions.size - actionDoneCount).coerceAtLeast(0)
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Primary)
        box.addView(ui.statusPill("老師今日工作台", ColorToken.Primary))
        box.addView(ui.label("今天先接住 $highRisk 位學生", 24, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("先處理高風險，再看待辦；穩定學生不用打斷他的練習節奏。", "#334155"))
        box.addView(metricRow(
            Metric("高風險", "$highRisk 位", if (highRisk > 0) ColorToken.Danger else ColorToken.Success),
            Metric("追蹤", "$middleRisk 位", ColorToken.Warning),
            Metric("待辦", "$pending 件", if (pending > 0) ColorToken.Warning else ColorToken.Success)
        ))
        box.addView(flowStrip("看第一優先", "分派接力", "確認紀錄", "整理週報"))
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun teacherFirstPriorityCard(): View {
        val target = currentRoster().firstOrNull { it.risk == "高" } ?: currentRoster().first()
        latestTeacherAiSummary = buildTeacherAiSummary(target)
        latestVolunteerDraft = buildVolunteerReplyDraft(target)
        val box = ui.container(ColorToken.WarningSoft, ColorToken.Warning)
        box.addView(ui.statusPill("第一優先學生", if (target.risk == "高") ColorToken.Danger else ColorToken.Warning))
        box.addView(ui.label("${target.name}｜${target.issue}", 21, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("狀態：${target.status}", "#334155"))
        box.addView(ui.body("老師下一步：先看摘要，再決定是否交給志工接力。", ColorToken.Danger).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        val (stage, stageColor, _) = relayStage(target)
        box.addView(ui.body("目前接力狀態：$stage", stageColor).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        box.addView(ui.primaryButton("查看學生摘要") { renderStudentDetail(target) })
        box.addView(ui.secondaryButton("交給志工接力") {
            addAiHandoffCollaborationNote(target)
            renderHandoffBoard()
        })
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun teacherClassPulseCard(): View {
        val roster = currentRoster()
        val stable = roster.count { it.risk == "低" }
        val needsRelay = roster.count { it.risk == "高" }
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("班級狀態", ColorToken.Accent))
        box.addView(ui.label("先看訊號，不先看分數", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("可自學", "$stable 位", ColorToken.Success),
            Metric("需接力", "$needsRelay 位", if (needsRelay > 0) ColorToken.Danger else ColorToken.Success),
            Metric("同步", "$offlinePendingCount 件", if (offlinePendingCount > 0) ColorToken.Warning else ColorToken.Success)
        ))
        weeklySignals.take(2).forEach { signal ->
            box.addView(timelineCard(signal.label, "${signal.value}｜${signal.note}", signal.color))
        }
        box.addView(ui.secondaryButton("查看全部學生") { renderRoster() })
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun teacherWorkQueueCard(): View {
        val pending = (teacherActions.size - actionDoneCount).coerceAtLeast(0)
        val nextAction = teacherActions.getOrNull(actionDoneCount)
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Success)
        box.addView(ui.statusPill("下一步", ColorToken.Success))
        box.addView(ui.label(if (nextAction == null) "今天待辦已清空" else nextAction.title, 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(
            if (nextAction == null) {
                "可以整理週報，或回學生列表查看是否有新的接力訊號。"
            } else {
                "${nextAction.owner}｜${nextAction.due}\n${nextAction.nextStep}"
            },
            "#334155"
        ))
        box.addView(metricRow(
            Metric("待辦", "$pending 件", if (pending > 0) ColorToken.Warning else ColorToken.Success),
            Metric("已處理", "$actionDoneCount 件", ColorToken.Success),
            Metric("協作", "${collaborationNotes.size} 筆", ColorToken.Primary)
        ))
        box.addView(ui.primaryButton(if (nextAction == null) "查看週報" else "處理待辦") {
            if (nextAction == null) renderWeeklyReport() else renderActionQueue()
        })
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun teacherReportShortcutCard(): View {
        val box = ui.container(ColorToken.Surface, ColorToken.Border)
        box.addView(ui.statusPill("週報準備", ColorToken.Primary))
        box.addView(ui.label("把今天的接力變成可追蹤紀錄", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("週報會整理班級訊號、學生斷點、志工回覆與待同步資料，方便下一位老師接續。", "#334155"))
        box.addView(actionGrid(
            ActionItem("學生證據", "看風險") { renderRoster() },
            ActionItem("接力板", "分派志工") { renderHandoffBoard() },
            ActionItem("同步", "補傳紀錄") { renderSyncCenter() },
            ActionItem("週報", "整理輸出") { renderWeeklyReport() }
        ))
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun volunteerTargetStudent(): StudentRow {
        return currentRoster().firstOrNull { it.risk == "高" } ?: currentRoster().first()
    }

    private fun relayNotesFor(row: StudentRow): List<CollaborationNote> {
        return collaborationNotes.filter {
            it.target == row.name || it.note.contains(row.name)
        }
    }

    private fun isRelayCompleted(row: StudentRow): Boolean {
        return relayNotesFor(row).any {
            it.status.contains("已回填") || it.status.contains("已完成") || it.status.contains("已回覆")
        }
    }

    private fun relayStage(row: StudentRow): Triple<String, String, String> {
        val notes = relayNotesFor(row)
        return when {
            isRelayCompleted(row) -> Triple("已完成", ColorToken.Success, "志工已回填紀錄，老師可以接續追蹤或整理週報。")
            notes.any { it.status.contains("陪伴中") || it.status.contains("腳本已用") } ->
                Triple("陪伴中", ColorToken.Primary, "志工已開始使用腳本，下一步是回填接力結果。")
            notes.any { it.status.contains("已指派") || it.status.contains("AI 接力摘要") } ->
                Triple("已指派", ColorToken.Warning, "老師已整理摘要，等待志工看摘要並開始陪伴。")
            else -> Triple("未指派", ColorToken.Danger, "尚未建立接力紀錄，老師需要先指派或生成摘要。")
        }
    }

    private fun relayStatusCard(row: StudentRow): View {
        val (label, color, detail) = relayStage(row)
        val box = ui.container(if (label == "已完成") ColorToken.SuccessSoft else if (label == "未指派") ColorToken.WarningSoft else ColorToken.PrimarySoft, color)
        box.addView(ui.statusPill("接力狀態：$label", color))
        box.addView(ui.label(row.name, 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(detail, "#334155"))
        box.addView(metricRow(
            Metric("志工回覆", "$mentorReplyCount", ColorToken.Success),
            Metric("協作紀錄", "${relayNotesFor(row).size}", ColorToken.Primary),
            Metric("待同步", "$offlinePendingCount", if (offlinePendingCount > 0) ColorToken.Warning else ColorToken.Success)
        ))
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun completeVolunteerRelay(row: StudentRow) {
        if (!isRelayCompleted(row)) {
            mentorReplyCount += 1
            actionDoneCount = (actionDoneCount + 1).coerceAtMost(teacherActions.size)
        }
        addCollaborationNote(
            actor = currentAccount().displayName,
            roleLabel = currentAccount().roleLabel,
            target = row.name,
            note = "已完成一次低壓接力：先肯定學生願意求助，再陪練同一概念 1-2 題，未追加新作業。",
            status = "志工已回填"
        )
        addOfflineSyncItem("志工回填：${row.name}", "志工接力", "已完成低壓接力並回填紀錄。")
        persistState()
        renderVolunteerRecord()
    }

    private fun volunteerStepHeaderCard(step: String, title: String, detail: String): View {
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Primary)
        box.addView(ui.statusPill(step, ColorToken.Primary))
        box.addView(ui.label(title, 22, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(detail, "#334155"))
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun studentDecisionHeaderCard(row: StudentRow): View {
        val riskColor = teacherRiskColor(row.risk)
        val decision = when (row.risk) {
            "高" -> "今天需要真人接力"
            "中" -> "本週追蹤，不急著加題"
            else -> "保留自學節奏"
        }
        val box = ui.container(if (row.risk == "高") ColorToken.WarningSoft else ColorToken.PrimarySoft, riskColor)
        box.addView(ui.statusPill("老師判斷", riskColor))
        box.addView(ui.label(decision, 23, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("${row.name}｜${row.issue}", "#334155"))
        box.addView(metricRow(
            Metric("風險", row.risk, riskColor),
            Metric("狀態", if (row.risk == "低") "可自學" else "需追蹤", ColorToken.Primary),
            Metric("接力", if (row.risk == "高") "今日" else "本週", ColorToken.Success)
        ))
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun studentEvidenceTimelineCard(row: StudentRow): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("學習證據", ColorToken.Primary))
        box.addView(ui.label("只看會影響下一步的證據", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(evidenceLine("最新狀態", row.status, teacherRiskColor(row.risk)))
        box.addView(evidenceLine("目前斷點", row.issue, if (row.risk == "高") ColorToken.Warning else ColorToken.Primary))
        box.addView(evidenceLine("最近任務", studyTasks.first().title, ColorToken.Success))
        box.addView(metricRow(
            Metric("答題事件", "$learningEventCount", ColorToken.Primary),
            Metric("錯題修復", "$repairedMistakeCount", ColorToken.Success),
            Metric("信心", "$confidence%", if (confidence < 45) ColorToken.Warning else ColorToken.Success)
        ))
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun evidenceLine(label: String, value: String, color: String): View {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(0, ui.dp(8), 0, ui.dp(8))
        }
        row.addView(ui.statusPill(label, color))
        row.addView(ui.body(value, "#334155").apply {
            setPadding(ui.dp(10), 0, 0, 0)
        }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        return row
    }

    private fun studentTeacherNextStepCard(row: StudentRow): View {
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Success)
        box.addView(ui.statusPill("老師下一步", ColorToken.Success))
        box.addView(ui.label(
            if (row.risk == "高") "派一位志工低壓接力" else "保留學生目前節奏",
            19,
            ColorToken.Ink,
            true
        ).apply { setPadding(0, ui.dp(10), 0, ui.dp(4)) })
        box.addView(ui.body(
            if (row.risk == "高") {
                "先用陪伴腳本降低挫折，再只帶同一概念 1-2 題；不要追加新作業。"
            } else {
                "先觀察是否願意回來完成任務；若狀態下降，再轉入接力。"
            },
            "#334155"
        ))
        box.addView(actionGrid(
            ActionItem("陪伴腳本", "交給志工") { renderMentorScript() },
            ActionItem("接力紀錄", "寫入摘要") {
                addAiHandoffCollaborationNote(row)
                renderHandoffBoard()
            },
            ActionItem("待辦", "查看派工") { renderActionQueue() },
            ActionItem("回列表", "看其他學生") { renderRoster() }
        ))
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun teacherAiBriefingCard(): View {
        val roster = currentRoster()
        val firstHighRisk = roster.firstOrNull { it.risk == "高" } ?: roster.first()
        val pending = (teacherActions.size - actionDoneCount).coerceAtLeast(0)
        latestTeacherAiSummary = buildTeacherAiSummary(firstHighRisk)
        latestVolunteerDraft = buildVolunteerReplyDraft(firstHighRisk)
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Success)
        box.addView(ui.statusPill("AI 接力摘要", ColorToken.Success))
        box.addView(ui.label("今天先處理：${firstHighRisk.name}", 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(latestTeacherAiSummary, "#334155"))
        box.addView(metricRow(
            Metric("待辦", "$pending 件", if (pending > 0) ColorToken.Warning else ColorToken.Success),
            Metric("協作", "${collaborationNotes.size} 筆", ColorToken.Primary),
            Metric("補救", "$repairedMistakeCount 筆", ColorToken.Accent)
        ))
        box.addView(ui.secondaryButton("查看這位學生") { renderStudentDetail(firstHighRisk) })
        box.addView(ui.secondaryButton("存成接力紀錄") {
            addAiHandoffCollaborationNote(firstHighRisk)
            renderHandoffBoard()
        })
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun volunteerFocusCard(): View {
        val target = volunteerTargetStudent()
        latestTeacherAiSummary = buildTeacherAiSummary(target)
        latestVolunteerDraft = buildVolunteerReplyDraft(target)
        val box = ui.container(ColorToken.WarningSoft, ColorToken.Warning)
        box.addView(ui.statusPill("志工今日任務", ColorToken.Warning))
        box.addView(ui.label("先陪 ${target.name} 完成一小步", 23, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("你不需要管理整個班級。先看學生卡住哪裡，再用低壓語句陪他回到題目。", "#334155"))
        box.addView(metricRow(
            Metric("學生", target.name, ColorToken.Primary),
            Metric("風險", target.risk, if (target.risk == "高") ColorToken.Danger else ColorToken.Warning),
            Metric("回填", "${mentorReplyCount} 則", ColorToken.Success)
        ))
        box.addView(ui.primaryButton("先看接力摘要") { renderVolunteerHandoffSummary() })
        box.addView(ui.secondaryButton("先看學生摘要") { renderStudentDetail(target) })
        return ui.margins(box, 0, 8, 0, 14)
    }

    private fun volunteerScriptPreviewCard(): View {
        val target = volunteerTargetStudent()
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.statusPill("陪伴腳本", ColorToken.Primary))
        box.addView(ui.label("照這三步走就好", 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(flowStrip("肯定願意求助", "只看同一概念", "回填一句紀錄"))
        box.addView(ui.body(buildVolunteerReplyDraft(target), "#334155").apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        box.addView(ui.secondaryButton("打開完整腳本") { renderMentorScript() })
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun volunteerActionEntrancesCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("志工入口", ColorToken.Success))
        box.addView(ui.label("今天只處理陪伴相關的事", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(6))
        })
        box.addView(actionGrid(
            ActionItem("接力摘要", "看學生狀況") { renderVolunteerHandoffSummary() },
            ActionItem("陪伴腳本", "照步驟回覆") { renderMentorScript() },
            ActionItem("回填紀錄", "完成接力") { renderVolunteerRecord() },
            ActionItem("同步紀錄", "補傳回覆") { renderSyncCenter() }
        ))
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun volunteerCompletionCard(): View {
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Success)
        box.addView(ui.statusPill("完成標準", ColorToken.Success))
        box.addView(ui.label("今天不用做更多管理", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("完成一次接力後，只要留下學生狀態與下一步。班級統計、題庫與週報交給老師端處理。", "#334155"))
        box.addView(ui.secondaryButton("查看我的接力紀錄") { renderVolunteerRecord() })
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun teacherAiStudentSummaryCard(row: StudentRow): View {
        val summary = buildTeacherAiSummary(row)
        val draft = buildVolunteerReplyDraft(row)
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.statusPill("AI 判讀", if (row.risk == "高") ColorToken.Warning else ColorToken.Primary))
        box.addView(ui.label("老師/志工看這段就能接手", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(summary, "#334155"))
        box.addView(ui.divider())
        box.addView(ui.label("志工可直接回覆", 16, ColorToken.Ink, true))
        box.addView(ui.body(draft, ColorToken.Success).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        box.addView(ui.secondaryButton("把摘要寫入協作紀錄") {
            latestTeacherAiSummary = summary
            latestVolunteerDraft = draft
            addAiHandoffCollaborationNote(row)
            renderStudentDetail(row)
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun buildTeacherAiSummary(row: StudentRow): String {
        val urgency = when (row.risk) {
            "高" -> "今天需要真人接力"
            "中" -> "本週持續追蹤"
            else -> "保留自學節奏"
        }
        val recovery = recoveryTaskTitle.ifBlank { "目前沒有未完成補救任務" }
        val help = preparedHelpSummary.ifBlank { "尚未有新的學生求助摘要" }
        return """
            判斷：$urgency。
            主要訊號：${row.issue}
            最新狀態：${row.status}
            目前學習證據：答題事件 $learningEventCount 筆、錯題修復 $repairedMistakeCount 筆、信心 $confidence%。
            補救任務：$recovery
            求助摘要：${help.lineSequence().take(3).joinToString(" / ")}
            建議：先用低壓語句回應，再只帶同一概念 1-2 題；不要把今日任務加長。
        """.trimIndent()
    }

    private fun buildVolunteerReplyDraft(row: StudentRow): String {
        val concept = questions.getOrNull(currentQuestionIndex)?.concept ?: "剛剛卡住的概念"
        return if (row.risk == "高" || confidence < 45 || recoveryTaskTitle.isNotBlank()) {
            "我看到你剛剛卡在「$concept」，願意求助已經很好。今天不用多做，我們只一起看同一個規則，再做 1 題就好。"
        } else {
            "你今天已經完成主要任務了。下一步不用急著加題，先保留現在的節奏；如果想挑戰，我再陪你看一題比較難的。"
        }
    }

    private fun addAiHandoffCollaborationNote(row: StudentRow) {
        addCollaborationNote(
            actor = currentAccount().displayName,
            roleLabel = currentAccount().roleLabel,
            target = row.name,
            note = "已指派給志工接力。\n\n${latestTeacherAiSummary.ifBlank { buildTeacherAiSummary(row) }}\n\n回覆草稿：${latestVolunteerDraft.ifBlank { buildVolunteerReplyDraft(row) }}",
            status = "已指派"
        )
        addOfflineSyncItem("AI 接力摘要：${row.name}", "老師/志工協作", latestTeacherAiSummary.ifBlank { buildTeacherAiSummary(row) })
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
        val middleRisk = roster.count { it.risk == "中" }
        val lowRisk = roster.count { it.risk == "低" }
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Primary)
        box.addView(ui.statusPill("班級雷達", ColorToken.Primary))
        box.addView(ui.label("先看需要人的學生", 21, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("管理中", "${roster.size} 位", ColorToken.Primary),
            Metric("高風險", "$highRisk 位", if (highRisk > 0) ColorToken.Danger else ColorToken.Success),
            Metric("追蹤", "$middleRisk 位", ColorToken.Warning)
        ))
        box.addView(ui.body("列表已依風險分段。先處理高風險，再看追蹤學生；低風險先不打斷。", "#334155"))
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
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun studentTodayQuestCard(): View {
        val title = if (!checkInCompleted) "先做 4 題狀態檢測" else "開始今天的英文小任務"
        val detail = if (!checkInCompleted) {
            "完成後 English+ 會依照心情、時間與想練的題型安排任務。"
        } else if (practiceTimeConfirmed && dailyTaskTotal() > 0) {
            if (isDailyTaskComplete()) {
                "今日必要題目已完成。接下來可以整理反思，或到練習中心自主加練。"
            } else {
                "今日任務還剩 ${remainingDailyTaskCount()} 題要答對；答錯會先看提示，不會推進進度。"
            }
        } else {
            "預計 ${minutes} 分鐘，先產生今天要完成的題目任務。"
        }
        val actionText = when {
            !checkInCompleted -> "開始檢測"
            !practiceTimeConfirmed -> "產生任務"
            isDailyTaskComplete() -> "整理今天學到什麼"
            else -> "繼續每日任務"
        }
        val action = when {
            !checkInCompleted -> ({ renderCheckIn() })
            !practiceTimeConfirmed -> ({ confirmPracticeTimeAndPlanToday() })
            isDailyTaskComplete() -> ({ renderReflection() })
            else -> ({ startNextDailyTaskOrPractice() })
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

    private fun studentMapStatusCard(): View {
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Primary)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val titleStack = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        titleStack.addView(ui.statusPill("今日地圖", ColorToken.Primary))
        titleStack.addView(ui.label(if (isDailyTaskComplete()) "今日題目已完成" else "看下一步要往哪裡走", 24, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        titleStack.addView(ui.body("學習地圖只顯示路線和建議；每日任務完成度只在題目任務中計算。", "#334155"))
        top.addView(titleStack, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(if (isDailyTaskComplete()) "完成" else "進行中", if (isDailyTaskComplete()) ColorToken.Success else ColorToken.Primary))
        box.addView(top)
        box.addView(flowStrip(
            mood.label,
            "${minutes} 分",
            selectedPracticeLevel,
            if (dailyTaskTotal() > 0) "${completedDailyTaskCount()}/${dailyTaskTotal()} 題" else "${targetDailyQuestionCount()} 題"
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
                "完成今日題目和 20 秒反思後，English+ 會依照錯題與題型偏好調整學習地圖。"
            },
            "#334155"
        ))
        if (hasInsight) {
            box.addView(ui.secondaryButton("依建議選題") { renderStudentPracticeCatalog() })
        }
        return ui.margins(box, 0, 0, 0, 14)
    }

    private fun studentMapPathCard(): View {
        val challengeUnlocked = todayReflected || selectedPracticeLevel.contains("B1")
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("主線路徑", ColorToken.Success))
        box.addView(ui.label("照著亮起的關卡往下走", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(pathNode("1", "狀態檢測", "已完成，今天的任務已依狀態生成", true, false) { renderCheckIn() })
        box.addView(pathNode("2", "今日任務", "已選定 ${minutes} 分鐘、${targetDailyQuestionCount()} 題", practiceTimeConfirmed, false) { renderTaskQueue() })
        box.addView(pathNode("3", "第一題練習", if (todayAnsweredFirstQuestion) "已開始累積答題紀錄" else "下一關：先完成一題", todayAnsweredFirstQuestion, !todayAnsweredFirstQuestion) { renderTaskQueue() })
        box.addView(pathNode("4", "反思整理", if (todayReflected) "已完成今日反思" else "完成一題後解鎖", todayReflected, todayAnsweredFirstQuestion && !todayReflected) { renderReflection() })
        box.addView(pathNode("5", "挑戰關卡", if (challengeUnlocked) "可挑戰 $selectedPracticeLevel 題組" else "完成反思後開啟", false, challengeUnlocked) { renderStudentPracticeCatalog() })

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
                detail = "把剛剛的錯題或不確定的地方記下來，學習地圖才會往下一關推進。"
                actionText = "開始反思"
                action = { renderReflection() }
            }
            selectedPracticeLevel.contains("B1") -> {
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
        val needsSupport = wrongAttempts > 0 || preparedHelpSummary.isNotBlank()
        val box = ui.container(if (needsSupport) ColorToken.WarningSoft else ColorToken.Surface, if (needsSupport) ColorToken.Warning else ColorToken.Border)
        box.addView(ui.statusPill(if (needsSupport) "可求助" else "需要時再用", if (needsSupport) ColorToken.Warning else ColorToken.Primary))
        box.addView(ui.label(if (needsSupport) "看提示或請人幫忙" else "主線任務先走完", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(
            if (needsSupport) "你可以先看提示重試；真的需要人協助時，再送出求助。"
            else "這裡不打擾主線任務；答錯後或你主動求助時才進來。",
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
            Metric("下一步", "產生任務", ColorToken.Success)
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
        if (bottomNavAttached) return
        bottomNavAttached = true
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
        } else if (isVolunteerAccount()) {
            val volunteerLabels = listOf("今日", "摘要", "陪伴", "同步", "紀錄")
            nav.addView(navDestination(navMark(volunteerLabels[0]), volunteerLabels[0], screen == Screen.Home || screen == Screen.Account) { renderHome() }, ui.weightParams())
            nav.addView(navDestination(navMark(volunteerLabels[1]), volunteerLabels[1], screen == Screen.StudentDetail || screen == Screen.Handoff) { renderVolunteerHandoffSummary() }, ui.weightParams())
            nav.addView(navDestination(navMark(volunteerLabels[2]), volunteerLabels[2], screen == Screen.Mentor) { renderMentorScript() }, ui.weightParams())
            nav.addView(navDestination(navMark(volunteerLabels[3]), volunteerLabels[3], screen == Screen.SyncCenter || screen == Screen.AiLab) { renderSyncCenter() }, ui.weightParams())
            nav.addView(navDestination(navMark(volunteerLabels[4]), volunteerLabels[4], screen == Screen.ActionQueue || screen == Screen.Report) { renderVolunteerRecord() }, ui.weightParams())
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
            "摘要" -> "摘"
            "陪伴" -> "陪"
            "紀錄" -> "錄"
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
        } else if (isVolunteerAccount()) {
            val labels = listOf("今日", "摘要", "陪伴", "同步", "紀錄")
            when (screen) {
                Screen.Home, Screen.Account -> labels[0]
                Screen.StudentDetail, Screen.Handoff -> labels[1]
                Screen.Mentor -> labels[2]
                Screen.SyncCenter, Screen.AiLab -> labels[3]
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
            Metric("下一步", "產生任務", ColorToken.Success)
        ))
        box.addView(ui.primaryButton("開始這個任務") { renderTaskQueue() })
        box.addView(ui.secondaryButton("我想先調整今天狀態") { renderCheckIn() })
        return ui.margins(box, 0, 8, 0, 16)
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
        val complete = answered == total
        box.addView(ui.statusPill(if (complete) "檢測完成" else "檢測進度", if (complete) ColorToken.Success else ColorToken.Primary))
        box.addView(metricRow(
            Metric("已完成", "$answered/$total", if (complete) ColorToken.Success else ColorToken.Primary),
            Metric("下一步", if (complete) "產生任務" else "繼續作答", if (complete) ColorToken.Success else ColorToken.Accent),
            Metric("題數", "$total 題", ColorToken.Primary)
        ))
        box.addView(ui.body(
            if (complete) "檢測已完成。下一頁會依你的狀態安排今日題目，不會把內部分數當成進度顯示。"
            else "先完成這 4 題，系統再決定今天適合的題目與難度。",
            "#334155"
        ).apply { setPadding(0, ui.dp(8), 0, 0) })
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

    private fun dailyTaskReadyCard(result: CheckInResult): View {
        val typeText = result.preferredQuestionTypes.ifEmpty { listOf("系統推薦") }.joinToString("、")
        val routeLabel = when (result.route) {
            "challenge" -> "挑戰路線"
            "repair" -> "暖身路線"
            else -> "穩定路線"
        }
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Primary)
        box.addView(ui.statusPill("今日任務已排好", ColorToken.Success))
        box.addView(ui.label("今天先完成這一組", 23, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(result.nextStep, "#334155"))
        box.addView(metricRow(
            Metric("時間", "${result.recommendedMinutes} 分", ColorToken.Accent),
            Metric("題量", "${targetQuestionCountForMinutes(result.recommendedMinutes)} 題", ColorToken.Primary),
            Metric("路線", routeLabel, result.mood.color)
        ))
        box.addView(ui.body("題型：$typeText\n接下來會直接進入今日任務，進度條只會在作題時出現。", ColorToken.Muted).apply {
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
            Metric("下一步", "產生任務", ColorToken.Success)
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
        box.addView(ui.statusPill("可選擇", ColorToken.Success))
        box.addView(ui.label("你想要哪一種幫忙？", 22, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("選最接近現在的狀態。English+ 會先保留題目和你的答案；只有你送出時，老師或志工才會看到求助摘要。", "#334155"))
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
        box.addView(ui.statusPill("學習紀錄", ColorToken.Success))
        box.addView(ui.label("學習紀錄已寫入手機", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("狀態", stateText, ColorToken.Success),
            Metric("事件", "${snapshot.eventCount} 筆", ColorToken.Primary),
            Metric("待補傳", "${snapshot.pendingSyncCount} 筆", if (snapshot.pendingSyncCount > 0) ColorToken.Warning else ColorToken.Success)
        ))
        box.addView(ui.body("最新紀錄：${snapshot.latestEventTitle}\n協作紀錄：${snapshot.collaborationCount} 筆｜離線包：${snapshot.downloadedPackCount} 包", "#334155"))
        box.addView(ui.body("目前紀錄會先保存在這台裝置；有網路時再補傳，老師與志工就能接續查看。", ColorToken.Muted).apply {
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
        box.addView(ui.statusPill("題庫已準備", ColorToken.Success))
        box.addView(ui.label("English+ 正式題庫骨架", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("題目", "${bankItems.size} 題", ColorToken.Primary),
            Metric("題型", "$typeCount 類", ColorToken.Accent),
            Metric("技能", "$skillCount 類", ColorToken.Success)
        ))
        box.addView(ui.body("練習題已依程度、單元、技能與推薦理由整理。後續可擴充更多分級題庫，或由老師後台匯入。單元：$unitCount 組。", "#334155"))
        box.addView(ui.secondaryButton("打開題庫中心") { renderQuestionBank() })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun aiQuestionBankLabelSummaryCard(items: List<QuestionBankItem>): View {
        val repairCount = items.count { "repair" in it.recommendationTags || it.emotionalFit == "low" }
        val challengeCount = items.count { it.challengeScore >= 5 || it.difficultyBand == "challenge" }
        val lowPressureCount = items.count { "low-pressure" in it.recommendationTags || it.estimatedSeconds <= 45 }
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Success)
        box.addView(ui.statusPill("AI 題庫標籤", ColorToken.Success))
        box.addView(ui.label("把題庫變成可推薦的學習路線", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(
            "English+ 會依照難度、題型、情緒適配、作答時間與挑戰分，把題目標成修復題、低壓題、會考基準題或挑戰題。老師審題時可先看這些標籤，學生端則只看到推薦理由。",
            "#334155"
        ))
        box.addView(metricRow(
            Metric("修復題", "$repairCount", ColorToken.Success),
            Metric("挑戰題", "$challengeCount", ColorToken.Warning),
            Metric("低壓題", "$lowPressureCount", ColorToken.Primary)
        ))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun aiStudentPracticeLabelCard(items: List<QuestionBankItem>): View {
        val first = items.firstOrNull()
        val labelLine = first?.let { aiQuestionBankLabels(it).joinToString("、") } ?: "尚未有推薦題"
        val reason = first?.let { aiQuestionRecommendationReason(it) } ?: "完成心情檢測後，English+ 會依照時間、信心與題型偏好挑題。"
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Border)
        box.addView(ui.statusPill("AI 選題理由", ColorToken.Success))
        box.addView(ui.label("不是隨機出題，是照今天狀態挑", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("目前標籤：$labelLine\n推薦原因：$reason", "#334155"))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun aiQuestionBankLabels(item: QuestionBankItem): List<String> {
        val labels = mutableListOf<String>()
        when {
            "repair" in item.recommendationTags || item.difficultyBand == "foundation" -> labels.add("修復優先")
            item.difficultyBand == "challenge" || item.challengeScore >= 5 -> labels.add("挑戰題")
            else -> labels.add("會考基準")
        }
        when (item.emotionalFit) {
            "low" -> labels.add("低壓可做")
            "high-confidence" -> labels.add("信心高再做")
            else -> labels.add("穩定練習")
        }
        if (item.estimatedSeconds <= 45) labels.add("短時間")
        if (normalizedQuestionType(item).contains("閱讀") || normalizedQuestionType(item).contains("克漏")) labels.add("需要專注")
        if (selectedPracticeTypes.contains(normalizedQuestionType(item))) labels.add("符合偏好")
        return labels.distinct()
    }

    private fun aiQuestionRecommendationReason(item: QuestionBankItem): String {
        val type = normalizedQuestionType(item)
        return when {
            confidence < 45 || wrongAttempts > 0 || "repair" in item.recommendationTags ->
                "適合先修復 $type 的小概念，題目壓力較低，不會直接加難度。"
            confidence >= 70 && item.challengeScore >= 5 ->
                "你目前信心較高，這題可以拿來挑戰會考偏難題型。"
            minutes <= 5 && item.estimatedSeconds <= 45 ->
                "今天時間不多，這題能在短時間內完成，適合放進每日任務。"
            selectedPracticeTypes.contains(type) ->
                "這題符合你心情檢測後選擇的題型偏好，可以讓練習更有掌控感。"
            item.difficultyBand == "cap-standard" ->
                "這題接近會考基準難度，適合穩定累積分數。"
            else ->
                "這題可補足目前題型分布，讓練習不只停在同一種選擇題。"
        }
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
        box.addView(ui.body("AI 標籤：${aiQuestionBankLabels(item).joinToString("、")}", ColorToken.Success).apply { setPadding(0, ui.dp(6), 0, 0) })
        box.addView(ui.body("派題理由：${aiQuestionRecommendationReason(item)}", "#334155"))
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
        box.addView(ui.statusPill(if (hasBackend) "雲端同步已開啟" else "先保存在本機", if (hasBackend) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label(if (hasBackend) "可補傳到雲端" else "目前先保存在這台裝置", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(
            if (hasBackend) {
                "按下同步後，學習紀錄與接力紀錄會補傳到雲端。"
            } else {
                "沒有網路或尚未開啟雲端同步時，資料仍會保存在這台裝置。"
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
        box.addView(ui.body("按下智慧同步時，English+ 會先檢查網路與雲端同步狀態；失敗就保留待補傳，成功才把本機佇列標記為已同步。", ColorToken.Muted).apply {
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
        val endpointState = if (stateStore.hasRemoteAuthEndpoint()) "已開啟" else "尚未開啟"
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill("帳號狀態", ColorToken.Primary))
        box.addView(ui.label("角色與登入狀態", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(
            "學生帳號：$studentCount\n老師/志工帳號：$staffCount\n學校帳號連線：$endpointState\n目前可先使用下方帳號檢視完整流程。",
            "#334155"
        ))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun remoteAuthLoginCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label("帳號來源", 18, ColorToken.Ink, true))
        box.addView(ui.body("可以先用本機帳號體驗完整流程；之後也能接學校或班級帳號。", "#334155"))
        box.addView(ui.secondaryButton("查看本機帳號") { renderAccountCenter() })
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
            "答錯後會先出現一個提示，你可以看完再重試。"
        } else {
            "現在先作答；需要時再開啟提示或求助。"
        }
        val box = ui.container(fill, ColorToken.Border)
        box.addView(ui.statusPill("需要時再開啟", color))
        box.addView(ui.label("答錯後會提供提示", 17, ColorToken.Ink, true).apply {
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
            Metric("下一步", "產生任務", ColorToken.Success),
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
        val normalizedRole = AuthContract.normalizeRole(account.roleLabel)
        val roleHint = when (normalizedRole) {
            AuthContract.ROLE_TEACHER -> "進入後先看班級訊號、學生風險與派工進度。"
            AuthContract.ROLE_VOLUNTEER -> "進入後只看今天要陪伴的學生、腳本與回填紀錄。"
            else -> "進入後先做狀態檢測，再開始今日任務。"
        }
        val actionText = when (normalizedRole) {
            AuthContract.ROLE_TEACHER -> "登入老師端"
            AuthContract.ROLE_VOLUNTEER -> "登入志工端"
            else -> "登入學生端"
        }
        val box = ui.container(if (isStudent) ColorToken.PrimarySoft else ColorToken.SuccessSoft, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(account.displayName, 20, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(account.roleLabel, if (isStudent) ColorToken.Primary else ColorToken.Success))
        box.addView(top)
        box.addView(ui.body("班級/群組：${account.classCode}", "#334155").apply { setPadding(0, ui.dp(8), 0, 0) })
        box.addView(ui.body(roleHint, ColorToken.Muted))
        box.addView(ui.primaryButton(actionText) {
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
                role = "系統紀錄",
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
        box.addView(ui.label(if (hasBackend) "老師/志工紀錄可同步" else "協作紀錄先保存在本機", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(
            if (hasBackend) {
                "可以送出本機協作紀錄，也可以更新其他老師或志工留下的最新紀錄。"
            } else {
                "雲端協作尚未開啟時，老師與志工仍可先用本機紀錄接力。"
            },
            "#334155"
        ))
        box.addView(ui.primaryButton(if (hasBackend) "同步協作紀錄" else "查看同步狀態") {
            if (hasBackend) renderRemoteCollaborationSync(pushFirst = true) else renderSyncCenter()
        })
        box.addView(ui.secondaryButton("更新最新紀錄") {
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

    private fun dailyTaskTotal(): Int {
        return aiDailyPlanItemIds.size
    }

    private fun completedDailyTaskCount(): Int {
        val planned = aiDailyPlanItemIds.toSet()
        return completedDailyTaskItemIds.count { it in planned }
    }

    private fun remainingDailyTaskCount(): Int {
        return (dailyTaskTotal() - completedDailyTaskCount()).coerceAtLeast(0)
    }

    private fun dailyTaskProgressPercent(): Int {
        val total = dailyTaskTotal()
        if (total <= 0) return 0
        return ((completedDailyTaskCount() * 100f) / total).toInt().coerceIn(0, 100)
    }

    private fun isDailyTaskComplete(): Boolean {
        return dailyTaskTotal() > 0 && completedDailyTaskCount() >= dailyTaskTotal()
    }

    private fun dailyTaskItemId(question: Question): String? {
        return questionBankItemFor(question)?.id?.takeIf { aiDailyPlanItemIds.contains(it) }
    }

    private fun nextIncompleteDailyTaskQuestionIndex(): Int? {
        val itemsById = stateStore.questionBankItems().associateBy { it.id }
        val nextItem = aiDailyPlanItemIds
            .filterNot { completedDailyTaskItemIds.contains(it) }
            .mapNotNull { itemsById[it] }
            .firstOrNull()
        return nextItem?.let { item ->
            questions.indexOfFirst {
                it.prompt == item.question.prompt && it.answer == item.question.answer
            }.takeIf { it >= 0 }
        }
    }

    private fun startNextDailyTaskOrPractice() {
        nextIncompleteDailyTaskQuestionIndex()?.let {
            currentQuestionIndex = it
        }
        renderLesson()
    }

    private fun dailyTaskProgressCard(): View {
        val total = dailyTaskTotal()
        val completed = completedDailyTaskCount()
        val remaining = remainingDailyTaskCount()
        val complete = isDailyTaskComplete()
        val box = ui.container(if (complete) ColorToken.SuccessSoft else ColorToken.Card, if (complete) ColorToken.Success else ColorToken.Border)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        top.addView(ui.label(if (complete) "今日題目任務完成" else "今日題目任務", 19, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill("$completed/$total", if (complete) ColorToken.Success else ColorToken.Primary))
        box.addView(top)
        box.addView(ui.body(
            when {
                total <= 0 -> "完成心情檢測後，English+ 會安排今天要答對的題目。"
                complete -> "太好了，今天 AI 安排的題目都答對了。接下來可以休息，也可以去練習中心自主加練。"
                remaining == 1 -> "只差最後 1 題答對，就完成今天的每日任務。"
                else -> "再答對 $remaining 題，就完成今天的每日任務。答錯不會扣分，但不會推進進度。"
            },
            "#334155"
        ).apply { setPadding(0, ui.dp(8), 0, ui.dp(6)) })
        box.addView(ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = dailyTaskProgressPercent()
            setPadding(0, ui.dp(8), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("已答對", "$completed 題", if (complete) ColorToken.Success else ColorToken.Primary),
            Metric("剩下", "$remaining 題", if (remaining == 0) ColorToken.Success else ColorToken.Accent),
            Metric("進度", "${dailyTaskProgressPercent()}%", if (complete) ColorToken.Success else ColorToken.Primary)
        ))
        if (complete) {
            box.addView(ui.primaryButton("去練習中心自主加練") { renderStudentPracticeCatalog() })
        }
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun dailyTaskCompletionCard(): View {
        val total = dailyTaskTotal().coerceAtLeast(1)
        val completed = completedDailyTaskCount().coerceAtMost(total)
        val box = ui.container(ColorToken.SuccessSoft, ColorToken.Success).apply {
            setPadding(ui.dp(18), ui.dp(18), ui.dp(18), ui.dp(18))
        }
        box.addView(ui.statusPill("今日任務完成", ColorToken.Success))
        box.addView(ui.label("今天的每日任務完成了！", 25, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(6))
        })
        box.addView(ui.body("你已答對今天安排的 $completed/$total 題。必要任務已結束，可以休息一下；想繼續進步，也可以到練習中心自主加練。", "#334155"))
        box.addView(ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
            max = 100
            progress = 100
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("完成 100%｜今日任務已達成", ColorToken.Success).apply {
            setPadding(0, ui.dp(4), 0, ui.dp(8))
        })
        box.addView(metricRow(
            Metric("已答對", "$completed/$total", ColorToken.Success),
            Metric("狀態", "已完成", ColorToken.Success),
            Metric("下一步", "休息/加練", ColorToken.Primary)
        ))
        return ui.margins(box, 0, 8, 0, 14)
    }
    private fun lessonSessionHeader(question: Question): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val dailyItemId = dailyTaskItemId(question)
        val isActiveDailyTask = dailyItemId != null && !isDailyTaskComplete()
        if (isActiveDailyTask) {
            top.addView(ui.statusPill("每日任務", ColorToken.Primary))
        } else {
            top.addView(ui.statusPill("自主練習", ColorToken.Accent))
        }
        top.addView(ui.label(normalizedLessonType(question), 16, ColorToken.Ink, true).apply {
            setPadding(ui.dp(10), 0, 0, 0)
        }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        if (isActiveDailyTask) top.addView(ui.statusPill("${completedDailyTaskCount()}/${dailyTaskTotal()}", ColorToken.Success))
        box.addView(top)
        if (isActiveDailyTask) {
            box.addView(ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
                max = 100
                progress = dailyTaskProgressPercent()
                setPadding(0, ui.dp(10), 0, ui.dp(4))
            })
            box.addView(ui.body("答對才會推進今日任務進度；答錯會先看提示重試。", ColorToken.Muted))
        } else {
            box.addView(ui.body("這是自主練習，不影響今日任務進度。", ColorToken.Muted))
        }
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
            box.addView(ui.primaryButton("開始推薦題") { startPracticeItem(item, items) })
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
    private fun studentPracticeOptionCard(item: QuestionBankItem, sessionItems: List<QuestionBankItem> = emptyList()): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        top.addView(ui.label(item.skill, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(item.level, ColorToken.Accent))
        box.addView(top)
        box.addView(ui.body("${normalizedQuestionType(item)}｜挑戰 ${item.challengeScore}｜約 ${item.estimatedSeconds} 秒", ColorToken.Muted).apply { setPadding(0, ui.dp(6), 0, 0) })
        box.addView(ui.body("推薦原因：${aiQuestionRecommendationReason(item)}", ColorToken.Success).apply { setPadding(0, ui.dp(6), 0, 0) })
        box.addView(ui.body(item.question.prompt.take(90), "#334155").apply { setPadding(0, ui.dp(6), 0, 0) })
        box.addView(ui.secondaryButton("開始這題") { startPracticeItem(item, sessionItems) })
        box.setOnClickListener { startPracticeItem(item, sessionItems) }
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
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.statusPill("今日任務", ColorToken.Primary))
        box.addView(ui.label(aiDailyPlanTitle.ifBlank { "今日任務推薦" }, 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(aiDailyPlanMessage.ifBlank { "完成心情檢測與時間選擇後，系統會把今天要做的題目排成清楚順序。" }, "#334155"))
        box.addView(metricRow(
            Metric("時間", "${minutes} 分", ColorToken.Accent),
            Metric("題數", "${plannedItems.size} 題", ColorToken.Primary),
            Metric("節奏", if (selectedPracticeLevel.contains("B1")) "挑戰" else "穩定練", if (selectedPracticeLevel.contains("B1")) ColorToken.Accent else ColorToken.Success)
        ))
        if (plannedItems.isNotEmpty()) {
            box.addView(ui.body("進入每日任務後才會顯示題目進度；答對會前進，答錯會先看提示。", ColorToken.Primary).apply {
                setPadding(0, ui.dp(4), 0, ui.dp(8))
            })
        }
        plannedItems.forEachIndexed { index, item ->
            val label = aiQuestionBankLabels(item).take(2).joinToString("、")
            val done = item.id in completedDailyTaskItemIds
            val status = if (done) "已完成" else "待完成"
            box.addView(ui.secondaryButton("${index + 1}. $status｜$label｜${normalizedQuestionType(item)}") {
                if (done) {
                    nextIncompleteDailyTaskQuestionIndex()?.let {
                        currentQuestionIndex = it
                        renderLesson()
                    } ?: renderStudentPracticeCatalog()
                } else {
                    startPracticeItem(item)
                }
            })
        }
        if (plannedItems.isEmpty()) {
            box.addView(ui.secondaryButton("產生今日任務") { confirmPracticeTimeAndPlanToday() })
        } else {
            box.addView(ui.secondaryButton("重新安排今日任務") { confirmPracticeTimeAndPlanToday() })
        }
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun recoveryTaskCard(): View {
        val box = ui.container(ColorToken.WarningSoft, ColorToken.Border)
        box.addView(ui.statusPill("錯題補救", ColorToken.Warning))
        box.addView(ui.label(recoveryTaskTitle, 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body(recoveryTaskDetail, "#334155"))
        box.addView(metricRow(
            Metric("下一步", "看提示", ColorToken.Warning),
            Metric("題型", selectedPracticeType, ColorToken.Primary),
            Metric("任務", "不加題", ColorToken.Success)
        ))
        box.addView(ui.primaryButton("開始補救任務") { startRecoveryTask() })
        box.addView(ui.secondaryButton("整理給老師/志工") { renderHelpRequest() })
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
                startPracticeItem(item, items)
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
                startPracticeItem(item, recommendations)
            })
        }
        box.addView(ui.secondaryButton("回練習中心自己挑題") { renderStudentPracticeCatalog() })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun activatePracticeSession(item: QuestionBankItem, sessionItems: List<QuestionBankItem>) {
        val isDailyTaskItem = aiDailyPlanItemIds.contains(item.id) && !isDailyTaskComplete()
        if (isDailyTaskItem) {
            activePracticeItemIds = emptyList()
            activePracticeItemIndex = -1
            return
        }
        val fallbackItems = if (sessionItems.isNotEmpty()) sessionItems else filteredPracticeItems(stateStore.questionBankItems()).ifEmpty { listOf(item) }
        val distinct = (listOf(item) + fallbackItems)
            .distinctBy { "${it.question.prompt}｜${it.question.answer}" }
            .filter { candidate ->
                if (selectedPracticeLevel.contains("B1")) candidate.level == "B1" || candidate.difficultyBand == "challenge"
                else true
            }
            .ifEmpty { listOf(item) }
        activePracticeItemIds = distinct.map { it.id }
        activePracticeItemIndex = activePracticeItemIds.indexOf(item.id).takeIf { it >= 0 } ?: 0
    }

    private fun nextPracticeSessionQuestionIndex(): Int? {
        if (activePracticeItemIds.isEmpty()) return null
        val itemsById = stateStore.questionBankItems().associateBy { it.id }
        repeat(activePracticeItemIds.size) {
            activePracticeItemIndex = (activePracticeItemIndex + 1).floorMod(activePracticeItemIds.size)
            val nextItem = itemsById[activePracticeItemIds[activePracticeItemIndex]] ?: return@repeat
            val nextQuestionIndex = questions.indexOfFirst { q ->
                q.prompt == nextItem.question.prompt && q.answer == nextItem.question.answer
            }
            if (nextQuestionIndex >= 0 && nextQuestionIndex != currentQuestionIndex) return nextQuestionIndex
        }
        return null
    }

    private fun Int.floorMod(modulus: Int): Int = ((this % modulus) + modulus) % modulus
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
        val combined = (plannedByAi + seed + items)
            .distinctBy { "${it.question.prompt}｜${it.question.answer}" }
        return combined.take(16)
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

    private fun startPracticeItem(item: QuestionBankItem, sessionItems: List<QuestionBankItem> = emptyList()) {
        val index = questions.indexOfFirst {
            it.prompt == item.question.prompt && it.answer == item.question.answer
        }
        if (index >= 0) currentQuestionIndex = index
        activatePracticeSession(item, sessionItems)
        wrongAttempts = 0
        lastSelectedAnswer = ""
        lastAnswerMessage = "已切換到 ${item.level}｜${normalizedQuestionType(item)}。先做這一題，答對後會前往同關卡下一題。"
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
        val title = when (option.route) {
            "AI 先處理" -> "先給我一個提示"
            "志工接力" -> "請真人陪我看錯在哪"
            "閱讀拆解" -> "幫我把長題目拆小"
            "復原模式" -> "換成更小的任務"
            "離線任務" -> "先做不用網路的練習"
            else -> "請老師或志工陪我"
        }
        val detail = when (option.route) {
            "AI 先處理" -> "適合只是差一點、想先自己修正。"
            "志工接力" -> "適合已經試過提示，還是需要老師或志工陪你對答案。"
            "閱讀拆解" -> "適合看到閱讀題、克漏字或長句時，不知道從哪裡開始。"
            "復原模式" -> "適合今天比較累，先完成一個很小的步驟。"
            "離線任務" -> "適合網路不穩，先保留進度。"
            else -> "適合已經試過提示，還是想要真人陪你看。"
        }
        val box = ui.container(routeFill, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(title, 18, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(option.route, routeColor))
        box.addView(top)
        box.addView(ui.body(detail, "#334155").apply { setPadding(0, ui.dp(8), 0, 0) })
        box.addView(ui.body(option.studentText, ColorToken.Muted).apply { setPadding(0, ui.dp(6), 0, 0) })
        box.setOnClickListener { handleHelpRequest(option) }
        return ui.margins(box, 0, 8, 0, 8)
    }
    private fun studentRowCard(row: StudentRow): View {
        val fill = if (row.risk == "高") ColorToken.WarningSoft else ColorToken.Card
        val riskColor = teacherRiskColor(row.risk)
        val actionLabel = when (row.risk) {
            "高" -> "今天處理"
            "中" -> "本週追蹤"
            else -> "保留自學"
        }
        val box = ui.container(fill, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label("${row.name}｜$actionLabel", 18, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill("風險 ${row.risk}", riskColor))
        box.addView(top)
        box.addView(ui.body("斷點：${row.issue}", "#334155").apply { setPadding(0, ui.dp(7), 0, 0) })
        box.addView(ui.body("狀態：${row.status}", ColorToken.Muted))
        box.addView(ui.body(if (row.risk == "高") "點開後可直接交給志工接力。" else "點開後查看證據與追蹤建議。", riskColor).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        box.setOnClickListener { renderStudentDetail(row) }
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun teacherRiskColor(risk: String): String {
        return when (risk) {
            "高" -> ColorToken.Danger
            "中" -> ColorToken.Warning
            else -> ColorToken.Success
        }
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
        val targetRow = currentRoster().firstOrNull { item.title.contains(it.name) } ?: currentRoster().first()
        box.addView(ui.divider())
        box.addView(ui.body("AI 摘要：${buildTeacherAiSummary(targetRow).lineSequence().take(2).joinToString(" / ")}", "#334155"))
        box.addView(ui.secondaryButton("查看 AI 接力資料") { renderStudentDetail(targetRow) })
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
