import Foundation

@MainActor
final class LearningRepositoryStore: ObservableObject {
    @Published private(set) var currentCheckIn: MoodCheckIn?
    @Published private(set) var currentMission: DailyMission?
    @Published private(set) var missionAttempts: [MissionAttempt] = []
    @Published private(set) var supportRequests: [StudentSupportRequest] = []
    @Published private(set) var assignedPracticeTasks: [TeacherAssignedPracticeTask] = []
    @Published private(set) var masteryRecords: [SkillMasteryRecord] = []
    @Published private(set) var learningFlow: LearningFlowState = .initial(dateKey: "1970-01-01")
    @Published private(set) var syncStatus: LearningRepositorySyncStatus = .idle
    @Published private(set) var connectivityStatus: NetworkConnectivityStatus = .unknown
    @Published private(set) var lastSuccessfulSyncAt: Date?
    @Published private(set) var pendingPracticeLaunch: PracticeLaunchRequest?
    @Published private(set) var pendingSupportActionKeys = Set<String>()
    @Published private(set) var supportActionErrorMessage: String?
    @Published private(set) var pendingAssignmentActionIds = Set<String>()
    @Published private(set) var assignmentActionErrorMessage: String?

    let backend: any LearningRepositoryBackend
    private let connectivityMonitor: any NetworkConnectivityMonitoring
    private let retryDelaysNanoseconds: [UInt64]
    private let recoveryConfirmationDelayNanoseconds: UInt64
    private var listener: LearningRepositoryListenerToken?
    private var retryTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var syncContext: LearningRepositorySyncContext?
    private var consecutiveSyncFailures = 0
    private var listenerGeneration = 0
    private var componentIssues = LearningRepositoryComponentIssueRegistry()

    convenience init() {
        self.init(backend: MockLearningRepository())
    }

    init(
        backend: any LearningRepositoryBackend,
        connectivityMonitor: any NetworkConnectivityMonitoring = NetworkConnectivityMonitor(),
        retryDelaysNanoseconds: [UInt64] = [1_000_000_000, 2_000_000_000, 5_000_000_000, 10_000_000_000],
        recoveryConfirmationDelayNanoseconds: UInt64 = 750_000_000
    ) {
        self.backend = backend
        self.connectivityMonitor = connectivityMonitor
        self.retryDelaysNanoseconds = retryDelaysNanoseconds.isEmpty
            ? [1_000_000_000]
            : retryDelaysNanoseconds
        self.recoveryConfirmationDelayNanoseconds = recoveryConfirmationDelayNanoseconds
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
        recoveryTask?.cancel()
        listener?.cancel()
        connectivityMonitor.stop()
    }

    var questionPracticeSets: [QuestionPracticeSet] {
        backend.questionPracticeSets
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
        recoveryTask?.cancel()
        recoveryTask = nil
        consecutiveSyncFailures = 0
        syncContext = context
        beginRealtimeListening(context: context, isRetry: false)
    }

    func retryRealtimeSync() {
        guard connectivityStatus != .disconnected,
              let context = syncContext
        else { return }
        if case .syncIssue(_, let retryAvailable) = syncStatus,
           !retryAvailable {
            return
        }
        retryTask?.cancel()
        retryTask = nil
        recoveryTask?.cancel()
        recoveryTask = nil
        beginRealtimeListening(context: context, isRetry: true, presentsProgress: true)
    }

    private func beginRealtimeListening(
        context: LearningRepositorySyncContext,
        isRetry: Bool,
        presentsProgress: Bool = true
    ) {
        listener?.cancel()
        componentIssues.reset()
        listenerGeneration &+= 1
        let generation = listenerGeneration
        let attempt = max(consecutiveSyncFailures + (isRetry ? 1 : 0), 1)
        if presentsProgress {
            updateSyncStatus(
                isRetry
                    ? .retrying(classId: context.classId, attempt: attempt)
                    : .connecting(classId: context.classId)
            )
        }
        listener = backend.startRealtimeListener(
            classId: context.classId,
            user: context.user,
            profile: context.profile
        ) { [weak self] snapshot in
            guard let self else { return }
            guard syncContext?.scopeKey == context.scopeKey,
                  listenerGeneration == generation
            else { return }
            apply(snapshot)
            if connectivityStatus == .disconnected {
                updateSyncStatus(.offlineFallback(reason: Self.disconnectedMessage))
            } else if let unresolvedIssue = componentIssues.presentation {
                // A healthy sibling snapshot must not hide another listener's failure.
                updateSyncStatus(
                    .syncIssue(
                        reason: unresolvedIssue.message,
                        retryAvailable: unresolvedIssue.shouldRetry
                    )
                )
            } else if componentIssues.isEmpty, case .syncIssue = syncStatus {
                scheduleRecoveryConfirmation(for: context)
            } else {
                retryTask?.cancel()
                retryTask = nil
                recoveryTask?.cancel()
                recoveryTask = nil
                consecutiveSyncFailures = 0
                lastSuccessfulSyncAt = Date()
                updateSyncStatus(.listening(classId: context.classId))
            }
        } onComponentHealth: { [weak self] event in
            guard let self,
                  syncContext?.scopeKey == context.scopeKey,
                  listenerGeneration == generation
            else { return }
            handleComponentHealth(event, context: context)
        } onError: { [weak self] error in
            guard let self,
                  syncContext?.scopeKey == context.scopeKey,
                  listenerGeneration == generation
            else { return }
            handleRealtimeSyncFailure(error)
        }
    }

