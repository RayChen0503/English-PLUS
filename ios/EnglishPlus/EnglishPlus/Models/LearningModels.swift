import Foundation

struct MoodCheckIn: Identifiable, Codable, Equatable {
    let id: String
    let studentUid: String
    let dateKey: String
    let moodScore: Int
    let availableTimeLevel: Int
    let wantsChallenge: Bool
    let preferredQuestionTypes: [QuestionType]
    let recommendedMinutes: Int
    let createdAt: Date
}

struct DailyMission: Identifiable, Codable, Equatable {
    let id: String
    let studentUid: String
    let dateKey: String
    let sourceCheckInId: String
    let track: MissionTrack
    let targetCorrectCount: Int
    let recommendedMinutes: Int
    let questions: [QuestionBankItem]
    let createdAt: Date
    var completedAt: Date?

    var status: MissionStatus {
        completedAt == nil ? .active : .completed
    }
}

struct MissionAttempt: Identifiable, Codable, Equatable {
    let id: String
    let missionId: String
    let questionId: String
    let prompt: String
    let selectedAnswer: String
    let acceptedAnswer: String
    let isCorrect: Bool
    let attemptNumber: Int
    let explanation: String
    let repairHint: String
    let createdAt: Date
}

enum LearningFlowStage: String, Codable, Equatable {
    case needsCheckIn
    case missionActive
    case missionCompleted
    case freePractice
}

struct LearningContinuation: Codable, Equatable {
    let missionId: String
    let missionDateKey: String
    let roundNumber: Int
    let progressText: String
}

struct LearningFlowState: Codable, Equatable {
    let dateKey: String
    let roundNumber: Int
    let stage: LearningFlowStage
    let activeMissionId: String?
    let continuation: LearningContinuation?
    let updatedAt: Date
    let completedFreePracticeSessionCount: Int
    let lastFreePracticeCompletedAt: Date?

    private enum CodingKeys: String, CodingKey {
        case dateKey
        case roundNumber
        case stage
        case activeMissionId
        case continuation
        case updatedAt
        case completedFreePracticeSessionCount
        case lastFreePracticeCompletedAt
    }

