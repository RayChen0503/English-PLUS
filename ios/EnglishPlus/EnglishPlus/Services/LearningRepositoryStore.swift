import Foundation

struct LearningRepositorySnapshot: Equatable {
    var currentCheckIn: MoodCheckIn?
    var currentMission: DailyMission?
    var missionAttempts: [MissionAttempt]
    var supportRequests: [StudentSupportRequest]
    var assignedPracticeTasks: [TeacherAssignedPracticeTask]
    var learningFlow: LearningFlowState
}

enum LearningRepositorySyncStatus: Equatable {
    case idle
    case listening(classId: String)
    case offlineFallback(reason: String)
}

struct PracticeLaunchRequest: Identifiable, Equatable {
    let id: String
    let title: String
    let questionIds: [String]
}

enum SupportMutationError: LocalizedError {
    case remoteSyncUnavailable
    case classRequired
    case unauthenticated
    case roleNotAllowed
    case requestNotFound
    case requestAlreadyHandled
    case emptyReply
    case invalidSupportContext

    var errorDescription: String? {
        switch self {
        case .remoteSyncUnavailable:
            return "目前無法連上班級同步服務，請確認網路後再試一次。"
        case .classRequired:
            return "請先加入或切換到班級，再使用老師與志工協助。"
        case .unauthenticated:
            return "登入狀態已失效，請重新登入後再試一次。"
        case .roleNotAllowed:
            return "目前帳號沒有執行這個操作的權限。"
        case .requestNotFound:
            return "這筆求助已不存在或已被收回，列表即將重新整理。"
        case .requestAlreadyHandled:
            return "這筆求助已有新回覆或狀態已改變，請重新確認後再操作。"
        case .emptyReply:
            return "請先輸入回覆內容。"
        case .invalidSupportContext:
            return "題目資料不完整，這次沒有送出。請回到題目後重新求助。"
        }
    }
}

protocol LearningRepositoryListenerToken {
    func cancel()
}

final class AnyLearningRepositoryListenerToken: LearningRepositoryListenerToken {
    private let onCancel: () -> Void

    init(onCancel: @escaping () -> Void) {
        self.onCancel = onCancel
    }

    func cancel() {
        onCancel()
    }
}

@MainActor
protocol LearningRepositoryBackend: AnyObject {
    var snapshot: LearningRepositorySnapshot { get }
    var supportedQuestionTypes: [QuestionType] { get }
    var defaultPreferredQuestionTypes: [QuestionType] { get }
    var questionBankItems: [QuestionBankItem] { get }
    var questionPracticeSets: [QuestionPracticeSet] { get }

