import Foundation

private struct LearningRepositorySyncContext {
    let classId: String
    let user: DemoUser?
    let profile: AppUserProfile?

    var scopeKey: String {
        [classId, profile?.id ?? user?.id ?? "anonymous", profile?.role.rawValue ?? user?.role.rawValue ?? "unknown"]
            .joined(separator: "|")
    }
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
    @Published private(set) var connectivityStatus: NetworkConnectivityStatus = .unknown
    @Published private(set) var lastSuccessfulSyncAt: Date?
    @Published private(set) var pendingPracticeLaunch: PracticeLaunchRequest?
    @Published private(set) var pendingSupportActionKeys = Set<String>()
    @Published private(set) var supportActionErrorMessage: String?

    private let backend: any LearningRepositoryBackend
    private let connectivityMonitor: any NetworkConnectivityMonitoring
    private let retryDelaysNanoseconds: [UInt64]
    private var listener: LearningRepositoryListenerToken?
    private var retryTask: Task<Void, Never>?
    private var syncContext: LearningRepositorySyncContext?
    private var consecutiveSyncFailures = 0

    convenience init() {
        self.init(backend: MockLearningRepository())
    }

    init(
        backend: any LearningRepositoryBackend,
        connectivityMonitor: any NetworkConnectivityMonitoring = NetworkConnectivityMonitor(),
        retryDelaysNanoseconds: [UInt64] = [1_000_000_000, 2_000_000_000, 5_000_000_000, 10_000_000_000]
    ) {
        self.backend = backend
        self.connectivityMonitor = connectivityMonitor
        self.retryDelaysNanoseconds = retryDelaysNanoseconds.isEmpty
            ? [1_000_000_000]
            : retryDelaysNanoseconds
        apply(backend.snapshot)
        connectivityStatus = connectivityMonitor.currentStatus
        connectivityMonitor.start { [weak self] status in
            Task { @MainActor [weak self] in
                self?.handleConnectivityChange(status)
            }
        }
    }

    deinit {
        retryTask?.cancel()
        listener?.cancel()
        connectivityMonitor.stop()
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

    func startRealtimeSync(classId: String, user: DemoUser?, profile: AppUserProfile?) {
        let context = LearningRepositorySyncContext(
            classId: classId,
            user: user,
            profile: profile
        )
        if syncContext?.scopeKey == context.scopeKey, listener != nil {
            syncContext = context
            return
        }

        retryTask?.cancel()
        retryTask = nil
        consecutiveSyncFailures = 0
        syncContext = context
        beginRealtimeListening(context: context, isRetry: false)
    }

    func retryRealtimeSync() {
        guard let context = syncContext else { return }
        retryTask?.cancel()
        retryTask = nil
        beginRealtimeListening(context: context, isRetry: true)
    }

    private func beginRealtimeListening(
        context: LearningRepositorySyncContext,
        isRetry: Bool
    ) {
        listener?.cancel()
        let attempt = max(consecutiveSyncFailures + (isRetry ? 1 : 0), 1)
        updateSyncStatus(
            isRetry
                ? .retrying(classId: context.classId, attempt: attempt)
                : .connecting(classId: context.classId)
        )
        listener = backend.startRealtimeListener(
            classId: context.classId,
            user: context.user,
            profile: context.profile
        ) { [weak self] snapshot in
            guard let self else { return }
            guard syncContext?.scopeKey == context.scopeKey else { return }
            retryTask?.cancel()
            retryTask = nil
            consecutiveSyncFailures = 0
            lastSuccessfulSyncAt = Date()
            apply(snapshot)
            if connectivityStatus == .disconnected {
                updateSyncStatus(.offlineFallback(reason: Self.disconnectedMessage))
            } else {
                updateSyncStatus(.listening(classId: context.classId))
            }
        } onError: { [weak self] error in
            guard let self, syncContext?.scopeKey == context.scopeKey else { return }
            handleRealtimeSyncFailure(error)
        }
    }

    func stopRealtimeSync() {
        retryTask?.cancel()
        retryTask = nil
        listener?.cancel()
        listener = nil
        syncContext = nil
        consecutiveSyncFailures = 0
        updateSyncStatus(.idle)
    }

    func eraseLocalData(for uid: String) {
        retryTask?.cancel()
        retryTask = nil
        listener?.cancel()
        listener = nil
        syncContext = nil
        consecutiveSyncFailures = 0
        backend.eraseLocalData(for: uid)
        pendingPracticeLaunch = nil
        lastSuccessfulSyncAt = nil
        updateSyncStatus(.idle)
        apply(backend.snapshot)
    }

    func refresh() async {
        let context = syncContext
        if let context {
            updateSyncStatus(
                .retrying(
                    classId: context.classId,
                    attempt: max(consecutiveSyncFailures + 1, 1)
                )
            )
        }
        do {
            try await backend.refresh()
            apply(backend.snapshot)
            lastSuccessfulSyncAt = Date()
            consecutiveSyncFailures = 0
            if let context {
                beginRealtimeListening(context: context, isRetry: true)
            } else {
                updateSyncStatus(.idle)
            }
        } catch {
            apply(backend.snapshot)
            handleRealtimeSyncFailure(error)
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

    private func handleRealtimeSyncFailure(_ error: Error) {
        consecutiveSyncFailures += 1
        updateSyncStatus(
            .offlineFallback(reason: Self.syncFailureMessage(for: error))
        )
        scheduleAutomaticRetryIfPossible()
    }

    private func scheduleAutomaticRetryIfPossible() {
        guard connectivityStatus != .disconnected,
              let context = syncContext,
              retryTask == nil
        else { return }

        let index = min(
            max(consecutiveSyncFailures - 1, 0),
            retryDelaysNanoseconds.count - 1
        )
        let delay = retryDelaysNanoseconds[index]
        retryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: delay)
            } catch {
                return
            }
            guard let self,
                  self.syncContext?.scopeKey == context.scopeKey,
                  self.connectivityStatus != .disconnected
            else { return }
            self.retryTask = nil
            self.beginRealtimeListening(context: context, isRetry: true)
        }
    }

    private func handleConnectivityChange(_ status: NetworkConnectivityStatus) {
        let previousStatus = connectivityStatus
        connectivityStatus = status

        switch status {
        case .unknown:
            break
        case .disconnected:
            retryTask?.cancel()
            retryTask = nil
            guard syncContext != nil else { return }
            updateSyncStatus(.offlineFallback(reason: Self.disconnectedMessage))
        case .connected:
            guard previousStatus == .disconnected, syncContext != nil else { return }
            retryRealtimeSync()
        }
    }

    private static func syncFailureMessage(for _: Error) -> String {
        "同步暫時中斷；你仍可查看目前資料，連線恢復後會自動重試。"
    }

    private static let disconnectedMessage = "網路連線中斷，已切換為裝置上的資料。"

    private func updateSyncStatus(_ status: LearningRepositorySyncStatus) {
        syncStatus = status
    }

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