    init(
        dateKey: String,
        roundNumber: Int,
        stage: LearningFlowStage,
        activeMissionId: String?,
        continuation: LearningContinuation?,
        updatedAt: Date,
        completedFreePracticeSessionCount: Int = 0,
        lastFreePracticeCompletedAt: Date? = nil
    ) {
        self.dateKey = dateKey
        self.roundNumber = roundNumber
        self.stage = stage
        self.activeMissionId = activeMissionId
        self.continuation = continuation
        self.updatedAt = updatedAt
        self.completedFreePracticeSessionCount = max(completedFreePracticeSessionCount, 0)
        self.lastFreePracticeCompletedAt = lastFreePracticeCompletedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            dateKey: try container.decode(String.self, forKey: .dateKey),
            roundNumber: try container.decode(Int.self, forKey: .roundNumber),
            stage: try container.decode(LearningFlowStage.self, forKey: .stage),
            activeMissionId: try container.decodeIfPresent(String.self, forKey: .activeMissionId),
            continuation: try container.decodeIfPresent(LearningContinuation.self, forKey: .continuation),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            completedFreePracticeSessionCount: try container.decodeIfPresent(Int.self, forKey: .completedFreePracticeSessionCount) ?? 0,
            lastFreePracticeCompletedAt: try container.decodeIfPresent(Date.self, forKey: .lastFreePracticeCompletedAt)
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dateKey, forKey: .dateKey)
        try container.encode(roundNumber, forKey: .roundNumber)
        try container.encode(stage, forKey: .stage)
        try container.encodeIfPresent(activeMissionId, forKey: .activeMissionId)
        try container.encodeIfPresent(continuation, forKey: .continuation)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(completedFreePracticeSessionCount, forKey: .completedFreePracticeSessionCount)
        try container.encodeIfPresent(lastFreePracticeCompletedAt, forKey: .lastFreePracticeCompletedAt)
    }

    var hasActiveMission: Bool {
        activeMissionId != nil
    }

    var hasCompletedFreePracticeSession: Bool {
        completedFreePracticeSessionCount > 0
    }

    var canContinuePreviousProgress: Bool {
        continuation != nil && stage == .needsCheckIn
    }

    func recordingFreePracticeSessionCompleted(at date: Date) -> LearningFlowState {
        LearningFlowState(
            dateKey: dateKey,
            roundNumber: roundNumber,
            stage: stage,
            activeMissionId: activeMissionId,
            continuation: continuation,
            updatedAt: date,
            completedFreePracticeSessionCount: completedFreePracticeSessionCount + 1,
            lastFreePracticeCompletedAt: date
        )
    }

    static func initial(dateKey: String, updatedAt: Date = Date()) -> LearningFlowState {
        LearningFlowState(
            dateKey: dateKey,
            roundNumber: 1,
            stage: .needsCheckIn,
            activeMissionId: nil,
            continuation: nil,
            updatedAt: updatedAt
        )
    }

    static func derived(
        dateKey: String,
        currentMission: DailyMission?,
        missionAttempts: [MissionAttempt],
        updatedAt: Date
    ) -> LearningFlowState {
        guard let currentMission else {
            return initial(dateKey: dateKey, updatedAt: updatedAt)
        }

        let stage: LearningFlowStage = currentMission.status == .completed ? .missionCompleted : .missionActive
        return LearningFlowState(
            dateKey: currentMission.dateKey,
            roundNumber: roundNumber(fromMissionId: currentMission.id, fallback: 1),
            stage: stage,
            activeMissionId: currentMission.id,
            continuation: continuation(
                from: currentMission,
                missionAttempts: missionAttempts,
                fallbackRoundNumber: roundNumber(fromMissionId: currentMission.id, fallback: 1)
            ),
            updatedAt: updatedAt
        )
    }

    static func normalizedForToday(
        todayKey: String,
        currentMission: DailyMission?,
        missionAttempts: [MissionAttempt],
        storedFlow: LearningFlowState,
        updatedAt: Date
    ) -> LearningFlowState {
        if let currentMission, currentMission.dateKey != todayKey {
            return LearningFlowState(
                dateKey: todayKey,
                roundNumber: 1,
                stage: .needsCheckIn,
                activeMissionId: nil,
                continuation: continuation(
                    from: currentMission,
                    missionAttempts: missionAttempts,
                    fallbackRoundNumber: storedFlow.roundNumber
                ) ?? storedFlow.continuation,
                updatedAt: updatedAt
            )
        }

        guard let currentMission else {
            if storedFlow.dateKey != todayKey {
                return LearningFlowState(
                    dateKey: todayKey,
                    roundNumber: 1,
                    stage: .needsCheckIn,
                    activeMissionId: nil,
                    continuation: storedFlow.continuation,
                    updatedAt: updatedAt
                )
            }

            return LearningFlowState(
                dateKey: todayKey,
                roundNumber: max(storedFlow.roundNumber, 1),
                stage: storedFlow.stage == .freePractice ? .freePractice : .needsCheckIn,
                activeMissionId: nil,
                continuation: storedFlow.continuation,
                updatedAt: storedFlow.updatedAt,
                completedFreePracticeSessionCount: storedFlow.completedFreePracticeSessionCount,
                lastFreePracticeCompletedAt: storedFlow.lastFreePracticeCompletedAt
            )
        }

        let stage: LearningFlowStage
        if storedFlow.stage == .freePractice {
            stage = .freePractice
        } else {
            stage = currentMission.status == .completed ? .missionCompleted : .missionActive
        }

        return LearningFlowState(
            dateKey: todayKey,
            roundNumber: roundNumber(
                fromMissionId: currentMission.id,
                fallback: max(storedFlow.roundNumber, 1)
            ),
            stage: stage,
            activeMissionId: currentMission.id,
            continuation: storedFlow.continuation,
            updatedAt: storedFlow.updatedAt,
            completedFreePracticeSessionCount: storedFlow.completedFreePracticeSessionCount,
            lastFreePracticeCompletedAt: storedFlow.lastFreePracticeCompletedAt
        )
    }

    static func continuation(
        from mission: DailyMission?,
        missionAttempts: [MissionAttempt],
        fallbackRoundNumber: Int
    ) -> LearningContinuation? {
        guard let mission else { return nil }
        let correctCount = Set(missionAttempts.filter(\.isCorrect).map(\.questionId)).count
        return LearningContinuation(
            missionId: mission.id,
            missionDateKey: mission.dateKey,
            roundNumber: roundNumber(fromMissionId: mission.id, fallback: fallbackRoundNumber),
            progressText: "已完成 \(min(correctCount, mission.targetCorrectCount)) / \(mission.targetCorrectCount)"
        )
    }

    static func roundNumber(fromMissionId missionId: String, fallback: Int) -> Int {
        guard let markerRange = missionId.range(of: "-r") else {
            return fallback
        }
        let afterMarker = missionId[markerRange.upperBound...]
        let numberText = afterMarker.prefix { $0.isNumber }
        return Int(numberText) ?? fallback
    }
}

