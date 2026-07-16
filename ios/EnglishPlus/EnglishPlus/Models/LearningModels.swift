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

enum LearningAttemptSource: String, Codable, Equatable {
    case dailyMission
    case freePractice
    case repairPractice
    case teacherAssignment
}

enum MasteryBand: String, Codable, Equatable, CaseIterable {
    case needsReview
    case developing
    case strong
    case mastered

    var title: String {
        switch self {
        case .needsReview:
            return "需要複習"
        case .developing:
            return "正在建立"
        case .strong:
            return "表現穩定"
        case .mastered:
            return "已熟練"
        }
    }
}

struct SkillMasteryRecord: Identifiable, Codable, Equatable {
    let id: String
    let studentUid: String
    let curriculumKey: String
    let unit: String
    let skill: String
    let questionType: QuestionType
    let level: QuestionLevel
    var attemptCount: Int
    var correctCount: Int
    var firstTryCorrectCount: Int
    var consecutiveCorrectCount: Int
    var masteryScore: Int
    var lastQuestionId: String
    var lastResultCorrect: Bool
    var lastAttemptSource: LearningAttemptSource
    var lastAnsweredAt: Date
    var nextReviewAt: Date
    var updatedAt: Date

    func isDue(at date: Date = Date()) -> Bool {
        nextReviewAt <= date
    }

    var accuracy: Double {
        guard attemptCount > 0 else { return 0 }
        return Double(correctCount) / Double(attemptCount)
    }

    var band: MasteryBand {
        if !lastResultCorrect || masteryScore < 55 {
            return .needsReview
        }
        if attemptCount >= 8, masteryScore >= 85, consecutiveCorrectCount >= 3 {
            return .mastered
        }
        if attemptCount >= 4, masteryScore >= 70, consecutiveCorrectCount >= 2 {
            return .strong
        }
        return .developing
    }
}

struct MasterySummary: Equatable {
    let trackedSkillCount: Int
    let dueReviewCount: Int
    let strongSkillCount: Int
    let averageScore: Int

    static let empty = MasterySummary(
        trackedSkillCount: 0,
        dueReviewCount: 0,
        strongSkillCount: 0,
        averageScore: 0
    )
}