    func stopRealtimeSync() {
        retryTask?.cancel()
        retryTask = nil
        recoveryTask?.cancel()
        recoveryTask = nil
        listener?.cancel()
        listener = nil
        listenerGeneration &+= 1
        syncContext = nil
        consecutiveSyncFailures = 0
        componentIssues.reset()
        updateSyncStatus(.idle)
    }

    func eraseLocalData(for uid: String) {
        retryTask?.cancel()
        retryTask = nil
        recoveryTask?.cancel()
        recoveryTask = nil
        listener?.cancel()
        listener = nil
        listenerGeneration &+= 1
        syncContext = nil
        consecutiveSyncFailures = 0
        componentIssues.reset()
        backend.eraseLocalData(for: uid)
        pendingPracticeLaunch = nil
        lastSuccessfulSyncAt = nil
        updateSyncStatus(.idle)
        apply(backend.snapshot)
    }

    func refresh() async {
        recoveryTask?.cancel()
        recoveryTask = nil
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

    func recordPracticeAnswer(
        studentUid: String,
        questionItem: QuestionBankItem,
        isCorrect: Bool,
        source: LearningAttemptSource
    ) {
        backend.recordPracticeAnswer(
            studentUid: studentUid,
            questionItem: questionItem,
            isCorrect: isCorrect,
            source: source
        )
        apply(backend.snapshot)
    }

    func sendSupportRequest(
        from user: DemoUser?,
        profile: AppUserProfile?,
        option: SupportOption,
        message: String? = nil
    ) async -> Bool {
        let succeeded = await performSupportAction(key: "create-general") {
            let safeMessage = try SupportContentPolicy.validatedOptional(message)
            try await backend.sendSupportRequest(
                from: user,
                profile: profile,
                option: option,
                message: safeMessage
            )
        }
        if succeeded {
            restartRealtimeSyncAfterCreatingSupportThread()
        }
        return succeeded
    }

    func sendQuestionSupportRequest(
        from user: DemoUser?,
        profile: AppUserProfile?,
        option: SupportOption,
        questionItem: QuestionBankItem,
        selectedAnswer: String?,
        message: String
    ) async -> Bool {
        let succeeded = await performSupportAction(key: "create-question-\(questionItem.id)") {
            let safeMessage = try SupportContentPolicy.validatedRequired(message)
            try await backend.sendQuestionSupportRequest(
                from: user,
                profile: profile,
                option: option,
                questionItem: questionItem,
                selectedAnswer: selectedAnswer,
                message: safeMessage
            )
        }
        if succeeded {
            restartRealtimeSyncAfterCreatingSupportThread()
        }
        return succeeded
    }

    func addTeacherReply(to requestId: String, body: String) async -> Bool {
        await performSupportAction(key: "\(requestId):teacher-reply") {
            let safeBody = try SupportContentPolicy.validatedRequired(body)
            try await backend.addTeacherReply(to: requestId, body: safeBody)
        }
    }

    func addVolunteerReply(to requestId: String, body: String) async -> Bool {
        await performSupportAction(key: "\(requestId):volunteer-reply") {
            let safeBody = try SupportContentPolicy.validatedRequired(body)
            try await backend.addVolunteerReply(to: requestId, body: safeBody)
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

    func dismissSupportActionError() {
        supportActionErrorMessage = nil
    }

    func assignPracticeSet(_ set: QuestionPracticeSet, to student: StaffStudentSummary, by teacher: DemoUser?) {
        backend.assignPracticeSet(set, to: student, by: teacher)
        apply(backend.snapshot)
    }

    func startAssignedPracticeTask(_ assignment: TeacherAssignedPracticeTask) async -> Bool {
        guard pendingAssignmentActionIds.insert(assignment.id).inserted else { return false }
        assignmentActionErrorMessage = nil
        defer { pendingAssignmentActionIds.remove(assignment.id) }
        do {
            try await backend.startAssignedPracticeTask(assignment)
            apply(backend.snapshot)
            return true
        } catch {
            apply(backend.snapshot)
            assignmentActionErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? LearningRepositorySyncFailureClassifier.classify(error).message
            return false
        }
    }

    func submitAssignedPracticeAnswer(
        _ answer: String,
        assignmentId: String
    ) async -> PracticeAssignmentQuestionResult? {
        guard pendingAssignmentActionIds.insert(assignmentId).inserted else { return nil }
        assignmentActionErrorMessage = nil
        defer { pendingAssignmentActionIds.remove(assignmentId) }
        do {
            let result = try await backend.submitAssignedPracticeAnswer(
                answer,
                assignmentId: assignmentId
            )
            apply(backend.snapshot)
            return result
        } catch {
            apply(backend.snapshot)
            assignmentActionErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? LearningRepositorySyncFailureClassifier.classify(error).message
            return nil
        }
    }

    func withdrawAssignedPracticeTask(_ assignmentId: String) async -> Bool {
        guard pendingAssignmentActionIds.insert(assignmentId).inserted else { return false }
        assignmentActionErrorMessage = nil
        defer { pendingAssignmentActionIds.remove(assignmentId) }
        do {
            try await backend.withdrawAssignedPracticeTask(assignmentId)
            apply(backend.snapshot)
            return true
        } catch {
            apply(backend.snapshot)
            assignmentActionErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? LearningRepositorySyncFailureClassifier.classify(error).message
            return false
        }
    }

    func clearAssignmentActionError() {
        assignmentActionErrorMessage = nil
    }

    private func apply(_ snapshot: LearningRepositorySnapshot) {
        currentCheckIn = snapshot.currentCheckIn
        currentMission = snapshot.currentMission
        missionAttempts = snapshot.missionAttempts
        supportRequests = snapshot.supportRequests
            .filter(\.hasActionableSupportContent)
            .map { $0.reconcilingLifecycle() }
        assignedPracticeTasks = snapshot.assignedPracticeTasks
        masteryRecords = snapshot.masteryRecords
        learningFlow = snapshot.learningFlow
    }

    func performSupportAction(
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
                    ?? LearningRepositorySyncFailureClassifier.classify(error).message
            }
            return false
        }
    }

    private func restartRealtimeSyncAfterCreatingSupportThread() {
        guard let context = syncContext else { return }
        retryTask?.cancel()
        retryTask = nil
        recoveryTask?.cancel()
        recoveryTask = nil
        consecutiveSyncFailures = 0
        beginRealtimeListening(context: context, isRetry: false)
    }

    private func handleRealtimeSyncFailure(_ error: Error) {
        recoveryTask?.cancel()
        recoveryTask = nil
        if connectivityStatus == .disconnected {
            retryTask?.cancel()
            retryTask = nil
            updateSyncStatus(.offlineFallback(reason: Self.disconnectedMessage))
            return
        }

        let disposition = LearningRepositorySyncFailureClassifier.classify(error)
        consecutiveSyncFailures += 1
        updateSyncStatus(
            .syncIssue(
                reason: disposition.message,
                retryAvailable: disposition.shouldRetry
            )
        )
        if disposition.shouldRetry {
            scheduleAutomaticRetryIfPossible()
        } else {
            retryTask?.cancel()
            retryTask = nil
        }
    }

    private func handleComponentHealth(
        _ event: LearningRepositoryListenerHealthEvent,
        context: LearningRepositorySyncContext
    ) {
        switch componentIssues.apply(event) {
        case .unchanged:
            return
        case .issue(let disposition):
            recoveryTask?.cancel()
            recoveryTask = nil
            retryTask?.cancel()
            retryTask = nil
            guard connectivityStatus != .disconnected else {
                updateSyncStatus(.offlineFallback(reason: Self.disconnectedMessage))
                return
            }
            updateSyncStatus(
                .syncIssue(reason: disposition.message, retryAvailable: disposition.shouldRetry)
            )
        case .healthy:
            if connectivityStatus != .disconnected {
                scheduleRecoveryConfirmation(for: context)
            }
        }
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
                  self.connectivityStatus != .disconnected,
                  self.componentIssues.isEmpty
            else { return }
            self.retryTask = nil
            self.beginRealtimeListening(
                context: context,
                isRetry: true,
                presentsProgress: false
            )
        }
    }

    private func scheduleRecoveryConfirmation(for context: LearningRepositorySyncContext) {
        guard recoveryTask == nil else { return }
        recoveryTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(nanoseconds: self?.recoveryConfirmationDelayNanoseconds ?? 0)
            } catch {
                return
            }
            guard let self,
                  self.syncContext?.scopeKey == context.scopeKey,
                  self.connectivityStatus != .disconnected
            else { return }
            self.recoveryTask = nil
            self.retryTask?.cancel()
            self.retryTask = nil
            self.consecutiveSyncFailures = 0
            self.lastSuccessfulSyncAt = Date()
            self.updateSyncStatus(.listening(classId: context.classId))
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
            recoveryTask?.cancel()
            recoveryTask = nil
            guard syncContext != nil else { return }
            updateSyncStatus(.offlineFallback(reason: Self.disconnectedMessage))
        case .connected:
            guard previousStatus == .disconnected, syncContext != nil else { return }
            retryRealtimeSync()
        }
    }

    private static let disconnectedMessage = "網路連線中斷，已切換為裝置上的資料。"

    private func updateSyncStatus(_ status: LearningRepositorySyncStatus) {
        guard syncStatus != status else { return }
        syncStatus = status
    }
}