    func refresh() async throws
    func startRealtimeListener(
        classId: String,
        user: DemoUser?,
        profile: AppUserProfile?,
        onChange: @escaping @MainActor (LearningRepositorySnapshot) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> LearningRepositoryListenerToken

    func generateMission(
        for user: DemoUser?,
        profile: AppUserProfile?,
        moodScore: Int,
        availableTimeLevel: Int,
        wantsChallenge: Bool,
        preferredQuestionTypes: [QuestionType],
        aiMission: AiMissionOutput?
    )

    func startNewLearningRound(for user: DemoUser?, profile: AppUserProfile?)
    func continueLearningFlow()
    func enterFreePracticeMode()
    func returnToMissionFlow()
    func completeFreePracticeSession(correctCount: Int, totalCount: Int)
    func submitMissionAnswer(_ answer: String) -> MissionAttempt?
    func supportRequests(forStudentUid studentUid: String?) -> [StudentSupportRequest]
    func sendSupportRequest(
        from user: DemoUser?,
        profile: AppUserProfile?,
        option: SupportOption,
        message: String?
    ) async throws
    func sendQuestionSupportRequest(
        from user: DemoUser?,
        profile: AppUserProfile?,
        option: SupportOption,
        questionItem: QuestionBankItem,
        selectedAnswer: String?,
        message: String
    ) async throws
    func addTeacherReply(to requestId: String, body: String) async throws
    func addVolunteerReply(to requestId: String, body: String) async throws
    func markSupportThreadReadByStudent(_ requestId: String) async throws
    func archiveSupportThreadForStudent(_ requestId: String) async throws
    func withdrawSupportRequest(_ requestId: String) async throws
    func markSupportThreadHandledWithoutReply(_ requestId: String, by staffUser: DemoUser?) async throws
    func archiveSupportThreadForStaff(_ requestId: String, by staffUser: DemoUser?) async throws
    func assignPracticeSet(_ set: QuestionPracticeSet, to student: StaffStudentSummary, by teacher: DemoUser?)
    func startAssignedPracticeTask(_ assignment: TeacherAssignedPracticeTask)
    func withdrawAssignedPracticeTask(_ assignmentId: String)
    func eraseLocalData(for uid: String)
}

@MainActor
final class LearningRepositoryStore: ObservableObject {
    @Published private(set) var currentCheckIn: MoodCheckIn?
    @Published private(set) var currentMission: DailyMission?
    @Published private(set) var missionAttempts: [MissionAttempt] = []
    @Published private(set) var supportRequests: [StudentSupportRequest] = []
    @Published private(set) var assignedPracticeTasks: [TeacherAssignedPracticeTask] = []
    @Published private(set) var learningFlow: LearningFlowState = .initial(dateKey: "1970-01-01")
    @Published private(set) var syncStatus: LearningRepositorySyncStatus = .idle
    @Published private(set) var pendingPracticeLaunch: PracticeLaunchRequest?
    @Published private(set) var pendingSupportActionKeys = Set<String>()
    @Published private(set) var supportActionErrorMessage: String?

    private let backend: any LearningRepositoryBackend
    private var listener: LearningRepositoryListenerToken?

    convenience init() {
        self.init(backend: MockLearningRepository())
    }

    init(backend: any LearningRepositoryBackend) {
        self.backend = backend
        apply(backend.snapshot)
    }

    deinit {
        listener?.cancel()
    }

    var supportedQuestionTypes: [QuestionType] {
        backend.supportedQuestionTypes
    }

    var defaultPreferredQuestionTypes: [QuestionType] {
        backend.defaultPreferredQuestionTypes
    }

    var questionBankItems: [QuestionBankItem] {
        backend.questionBankItems
    }

    var questionPracticeSets: [QuestionPracticeSet] {
        backend.questionPracticeSets
    }

    var latestMissionAttempt: MissionAttempt? {
        missionAttempts.last
    }

    var canContinuePreviousProgress: Bool {
        learningFlow.canContinuePreviousProgress
    }

    var isDailyMissionComplete: Bool {
        learningFlow.stage == .missionCompleted
    }

    var hasCompletedFreePracticeSession: Bool {
        learningFlow.hasCompletedFreePracticeSession
    }

    var recentAccuracy: Double? {
        guard !missionAttempts.isEmpty else { return nil }
        let correctCount = missionAttempts.filter(\.isCorrect).count
        return Double(correctCount) / Double(missionAttempts.count)
    }

    var recentWeakSkills: [String] {
        guard let currentMission else { return [] }
        let questionsById = Dictionary(
            currentMission.questions.map { ($0.id, $0) },
            uniquingKeysWith: { existing, _ in existing }
        )
        let missedSkills = missionAttempts
            .filter { !$0.isCorrect }
            .compactMap { questionsById[$0.questionId]?.question.concept }
        return Array(missedSkills.uniqued().prefix(3))
    }

    var progressSnapshot: StudentProgressSnapshot? {
        guard let currentMission else { return nil }
        return StudentProgressSnapshot(
            correctCount: uniqueCorrectQuestionIds.count,
            targetCorrectCount: currentMission.targetCorrectCount,
            status: currentMission.status
        )
    }

    var nextMissionQuestion: QuestionBankItem? {
        guard let currentMission else { return nil }
        return currentMission.questions.first { !uniqueCorrectQuestionIds.contains($0.id) }
    }