struct StudentProgressSnapshot: Equatable {
    let correctCount: Int
    let targetCorrectCount: Int
    let status: MissionStatus

    var progressFraction: Double {
        guard targetCorrectCount > 0 else { return 0 }
        return min(Double(correctCount) / Double(targetCorrectCount), 1)
    }

    var remainingCount: Int {
        max(targetCorrectCount - correctCount, 0)
    }

    var progressText: String {
        return "已完成 \(correctCount) / \(targetCorrectCount)"
    }
}

struct StudentSupportRequest: Identifiable, Codable, Equatable {
    let id: String
    let studentUid: String
    let studentName: String
    let classCode: String
    let reason: SupportReason
    let route: SupportRoute
    var priority: RiskLevel
    var status: SupportThreadStatus
    var studentMessage: String
    var moodScore: Int?
    var latestQuestionId: String?
    var questionSnapshot: SupportQuestionSnapshot?
    var studentArchivedAt: Date? = nil
    var withdrawnAt: Date? = nil
    var staffArchivedAt: Date? = nil
    var teacherArchivedAt: Date? = nil
    var volunteerArchivedAt: Date? = nil
    var handledWithoutReplyAt: Date? = nil
    var teacherHandledWithoutReplyAt: Date? = nil
    var volunteerHandledWithoutReplyAt: Date? = nil
    var handledByUid: String? = nil
    var handledByName: String? = nil
    var handledByRole: UserRole? = nil
    var studentLastReadAt: Date? = nil
    let createdAt: Date
    var updatedAt: Date
    var replies: [SupportReply]

    var isVisibleToStudent: Bool {
        studentArchivedAt == nil && withdrawnAt == nil
    }

    var isWithdrawn: Bool {
        withdrawnAt != nil
    }

    var canStudentWithdrawBeforeReply: Bool {
        isVisibleToStudent
            && !isWithdrawn
            && visibleStaffRepliesToStudent.isEmpty
            && (status == .open || status == .waitingForStaff)
    }

    var canStudentArchiveAfterStaffArchivedWithoutReply: Bool {
        isVisibleToStudent
            && visibleStaffRepliesToStudent.isEmpty
            && status == .archived
    }

    var isWaitingForStaffAction: Bool {
        !hasAnyStaffAction
            && (status == .open || status == .waitingForStaff)
    }

