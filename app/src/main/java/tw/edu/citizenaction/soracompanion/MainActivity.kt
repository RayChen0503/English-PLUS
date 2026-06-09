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
import tw.edu.citizenaction.soracompanion.ai.AiLearningPlanContract
import tw.edu.citizenaction.soracompanion.ai.AiProxyClient
import tw.edu.citizenaction.soracompanion.ai.OpenAiClient
import tw.edu.citizenaction.soracompanion.auth.AuthClient
import tw.edu.citizenaction.soracompanion.auth.AuthContract
import tw.edu.citizenaction.soracompanion.auth.AuthSession
import tw.edu.citizenaction.soracompanion.cloud.CloudBackendClient
import tw.edu.citizenaction.soracompanion.cloud.CloudDataContract
import tw.edu.citizenaction.soracompanion.cloud.CloudSyncResult
import tw.edu.citizenaction.soracompanion.cloud.QuestionBankContract
import tw.edu.citizenaction.soracompanion.data.PrototypeRepository
import tw.edu.citizenaction.soracompanion.model.ActionItem
import tw.edu.citizenaction.soracompanion.model.AiScenario
import tw.edu.citizenaction.soracompanion.model.AppState
import tw.edu.citizenaction.soracompanion.model.Breakpoint
import tw.edu.citizenaction.soracompanion.model.CollaborationNote
import tw.edu.citizenaction.soracompanion.model.CollaborationFlowContract
import tw.edu.citizenaction.soracompanion.model.DailyMissionContract
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
import tw.edu.citizenaction.soracompanion.model.StudentHelpThread
import tw.edu.citizenaction.soracompanion.model.SyncRecord
import tw.edu.citizenaction.soracompanion.model.SupportMessage
import tw.edu.citizenaction.soracompanion.model.SupportTarget
import tw.edu.citizenaction.soracompanion.model.TeacherAction
import tw.edu.citizenaction.soracompanion.model.TeacherWorkspaceContract
import tw.edu.citizenaction.soracompanion.model.UserFlowContract
import tw.edu.citizenaction.soracompanion.model.VolunteerHandoffContract
import tw.edu.citizenaction.soracompanion.model.WeeklySignal
import tw.edu.citizenaction.soracompanion.qa.ReportContext
import tw.edu.citizenaction.soracompanion.qa.ReportExportContract
import tw.edu.citizenaction.soracompanion.qa.ReportKind
import tw.edu.citizenaction.soracompanion.qa.PrivacyGovernanceContract
import tw.edu.citizenaction.soracompanion.state.PrototypeStateStore
import tw.edu.citizenaction.soracompanion.ui.UiKit
import tw.edu.citizenaction.soracompanion.ui.UiKit.ColorToken