    var teacherQueue: [StudentSupportRequest] {
        supportRequests
            .filter { $0.isVisibleInStaffQueue(for: .teacher) }
            .sorted { priorityScore($0.priority) > priorityScore($1.priority) }
    }

    var volunteerQueue: [StudentSupportRequest] {
        supportRequests
            .filter { $0.isVisibleInStaffQueue(for: .volunteer) }
            .sorted { priorityScore($0.priority) > priorityScore($1.priority) }
    }

    var staffStudentSummaries: [StaffStudentSummary] {
        supportRequests.map { request in
            StaffStudentSummary(
                id: request.studentUid,
                studentUid: request.studentUid,
                studentName: request.studentName,
                classCode: request.classCode,
                moodScore: request.moodScore,
                riskLevel: request.priority,
                missionProgress: request.status.uiTitle,
                nextAction: request.status == .replied ? "確認學生是否已讀回覆" : "先回應學生求助"
            )
        }
        .uniqued(by: \.studentUid)
    }

    var staffDashboardMetrics: StaffDashboardMetrics {
        let moodScores = supportRequests.compactMap(\.moodScore)
        let averageMood = moodScores.isEmpty
            ? "尚無"
            : String(format: "%.1f/5", Double(moodScores.reduce(0, +)) / Double(moodScores.count))

        return StaffDashboardMetrics(
            studentCount: staffStudentSummaries.count,
            priorityHelpCount: teacherQueue.filter { $0.priority == .high }.count,
            waitingHelpCount: supportRequests.filter { $0.countsTowardSharedStaffBadge(for: .teacher) }.count,
            repliedCount: supportRequests.filter { $0.status == .replied || $0.status == .readByStudent || $0.status == .staffHandledNoReply }.count,
            questionCount: SeedData.approvedQuestionBankItems.count,
            averageMoodText: averageMood
        )
    }

    var volunteerDashboardMetrics: VolunteerDashboardMetrics {
        VolunteerDashboardMetrics(
            waitingCount: supportRequests.filter { $0.countsTowardSharedStaffBadge(for: .volunteer) }.count,
            highPriorityCount: volunteerQueue.filter { $0.priority == .high }.count,
            repliedByVolunteerCount: supportRequests.filter { request in
                request.replies.contains {
                    $0.authorRole == .volunteer && $0.visibleToStudent
                }
            }.count,
            syncRecordCount: supportRequests.reduce(0) { count, request in
                count + request.replies.count
            }
        )
    }

    var questionBankOverview: [QuestionBankTypeOverview] {
        let groupedByType = Dictionary(grouping: SeedData.approvedQuestionBankItems) { item in
            item.question.type
        }

        return QuestionType.allCases.compactMap { type in
            guard let items = groupedByType[type], !items.isEmpty else { return nil }
            let levelCounts = Dictionary(grouping: items) { item in
                item.level
            }.mapValues(\.count)

            return QuestionBankTypeOverview(
                type: type,
                totalCount: items.count,
                levelCounts: levelCounts
            )
        }
    }

    var classroomReportExport: ClassroomReportExport {
        makeClassroomReportExport()
    }