    var hasCompleteQuestionSnapshotForStaff: Bool {
        guard let questionSnapshot else { return false }
        return !questionSnapshot.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !questionSnapshot.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !questionSnapshot.explanation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var requiresStaffTeachingResponse: Bool {
        countsTowardSharedStaffBadge(for: .teacher)
            || countsTowardSharedStaffBadge(for: .volunteer)
    }

    var countsTowardStaffBadge: Bool {
        requiresStaffTeachingResponse
    }

    var hasAnyStaffAction: Bool {
        !staffReplies.isEmpty
            || handledWithoutReplyAt != nil
            || teacherHandledWithoutReplyAt != nil
            || volunteerHandledWithoutReplyAt != nil
    }

    func isVisibleInStaffQueue(for role: UserRole) -> Bool {
        guard role != .student else { return false }
        guard !isWithdrawn else { return false }
        guard status != .archived && status != .closed else { return false }
        guard hasCompleteQuestionSnapshotForStaff else { return false }
        return !isArchivedForStaffRole(role)
    }

    func countsTowardSharedStaffBadge(for role: UserRole) -> Bool {
        isVisibleInStaffQueue(for: role)
            && !hasAnyStaffAction
            && (status == .open || status == .waitingForStaff)
    }

    var staffReplies: [SupportReply] {
        replies.filter(\.isStaffReply)
    }

    var visibleStaffRepliesToStudent: [SupportReply] {
        staffReplies.filter(\.visibleToStudent)
    }

    var hasStudentUnreadReply: Bool {
        isVisibleToStudent && status == .replied
    }

    var isPendingOnStudentLearningMap: Bool {
        isVisibleToStudent
            && (status == .open || status == .waitingForStaff || hasStudentUnreadReply)
    }

    private func isArchivedForStaffRole(_ role: UserRole) -> Bool {
        switch role {
        case .student:
            return false
        case .teacher:
            return teacherArchivedAt != nil
                || (staffArchivedAt != nil && handledByRole != .volunteer)
        case .volunteer:
            return volunteerArchivedAt != nil
                || (staffArchivedAt != nil && handledByRole != .teacher)
        }
    }
}

struct SupportQuestionSnapshot: Codable, Equatable {
    let questionId: String
    let prompt: String
    let options: [String]
    let questionTypeTitle: String
    let levelTitle: String
    let skill: String
    let selectedAnswer: String?
    let correctAnswer: String
    let explanation: String
    let repairHint: String

    init(
        questionId: String,
        prompt: String,
        options: [String],
        questionTypeTitle: String,
        levelTitle: String,
        skill: String,
        selectedAnswer: String?,
        correctAnswer: String,
        explanation: String,
        repairHint: String
    ) {
        self.questionId = questionId
        self.prompt = prompt
        self.options = options
        self.questionTypeTitle = questionTypeTitle
        self.levelTitle = levelTitle
        self.skill = skill
        self.selectedAnswer = selectedAnswer
        self.correctAnswer = correctAnswer
        self.explanation = explanation
        self.repairHint = repairHint
    }

    init(questionItem: QuestionBankItem, selectedAnswer: String?) {
        self.init(
            questionId: questionItem.id,
            prompt: questionItem.question.prompt,
            options: questionItem.question.options,
            questionTypeTitle: questionItem.question.type.title,
            levelTitle: questionItem.level.uiTitle,
            skill: questionItem.skill,
            selectedAnswer: selectedAnswer,
            correctAnswer: questionItem.question.answer,
            explanation: questionItem.question.explanation,
            repairHint: questionItem.question.repairHint
        )
    }

    var selectedAnswerText: String {
        guard let selectedAnswer,
              !selectedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return "尚未作答"
        }
        return selectedAnswer
    }
}

enum PracticeAssignmentStatus: String, Codable, Equatable {
    case pending
    case active
    case completed
}

struct TeacherAssignedPracticeTask: Identifiable, Codable, Equatable {
    let id: String
    let classId: String
    let studentUid: String
    let studentName: String
    let setId: String
    let setTitle: String
    let questionIds: [String]
    let assignedByUid: String
    let assignedByName: String
    var status: PracticeAssignmentStatus
    let createdAt: Date
    var updatedAt: Date
}

struct SupportReply: Identifiable, Codable, Equatable {
    let id: String
    let authorUid: String
    let authorName: String
    let authorRole: UserRole
    let body: String
    let visibleToStudent: Bool
    let createdAt: Date

    var isStaffReply: Bool {
        authorRole == .teacher || authorRole == .volunteer
    }
}

struct StaffStudentSummary: Identifiable, Equatable {
    let id: String
    let studentUid: String
    let studentName: String
    let classCode: String
    let moodScore: Int?
    let riskLevel: RiskLevel
    let missionProgress: String
    let nextAction: String
}

struct StaffDashboardMetrics: Equatable {
    let studentCount: Int
    let highRiskCount: Int
    let waitingHelpCount: Int
    let repliedCount: Int
    let questionCount: Int
    let averageMoodText: String
}

struct VolunteerDashboardMetrics: Equatable {
    let waitingCount: Int
    let highPriorityCount: Int
    let repliedByVolunteerCount: Int
    let syncRecordCount: Int
}