enum SpacedRepetitionEngine {
    static func recording(
        existing: SkillMasteryRecord?,
        studentUid: String,
        item: QuestionBankItem,
        isCorrect: Bool,
        firstTryCorrect: Bool,
        source: LearningAttemptSource,
        at date: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> SkillMasteryRecord {
        let priorAttemptCount = existing?.attemptCount ?? 0
        let priorScore = existing?.masteryScore ?? 50
        let outcomeScore = isCorrect ? (firstTryCorrect ? 100 : 72) : 20
        let learningWeight = max(14, 34 - min(priorAttemptCount, 10) * 2)
        let updatedScore = min(
            100,
            max(0, Int((Double(priorScore * (100 - learningWeight) + outcomeScore * learningWeight) / 100).rounded()))
        )
        let streak = isCorrect ? (existing?.consecutiveCorrectCount ?? 0) + 1 : 0
        let intervalDays = isCorrect ? reviewIntervalDays(for: streak) : 0
        let nextReviewAt = calendar.date(byAdding: .day, value: intervalDays, to: date) ?? date

        return SkillMasteryRecord(
            id: existing?.id ?? masteryId(for: item),
            studentUid: studentUid,
            curriculumKey: item.curriculumKey,
            unit: item.unit,
            skill: item.skill.isEmpty ? item.question.concept : item.skill,
            questionType: item.question.type,
            level: item.level,
            attemptCount: priorAttemptCount + 1,
            correctCount: (existing?.correctCount ?? 0) + (isCorrect ? 1 : 0),
            firstTryCorrectCount: (existing?.firstTryCorrectCount ?? 0) + (firstTryCorrect ? 1 : 0),
            consecutiveCorrectCount: streak,
            masteryScore: updatedScore,
            lastQuestionId: item.id,
            lastResultCorrect: isCorrect,
            lastAttemptSource: source,
            lastAnsweredAt: date,
            nextReviewAt: nextReviewAt,
            updatedAt: date
        )
    }

    static func summary(
        records: [SkillMasteryRecord],
        at date: Date = Date()
    ) -> MasterySummary {
        guard !records.isEmpty else { return .empty }
        let dueCount = records.filter { $0.isDue(at: date) || $0.band == .needsReview }.count
        let strongCount = records.filter { $0.band == .strong || $0.band == .mastered }.count
        let average = Int((Double(records.map(\.masteryScore).reduce(0, +)) / Double(records.count)).rounded())
        return MasterySummary(
            trackedSkillCount: records.count,
            dueReviewCount: dueCount,
            strongSkillCount: strongCount,
            averageScore: average
        )
    }

    static func reviewQuestions(
        records: [SkillMasteryRecord],
        questionBank: [QuestionBankItem],
        limit: Int,
        at date: Date = Date(),
        rotationSeed: String
    ) -> [QuestionBankItem] {
        let target = max(0, min(limit, 12))
        guard target > 0 else { return [] }
        let eligibleRecords = records
            .filter { $0.isDue(at: date) || $0.band == .needsReview || $0.masteryScore < 70 }
        let recordsByPriority = (eligibleRecords.isEmpty ? records : eligibleRecords)
            .sorted { lhs, rhs in
                let lhsDue = lhs.isDue(at: date) || lhs.band == .needsReview
                let rhsDue = rhs.isDue(at: date) || rhs.band == .needsReview
                if lhsDue != rhsDue { return lhsDue && !rhsDue }
                if lhs.masteryScore != rhs.masteryScore { return lhs.masteryScore < rhs.masteryScore }
                return lhs.nextReviewAt < rhs.nextReviewAt
            }

        let lastQuestionIds = Set(recordsByPriority.map(\.lastQuestionId))
        let lastSemanticKeys = Set(
            questionBank
                .filter { lastQuestionIds.contains($0.id) }
                .map(\.semanticKey)
        )
        var selected: [QuestionBankItem] = []
        var seenSemanticKeys = Set<String>()
        for record in recordsByPriority where selected.count < target {
            let candidates = questionBank.filter {
                $0.curriculumKey == record.curriculumKey
                    && $0.id != record.lastQuestionId
                    && !lastSemanticKeys.contains($0.semanticKey)
                    && !seenSemanticKeys.contains($0.semanticKey)
            }
            guard let item = QuestionGroupingEngine.balancedItems(
                from: candidates,
                limit: 1,
                rotationSeed: "\(rotationSeed)-\(record.id)"
            ).first else { continue }
            selected.append(item)
            seenSemanticKeys.insert(item.semanticKey)
        }

        guard selected.count < target else { return selected }
        let priorityKeys = Set(recordsByPriority.map(\.curriculumKey))
        let fill = QuestionGroupingEngine.balancedItems(
            from: questionBank.filter {
                priorityKeys.contains($0.curriculumKey)
                    && !lastQuestionIds.contains($0.id)
                    && !lastSemanticKeys.contains($0.semanticKey)
                    && !seenSemanticKeys.contains($0.semanticKey)
            },
            limit: target - selected.count,
            rotationSeed: "\(rotationSeed)-fill"
        )
        return selected + fill
    }

    private static func reviewIntervalDays(for streak: Int) -> Int {
        let intervals = [1, 3, 7, 14, 30]
        return intervals[min(max(streak - 1, 0), intervals.count - 1)]
    }

    private static func masteryId(for item: QuestionBankItem) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in item.curriculumKey.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return "mastery-\(String(hash, radix: 16))"
    }
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