    func makeClassroomReportExport(
        rosterStudentCount: Int? = nil,
        activeClassId: String? = nil
    ) -> ClassroomReportExport {
        let metrics = staffDashboardMetrics
        let priorityRows = teacherQueue.prefix(5).map { request in
            ClassroomReportStudentRow(
                id: request.id,
                studentName: request.studentName,
                classCode: request.classCode,
                priorityText: request.priority.uiTitle,
                statusText: request.status.uiTitle,
                summary: request.studentMessage
            )
        }
        let questionRows = questionBankOverview.map { overview in
            ClassroomReportQuestionBankRow(
                id: overview.id,
                typeTitle: overview.type.title,
                totalCount: overview.totalCount,
                levelSummary: overview.levelSummary
            )
        }

        return ClassroomReportExport(
            title: "English+ 班級週報",
            classCode: activeClassId ?? priorityRows.first?.classCode ?? "未選擇班級",
            generatedAtText: Self.teacherReportDateFormatter.string(from: Date()),
            metrics: [
                ClassroomReportMetric(
                    id: "students",
                    label: "追蹤學生",
                    value: "\(rosterStudentCount ?? metrics.studentCount)",
                    detail: "位"
                ),
                ClassroomReportMetric(
                    id: "priority-help",
                    label: "優先關懷",
                    value: "\(metrics.priorityHelpCount)",
                    detail: "位"
                ),
                ClassroomReportMetric(
                    id: "waiting-help",
                    label: "待回應求助",
                    value: "\(metrics.waitingHelpCount)",
                    detail: "件"
                ),
                ClassroomReportMetric(
                    id: "average-mood",
                    label: "平均心情",
                    value: metrics.averageMoodText,
                    detail: ""
                ),
            ],
            priorityStudents: priorityRows,
            questionBankRows: questionRows,
            recommendedActions: recommendedReportActions
        )
    }