struct QuestionBankTypeOverview: Identifiable, Equatable {
    let type: QuestionType
    let totalCount: Int
    let levelCounts: [QuestionLevel: Int]

    var id: String {
        type.id
    }

    var levelSummary: String {
        QuestionLevel.allCases
            .map { "\($0.uiTitle) \(levelCounts[$0, default: 0])" }
            .joined(separator: "、")
    }
}

struct ClassroomReportExport: Equatable {
    let title: String
    let classCode: String
    let generatedAtText: String
    let metrics: [ClassroomReportMetric]
    let priorityStudents: [ClassroomReportStudentRow]
    let questionBankRows: [ClassroomReportQuestionBankRow]
    let recommendedActions: [String]

    var shareText: String {
        let metricLines = metrics.map { "- \($0.label): \($0.value) \($0.detail)" }
        let studentLines = priorityStudents.isEmpty
            ? ["- 目前沒有需要優先接力的學生。"]
            : priorityStudents.map { "- \($0.studentName): \($0.priorityText)，\($0.summary)" }
        let questionLines = questionBankRows.map { "- \($0.typeTitle): \($0.totalCount) 題，\($0.levelSummary)" }
        let actionLines = recommendedActions.map { "- \($0)" }

        return ([
            "# \(title)",
            "班級：\(classCode)",
            "產生時間：\(generatedAtText)",
            "",
            "## 班級摘要",
        ] + metricLines + [
            "",
            "## 優先學生",
        ] + studentLines + [
            "",
            "## 題庫摘要",
        ] + questionLines + [
            "",
            "## 建議行動",
        ] + actionLines).joined(separator: "\n")
    }

    var htmlBody: String {
        """
        <html>
        <head>
          <meta charset="utf-8">
          <title>\(title)</title>
          <style>
            body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; line-height: 1.6; color: #183047; padding: 24px; }
            h1 { color: #143B5B; }
            h2 { margin-top: 28px; color: #1D7D7A; }
            li { margin-bottom: 8px; }
          </style>
        </head>
        <body>
          <h1>\(title)</h1>
          <p>班級：\(classCode)<br>產生時間：\(generatedAtText)</p>
          <h2>班級摘要</h2>
          <ul>\(metrics.map { "<li>\($0.label): \($0.value) \($0.detail)</li>" }.joined())</ul>
          <h2>優先學生</h2>
          <ul>\(priorityStudents.isEmpty ? "<li>目前沒有需要優先接力的學生。</li>" : priorityStudents.map { "<li>\($0.studentName): \($0.priorityText)，\($0.summary)</li>" }.joined())</ul>
          <h2>題庫摘要</h2>
          <ul>\(questionBankRows.map { "<li>\($0.typeTitle): \($0.totalCount) 題，\($0.levelSummary)</li>" }.joined())</ul>
          <h2>建議行動</h2>
          <ul>\(recommendedActions.map { "<li>\($0)</li>" }.joined())</ul>
        </body>
        </html>
        """
    }
}

struct ClassroomReportMetric: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
    let detail: String
}

struct ClassroomReportStudentRow: Identifiable, Equatable {
    let id: String
    let studentName: String
    let classCode: String
    let priorityText: String
    let statusText: String
    let summary: String
}

struct ClassroomReportQuestionBankRow: Identifiable, Equatable {
    let id: String
    let typeTitle: String
    let totalCount: Int
    let levelSummary: String
}

struct LocalLearningSnapshot: Codable, Equatable {
    let currentCheckIn: MoodCheckIn?
    let currentMission: DailyMission?
    let missionAttempts: [MissionAttempt]
    let supportRequests: [StudentSupportRequest]
    let assignedPracticeTasks: [TeacherAssignedPracticeTask]
    let learningFlow: LearningFlowState
    let savedAt: Date

    private enum CodingKeys: String, CodingKey {
        case currentCheckIn
        case currentMission
        case missionAttempts
        case supportRequests
        case assignedPracticeTasks
        case learningFlow
        case savedAt
    }