    var hasActionableHumanSupportContext: Bool {
        reason == .emotionalSupport
            && !studentMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasActionableSupportContent: Bool {
        hasCompleteQuestionSnapshotForStaff || hasActionableHumanSupportContext
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
        guard hasCompleteQuestionSnapshotForStaff || hasActionableHumanSupportContext else { return false }
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
        guard isVisibleToStudent,
              let latestReplyAt = visibleStaffRepliesToStudent.map(\.createdAt).max()
        else {
            return false
        }
        guard let studentLastReadAt else { return true }
        return latestReplyAt > studentLastReadAt
    }

    var reconciledStatus: SupportThreadStatus {
        if isWithdrawn {
            return .closed
        }
        if studentArchivedAt != nil {
            return .readByStudent
        }
        if !visibleStaffRepliesToStudent.isEmpty {
            return hasStudentUnreadReply ? .replied : .readByStudent
        }
        if teacherArchivedAt != nil && volunteerArchivedAt != nil {
            return .archived
        }
        if handledWithoutReplyAt != nil
            || teacherHandledWithoutReplyAt != nil
            || volunteerHandledWithoutReplyAt != nil {
            return .staffHandledNoReply
        }
        if status == .open || status == .waitingForStaff {
            return status
        }
        return .waitingForStaff
    }

    func reconcilingLifecycle() -> StudentSupportRequest {
        var request = self
        request.status = reconciledStatus
        return request
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
    case withdrawn
}

struct PracticeAssignmentQuestionResult: Identifiable, Codable, Equatable {
    let id: String
    let questionId: String
    let prompt: String
    let selectedAnswer: String
    let acceptedAnswer: String
    let isCorrect: Bool
    let explanation: String
    let repairHint: String
    let answeredAt: Date
    let attemptCount: Int
    let firstAttemptCorrect: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case questionId
        case prompt
        case selectedAnswer
        case acceptedAnswer
        case isCorrect
        case explanation
        case repairHint
        case answeredAt
        case attemptCount
        case firstAttemptCorrect
    }

    init(
        id: String,
        questionId: String,
        prompt: String,
        selectedAnswer: String,
        acceptedAnswer: String,
        isCorrect: Bool,
        explanation: String,
        repairHint: String,
        answeredAt: Date,
        attemptCount: Int = 1,
        firstAttemptCorrect: Bool? = nil
    ) {
        self.id = id
        self.questionId = questionId
        self.prompt = prompt
        self.selectedAnswer = selectedAnswer
        self.acceptedAnswer = acceptedAnswer
        self.isCorrect = isCorrect
        self.explanation = explanation
        self.repairHint = repairHint
        self.answeredAt = answeredAt
        self.attemptCount = max(1, attemptCount)
        self.firstAttemptCorrect = firstAttemptCorrect ?? isCorrect
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let isCorrect = try container.decode(Bool.self, forKey: .isCorrect)
        self.init(
            id: try container.decode(String.self, forKey: .id),
            questionId: try container.decode(String.self, forKey: .questionId),
            prompt: try container.decode(String.self, forKey: .prompt),
            selectedAnswer: try container.decode(String.self, forKey: .selectedAnswer),
            acceptedAnswer: try container.decode(String.self, forKey: .acceptedAnswer),
            isCorrect: isCorrect,
            explanation: try container.decode(String.self, forKey: .explanation),
            repairHint: try container.decode(String.self, forKey: .repairHint),
            answeredAt: try container.decode(Date.self, forKey: .answeredAt),
            attemptCount: try container.decodeIfPresent(Int.self, forKey: .attemptCount) ?? 1,
            firstAttemptCorrect: try container.decodeIfPresent(Bool.self, forKey: .firstAttemptCorrect) ?? isCorrect
        )
    }
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
    var questionResults: [PracticeAssignmentQuestionResult]? = nil
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

enum SupportSafetyReportReason: String, CaseIterable, Identifiable, Codable {
    case inappropriateContent
    case harassment
    case privacyConcern
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inappropriateContent:
            return "內容不適當"
        case .harassment:
            return "讓我感到不舒服"
        case .privacyConcern:
            return "涉及個人資料"
        case .other:
            return "其他原因"
        }
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
    let priorityHelpCount: Int
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

        var lines = [
            "# \(title)",
            "班級：\(classCode)",
            "產生時間：\(generatedAtText)",
            "",
            "## 班級摘要",
        ]
        lines.append(contentsOf: metricLines)
        lines.append(contentsOf: [
            "",
            "## 優先學生",
        ])
        lines.append(contentsOf: studentLines)
        lines.append(contentsOf: [
            "",
            "## 題庫摘要",
        ])
        lines.append(contentsOf: questionLines)
        lines.append(contentsOf: [
            "",
            "## 建議行動",
        ])
        lines.append(contentsOf: actionLines)
        return lines.joined(separator: "\n")
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
    let masteryRecords: [SkillMasteryRecord]
    let learningFlow: LearningFlowState
    let savedAt: Date

    private enum CodingKeys: String, CodingKey {
        case currentCheckIn
        case currentMission
        case missionAttempts
        case supportRequests
        case assignedPracticeTasks
        case masteryRecords
        case learningFlow
        case savedAt
    }

    init(
        currentCheckIn: MoodCheckIn?,
        currentMission: DailyMission?,
        missionAttempts: [MissionAttempt],
        supportRequests: [StudentSupportRequest],
        assignedPracticeTasks: [TeacherAssignedPracticeTask] = [],
        masteryRecords: [SkillMasteryRecord] = [],
        learningFlow: LearningFlowState? = nil,
        savedAt: Date
    ) {
        self.currentCheckIn = currentCheckIn
        self.currentMission = currentMission
        self.missionAttempts = missionAttempts
        self.supportRequests = supportRequests
        self.assignedPracticeTasks = assignedPracticeTasks
        self.masteryRecords = masteryRecords
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
            masteryRecords: snapshot.masteryRecords,
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
            masteryRecords: masteryRecords,
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
        let masteryRecords = try container.decodeIfPresent([SkillMasteryRecord].self, forKey: .masteryRecords) ?? []
        let savedAt = try container.decodeIfPresent(Date.self, forKey: .savedAt) ?? Date()
        let learningFlow = try container.decodeIfPresent(LearningFlowState.self, forKey: .learningFlow)

        self.init(
            currentCheckIn: currentCheckIn,
            currentMission: currentMission,
            missionAttempts: missionAttempts,
            supportRequests: supportRequests,
            assignedPracticeTasks: assignedPracticeTasks,
            masteryRecords: masteryRecords,
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
        try container.encode(masteryRecords, forKey: .masteryRecords)
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
            return "一般"
        case .medium:
            return "較優先"
        case .high:
            return "優先回覆"
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