    var visibleVolunteerReplies: [SupportReply] {
        supportRequests
            .flatMap(\.replies)
            .filter { $0.authorRole == .volunteer && $0.visibleToStudent }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func startRealtimeSync(classId: String, user: DemoUser?, profile: AppUserProfile?) {
        listener?.cancel()
        listener = backend.startRealtimeListener(
            classId: classId,
            user: user,
            profile: profile
        ) { [weak self] snapshot in
            self?.apply(snapshot)
        } onError: { [weak self] error in
            self?.updateSyncStatus(.offlineFallback(reason: String(describing: error)))
        }
        updateSyncStatus(.listening(classId: classId))
    }

    func stopRealtimeSync() {
        listener?.cancel()
        listener = nil
        updateSyncStatus(.idle)
    }

    func eraseLocalData(for uid: String) {
        listener?.cancel()
        listener = nil
        backend.eraseLocalData(for: uid)
        pendingPracticeLaunch = nil
        updateSyncStatus(.idle)
        apply(backend.snapshot)
    }

    func refresh() async {
        do {
            try await backend.refresh()
            apply(backend.snapshot)
        } catch {
            updateSyncStatus(.offlineFallback(reason: String(describing: error)))
            apply(backend.snapshot)
        }
    }

    func generateMission(
        for user: DemoUser?,
        profile: AppUserProfile?,
        moodScore: Int,
        availableTimeLevel: Int,
        wantsChallenge: Bool,
        preferredQuestionTypes: [QuestionType],
        aiMission: AiMissionOutput? = nil
    ) {
        backend.generateMission(
            for: user,
            profile: profile,
            moodScore: moodScore,
            availableTimeLevel: availableTimeLevel,
            wantsChallenge: wantsChallenge,
            preferredQuestionTypes: preferredQuestionTypes,
            aiMission: aiMission
        )
        apply(backend.snapshot)
    }

    func startNewLearningRound(for user: DemoUser?, profile: AppUserProfile?) {
        backend.startNewLearningRound(for: user, profile: profile)
        apply(backend.snapshot)
    }

    func continueLearningFlow() {
        backend.continueLearningFlow()
        apply(backend.snapshot)
    }

    func enterFreePracticeMode() {
        backend.enterFreePracticeMode()
        apply(backend.snapshot)
    }

    func returnToMissionFlow() {
        backend.returnToMissionFlow()
        apply(backend.snapshot)
    }

    func completeFreePracticeSession(correctCount: Int, totalCount: Int) {
        backend.completeFreePracticeSession(correctCount: correctCount, totalCount: totalCount)
        apply(backend.snapshot)
    }

    func scheduleFocusedPractice(title: String, questionIds: [String]) {
        let uniqueIds = questionIds.uniqued()
        guard !uniqueIds.isEmpty else { return }
        pendingPracticeLaunch = PracticeLaunchRequest(
            id: UUID().uuidString,
            title: title,
            questionIds: uniqueIds
        )
    }

    func takePendingPracticeLaunch() -> PracticeLaunchRequest? {
        defer { pendingPracticeLaunch = nil }
        return pendingPracticeLaunch
    }

    func submitMissionAnswer(_ answer: String) -> MissionAttempt? {
        let attempt = backend.submitMissionAnswer(answer)
        apply(backend.snapshot)
        return attempt
    }

    func supportRequests(forStudentUid studentUid: String?) -> [StudentSupportRequest] {
        guard let studentUid else { return [] }
        return supportRequests
            .filter { $0.studentUid == studentUid }
            .filter(\.isVisibleToStudent)
            .filter(\.hasActionableSupportContent)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func sendSupportRequest(
        from user: DemoUser?,
        profile: AppUserProfile?,
        option: SupportOption,
        message: String? = nil
    ) async -> Bool {
        await performSupportAction(key: "create-general") {
            try await backend.sendSupportRequest(
                from: user,
                profile: profile,
                option: option,
                message: message
            )
        }
    }

    func sendQuestionSupportRequest(
        from user: DemoUser?,
        profile: AppUserProfile?,
        option: SupportOption,
        questionItem: QuestionBankItem,
        selectedAnswer: String?,
        message: String
    ) async -> Bool {
        await performSupportAction(key: "create-question-\(questionItem.id)") {
            try await backend.sendQuestionSupportRequest(
                from: user,
                profile: profile,
                option: option,
                questionItem: questionItem,
                selectedAnswer: selectedAnswer,
                message: message
            )
        }
    }

    func addTeacherReply(to requestId: String, body: String) async -> Bool {
        await performSupportAction(key: "\(requestId):teacher-reply") {
            try await backend.addTeacherReply(to: requestId, body: body)
        }
    }

    func addVolunteerReply(to requestId: String, body: String) async -> Bool {
        await performSupportAction(key: "\(requestId):volunteer-reply") {
            try await backend.addVolunteerReply(to: requestId, body: body)
        }
    }

    func markSupportThreadReadByStudent(_ requestId: String) async -> Bool {
        await performSupportAction(key: "\(requestId):student-read", reportsFailure: false) {
            try await backend.markSupportThreadReadByStudent(requestId)
        }
    }

    func archiveSupportThreadForStudent(_ requestId: String) async -> Bool {
        await performSupportAction(key: "\(requestId):student-archive") {
            try await backend.archiveSupportThreadForStudent(requestId)
        }
    }

    func withdrawSupportRequest(_ requestId: String) async -> Bool {
        await performSupportAction(key: "\(requestId):student-withdraw") {
            try await backend.withdrawSupportRequest(requestId)
        }
    }

    func markSupportThreadHandledWithoutReply(_ requestId: String, by staffUser: DemoUser?) async -> Bool {
        await performSupportAction(key: "\(requestId):staff-handle") {
            try await backend.markSupportThreadHandledWithoutReply(requestId, by: staffUser)
        }
    }

    func archiveSupportThreadForStaff(_ requestId: String, by staffUser: DemoUser?) async -> Bool {
        await performSupportAction(key: "\(requestId):staff-archive") {
            try await backend.archiveSupportThreadForStaff(requestId, by: staffUser)
        }
    }

    func isSupportActionPending(for requestId: String) -> Bool {
        pendingSupportActionKeys.contains { $0.hasPrefix("\(requestId):") }
    }

    var isCreatingSupportRequest: Bool {
        pendingSupportActionKeys.contains { $0.hasPrefix("create-") }
    }

    func dismissSupportActionError() {
        supportActionErrorMessage = nil
    }

    func pendingAssignments(forStudentUid studentUid: String?) -> [TeacherAssignedPracticeTask] {
        guard let studentUid else { return [] }
        return assignedPracticeTasks
            .filter { $0.studentUid == studentUid && $0.status == .pending }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func assignments(forStudentUid studentUid: String?) -> [TeacherAssignedPracticeTask] {
        guard let studentUid else { return [] }
        return assignedPracticeTasks
            .filter { $0.studentUid == studentUid }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func assignPracticeSet(_ set: QuestionPracticeSet, to student: StaffStudentSummary, by teacher: DemoUser?) {
        backend.assignPracticeSet(set, to: student, by: teacher)
        apply(backend.snapshot)
    }

    func startAssignedPracticeTask(_ assignment: TeacherAssignedPracticeTask) {
        backend.startAssignedPracticeTask(assignment)
        apply(backend.snapshot)
    }

    func withdrawAssignedPracticeTask(_ assignmentId: String) {
        backend.withdrawAssignedPracticeTask(assignmentId)
        apply(backend.snapshot)
    }

    private func apply(_ snapshot: LearningRepositorySnapshot) {
        currentCheckIn = snapshot.currentCheckIn
        currentMission = snapshot.currentMission
        missionAttempts = snapshot.missionAttempts
        supportRequests = snapshot.supportRequests
            .filter(\.hasActionableSupportContent)
            .map { $0.reconcilingLifecycle() }
        assignedPracticeTasks = snapshot.assignedPracticeTasks
        learningFlow = snapshot.learningFlow
    }

    private func performSupportAction(
        key: String,
        reportsFailure: Bool = true,
        operation: () async throws -> Void
    ) async -> Bool {
        guard pendingSupportActionKeys.insert(key).inserted else { return false }
        supportActionErrorMessage = nil
        defer { pendingSupportActionKeys.remove(key) }

        do {
            try await operation()
            apply(backend.snapshot)
            return true
        } catch {
            apply(backend.snapshot)
            if reportsFailure {
                supportActionErrorMessage = (error as? LocalizedError)?.errorDescription
                    ?? "同步沒有完成，請確認網路後再試一次。"
            }
            return false
        }
    }

    private func updateSyncStatus(_ status: LearningRepositorySyncStatus) {
        syncStatus = status
    }

    private var uniqueCorrectQuestionIds: Set<String> {
        Set(missionAttempts.filter(\.isCorrect).map(\.questionId))
    }

    private func priorityScore(_ riskLevel: RiskLevel) -> Int {
        switch riskLevel {
        case .low:
            return 1
        case .medium:
            return 2
        case .high:
            return 3
        }
    }

    private var recommendedReportActions: [String] {
        var actions: [String] = []
        if staffDashboardMetrics.waitingHelpCount > 0 {
            actions.append("先回應待處理求助，讓學生知道有人接住。")
        }
        if staffDashboardMetrics.priorityHelpCount > 0 {
            actions.append("先回覆學生主動送出的優先求助，再決定是否需要志工接力。")
        }
        if visibleVolunteerReplies.isEmpty {
            actions.append("可請志工先使用陪伴腳本，補上學生看得到的鼓勵。")
        } else {
            actions.append("檢查志工回覆是否能被學生理解，必要時補一則老師總結。")
        }
        actions.append("下次任務優先從錯題題型與閱讀卡點挑選，不用用排名壓力推進。")
        return actions
    }

    private static let teacherReportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "zh_Hant_TW")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()
}

extension MockLearningRepository: LearningRepositoryBackend {
    var snapshot: LearningRepositorySnapshot {
        LearningRepositorySnapshot(
            currentCheckIn: currentCheckIn,
            currentMission: currentMission,
            missionAttempts: missionAttempts,
            supportRequests: supportRequests,
            assignedPracticeTasks: assignedPracticeTasks,
            learningFlow: learningFlow
        )
    }

    func refresh() async throws {}

    func startRealtimeListener(
        classId: String,
        user: DemoUser?,
        profile: AppUserProfile?,
        onChange: @escaping @MainActor (LearningRepositorySnapshot) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> LearningRepositoryListenerToken {
        onChange(snapshot)
        return AnyLearningRepositoryListenerToken {}
    }
}

private extension Array {
    func uniqued<ID: Hashable>(by keyPath: KeyPath<Element, ID>) -> [Element] {
        var seen = Set<ID>()
        return filter { element in
            seen.insert(element[keyPath: keyPath]).inserted
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { element in
            seen.insert(element).inserted
        }
    }
}