    init(
        currentCheckIn: MoodCheckIn?,
        currentMission: DailyMission?,
        missionAttempts: [MissionAttempt],
        supportRequests: [StudentSupportRequest],
        assignedPracticeTasks: [TeacherAssignedPracticeTask] = [],
        learningFlow: LearningFlowState? = nil,
        savedAt: Date
    ) {
        self.currentCheckIn = currentCheckIn
        self.currentMission = currentMission
        self.missionAttempts = missionAttempts
        self.supportRequests = supportRequests
        self.assignedPracticeTasks = assignedPracticeTasks
        self.learningFlow = learningFlow ?? LearningFlowState.derived(
            dateKey: currentMission?.dateKey ?? currentCheckIn?.dateKey ?? Self.dateKey(from: savedAt),
            currentMission: currentMission,
            missionAttempts: missionAttempts,
            updatedAt: savedAt
        )
        self.savedAt = savedAt
    }

    init(snapshot: LearningRepositorySnapshot, savedAt: Date = Date()) {
        self.init(
            currentCheckIn: snapshot.currentCheckIn,
            currentMission: snapshot.currentMission,
            missionAttempts: snapshot.missionAttempts,
            supportRequests: snapshot.supportRequests,
            assignedPracticeTasks: snapshot.assignedPracticeTasks,
            learningFlow: snapshot.learningFlow,
            savedAt: savedAt
        )
    }

    var repositorySnapshot: LearningRepositorySnapshot {
        LearningRepositorySnapshot(
            currentCheckIn: currentCheckIn,
            currentMission: currentMission,
            missionAttempts: missionAttempts,
            supportRequests: supportRequests,
            assignedPracticeTasks: assignedPracticeTasks,
            learningFlow: learningFlow
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let currentCheckIn = try container.decodeIfPresent(MoodCheckIn.self, forKey: .currentCheckIn)
        let currentMission = try container.decodeIfPresent(DailyMission.self, forKey: .currentMission)
        let missionAttempts = try container.decodeIfPresent([MissionAttempt].self, forKey: .missionAttempts) ?? []
        let supportRequests = try container.decodeIfPresent([StudentSupportRequest].self, forKey: .supportRequests) ?? []
        let assignedPracticeTasks = try container.decodeIfPresent([TeacherAssignedPracticeTask].self, forKey: .assignedPracticeTasks) ?? []
        let savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
        let learningFlow = try container.decodeIfPresent(LearningFlowState.self, forKey: .learningFlow)

        self.init(
            currentCheckIn: currentCheckIn,
            currentMission: currentMission,
            missionAttempts: missionAttempts,
            supportRequests: supportRequests,
            assignedPracticeTasks: assignedPracticeTasks,
            learningFlow: learningFlow,
            savedAt: savedAt
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(currentCheckIn, forKey: .currentCheckIn)
        try container.encodeIfPresent(currentMission, forKey: .currentMission)
        try container.encode(missionAttempts, forKey: .missionAttempts)
        try container.encode(supportRequests, forKey: .supportRequests)
        try container.encode(assignedPracticeTasks, forKey: .assignedPracticeTasks)
        try container.encode(learningFlow, forKey: .learningFlow)
        try container.encode(savedAt, forKey: .savedAt)
    }

    private static func dateKey(from date: Date) -> String {
        localDateFormatter.string(from: date)
    }

    private static let localDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension QuestionType {
    var checkInLabel: String {
        title
    }
}

extension RiskLevel {
    var uiTitle: String {
        switch self {
        case .low:
            return "低風險"
        case .medium:
            return "中風險"
        case .high:
            return "高風險"
        }
    }
}

extension SupportThreadStatus {
    var uiTitle: String {
        switch self {
        case .open:
            return "已送出"
        case .waitingForStaff:
            return "等待接力"
        case .replied:
            return "已有回覆"
        case .readByStudent:
            return "學生已讀"
        case .staffHandledNoReply:
            return "已處理"
        case .archived:
            return "已歸檔"
        case .closed:
            return "已結案"
        }
    }
}

extension MissionTrack {
    var uiTitle: String {
        switch self {
        case .repair:
            return "低壓修復"
        case .steady:
            return "穩定練習"
        case .challenge:
            return "挑戰關卡"
        }
    }
}
