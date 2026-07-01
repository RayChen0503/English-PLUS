import Foundation

struct LearningRepositorySnapshot: Equatable {
    var currentCheckIn: MoodCheckIn?
    var currentMission: DailyMission?
    var missionAttempts: [MissionAttempt]
    var supportRequests: [StudentSupportRequest]
}

enum LearningRepositorySyncStatus: Equatable {
    case idle
    case listening(classId: String)
    case offlineFallback(reason: String)
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

    func refresh() async throws
    func startRealtimeListener(
        classId: String,
        user: DemoUser?,
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

    func submitMissionAnswer(_ answer: String) -> MissionAttempt?
    func supportRequests(forStudentUid studentUid: String?) -> [StudentSupportRequest]
    func sendSupportRequest(
        from user: DemoUser?,
        profile: AppUserProfile?,
        option: SupportOption,
        message: String?
    )
    func addTeacherReply(to requestId: String, body: String)
    func addVolunteerReply(to requestId: String, body: String)
    func markSupportThreadReadByStudent(_ requestId: String)
}

@MainActor
final class LearningRepositoryStore: ObservableObject {
    @Published private(set) var currentCheckIn: MoodCheckIn?
    @Published private(set) var currentMission: DailyMission?
    @Published private(set) var missionAttempts: [MissionAttempt] = []
    @Published private(set) var supportRequests: [StudentSupportRequest] = []
    @Published private(set) var syncStatus: LearningRepositorySyncStatus = .idle

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

    var latestMissionAttempt: MissionAttempt? {
        missionAttempts.last
    }

    var recentAccuracy: Double? {
        guard !missionAttempts.isEmpty else { return nil }
        let correctCount = missionAttempts.filter(\.isCorrect).count
        return Double(correctCount) / Double(missionAttempts.count)
    }

    var recentWeakSkills: [String] {
        guard let currentMission else { return [] }
        let questionsById = Dictionary(uniqueKeysWithValues: currentMission.questions.map { ($0.id, $0) })
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
            .filter { $0.status == .waitingForStaff || $0.status == .open }
            .sorted { priorityScore($0.priority) > priorityScore($1.priority) }
    }

    var volunteerQueue: [StudentSupportRequest] {
        supportRequests
            .filter { request in
                request.route == .humanHandoff || request.reason == .emotionalSupport || request.reason == .readingHelp
            }
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
            studentCount: max(staffStudentSummaries.count, 1),
            highRiskCount: supportRequests.filter { $0.priority == .high }.count,
            waitingHelpCount: teacherQueue.count,
            repliedCount: supportRequests.filter { $0.status == .replied || $0.status == .readByStudent }.count,
            questionCount: SeedData.approvedQuestionBankItems.count,
            averageMoodText: averageMood
        )
    }

    var volunteerDashboardMetrics: VolunteerDashboardMetrics {
        VolunteerDashboardMetrics(
            waitingCount: volunteerQueue.count,
            highPriorityCount: volunteerQueue.filter { $0.priority == .high }.count,
            repliedByVolunteerCount: visibleVolunteerReplies.count,
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
            classCode: priorityRows.first?.classCode ?? FirebaseBackendConfig.firstClassId,
            generatedAtText: Self.teacherReportDateFormatter.string(from: Date()),
            metrics: [
                ClassroomReportMetric(
                    id: "students",
                    label: "追蹤學生",
                    value: "\(metrics.studentCount)",
                    detail: "位"
                ),
                ClassroomReportMetric(
                    id: "high-risk",
                    label: "優先關懷",
                    value: "\(metrics.highRiskCount)",
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

    func startRealtimeSync(classId: String, user: DemoUser?) {
        listener?.cancel()
        listener = backend.startRealtimeListener(
            classId: classId,
            user: user
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

    func submitMissionAnswer(_ answer: String) -> MissionAttempt? {
        let attempt = backend.submitMissionAnswer(answer)
        apply(backend.snapshot)
        return attempt
    }

    func supportRequests(forStudentUid studentUid: String?) -> [StudentSupportRequest] {
        guard let studentUid else { return [] }
        return supportRequests
            .filter { $0.studentUid == studentUid }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func sendSupportRequest(
        from user: DemoUser?,
        profile: AppUserProfile?,
        option: SupportOption,
        message: String? = nil
    ) {
        backend.sendSupportRequest(
            from: user,
            profile: profile,
            option: option,
            message: message
        )
        apply(backend.snapshot)
    }

    func addTeacherReply(to requestId: String, body: String) {
        backend.addTeacherReply(to: requestId, body: body)
        apply(backend.snapshot)
    }

    func addVolunteerReply(to requestId: String, body: String) {
        backend.addVolunteerReply(to: requestId, body: body)
        apply(backend.snapshot)
    }

    func markSupportThreadReadByStudent(_ requestId: String) {
        backend.markSupportThreadReadByStudent(requestId)
        apply(backend.snapshot)
    }

    private func apply(_ snapshot: LearningRepositorySnapshot) {
        currentCheckIn = snapshot.currentCheckIn
        currentMission = snapshot.currentMission
        missionAttempts = snapshot.missionAttempts
        supportRequests = snapshot.supportRequests
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
        if staffDashboardMetrics.highRiskCount > 0 {
            actions.append("高風險學生先安排短回覆或志工接力，不急著增加題量。")
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
            supportRequests: supportRequests
        )
    }

    func refresh() async throws {}

    func startRealtimeListener(
        classId: String,
        user: DemoUser?,
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