class MainActivity : Activity() {
    private lateinit var root: LinearLayout
    private lateinit var navRoot: LinearLayout
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
    private var inDailyMission = false
    private var dailyQuestionGoal = 0
    private var dailyQuestionDone = 0
    private var dailyMissionCursor = 0
    private var dailyMissionQuestions: List<Question> = emptyList()
    private var moodScale = 3
    private var timeScale = 3
    private var challengeWanted = false
    private val preferredQuestionTypes = UserFlowContract.defaultPreferredQuestionTypes.toMutableSet()
    private var lastAnswerMessage = "還沒有作答，先從一題短任務開始。"
    private var lastSelectedAnswer = ""

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
        renderHome()
    }

    private fun restoreState() {
        stateStore.seedQuestionBank(PrototypeRepository.questionBankItems)
        questions = stateStore.questionBankQuestions().ifEmpty { PrototypeRepository.questions }
        val saved = stateStore.load()
        mood = saved.mood
        minutes = saved.minutes
        moodScale = UserFlowContract.moodScaleForMood(mood)
        timeScale = UserFlowContract.timeScaleForMinutes(minutes)
        confidence = saved.confidence
        completedTasks = saved.completedTasks
        currentQuestionIndex = saved.currentQuestionIndex.coerceIn(0, questions.lastIndex)
        actionDoneCount = saved.actionDoneCount
        managedStudentCount = saved.managedStudentCount
        offlinePendingCount = saved.offlinePendingCount
        selectedAccountName = saved.selectedAccountName
        role = UserFlowContract.roleForAuthLabel(currentAccount().roleLabel)
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

    private fun recordStudentHelpRequest(reason: String, studentText: String, platformAction: String, route: String) {
        val q = activeQuestion()
        val missionText = if (inDailyMission) {
            "今日任務 $dailyQuestionDone/$dailyQuestionGoal"
        } else {
            "自由練習"
        }
        addCollaborationNote(
            actor = student.name,
            roleLabel = "學生",
            target = student.name,
            note = buildString {
                appendLine("求助原因：$reason")
                appendLine("學生說：$studentText")
                appendLine("目前題目：${q.prompt}")
                appendLine("概念：${q.concept}")
                appendLine("心情：${mood.label}｜任務：$missionText｜路線：$route")
                append("平台摘要：$platformAction")
            },
            status = CollaborationFlowContract.STATUS_STUDENT_REQUEST
        )
    }

    private fun studentHelpThreads(limit: Int = 8) =
        CollaborationFlowContract.studentThreads(collaborationNotes, student.name, limit)

    private fun pendingStudentHelpRequests(limit: Int = 8): List<CollaborationNote> {
        return CollaborationFlowContract.unansweredRequests(collaborationNotes).take(limit)
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
        val queue = CloudDataContract.buildQueueState(
            items = offlineSyncItems.map { CloudDataContract.queueItemFromOfflineSync(it) },
            networkAvailable = isNetworkAvailable(),
            lastSuccessAt = offlineSyncItems
                .filter { it.status.contains("已同步") }
                .maxOfOrNull { it.updatedAt } ?: 0L
        )
        return "$networkText\n$backendText\n$pendingText\n下一步：${queue.message}"
    }

    private fun accountList(): List<LocalAccount> = stateStore.localAccounts(defaultAccounts)

    private fun currentAccount(): LocalAccount {
        return accountList().firstOrNull { it.displayName == selectedAccountName }
            ?: accountList().first()
    }

    private fun selectAccount(account: LocalAccount) {
        selectedAccountName = account.displayName
        role = UserFlowContract.roleForAuthLabel(account.roleLabel)
        stateStore.markAccountUsed(account.displayName)
        persistState()
        recordLearningEvent("account_login", "切換登入：${account.displayName}", "角色：${account.roleLabel}｜班級/群組：${account.classCode}")
    }

    private fun renderHome() {
        screen = Screen.Home
        shell("English+", "偏鄉學生雙軌學習平台")
        hero("先接住情緒，再修復英文斷點", "學生卡關時由 AI 即時拆小任務；真正需要人的地方，再把斷點摘要交給雲端志工或老師。")
        root.addView(roleSwitch())
        when (UserFlowContract.normalizedRole(role)) {
            Role.Student -> studentHome()
            Role.Teacher -> teacherHome()
            Role.Volunteer -> volunteerHome()
            Role.Mentor -> volunteerHome()
        }
        bottomNav()
    }

    private fun studentHome() {
        root.addView(classContextCard())
        root.addView(nextActionCard())
        section("今天有兩條路可以走")
        root.addView(trackEntry(
            "學習軌",
            "先完成一個低壓任務",
            "現在最適合先做 ${minutes} 分鐘短任務，完成後會把這一小步寫回學習進度。",
            ColorToken.PrimarySoft,
            "查看今日任務"
        ) { renderTaskQueue() })
        root.addView(trackEntry(
            "支持軌",
            "先說說現在的感受",
            "如果今天比較累，先被理解也算前進。平台會依心情調整短練習、陪伴和接力。",
            ColorToken.AccentSoft,
            "先做心情回報"
        ) { renderCheckIn() })
        root.addView(flowStrip("心情回報", "今日任務", "即時回饋", "需要時接力"))
        root.addView(card("今日建議", "先做「${modules[1].title}」中的一題一概念任務。今天不是補完整章，而是把一個斷點修回來。", ColorToken.PrimarySoft))
        root.addView(contractPreviewCard(learningContracts.first()))
        section("下一步")
        studyTasks.take(2).forEach { root.addView(taskCard(it)) }
        if (customTaskCount > 0) {
            repeat(customTaskCount) { index ->
                root.addView(taskCard(StudyTask("自訂修復任務 ${index + 1}", 3, "低", "由老師端新增，先做一題一概念修復。", "老師指派")))
            }
        }
        root.addView(ui.secondaryButton("查看所有任務安排") { renderTaskQueue() })
        section("今天的支持")
        supportMessages.take(1).forEach { root.addView(messageCard(it)) }
        root.addView(ui.secondaryButton("我想請平台幫我整理求助訊息") { renderHelpRequest() })
        section("更多探索")
        root.addView(actionGrid(
            ActionItem("學習檔案", "看目標與偏好") { renderProfile() },
            ActionItem("學習地圖", "看進度與斷點") { renderMap() },
            ActionItem("離線任務包", "碎片時間也能學") { renderOfflinePacks() },
            ActionItem("今日紀錄", "看學習與支持紀錄") { renderMap() }
        ))
        root.addView(ui.secondaryButton("帳號與班級資料") { renderAccountCenter() })
    }

    private fun teacherHome() {
        val pendingRequests = pendingStudentHelpRequests()
        val summary = TeacherWorkspaceContract.homeSummary(
            roster = currentRoster(),
            notes = collaborationNotes,
            pendingSyncCount = offlinePendingCount
        )
        section("老師工作台")
        root.addView(classContextCard())
        root.addView(metricRow(
            Metric("待回覆", "${summary.helpPending} 位", if (summary.helpPending > 0) ColorToken.Warning else ColorToken.Success),
            Metric("高風險", "${summary.highRiskCount} 位", if (summary.highRiskCount > 0) ColorToken.Danger else ColorToken.Success),
            Metric("題庫", "${questions.size} 題", ColorToken.Primary)
        ))
        root.addView(flowStrip("班級風險", "學生詳情", "回覆求助", "週報追蹤"))
        root.addView(card("今日優先處理", "${summary.priorityStudent}\n${summary.nextAction}", if (pendingRequests.isNotEmpty()) ColorToken.WarningSoft else ColorToken.PrimarySoft))
        root.addView(ui.primaryButton("查看待辦處理佇列") { renderActionQueue() })
        root.addView(actionGrid(
            ActionItem("學生列表", "看誰需要追蹤") { renderRoster() },
            ActionItem("題庫中心", "看分級與題型") { renderQuestionBank() },
            ActionItem("接力優先序", "分派老師/志工") { renderHandoffBoard() },
            ActionItem("週報摘要", "看本週支持證據") { renderWeeklyReport() }
        ))
        root.addView(ui.secondaryButton("學生資料管理") { renderStudentManager() })
        section("本週訊號")
        weeklySignals.forEach { root.addView(signalCard(it)) }
        root.addView(card("操作紀錄摘要", "已處理待辦：${actionDoneCount} 件\n接力回覆：${mentorReplyCount} 則\n新增任務：${customTaskCount} 個", ColorToken.Card))
        root.addView(ui.secondaryButton("查看週報與提案摘要") { renderWeeklyReport() })
    }

    private fun volunteerHome() {
        val pendingRequests = pendingStudentHelpRequests()
        val workspace = VolunteerHandoffContract.workspaceFor(role)
        section("志工接力工作台")
        root.addView(classContextCard())
        root.addView(metricRow(
            Metric("待回覆", "${pendingRequests.size} 位", if (pendingRequests.isNotEmpty()) ColorToken.Warning else ColorToken.Success),
            Metric("接力紀錄", "${collaborationNotes.size} 筆", ColorToken.Primary),
            Metric("可處理", "15 分鐘", ColorToken.Success)
        ))
        root.addView(flowStrip("看卡點", "回覆學生", "陪練一題", "留下紀錄"))
        root.addView(card("今天先做什麼", workspace.primaryAction, ColorToken.PrimarySoft))
        if (pendingRequests.isEmpty()) {
            root.addView(card("目前沒有待回覆學生", "可以先看陪伴腳本或同步最新協作紀錄。", ColorToken.SuccessSoft))
        } else {
            root.addView(card("下一位先接住", "${pendingRequests.first().target}\n${collaborationField(pendingRequests.first().note, "求助原因：").ifBlank { "學生主動求助" }}", ColorToken.WarningSoft))
        }
        root.addView(ui.primaryButton("查看學生求助佇列") { renderActionQueue() })
        root.addView(actionGrid(
            ActionItem("接力優先序", "先看誰最需要人") { renderHandoffBoard() },
            ActionItem("陪伴腳本", "直接照腳本陪練") { renderMentorScript() },
            ActionItem("學生摘要", "只看必要背景") { renderRoster() },
            ActionItem("同步紀錄", "拉取最新接力") { renderSyncCenter() }
        ))
        section("陪伴原則")
        root.addView(card("志工只做下一小步", "先肯定學生卡住的地方，再用同一概念陪練一題；不追加作業、不評比分數。", ColorToken.PrimarySoft))
    }

    private fun renderProfile() {
        screen = Screen.Profile
        shell("學生學習檔案", "讓老師更快理解學生，而不是只看分數")
        root.addView(card("基本資料", "${student.name}｜${student.age} 歲｜${student.location}｜${student.grade}\n目標：${student.goal}", ColorToken.PrimarySoft))
        root.addView(card("限制條件", student.constraint, ColorToken.WarningSoft))
        root.addView(card("學習偏好", student.learningStyle, ColorToken.SuccessSoft))
        root.addView(card("支持需求", student.supportNeed, ColorToken.VioletSoft))
        root.addView(card("我的資料權利", PrivacyGovernanceContract.dataRightsPolicy().studentFacingCopy, ColorToken.PrimarySoft))
        root.addView(ui.primaryButton("依照檔案產生今日任務") { renderTaskQueue() })
        bottomNav()
    }

    private fun renderAccountCenter() {
        screen = Screen.Account
        val account = currentAccount()
        shell("帳號與班級", "選擇今天要使用的身分")
        root.addView(card("目前登入", "${account.displayName}｜${account.roleLabel}\n班級/群組：${account.classCode}\n${account.loginState}", ColorToken.PrimarySoft))
        root.addView(accountReadinessCard())
        root.addView(remoteAuthStatusCard())
        root.addView(remoteAuthLoginCard())
        accountList().forEach { root.addView(accountCard(it)) }
        root.addView(ui.secondaryButton("切換到老師端") {
            val teacher = accountList().firstOrNull { AuthContract.normalizeRole(it.roleLabel) == AuthContract.ROLE_TEACHER } ?: account
            selectAccount(teacher)
            renderHome()
        })
        root.addView(ui.secondaryButton("切換到志工端") {
            val volunteer = accountList().firstOrNull { AuthContract.normalizeRole(it.roleLabel) == AuthContract.ROLE_VOLUNTEER } ?: account
            selectAccount(volunteer)
            renderHome()
        })
        bottomNav()
    }

    private fun renderRemoteLoginProgress(username: String, password: String, classCode: String) {
        screen = Screen.Account
        val endpoint = stateStore.remoteAuthEndpoint()
        if (!stateStore.hasRemoteAuthEndpoint()) {
            shell("使用班級帳號登入", "之後可接學校帳號")
            root.addView(card("目前狀態", "目前可以先用班級帳號進入。", ColorToken.WarningSoft))
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
        role = UserFlowContract.roleForAuthLabel(session.roleLabel)
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
        shell("登入暫時失敗", "你仍可使用班級帳號")
        root.addView(card("錯誤訊息", message, ColorToken.WarningSoft))
        root.addView(card("下一步", "你仍可以先使用班級帳號進入；若要使用學校帳號，請稍後重新登入。", ColorToken.Card))
        root.addView(ui.primaryButton("回帳號中心") { renderAccountCenter() })
        bottomNav()
    }

    private fun roleLabel(): String = UserFlowContract.roleTitle(role)

    private fun renderLearningContract() {
        screen = Screen.Contract
        shell("今日學習契約", "先約定任務邊界，再開始學習")
        root.addView(card("為什麼需要契約？", "偏鄉學生常遇到時間零碎、挫折累積、求助成本高。學習契約讓學生知道今天只要做到哪裡，也讓老師知道平台不會用公開比較或大量題目壓迫學生。", ColorToken.PrimarySoft))
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
        root.addView(ui.primaryButton("整理給老師/志工") {
            if (role == Role.Student) {
                val latest = breakpoints.first()
                recordStudentHelpRequest(latest.title, latest.evidence, latest.aiAction, "老師接力")
                renderStudentHelpSent(latest.title)
            } else {
                renderHandoff()
            }
        })
        bottomNav()
    }

    private fun renderDesignPrinciples() {
        screen = Screen.Mentor
        shell("產品設計原則", "把課程提案翻成可被檢核的功能")
        root.addView(card("v0.6 檢核方向", "這頁用來確認我們做的不是單純英文練習 app，而是面向偏鄉學生、情緒斷點與雙軌接力的學習平台。", ColorToken.PrimarySoft))
        designPrinciples.forEach { root.addView(principleCard(it)) }
        root.addView(ui.secondaryButton("查看 English+ 設計系統") { renderDesignSystem() })
        root.addView(ui.primaryButton("查看服務品質檢核") { renderMentorChecks() })
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
            "學生端維持低壓與短任務；老師端看班級與題庫，志工端看接力與陪伴。任何新功能都要先判斷放在哪一軌，不混在同一張卡裡。",
            ColorToken.VioletSoft
        ))
        root.addView(ui.primaryButton("回產品設計原則") { renderDesignPrinciples() })
        root.addView(ui.secondaryButton("回首頁") { renderHome() })
        bottomNav()
    }

    private fun renderTaskQueue() {
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
        root.addView(ui.primaryButton("開始今日題目任務") { startDailyMission() })
        root.addView(ui.secondaryButton("自由練習，不計入今日任務") {
            inDailyMission = false
            dailyMissionQuestions = emptyList()
            renderLesson()
        })
        bottomNav()
    }

    private fun renderCheckIn() {
        screen = Screen.CheckIn
        shell("今天狀態檢測", "四個問題決定今天先做哪一組題目")
        root.addView(checkInIntroCard())

        section("1. 今天的心情量表")
        root.addView(scaleSelector(
            selected = moodScale,
            lowLabel = "低",
            highLabel = "好",
            color = ColorToken.Accent
        ) { value ->
            moodScale = value
            mood = UserFlowContract.moodFromScale(value)
            confidence = (35 + value * 12 + mood.confidenceDelta).coerceIn(0, 100)
            persistState()
            renderCheckIn()
        })
        root.addView(selectedMoodResponse())

        section("2. 今天有足夠的時間練習英文嗎")
        root.addView(scaleSelector(
            selected = timeScale,
            lowLabel = "很少",
            highLabel = "很充足",
            color = ColorToken.Primary
        ) { value ->
            timeScale = value
            minutes = UserFlowContract.minutesFromTimeScale(value)
            persistState()
            renderCheckIn()
        })

        section("3. 今天會想要挑戰更難的題目嗎")
        root.addView(twoChoiceSelector(
            left = "想",
            right = "不想",
            leftSelected = challengeWanted,
            onLeft = {
                challengeWanted = true
                renderCheckIn()
            },
            onRight = {
                challengeWanted = false
                renderCheckIn()
            }
        ))

        section("4. 想要多練習哪幾種題型")
        root.addView(questionTypeSelector())
        root.addView(planPreviewCard())
        root.addView(ui.primaryButton("產生今日任務") { startDailyMission() })
        root.addView(ui.secondaryButton("先回首頁看看兩條路") { renderHome() })
        bottomNav()
    }

    private fun renderLesson() {
        screen = Screen.Lesson
        currentQuestionIndex = currentQuestionIndex.coerceIn(0, questions.lastIndex)
        val q = activeQuestion()
        shell(if (inDailyMission) "今日題目任務" else "自由練習", "一題一概念，避免二度挫折")
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
        val q = activeQuestion()
        if (option == q.answer) {
            completedTasks += 1
            if (inDailyMission) {
                dailyQuestionDone = DailyMissionContract.progressAfterAnswer(
                    done = dailyQuestionDone,
                    goal = dailyQuestionGoal,
                    isCorrect = true
                ).done
            } else {
                currentQuestionIndex = (currentQuestionIndex + 1) % questions.size
            }
            confidence = (confidence + 4).coerceAtMost(100)
            learningEventCount += 1
            if (wrongAttempts > 0) repairedMistakeCount += 1
            wrongAttempts = 0
            lastSelectedAnswer = option
            lastAnswerMessage = "答對了：${q.explanation}"
            addOfflineSyncItem("答題完成：${q.concept}", "學習事件", q.explanation)
            persistState()
            recordLearningEvent("answer_correct", "完成微任務：${q.concept}", q.explanation)
            if (inDailyMission && dailyQuestionDone >= dailyQuestionGoal) {
                currentQuestionIndex = nextPracticeIndexAfter(q)
                renderDailyMissionComplete(q)
            } else {
                if (inDailyMission) {
                    dailyMissionCursor = DailyMissionContract.nextCursor(
                        currentCursor = dailyMissionCursor,
                        questionCount = dailyMissionQuestions.size
                    )
                    currentQuestionIndex = nextPracticeIndexAfter(q)
                }
                renderSuccess(q)
            }
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
                val title = "今日新斷點：${q.concept}"
                if (breakpoints.none { it.title == title }) {
                    breakpoints.add(0, Breakpoint(title, "高", "同一題連續答錯 3 次", "平台先保留提示並改用錯題修復，不自動送出接力。", "若學生主動求助，再請志工用同一概念帶 2 題，不追加作業。"))
                }
                renderAiCoach()
            } else {
                renderAiCoach()
            }
        }
    }

    private fun startDailyMission() {
        val requestedGoal = recommendedQuestionGoal()
        dailyQuestionDone = 0
        dailyMissionCursor = 0
        dailyMissionQuestions = selectDailyMissionQuestions(requestedGoal)
        dailyQuestionGoal = dailyMissionQuestions.size.coerceAtLeast(1)
        inDailyMission = true
        lastAnswerMessage = "今日任務已開始。答對才會推進進度；答錯會停在同一題看提示。"
        renderLesson()
    }

    private fun recommendedQuestionGoal(): Int {
        return DailyMissionContract.goalForMinutes(minutes)
    }

    private fun activeQuestion(): Question {
        if (inDailyMission && dailyMissionQuestions.isNotEmpty()) {
            return dailyMissionQuestions[dailyMissionCursor.coerceIn(0, dailyMissionQuestions.lastIndex)]
        }
        currentQuestionIndex = currentQuestionIndex.coerceIn(0, questions.lastIndex)
        return questions[currentQuestionIndex]
    }

    private fun selectDailyMissionQuestions(goal: Int): List<Question> {
        return DailyMissionContract.selectQuestions(
            bankItems = stateStore.questionBankItems(),
            fallbackQuestions = questions,
            requestedGoal = goal,
            preferredTypes = preferredQuestionTypes,
            challengeWanted = challengeWanted,
            seed = currentQuestionIndex + completedTasks + learningEventCount + confidence
        )
    }

    private fun nextPracticeIndexAfter(question: Question): Int {
        val index = questions.indexOfFirst { it.prompt == question.prompt }
        return if (index >= 0) (index + 1) % questions.size else (currentQuestionIndex + 1) % questions.size
    }

    private fun renderSuccess(q: Question) {
        screen = Screen.Lesson
        shell("答對了", "先確認結果，再決定下一步")
        root.addView(successSummaryCard(q))
        val nextText = if (inDailyMission) {
            val remaining = DailyMissionContract.remaining(
                goal = dailyQuestionGoal,
                done = dailyQuestionDone
            )
            "今日任務還剩 $remaining 題。先照這個節奏完成，不另外加壓。"
        } else {
            "這題已完成。你可以繼續自由練習，也可以先停下來。"
        }
        root.addView(card("下一步", nextText, ColorToken.PrimarySoft))
        root.addView(ui.primaryButton("做一個 20 秒反思") { renderReflection() })
        root.addView(ui.primaryButton(if (inDailyMission) "繼續今日任務" else "繼續下一題") { renderLesson() })
        root.addView(ui.secondaryButton("回學習地圖") { renderMap() })
        bottomNav()
    }

    private fun renderDailyMissionComplete(q: Question) {
        screen = Screen.Lesson
        inDailyMission = false
        val completion = DailyMissionContract.completionCopy(
            goal = dailyQuestionGoal,
            done = dailyQuestionDone
        )
        shell(completion.title, "你已經完成今天最重要的英文小步驟")
        root.addView(successSummaryCard(q))
        root.addView(card("完成今日題目任務", completion.body, ColorToken.SuccessSoft))
        root.addView(card("可以停在這裡", completion.nextAction, ColorToken.PrimarySoft))
        root.addView(ui.primaryButton("繼續自主練習") { renderLesson() })
        root.addView(ui.secondaryButton("回首頁") { renderHome() })
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
        val q = activeQuestion()
        shell("還沒答對", "先看清楚答案差在哪裡，再重新嘗試")
        root.addView(answerResultCard(false, q, lastSelectedAnswer))
        root.addView(supportStepCard("01", "我看見你卡在這裡", q.prompt, ColorToken.WarningSoft, ColorToken.Warning))
        root.addView(supportStepCard("02", "先把概念拆小", "${q.explanation}\n現在只要先記住這一個規則，不需要一次把整個單元補完。", ColorToken.VioletSoft, ColorToken.Primary))
        root.addView(supportStepCard("03", "你可以選下一步", "回到同一題再試一次；如果仍然不舒服，English+ 會幫你把狀況整理給志工。", ColorToken.PrimarySoft, ColorToken.Success))
        root.addView(ui.primaryButton("回題目再試一次") { renderLesson() })
        root.addView(ui.secondaryButton("交給志工接力") { renderHelpRequest() })
        bottomNav()
    }

    private fun renderHelpRequest() {
        screen = Screen.HelpRequest
        shell("主動求助", "讓學生用自己的話說出卡住的原因")
        root.addView(helpIntroCard())
        val threads = studentHelpThreads(2)
        if (threads.isNotEmpty()) {
            section("最近的求助狀態")
            threads.forEach { root.addView(studentHelpThreadCard(it)) }
        }
        root.addView(flowStrip("說出卡點", "平台分流", "下一步"))
        helpRequestOptions.forEach { root.addView(helpOptionCard(it)) }
        root.addView(ui.secondaryButton("查看所有老師/志工回覆") { renderStudentSupportCenter() })
        root.addView(ui.secondaryButton("我還是想先自己試一題") { renderLesson() })
        bottomNav()
    }

    private fun renderStudentSupportCenter() {
        screen = Screen.HelpRequest
        shell("支持與回覆", "可以求助，也可以看老師/志工回覆")
        val threads = studentHelpThreads(12)
        val pending = CollaborationFlowContract.waitingRequestCount(collaborationNotes, student.name)
        val unreadReplies = CollaborationFlowContract.unreadRepliesForStudent(collaborationNotes, student.name).size
        root.addView(metricRow(
            Metric("待回覆", "$pending", if (pending > 0) ColorToken.Warning else ColorToken.Success),
            Metric("新回覆", "$unreadReplies", if (unreadReplies > 0) ColorToken.Warning else ColorToken.Success),
            Metric("信心", "$confidence%", ColorToken.Accent)
        ))
        if (threads.isEmpty()) {
            root.addView(card("還沒有求助紀錄", "卡住時可以先選一個原因，English+ 會把題目、心情與卡點整理給老師或志工。", ColorToken.PrimarySoft))
        } else {
            section("我的求助進度")
            threads.forEach { root.addView(studentHelpThreadCard(it)) }
        }
        root.addView(ui.primaryButton("我要新增求助") { renderHelpRequest() })
        root.addView(ui.secondaryButton("回到練習") { renderLesson() })
        bottomNav()
    }

    private fun handleHelpRequest(option: HelpRequestOption) {
        lastAnswerMessage = option.studentText
        recordLearningEvent("help_request", option.reason, option.platformAction)
        when (UserFlowContract.supportTarget(option.route)) {
            SupportTarget.AiCoach -> renderAiCoach()
            SupportTarget.ReadingBreakdown -> renderReadingBreakdown()
            SupportTarget.Recovery -> {
                mood = Mood.Low
                minutes = 3
                persistState()
                renderRecoveryMode()
            }
            SupportTarget.HumanHandoff -> {
                breakpoints.add(0, Breakpoint(option.reason, "高", option.studentText, option.platformAction, "志工先肯定狀態，再用同一概念做低壓陪練。"))
                recordStudentHelpRequest(option.reason, option.studentText, option.platformAction, option.route)
                renderStudentHelpSent(option.reason)
            }
        }
    }

    private fun renderStudentHelpSent(reason: String) {
        screen = Screen.HelpRequest
        shell("求助已送出", "老師與志工會看到你的卡點")
        root.addView(card("已送出", "求助原因：$reason\n我們已保留目前題目、心情與任務狀態。", ColorToken.SuccessSoft))
        studentHelpThreads(4).forEach { root.addView(studentHelpThreadCard(it)) }
        root.addView(ui.primaryButton("等回覆時先做一題低壓練習") {
            inDailyMission = false
            renderLesson()
        })
        root.addView(ui.secondaryButton("查看支持與回覆") { renderStudentSupportCenter() })
        bottomNav()
    }

    private fun renderReadingBreakdown() {
        screen = Screen.HelpRequest
        shell("閱讀拆解", "先把長題目切成可以處理的三步")
        root.addView(card("第一步", "先看題目問什麼，不急著讀完整段。", ColorToken.PrimarySoft))
        root.addView(card("第二步", "找人名、時間、轉折詞，先圈出答案可能出現的位置。", ColorToken.SuccessSoft))
        root.addView(card("第三步", "只回到題目需要的那一句，避免被整篇文章嚇到。", ColorToken.Card))
        root.addView(ui.primaryButton("用閱讀理解練一題") {
            inDailyMission = false
            val readingIndex = questions.indexOfFirst { it.type == "閱讀理解" }.takeIf { it >= 0 } ?: currentQuestionIndex
            currentQuestionIndex = readingIndex
            renderLesson()
        })
        root.addView(ui.secondaryButton("我想請人陪我看") {
            breakpoints.add(0, Breakpoint("閱讀題卡住", "中", "學生主動選擇閱讀拆解後仍想要陪伴。", "平台已提供三步拆解。", "志工陪學生先看題目，再一起找關鍵句。"))
            recordStudentHelpRequest("閱讀題卡住", "我想請人陪我看閱讀題。", "平台已提供三步拆解，仍需要真人陪看。", "老師接力")
            renderStudentHelpSent("閱讀題卡住")
        })
        bottomNav()
    }

    private fun renderBreakpoints() {
        screen = Screen.Breakpoints
        shell("支持中心", "把卡關變成 English+ 可以接住的訊號")
        root.addView(card("支持原則", "連續錯題、停留過久、重複退出都不是懲罰理由，而是調整任務與安排陪伴的訊號。", ColorToken.WarningSoft))
        breakpoints.forEach { root.addView(breakpointCard(it)) }
        root.addView(ui.secondaryButton("看看平台會怎麼支持我") { renderInterventionFlow() })
        root.addView(ui.primaryButton("整理狀況給老師/志工") {
            if (role == Role.Student) {
                val latest = breakpoints.first()
                recordStudentHelpRequest(latest.title, latest.evidence, latest.aiAction, "老師接力")
                renderStudentHelpSent(latest.title)
            } else {
                renderHandoff()
            }
        })
        bottomNav()
    }

    private fun renderHandoff() {
        if (role == Role.Student) {
            renderStudentSupportCenter()
            return
        }
        screen = Screen.Handoff
        shell("雲端志工接力", "把真人時間用在最值得的地方")
        val latestRequest = pendingStudentHelpRequests(1).firstOrNull()
        root.addView(preparedHandoffCard())
        root.addView(card("學生摘要", "${student.name}｜${student.location}｜${student.goal}\n目前心情：${mood.label}\n今日任務時間：${minutes} 分鐘", ColorToken.PrimarySoft))
        root.addView(card("斷點摘要", "${breakpoints.first().title}\n證據：${breakpoints.first().evidence}\nAI 已做：${breakpoints.first().aiAction}", ColorToken.WarningSoft))
        root.addView(card("建議陪伴語", "你願意回來做修復任務已經很好。今天我們只看一個規則，先不追完整進度。", ColorToken.SuccessSoft))
        root.addView(card("協作狀態", "志工回覆：${mentorReplyCount} 則\n協作紀錄：${collaborationNotes.size} 筆\n待同步：${offlinePendingCount} 件", ColorToken.Card))
        root.addView(remoteCollaborationStatusCard())
        recentCollaborationNotes(3).forEach { root.addView(collaborationNoteCard(it)) }
        latestRequest?.let {
            root.addView(ui.primaryButton("回覆最新學生求助") { renderStaffReplyComposer(it) })
        } ?: root.addView(ui.secondaryButton("查看待回覆求助") { renderActionQueue() })
        root.addView(ui.primaryButton("查看陪伴腳本") { renderMentorScript() })
        bottomNav()
    }

    private fun renderMap() {
        screen = Screen.Map
        shell("個人化學習地圖", "固定節奏比一次衝刺更重要")
        root.addView(card("本週總覽", "完成微任務：$completedTasks\n信心值：$confidence%\n目前重點：${modules[1].title}", ColorToken.PrimarySoft))
        root.addView(storageStatusCard())
        root.addView(questionBankSummaryCard())
        modules.forEach { root.addView(moduleCard(it)) }
        section("學習紀錄時間線")
        root.addView(timelineCard("今日答題紀錄", "已累積 ${learningEventCount} 筆學習事件，包含答題、反思、求助與修復。", ColorToken.Primary))
        root.addView(timelineCard("錯題修復", "已完成 ${repairedMistakeCount} 筆錯題修復，會進入老師端週報。", ColorToken.Success))
        root.addView(timelineCard("待同步紀錄", "目前有 ${offlinePendingCount} 筆本機紀錄等待同步。", if (offlinePendingCount > 0) ColorToken.Warning else ColorToken.Success))
        section("錯題修復紀錄")
        mistakeRecords.forEach { root.addView(mistakeCard(it)) }
        root.addView(ui.secondaryButton("查看正式題庫中心") { renderQuestionBank() })
        root.addView(ui.secondaryButton("查看離線任務包") { renderOfflinePacks() })
        section("陪伴時間線")
        supportMessages.forEach { root.addView(messageCard(it)) }
        root.addView(ui.secondaryButton("看週報") { renderWeeklyReport() })
        bottomNav()
    }

    private fun renderQuestionBank() {
        if (UserFlowContract.normalizedRole(role) == Role.Volunteer) {
            renderRoleBoundary(
                title = "題庫由老師管理",
                message = "志工端只需要知道學生今天卡在哪一題，以及可以怎麼陪練；題庫分級與派題由老師端處理。"
            )
            return
        }
        screen = Screen.QuestionBank
        val bankItems = stateStore.questionBankItems()
        val blueprint = QuestionBankContract.practiceBlueprint(
            items = bankItems,
            preferredTypes = preferredQuestionTypes,
            challengeWanted = challengeWanted
        )
        val skillCounts = bankItems.groupingBy { it.skill }.eachCount()
        val levelCounts = bankItems.groupingBy { it.level }.eachCount()
        shell("正式題庫中心", "依程度、單元、技能管理 English+ 題目")
        root.addView(questionBankSummaryCard())
        root.addView(metricRow(
            Metric("題目", "${blueprint.totalQuestions} 題", ColorToken.Primary),
            Metric("題型", "${blueprint.availableTypes.size} 類", ColorToken.Success),
            Metric("程度", blueprint.availableLevels.joinToString("/").ifBlank { "A1" }, ColorToken.Accent)
        ))
        root.addView(card("練習藍圖", blueprint.recommendation, ColorToken.SuccessSoft))
        root.addView(card("題庫狀態", "學生練習會使用已審核題目，依程度、單元與題型逐步切換，不會只停在同一批暖身題。", ColorToken.PrimarySoft))
        section("技能分類")
        skillCounts.forEach { (skill, count) ->
            root.addView(timelineCard(skill, "$count 題｜可作為老師後台篩選與分級派題依據", ColorToken.Primary))
        }
        section("題目清單預覽")
        root.addView(card("練習可用題庫", "目前學生練習會從完整 ${bankItems.size} 題中依序進行；這裡只預覽前 60 題，避免老師端頁面過長。", ColorToken.Card))
        bankItems.take(60).forEach { root.addView(questionBankItemCard(it)) }
        root.addView(ui.primaryButton("用目前題庫開始練習") {
            inDailyMission = false
            dailyMissionQuestions = emptyList()
            currentQuestionIndex = currentQuestionIndex.coerceIn(0, questions.lastIndex)
            renderLesson()
        })
        root.addView(ui.secondaryButton("回學習地圖") { renderMap() })
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
            syncRecords.map { OfflineSyncItem(it.title, "等待同步", it.detail, it.status) }
        }.forEach { root.addView(offlineSyncItemCard(it)) }
        root.addView(ui.primaryButton("補傳 1 筆待同步紀錄") {
            addOfflineSyncItem(
                title = "手動補傳檢查",
                category = "同步檢查",
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
        val queueState = CloudDataContract.buildQueueState(
            items = offlineSyncItems.map { CloudDataContract.queueItemFromOfflineSync(it) },
            networkAvailable = isNetworkAvailable(),
            lastSuccessAt = offlineSyncItems
                .filter { it.status.contains("已同步") }
                .maxOfOrNull { it.updatedAt } ?: 0L
        )
        root.addView(card(
            "同步佇列下一步",
            "狀態：${queueState.nextAction}\n待處理：${queueState.pendingCount}｜重試：${queueState.retryCount}｜需確認：${queueState.blockedCount}\n${queueState.message}",
            if (queueState.blockedCount > 0) ColorToken.WarningSoft else ColorToken.PrimarySoft
        ))
        root.addView(card("同步策略", "學生離線時仍可完成短任務；網路恢復後，微任務、反思、志工接力摘要會補傳。", ColorToken.PrimarySoft))
        offlineSyncItems.ifEmpty {
            syncRecords.map { OfflineSyncItem(it.title, "等待同步", it.detail, it.status) }
        }.forEach { root.addView(offlineSyncItemCard(it)) }
        root.addView(card("本機待同步明細", "學習事件：${learningEventCount} 筆\n志工回覆：${mentorReplyCount} 則\n協作紀錄：${collaborationNotes.size} 筆\n老師新增任務：${customTaskCount} 個", ColorToken.Card))
        root.addView(ui.primaryButton("全部標記為已同步") {
            stateStore.markOfflineSyncItemsSynced()
            refreshOfflineSyncState()
            persistState()
            recordLearningEvent("sync", "本機紀錄已標記同步", "待同步數已歸零，資料仍保留在裝置中。")
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
                else -> "目前連線尚未完成，已保留待補傳佇列。"
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
            shell("同步服務準備中", "可先離線保存學習紀錄")
            root.addView(card("目前狀態", "學習紀錄會先保存在這台裝置，之後再補傳。", ColorToken.WarningSoft))
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
        root.addView(card("下一步", "同步失敗不會清掉本機資料與待同步佇列。網路恢復後可以再重試。", ColorToken.Card))
        root.addView(ui.primaryButton("回同步中心") { renderSyncCenter() })
        bottomNav()
    }

    private fun renderRoster() {
        screen = Screen.Roster
        shell("學生列表", UserFlowContract.rosterSubtitle(role))
        currentRoster().forEach { row -> root.addView(studentRowCard(row)) }
        root.addView(ui.primaryButton("查看 ${student.name} 的斷點") { renderBreakpoints() })
        root.addView(ui.secondaryButton("查看接力優先序") { renderHandoffBoard() })
        bottomNav()
    }

    private fun renderStudentDetail(row: StudentRow) {
        screen = Screen.StudentDetail
        shell("${row.name} 的接力資料", UserFlowContract.rosterSubtitle(role))
        val detail = TeacherWorkspaceContract.studentDetail(
            row = row,
            notes = collaborationNotes,
            recentAnswerTitles = listOf(
                "今日任務 ${dailyQuestionDone.coerceAtLeast(0)}/${dailyQuestionGoal.coerceAtLeast(1)}",
                activeQuestion().concept,
                mistakeRecords.firstOrNull()?.concept ?: "尚無錯題紀錄"
            ),
            missionProgress = "${dailyQuestionDone.coerceAtLeast(0)}/${dailyQuestionGoal.coerceAtLeast(1)}"
        )
        root.addView(metricRow(
            Metric("風險", row.risk, if (row.risk == "高") ColorToken.Danger else ColorToken.Warning),
            Metric("求助", "${detail.helpRequestCount} 件", if (detail.helpRequestCount > 0) ColorToken.Warning else ColorToken.Success),
            Metric("進度", detail.missionProgress, ColorToken.Primary)
        ))
        root.addView(card("目前斷點", row.issue, if (row.risk == "高") ColorToken.WarningSoft else ColorToken.PrimarySoft))
        root.addView(card("最新狀態", "${row.status}\n最近紀錄：${detail.recentAnswers.joinToString("、")}", ColorToken.Card))
        val nextStep = if (UserFlowContract.normalizedRole(role) == Role.Volunteer) {
            if (row.risk == "高") "先用陪伴腳本降低挫折，再只帶同一概念兩題。" else "保留低壓陪伴節奏，不追加作業。"
        } else {
            if (row.risk == "高") "先確認是否需要老師回覆，再決定是否指派志工陪練。" else "保留低壓任務，觀察是否願意回來完成。"
        }
        root.addView(card(UserFlowContract.studentDetailActionTitle(role), nextStep, ColorToken.SuccessSoft))
        if (UserFlowContract.normalizedRole(role) == Role.Volunteer) {
            val request = CollaborationFlowContract.unansweredRequests(collaborationNotes, row.name).firstOrNull()
            request?.let {
                val action = VolunteerHandoffContract.actionForRequest(it, completed = false)
                root.addView(card("志工下一步", "${action.nextStep}\n\n腳本：${action.script}", ColorToken.PrimarySoft))
            }
            root.addView(ui.primaryButton("查看陪伴腳本") { renderMentorScript() })
        } else {
            root.addView(ui.primaryButton(if (detail.primaryAction == "write_teacher_reply") "回覆學生求助" else "安排下一個任務") { renderActionQueue() })
        }
        root.addView(ui.secondaryButton("回學生列表") { renderRoster() })
        bottomNav()
    }

    private fun renderHandoffBoard() {
        screen = Screen.Mentor
        shell("接力優先序", "把有限的真人時間安排到最需要的地方")
        val pendingRequests = pendingStudentHelpRequests()
        val replyCount = collaborationNotes.count { CollaborationFlowContract.isStaffReply(it) }
        root.addView(metricRow(
            Metric("待回覆", "${pendingRequests.size}", if (pendingRequests.isNotEmpty()) ColorToken.Warning else ColorToken.Success),
            Metric("已回覆", "$replyCount", ColorToken.Success),
            Metric("協作", "${collaborationNotes.size}", ColorToken.Primary)
        ))
        root.addView(card("排序規則", "學生主動求助 > 高風險情緒斷點 > 連續錯題 > 重複退出 > 一般複習。", ColorToken.PrimarySoft))
        root.addView(remoteCollaborationStatusCard())
        section("學生求助")
        if (pendingRequests.isEmpty()) {
            root.addView(card("目前沒有待回覆求助", "可以先看高風險學生，或同步遠端協作紀錄。", ColorToken.SuccessSoft))
        } else {
            pendingRequests.forEach {
                if (UserFlowContract.normalizedRole(role) == Role.Volunteer) {
                    val action = VolunteerHandoffContract.actionForRequest(it, completed = false)
                    root.addView(card("志工下一步：${action.studentName}", "${action.nextStep}\n\n腳本：${action.script}", ColorToken.PrimarySoft))
                }
                root.addView(studentHelpRequestCard(it))
            }
        }
        handoffPriorities.forEach { root.addView(priorityCard(it)) }
        section("最新協作紀錄")
        recentCollaborationNotes(4).forEach { root.addView(collaborationNoteCard(it)) }
        root.addView(ui.secondaryButton("查看待辦處理佇列") { renderActionQueue() })
        if (UserFlowContract.isTeacherRole(role)) {
            root.addView(ui.primaryButton("分享最新老師報告") { shareTeacherReport(buildDemoReportText()) })
        } else {
            root.addView(ui.primaryButton("查看陪伴腳本") { renderMentorScript() })
        }
        bottomNav()
    }

    private fun renderActionQueue() {
        screen = Screen.ActionQueue
        shell(
            if (UserFlowContract.isTeacherRole(role)) "老師待辦佇列" else "志工接力佇列",
            if (UserFlowContract.isTeacherRole(role)) "先處理學生求助，再安排班級工作" else "只處理需要真人陪伴的下一步"
        )
        val pendingRequests = pendingStudentHelpRequests()
        val summary = CollaborationFlowContract.staffQueueSummary(collaborationNotes, teacherActions.size, actionDoneCount)
        val roleQueue = CollaborationFlowContract.staffRoleQueue(collaborationNotes, currentAccount().roleLabel)
        root.addView(metricRow(
            Metric("待辦", "${summary.totalPending} 件", if (summary.totalPending > 0) ColorToken.Warning else ColorToken.Success),
            Metric("已處理", "${summary.completed} 件", ColorToken.Success),
            Metric("協作", "${collaborationNotes.size} 筆", ColorToken.Primary)
        ))
        root.addView(card(
            if (UserFlowContract.isTeacherRole(role)) "老師今日重點" else "志工今日重點",
            if (roleQueue.meaning == "teacher_follow_up") {
                "先回覆學生主動求助，再處理班級待辦。每一次回覆都會回到學生端的支持頁。"
            } else {
                "只處理需要真人陪伴的求助與接力，不進入老師的班級管理待辦。"
            },
            ColorToken.PrimarySoft
        ))
        val queueLabel = if (roleQueue.meaning == "teacher_follow_up") "老師追蹤" else "志工陪伴"
        root.addView(ui.body("佇列：$queueLabel｜待回覆：${roleQueue.helpPending}｜本角色已回覆：${roleQueue.repliedCount}", ColorToken.Muted))
        root.addView(remoteCollaborationStatusCard())
        section("學生求助待回覆")
        if (pendingRequests.isEmpty()) {
            root.addView(card("沒有學生求助待回覆", "目前可以處理一般待辦，或查看接力優先序。", ColorToken.SuccessSoft))
        } else {
            pendingRequests.forEach { root.addView(studentHelpRequestCard(it)) }
        }
        if (UserFlowContract.isTeacherRole(role)) {
            section("班級待辦")
            teacherActions.forEach { root.addView(teacherActionCard(it)) }
            if (summary.normalPending > 0) {
                root.addView(ui.primaryButton("標記一件班級待辦已處理") {
                    actionDoneCount = (actionDoneCount + 1).coerceAtMost(teacherActions.size)
                    addCollaborationNote(
                        actor = currentAccount().displayName,
                        roleLabel = currentAccount().roleLabel,
                        target = "待辦處理佇列",
                        note = "已處理 1 件班級待辦，下一步交由負責人依摘要接力。",
                        status = "已處理"
                    )
                    renderActionQueue()
                })
            } else {
                root.addView(card("班級待辦已清空", "學生求助與班級待辦分開計算，不會因為回覆學生就誤標一般待辦完成。", ColorToken.SuccessSoft))
            }
        } else {
            section("志工下一步")
            root.addView(card("只做陪伴與回覆", "志工端不顯示老師的班級管理待辦。先看學生求助，再用陪伴腳本留下接力紀錄。", ColorToken.PrimarySoft))
            root.addView(ui.primaryButton("查看陪伴腳本") { renderMentorScript() })
        }
        root.addView(ui.primaryButton("查看接力優先序") { renderHandoffBoard() })
        bottomNav()
    }

    private fun renderRemoteCollaborationSync(pushFirst: Boolean) {
        screen = Screen.ActionQueue
        if (!stateStore.hasCloudBackend()) {
            shell("接力同步準備中", "目前先查看這台裝置的接力紀錄")
            root.addView(card("目前狀態", "接力紀錄會先保存在這台裝置。", ColorToken.WarningSoft))
            root.addView(ui.primaryButton("前往同步中心設定") { renderSyncCenter() })
            root.addView(ui.secondaryButton("回接力優先序") { renderHandoffBoard() })
            bottomNav()
            return
        }

        shell("同步多人協作", if (pushFirst) "先推送本機協作，再拉取遠端更新" else "正在拉取遠端協作紀錄")
        root.addView(card("協作後端", stateStore.cloudBackendUrl(), ColorToken.PrimarySoft))
        root.addView(card("同步班級", currentAccount().classCode, ColorToken.Card))
        root.addView(card(
            "同步規則",
            "協作紀錄會自動避免重複；同一筆接力在不同裝置更新時，保留較新的版本。學生端不能建立正式接力紀錄，老師與志工可以寫入。",
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
        root.addView(card("下一步", "協作同步失敗時，老師與志工仍可先保存這次處理紀錄；等網路恢復後再同步。", ColorToken.Card))
        root.addView(ui.primaryButton("回接力優先序") { renderHandoffBoard() })
        bottomNav()
    }

    private fun renderStudentManager() {
        if (!UserFlowContract.canUseTeacherTool(role, Screen.StudentManager)) {
            renderRoleBoundary(
                title = "學生資料由老師管理",
                message = "志工端只顯示陪伴必要背景，不提供新增或管理學生資料的入口。"
            )
            return
        }
        screen = Screen.StudentManager
        shell("學生資料管理", "整理班級學生、分組與追蹤狀態")
        root.addView(classContextCard())
        root.addView(metricRow(
            Metric("管理學生", "${managedStudentCount} 位", ColorToken.Primary),
            Metric("高風險", "1 位", ColorToken.Danger),
            Metric("已處理待辦", "${actionDoneCount} 件", ColorToken.Success)
        ))
        root.addView(card("管理重點", "先看需要關懷的學生，再決定要新增任務、安排志工，或回到週報確認進度。", ColorToken.PrimarySoft))
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
        screen = Screen.AiLab
        shell("AI 支持與任務建議", "先把學生今天能做的下一步整理清楚")
        root.addView(aiMissionPlanCard())
        root.addView(openAiStatusCard())
        root.addView(aiProxyEndpointCard())
        root.addView(openAiKeyEntryCard())
        root.addView(card("AI 會用在哪裡", "每日任務建議、錯題詳解、學生語氣回饋與接力摘要。沒有可用連線時，English+ 仍會提供內建學習提示。", ColorToken.PrimarySoft))
        aiScenarios.forEach { root.addView(aiScenarioCard(it)) }
        root.addView(ui.primaryButton("生成本題支持回饋") { renderLiveAiFeedback() })
        root.addView(ui.secondaryButton("改用備援回饋生成") { renderGeneratedAiFeedback() })
        bottomNav()
    }

    private fun aiMissionPlanCard(): View {
        val plan = AiLearningPlanContract.localDailyMissionPlan(
            moodLabel = mood.label,
            minutes = minutes,
            challengeWanted = challengeWanted,
            preferredTypes = preferredQuestionTypes,
            availableTypes = UserFlowContract.questionTypes
        )
        val box = ui.sectionBand(ColorToken.SuccessSoft)
        box.addView(ui.statusPill(plan.routeLabel, ColorToken.Success))
        box.addView(ui.label("今日任務建議", 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(plan.studentMessage, "#334155"))
        box.addView(metricRow(
            Metric("題數", "${plan.questionGoal} 題", ColorToken.Primary),
            Metric("題型", plan.recommendedTypes.joinToString("、"), ColorToken.Success),
            Metric("時間", "${minutes} 分", ColorToken.Accent)
        ))
        box.addView(ui.body(plan.handoffHint, ColorToken.Muted).apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun openAiStatusCard(): View {
        val hasKey = stateStore.hasOpenAiApiKey()
        val box = ui.container(
            if (hasKey) ColorToken.SuccessSoft else ColorToken.WarningSoft,
            ColorToken.Border
        )
        box.addView(ui.statusPill(if (hasKey) "AI 連線可用" else "內建回饋可用", if (hasKey) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label(if (hasKey) "AI 回饋可連線生成" else "目前提供內建回饋", 18, ColorToken.Ink, true).apply {
            layoutParams = ui.fullWidthParams()
        })
        box.addView(ui.body(
            if (hasKey) {
                "生成時會送出目前題目、情緒狀態與錯題次數；如果網路或外部服務失敗，會自動改用備援回饋。"
            } else {
                "學生仍會看到可用的任務建議與錯題提示；正式連線可由安全後端或內測憑證啟用。"
            }
        ))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun aiProxyEndpointCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label("安全後端連線", 18, ColorToken.Ink, true))
        box.addView(ui.body("建議使用學校或團隊的安全後端連線。手機只送學習脈絡，不保存服務憑證。"))
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
        box.addView(ui.primaryButton("儲存安全後端連線") {
            stateStore.saveAiProxyEndpoint(input.text.toString())
            recordLearningEvent("ai_proxy_config", "已更新 AI Proxy 端點", stateStore.aiProxyEndpoint().ifBlank { "已清空" })
            renderAiLab()
        })
        box.addView(ui.secondaryButton("清除安全後端連線") {
            stateStore.saveAiProxyEndpoint("")
            recordLearningEvent("ai_proxy_config", "已清除 AI Proxy 端點", "AI 回饋會回到本機 Key 或備援模式。")
            renderAiLab()
        })
        return ui.margins(box, 0, 0, 0, 12)
    }

    private fun openAiKeyEntryCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label("外部 AI 連線憑證", 18, ColorToken.Ink, true))
        box.addView(ui.body("這是內測用的本機連線方式。課堂展示時可以留空，系統會使用備援回饋。"))

        val input = EditText(this).apply {
            hint = if (stateStore.hasOpenAiApiKey()) "已設定，可貼上新的憑證覆蓋" else "貼上內測連線憑證"
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

        box.addView(ui.primaryButton("儲存並啟用外部 AI") {
            val key = input.text.toString().trim()
            if (key.startsWith("sk-")) {
                stateStore.saveOpenAiApiKey(key)
                recordLearningEvent("ai_config", "已更新外部 AI 連線憑證", "外部 AI 模式已可在支持頁呼叫。")
            } else {
                recordLearningEvent("ai_config", "外部 AI 連線憑證未更新", "輸入內容不是支援格式，維持原本設定。")
            }
            renderAiLab()
        })
        box.addView(ui.secondaryButton("清除憑證，改用備援回饋") {
            stateStore.saveOpenAiApiKey("")
            recordLearningEvent("ai_config", "已清除外部 AI 連線憑證", "AI 回饋已回到備援模式。")
            renderAiLab()
        })
        return ui.margins(box, 0, 0, 0, 12)
    }

    private fun renderLiveAiFeedback() {
        val decision = stateStore.aiSecurityDecision(productionMode = true)
        if (!decision.canCallRemoteAi) {
            recordLearningEvent("ai_security_fallback", "Remote AI blocked by security contract", decision.warning)
            renderGeneratedAiFeedback("安全檢查：目前改用備援回饋，不會從手機端送出正式服務憑證。")
            return
        }
        val apiKey = stateStore.openAiApiKey()
        if (!stateStore.hasAiProxyEndpoint() && !stateStore.hasOpenAiApiKey()) {
            recordLearningEvent("ai_fallback", "未設定外部 AI 連線憑證", "使用備援 AI 回饋。")
            renderGeneratedAiFeedback("目前使用備援回饋。")
            return
        }
        val q = activeQuestion()
        screen = Screen.AiLab
        shell("AI 生成中", "正在生成支持回饋")
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
                    recordLearningEvent("ai_fallback", "外部 AI 呼叫失敗", error.message ?: "未知錯誤")
                    renderGeneratedAiFeedback("外部 AI 暫時無法回應，已改用備援回饋。")
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
        recordLearningEvent("ai_live", "外部 AI 生成回饋", result.diagnosis)
        root.addView(ui.primaryButton("回今日任務") { renderLesson() })
        root.addView(ui.secondaryButton("回 AI 支持") { renderAiLab() })
        bottomNav()
    }

    private fun renderGeneratedAiFeedback(notice: String? = null) {
        screen = Screen.AiLab
        val q = activeQuestion()
        shell("AI 生成結果模擬", "依目前題型與錯題狀態產生個人化回饋")
        notice?.let { root.addView(card("AI 狀態", it, ColorToken.WarningSoft)) }
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
        if (!UserFlowContract.canUseVolunteerTool(role, Screen.MentorScript)) {
            renderRoleBoundary(
                title = "這是志工陪伴工具",
                message = "老師端負責判斷、回覆與派工；陪伴腳本只放在志工端，避免老師工作台混入陪練流程。"
            )
            return
        }
        screen = Screen.MentorScript
        shell("志工陪伴腳本", "降低志工準備成本，也避免學生被再次打擊")
        root.addView(card("開場 30 秒", "先肯定：你願意回來做修復任務已經很好。今天我們只看一個規則，不看整章。", ColorToken.SuccessSoft))
        root.addView(card("引導問題", "1. He 是一個人還是很多人？\n2. 一個人通常搭配 is 還是 are？\n3. 你可以自己造一句 He is 嗎？", ColorToken.PrimarySoft))
        root.addView(card("結束紀錄", "能完成 2 題再加 They are；如果仍卡住，記錄為高優先斷點，不追加作業。", ColorToken.WarningSoft))
        root.addView(ui.secondaryButton("使用腳本並留下志工紀錄") {
            mentorReplyCount += 1
            val handoffNote = VolunteerHandoffContract.internalHandoffNote(
                volunteerName = currentAccount().displayName,
                studentName = student.name,
                summary = "已使用陪伴腳本完成一次低壓接力；學生能先回答 He is，暫不加新題型。",
                createdAt = System.currentTimeMillis()
            )
            addCollaborationNote(
                actor = handoffNote.actor,
                roleLabel = handoffNote.role,
                target = handoffNote.target,
                note = handoffNote.note,
                status = handoffNote.status
            )
            renderMentorScript()
        })
        root.addView(ui.primaryButton("回志工工作台") {
            role = Role.Volunteer
            renderHome()
        })
        bottomNav()
    }

    private fun renderWeeklyReport() {
        if (!UserFlowContract.canUseTeacherTool(role, Screen.Report)) {
            renderRoleBoundary(
                title = "報告由老師端查看",
                message = "志工端只需要看到接力任務與必要學生背景；班級報告、週報與匯出功能保留在老師端。"
            )
            return
        }
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
        root.addView(ui.primaryButton("分享本週週報") { shareTeacherReport(buildDemoReportText()) })
        root.addView(ui.secondaryButton("查看接力優先序") { renderHandoffBoard() })
        bottomNav()
    }

    private fun renderExportReport() {
        screen = Screen.Report
        refreshOfflineSyncState()
        val reportText = buildDemoReportText()
        val file = writeDemoReport(reportText)
        shell("週報已產生", "把學生進度與接力紀錄整理成可分享摘要")
        root.addView(card("匯出檔案", file.absolutePath, ColorToken.SuccessSoft))
        root.addView(card("報告內容預覽", reportText, ColorToken.Card))
        root.addView(ui.secondaryButton("回本週學習週報") { renderWeeklyReport() })
        root.addView(ui.primaryButton("分享週報") { shareTeacherReport(reportText) })
        bottomNav()
    }

    private fun renderMentorChecks() {
        screen = Screen.Report
        shell("服務品質檢核", "確認陪伴流程是否真的幫得上學生")
        root.addView(card("檢核目的", "這頁協助老師與志工確認：學生是否被接住、任務是否低壓、接力是否有下一步。", ColorToken.PrimarySoft))
        root.addView(reportShowcaseCard())
        mentorChecks.forEach { root.addView(mentorCheckCard(it)) }
        root.addView(card("下一步", "先看高風險學生是否有明確接力，再確認低風險學生是否保有自主練習節奏。", ColorToken.WarningSoft))
        root.addView(ui.primaryButton("回本週週報") { renderWeeklyReport() })
        bottomNav()
    }

    private fun reportShowcaseCard(): View {
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.statusPill("本週摘要", ColorToken.Primary))
        box.addView(ui.label("English+ 學習支持狀態", 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(
            "本週重點不是排名，而是學生在哪些題型卡住、哪些斷點已被修復、哪些狀況需要老師或志工接力。"
        ))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun buildDemoReportText(): String {
        return ReportExportContract.renderText(ReportKind.Class, buildReportContext())
    }

    private fun buildReportContext(): ReportContext {
        val snapshot = stateStore.storageSnapshot()
        val latestCollaboration = collaborationNotes.firstOrNull()?.note ?: "尚未建立真人接力紀錄。"
        val latestSync = offlineSyncItems.firstOrNull()?.let { "${it.title} / ${it.status}" } ?: "尚未建立同步佇列。"
        return ReportContext(
            studentName = student.name,
            classCode = currentAccount().classCode,
            moodLabel = mood.label,
            missionProgress = "${dailyQuestionDone.coerceAtLeast(0)}/${dailyQuestionGoal.coerceAtLeast(1)}",
            supportSummary = "學習事件 ${snapshot.eventCount} 筆，協作紀錄 ${snapshot.collaborationCount} 筆。最新協作：$latestCollaboration",
            handoffSummary = "主要斷點：${breakpoints.first().title}；真人接力建議：${breakpoints.first().mentorAction}",
            syncSummary = "$latestSync；待補傳 ${snapshot.pendingSyncCount} 筆，已下載離線包 ${snapshot.downloadedPackCount} 包。",
            generatedAtLabel = "本週"
        )
    }

    private fun writeDemoReport(reportText: String): File {
        val targetDir = getExternalFilesDir(null) ?: filesDir
        val pack = ReportExportContract.exportPackage(ReportKind.Class, buildReportContext())
        var textFile: File? = null
        pack.files.forEach { boundary ->
            val file = File(targetDir, boundary.fileName)
            file.writeText(boundary.content, Charsets.UTF_8)
            if (boundary.mimeType.startsWith("text/plain")) {
                textFile = file
            }
        }
        val exportedTextFile = textFile ?: File(targetDir, "english_plus_class_report.txt").apply {
            writeText(reportText, Charsets.UTF_8)
        }
        recordLearningEvent("report_export", "已匯出班級支持週報", exportedTextFile.absolutePath)
        addOfflineSyncItem("班級支持週報匯出", "報告資料", "已產生 English+ 班級支持週報，可分享給老師。")
        return exportedTextFile
    }

    private fun writeDemoReportHtml(reportText: String): File {
        val targetDir = getExternalFilesDir(null) ?: filesDir
        val file = File(targetDir, "english_plus_class_report.html")
        file.writeText(ReportExportContract.renderHtml("English+ 班級支持週報", buildReportContext(), reportText), Charsets.UTF_8)
        recordLearningEvent("report_export_html", "已匯出 HTML 老師報告", file.absolutePath)
        return file
    }

    private fun buildDemoReportHtml(reportText: String): String {
        return ReportExportContract.renderHtml("English+ 班級支持週報", buildReportContext(), reportText)
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
        val page = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            background = ui.solid(ColorToken.Surface)
        }
        val scroll = ScrollView(this)
        root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(ui.dp(16), ui.dp(24), ui.dp(16), ui.dp(24))
            background = ui.solid(ColorToken.Surface)
        }
        navRoot = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(ui.dp(8), ui.dp(6), ui.dp(8), ui.dp(8))
            background = ui.solid(ColorToken.Surface)
        }
        scroll.addView(root)
        page.addView(scroll, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        page.addView(navRoot, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        setContentView(page)
        root.addView(ui.eyebrow("${navigationArea()} / English+"))
        root.addView(ui.label(title, 28, ColorToken.Ink, true).apply { setPadding(0, ui.dp(8), 0, ui.dp(4)) })
        root.addView(ui.body(subtitle, ColorToken.Muted))
        root.addView(ui.space(16))
    }

    private fun renderRoleBoundary(title: String, message: String) {
        screen = Screen.Home
        shell(title, "已為你保留正確工作台")
        root.addView(card("你現在使用的是${UserFlowContract.roleTitle(role)}", message, ColorToken.WarningSoft))
        root.addView(ui.primaryButton("回到我的工作台") { renderHome() })
        bottomNav()
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
        row.addView(ui.chipButton("老師端", UserFlowContract.normalizedRole(role) == Role.Teacher) {
            val teacherAccount = accountList().firstOrNull { AuthContract.normalizeRole(it.roleLabel) == AuthContract.ROLE_TEACHER } ?: currentAccount()
            selectAccount(teacherAccount)
            renderHome()
        })
        row.addView(ui.chipButton("志工端", UserFlowContract.normalizedRole(role) == Role.Volunteer) {
            val volunteerAccount = accountList().firstOrNull { AuthContract.normalizeRole(it.roleLabel) == AuthContract.ROLE_VOLUNTEER } ?: currentAccount()
            selectAccount(volunteerAccount)
            renderHome()
        })
        return ui.margins(row, 0, 8, 0, 16)
    }

    private fun bottomNav() {
        navRoot.removeAllViews()
        val nav = ui.container(ColorToken.Card, ColorToken.Border).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(ui.dp(8), ui.dp(8), ui.dp(8), ui.dp(8))
        }
        when (UserFlowContract.normalizedRole(role)) {
            Role.Student -> {
            nav.addView(navDestination("首", "首頁", screen == Screen.Home || screen == Screen.Account) { renderHome() }, ui.weightParams())
            nav.addView(navDestination("練", "練習", screen == Screen.Lesson || screen == Screen.AiCoach || screen == Screen.Contract || screen == Screen.Reflection || screen == Screen.QuestionBank) { renderTaskQueue() }, ui.weightParams())
            nav.addView(navDestination("助", "支持", screen == Screen.HelpRequest || screen == Screen.Handoff) { renderStudentSupportCenter() }, ui.weightParams())
            nav.addView(navDestination("圖", "地圖", screen == Screen.Map) { renderMap() }, ui.weightParams())
            nav.addView(navDestination("檔", "檔案", screen == Screen.Profile) { renderProfile() }, ui.weightParams())
            }
            Role.Teacher -> {
            nav.addView(navDestination("今", "今日", screen == Screen.Home || screen == Screen.Account) { renderHome() }, ui.weightParams())
            nav.addView(navDestination("生", "學生", screen == Screen.Roster || screen == Screen.StudentDetail || screen == Screen.StudentManager) { renderRoster() }, ui.weightParams())
            nav.addView(navDestination("接", "接力", screen == Screen.Breakpoints || screen == Screen.Handoff || screen == Screen.ActionQueue || screen == Screen.Mentor) { renderHandoffBoard() }, ui.weightParams())
            nav.addView(navDestination("題", "題庫", screen == Screen.QuestionBank) { renderQuestionBank() }, ui.weightParams())
            nav.addView(navDestination("報", "報告", screen == Screen.Report) { renderWeeklyReport() }, ui.weightParams())
            }
            Role.Volunteer, Role.Mentor -> {
            nav.addView(navDestination("今", "今日", screen == Screen.Home || screen == Screen.Account) { renderHome() }, ui.weightParams())
            nav.addView(navDestination("接", "接力", screen == Screen.Breakpoints || screen == Screen.Handoff || screen == Screen.ActionQueue || screen == Screen.Mentor) { renderHandoffBoard() }, ui.weightParams())
            nav.addView(navDestination("生", "學生", screen == Screen.Roster || screen == Screen.StudentDetail) { renderRoster() }, ui.weightParams())
            nav.addView(navDestination("雲", "同步", screen == Screen.SyncCenter) { renderSyncCenter() }, ui.weightParams())
            nav.addView(navDestination("陪", "腳本", screen == Screen.MentorScript) { renderMentorScript() }, ui.weightParams())
            }
        }
        navRoot.addView(ui.margins(nav, 0, 0, 0, 0))
    }

    private fun navigationArea(): String = when (screen) {
        Screen.Home, Screen.Account -> if (role == Role.Student) "首頁" else "今日"
        Screen.Lesson, Screen.AiCoach, Screen.Contract, Screen.Reflection -> "練習"
        Screen.QuestionBank -> if (UserFlowContract.isTeacherRole(role)) "題庫" else "練習"
        Screen.HelpRequest, Screen.Intervention -> "支持"
        Screen.Roster, Screen.StudentDetail, Screen.StudentManager -> "學生"
        Screen.Breakpoints, Screen.Handoff, Screen.ActionQueue, Screen.Mentor -> "接力"
        Screen.MentorScript -> "腳本"
        Screen.SyncCenter -> "同步"
        Screen.Report -> "報告"
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

    private fun scaleSelector(
        selected: Int,
        lowLabel: String,
        highLabel: String,
        color: String,
        onSelect: (Int) -> Unit
    ): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        (1..5).forEach { value ->
            row.addView(ui.chipButton(value.toString(), value == selected) { onSelect(value) }, ui.weightParams())
        }
        box.addView(row)
        val note = "$lowLabel 1  ·  $highLabel 5"
        box.addView(ui.body(note, color).apply { setPadding(0, ui.dp(8), 0, 0) })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun twoChoiceSelector(
        left: String,
        right: String,
        leftSelected: Boolean,
        onLeft: () -> Unit,
        onRight: () -> Unit
    ): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        row.addView(ui.chipButton(left, leftSelected) { onLeft() }, ui.weightParams())
        row.addView(ui.chipButton(right, !leftSelected) { onRight() }, ui.weightParams())
        box.addView(row)
        box.addView(ui.body(
            if (leftSelected) {
                "今天會優先放入較有挑戰的題型與程度。"
            } else {
                "今天會先選低壓題，不急著加難。"
            },
            ColorToken.Muted
        ).apply { setPadding(0, ui.dp(8), 0, 0) })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun questionTypeSelector(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        UserFlowContract.questionTypes.chunked(2).forEach { rowItems ->
            val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
            rowItems.forEach { type ->
                row.addView(ui.chipButton(type, preferredQuestionTypes.contains(type)) {
                    if (preferredQuestionTypes.contains(type)) {
                        if (preferredQuestionTypes.size > 1) preferredQuestionTypes.remove(type)
                    } else {
                        preferredQuestionTypes.add(type)
                    }
                    renderCheckIn()
                }, ui.weightParams())
            }
            if (rowItems.size == 1) row.addView(ui.space(1), ui.weightParams())
            box.addView(row)
        }
        box.addView(ui.body("已選：${preferredQuestionTypes.joinToString("、")}", ColorToken.Primary).apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun planPreviewCard(): View {
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.statusPill("今日小計畫", ColorToken.Primary))
        box.addView(ui.label(mood.planName, 20, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("任務長度：${minutes} 分鐘\n題目數：${recommendedQuestionGoal()} 題\n題型：${preferredQuestionTypes.joinToString("、")}", "#334155"))
        box.addView(ui.body(if (challengeWanted) "今天會放入較有挑戰的題目。" else "今天先以穩定完成為主。", ColorToken.Primary).apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
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
        box.addView(ui.body("練習題已整理成分級題庫，保留 level、unit、skill、source 欄位，後續可接分級題庫或老師後台匯入。", "#334155"))
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
        box.addView(ui.statusPill(if (hasBackend) "同步連線可用" else "等待同步連線", if (hasBackend) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label(if (hasBackend) "可同步到班級空間" else "目前先保存到這台裝置", 18, ColorToken.Ink, true).apply {
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
        box.addView(ui.statusPill(if (stateStore.hasRemoteAuthEndpoint()) "學校帳號可用" else "班級帳號可用", color))
        box.addView(ui.label("${account.displayName}｜${account.roleLabel}", 17, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(10), 0, ui.dp(4))
        })
        box.addView(ui.body("班級/群組代碼：${account.classCode}", "#334155"))
        box.addView(ui.body("可用班級帳號，也可在帳號中心接校內登入服務。", ColorToken.Muted).apply {
            setPadding(0, ui.dp(6), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun remoteAuthStatusCard(): View {
        val hasEndpoint = stateStore.hasRemoteAuthEndpoint()
        val status = AuthContract.authBoundaryStatus(
            provider = if (hasEndpoint) AuthContract.PROVIDER_SCHOOL else AuthContract.PROVIDER_DEMO,
            endpoint = stateStore.remoteAuthEndpoint(),
            hasRemoteCredential = hasEndpoint
        )
        val box = ui.container(if (hasEndpoint) ColorToken.SuccessSoft else ColorToken.WarningSoft, ColorToken.Border)
        box.addView(ui.statusPill(if (hasEndpoint) "學校帳號可用" else "班級帳號可用", if (hasEndpoint) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label(if (hasEndpoint) "登入狀態" else "班級帳號", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body("${status.message}\n${stateStore.authSessionSummary()}", "#334155"))
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
            "學生帳號：$studentCount\n老師/志工帳號：$staffCount\n正式登入：$endpointState\n角色來源：正式帳號權限或班級帳號設定",
            "#334155"
        ))
        box.addView(ui.body(
            "目前保留班級測試帳號，避免沒有學校帳號服務時課堂流程中斷；公開使用前會改由正式帳號權限管理。",
            ColorToken.Muted
        ).apply { setPadding(0, ui.dp(8), 0, 0) })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun remoteAuthLoginCard(): View {
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label("正式登入設定", 18, ColorToken.Ink, true))
        box.addView(ui.body("若學校已有正式登入服務，可以貼上登入網址並測試帳號；沒有正式服務時，班級帳號仍可完整操作課堂流程。"))

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
        val summary = DailyMissionContract.summary(
            minutes = minutes,
            goal = recommendedQuestionGoal(),
            preferredTypes = preferredQuestionTypes,
            challengeWanted = challengeWanted
        )
        val box = ui.sectionBand(ColorToken.PrimarySoft)
        box.addView(ui.statusPill(summary.routeLabel, ColorToken.Accent))
        box.addView(ui.label(summary.title, 23, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(metricRow(
            Metric("時間", "${minutes} 分", ColorToken.Primary),
            Metric("概念", "1 個", ColorToken.Success),
            Metric("完成", "${recommendedQuestionGoal()} 題", ColorToken.Accent)
        ))
        box.addView(ui.body(summary.description, "#334155"))
        box.addView(ui.body(summary.progressRule, ColorToken.Primary).apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        box.addView(ui.primaryButton("開始今日題目任務") { startDailyMission() })
        return ui.margins(box, 0, 8, 0, 16)
    }

    private fun taskRouteCard(): View {
        val aiPlan = AiLearningPlanContract.localDailyMissionPlan(
            moodLabel = mood.label,
            minutes = minutes,
            challengeWanted = challengeWanted,
            preferredTypes = preferredQuestionTypes,
            availableTypes = UserFlowContract.questionTypes
        )
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.statusPill(aiPlan.routeLabel, ColorToken.Primary))
        box.addView(ui.label("照今天狀態安排題目", 18, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(aiPlan.studentMessage, "#334155"))
        box.addView(ui.body(aiPlan.handoffHint, ColorToken.Muted).apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        box.addView(flowStrip("開始題組", "答對累積", "完成今日任務"))
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun lessonFocusCard(): View {
        val box = ui.container(ColorToken.PrimarySoft, ColorToken.Border)
        box.addView(ui.statusPill(if (inDailyMission) "今日任務" else "自由練習", ColorToken.Primary))
        box.addView(ui.label(if (inDailyMission) "完成今日題組" else "自己選節奏練習", 19, ColorToken.Ink, true).apply {
            setPadding(0, ui.dp(12), 0, ui.dp(4))
        })
        box.addView(ui.body(if (inDailyMission) {
            "上方進度只計算今天題目任務；答錯不會增加，也不會跳題。"
        } else {
            "自由練習不顯示每日進度條，適合完成任務後再挑戰。"
        }, "#334155"))
        box.addView(ui.body("答錯會改變支持路徑，不會把你推進更難的題目。", ColorToken.Success).apply {
            setPadding(0, ui.dp(8), 0, 0)
        })
        return ui.margins(box, 0, 8, 0, 12)
    }

    private fun lessonSupportCard(): View {
        val fill = if (wrongAttempts > 0) ColorToken.WarningSoft else ColorToken.Card
        val box = ui.container(fill, ColorToken.Border)
        box.addView(ui.statusPill("即時狀態", if (wrongAttempts > 0) ColorToken.Warning else ColorToken.Success))
        box.addView(metricRow(
            Metric(
                if (inDailyMission) "今日" else "題庫",
                if (inDailyMission) "$dailyQuestionDone/$dailyQuestionGoal" else "${currentQuestionIndex + 1}/${questions.size}",
                ColorToken.Primary
            ),
            Metric("卡住", "$wrongAttempts/3", if (wrongAttempts > 0) ColorToken.Warning else ColorToken.Success),
            Metric("信心", "$confidence%", ColorToken.Accent)
        ))
        box.addView(ui.body(lastAnswerMessage, "#334155"))
        if (DailyMissionContract.shouldShowProgress(inDailyMission, dailyQuestionGoal)) {
            val remaining = DailyMissionContract.remaining(
                goal = dailyQuestionGoal,
                done = dailyQuestionDone
            )
            box.addView(ui.body("今日任務剩 $remaining 題。完成後會出現達標提示。", ColorToken.Primary).apply {
                setPadding(0, ui.dp(8), 0, 0)
            })
        }
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

    private fun collaborationField(note: String, label: String): String {
        return note.lineSequence()
            .firstOrNull { it.startsWith(label) }
            ?.removePrefix(label)
            ?.trim()
            .orEmpty()
    }

    private fun visibleReplyText(reply: CollaborationNote): String {
        return reply.note.removePrefix("[read] ").trim()
    }

    private fun studentHelpRequestCard(request: CollaborationNote): View {
        val box = ui.container(ColorToken.WarningSoft, ColorToken.Border)
        val reason = collaborationField(request.note, "求助原因：").ifBlank { "學生主動求助" }
        val studentText = collaborationField(request.note, "學生說：").ifBlank { request.note }
        val question = collaborationField(request.note, "目前題目：")
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(request.target, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill("待回覆", ColorToken.Warning))
        box.addView(top)
        box.addView(ui.body("$reason｜${request.actor}｜${request.role}", ColorToken.Muted).apply { setPadding(0, ui.dp(7), 0, 0) })
        box.addView(ui.body("學生說：$studentText", "#334155"))
        if (question.isNotBlank()) {
            box.addView(ui.body("目前題目：$question", ColorToken.Muted))
        }
        box.addView(ui.primaryButton("回覆這位學生") { renderStaffReplyComposer(request) })
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun renderStaffReplyComposer(request: CollaborationNote) {
        screen = Screen.ActionQueue
        shell("回覆學生", "讓學生看得懂下一步，而不是只留下內部紀錄")
        root.addView(card("學生求助", request.note, ColorToken.WarningSoft))
        val q = activeQuestion()
        val input = EditText(this).apply {
            setText(CollaborationFlowContract.defaultStaffReply(request.target, q.concept))
            minLines = 4
            maxLines = 8
            textSize = 16f
            setTextColor(Color.parseColor(ColorToken.Ink))
            setHintTextColor(Color.parseColor(ColorToken.Muted))
            background = ui.rounded(ColorToken.Surface, ColorToken.Border)
            setPadding(ui.dp(14), ui.dp(12), ui.dp(14), ui.dp(12))
            layoutParams = ui.fullWidthParams()
        }
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        box.addView(ui.label("回覆內容", 18, ColorToken.Ink, true))
        box.addView(ui.body("這段文字會出現在學生端的「支持與回覆」。", ColorToken.Muted))
        box.addView(input)
        box.addView(ui.primaryButton("送出回覆給學生") {
            val replyNote = CollaborationFlowContract.buildCustomStaffReply(
                request = request,
                staffName = currentAccount().displayName,
                staffRole = currentAccount().roleLabel,
                message = input.text.toString(),
                createdAt = System.currentTimeMillis()
            )
            mentorReplyCount += 1
            addCollaborationNote(
                actor = replyNote.actor,
                roleLabel = replyNote.role,
                target = replyNote.target,
                note = replyNote.note,
                status = replyNote.status
            )
            renderStaffReplySent(request, replyNote.note)
        })
        box.addView(ui.secondaryButton("先不回覆，回接力佇列") { renderActionQueue() })
        root.addView(ui.margins(box, 0, 8, 0, 12))
        bottomNav()
    }

    private fun renderStaffReplySent(request: CollaborationNote, reply: String) {
        screen = Screen.ActionQueue
        shell("已回覆學生", "這段回饋會回到學生端的支持頁")
        val summary = CollaborationFlowContract.staffQueueSummary(collaborationNotes, teacherActions.size, actionDoneCount)
        root.addView(card("已送給 ${request.target}", reply, ColorToken.SuccessSoft))
        root.addView(metricRow(
            Metric("求助待回覆", "${summary.helpPending}", if (summary.helpPending > 0) ColorToken.Warning else ColorToken.Success),
            Metric("一般待辦", "${summary.normalPending}", if (summary.normalPending > 0) ColorToken.Warning else ColorToken.Success),
            Metric("已處理", "${summary.completed}", ColorToken.Success)
        ))
        root.addView(ui.primaryButton("繼續處理下一位") { renderActionQueue() })
        root.addView(ui.secondaryButton("查看接力優先序") { renderHandoffBoard() })
        bottomNav()
    }

    private fun studentHelpThreadCard(thread: StudentHelpThread): View {
        val request = thread.request
        val reply = thread.latestReply
        val answered = reply != null
        val reason = collaborationField(request.note, "求助原因：").ifBlank { "我需要協助" }
        val studentText = collaborationField(request.note, "學生說：").ifBlank { request.note }
        val fill = if (answered) ColorToken.SuccessSoft else ColorToken.WarningSoft
        val color = if (answered) ColorToken.Success else ColorToken.Warning
        val box = ui.container(fill, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(reason, 17, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(CollaborationFlowContract.requestStatusLabel(request, collaborationNotes), color))
        box.addView(top)
        box.addView(ui.body("我說：$studentText", "#334155").apply { setPadding(0, ui.dp(7), 0, 0) })
        if (reply == null) {
            box.addView(ui.body("老師/志工還沒回覆。你可以先做一題低壓練習，不需要重複送同一個求助。", ColorToken.Muted))
        } else {
            box.addView(ui.body("老師/志工回覆：${visibleReplyText(reply)}", "#334155").apply { setPadding(0, ui.dp(8), 0, 0) })
            if (reply.note.startsWith("[read] ")) {
                box.addView(ui.body("已讀。這則回覆會保留在支持紀錄中。", ColorToken.Success))
            } else {
                box.addView(ui.secondaryButton("我看到了，標記已讀") {
                    val readReply = CollaborationFlowContract.markReplyRead(reply)
                    addCollaborationNote(
                        actor = readReply.actor,
                        roleLabel = readReply.role,
                        target = readReply.target,
                        note = readReply.note,
                        status = readReply.status
                    )
                    renderStudentSupportCenter()
                })
            }
            box.addView(ui.primaryButton("照這個回饋練一題") {
                inDailyMission = false
                renderLesson()
            })
        }
        return ui.margins(box, 0, 8, 0, 8)
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
                role = "提醒",
                target = student.name,
                note = "目前還沒有接力紀錄。學生求助或老師回覆後，會出現在這裡。",
                status = "尚未建立"
            )
        )
    }

    private fun remoteCollaborationStatusCard(): View {
        val hasBackend = stateStore.hasCloudBackend()
        val box = ui.container(if (hasBackend) ColorToken.SuccessSoft else ColorToken.WarningSoft, ColorToken.Border)
        box.addView(ui.statusPill(if (hasBackend) "多人協作可同步" else "接力紀錄已保存", if (hasBackend) ColorToken.Success else ColorToken.Warning))
        box.addView(ui.label(if (hasBackend) "老師/志工紀錄可推送與拉取" else "接力同步準備中", 18, ColorToken.Ink, true).apply {
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
            VolunteerHandoffContract.STATUS_INTERNAL_HANDOFF_NOTE -> ColorToken.Primary
            CollaborationFlowContract.STATUS_STAFF_REPLY, "已回覆", "腳本已用", "待辦已完成" -> ColorToken.Success
            CollaborationFlowContract.STATUS_STUDENT_REQUEST -> ColorToken.Warning
            "已處理" -> ColorToken.Primary
            else -> ColorToken.Warning
        }
        val statusLabel = collaborationStatusLabel(note.status)
        val box = ui.container(ColorToken.Card, ColorToken.Border)
        val top = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        top.addView(ui.label(note.actor, 16, ColorToken.Ink, true), LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill(statusLabel, color))
        box.addView(top)
        box.addView(ui.body("${note.role}｜對象：${note.target}", ColorToken.Muted).apply { setPadding(0, ui.dp(7), 0, 0) })
        box.addView(ui.body(note.note, "#334155"))
        return ui.margins(box, 0, 8, 0, 8)
    }

    private fun collaborationStatusLabel(status: String): String {
        return when (status) {
            VolunteerHandoffContract.STATUS_INTERNAL_HANDOFF_NOTE -> "內部接力紀錄"
            else -> status
        }
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
        top.addView(ui.statusPill(if (inDailyMission) "今日 ${dailyQuestionDone + 1}/$dailyQuestionGoal" else "題目 ${currentQuestionIndex + 1}", ColorToken.Accent))
        top.addView(ui.label(question.type, 14, ColorToken.Muted, true).apply {
            setPadding(ui.dp(10), ui.dp(3), 0, 0)
        }, LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f))
        top.addView(ui.statusPill("一個概念", ColorToken.Success))
        box.addView(top)
        if (DailyMissionContract.shouldShowProgress(inDailyMission, dailyQuestionGoal)) {
            box.addView(ui.body("今日任務進度：$dailyQuestionDone / $dailyQuestionGoal", ColorToken.Primary).apply {
                setPadding(0, ui.dp(12), 0, 0)
            })
            box.addView(ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal).apply {
                max = dailyQuestionGoal.coerceAtLeast(1)
                progress = dailyQuestionDone.coerceIn(0, dailyQuestionGoal.coerceAtLeast(1))
                setPadding(0, ui.dp(8), 0, ui.dp(8))
            })
        }
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
