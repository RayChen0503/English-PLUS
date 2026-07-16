import Foundation

extension LearningRepositoryStore {
    var supportedQuestionTypes: [QuestionType] {
        backend.supportedQuestionTypes
    }

    var defaultPreferredQuestionTypes: [QuestionType] {
        backend.defaultPreferredQuestionTypes
    }

    var questionBankItems: [QuestionBankItem] {
        backend.questionBankItems
    }

    func supportRequests(forStudentUid studentUid: String?) -> [StudentSupportRequest] {
        guard let studentUid else { return [] }
        return supportRequests
            .filter { $0.studentUid == studentUid }
            .filter(\.isVisibleToStudent)
            .filter(\.hasActionableSupportContent)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    func isSupportActionPending(for requestId: String) -> Bool {
        pendingSupportActionKeys.contains { $0.hasPrefix("\(requestId):") }
    }

    var isCreatingSupportRequest: Bool {
        pendingSupportActionKeys.contains { $0.hasPrefix("create-") }
    }

    func reportSupportReply(
        requestId: String,
        reply: SupportReply,
        reason: SupportSafetyReportReason
    ) async -> Bool {
        await performSupportAction(key: "\(requestId):report:\(reply.id)") {
            try await backend.reportSupportReply(
                requestId: requestId,
                reply: reply,
                reason: reason
            )
        }
    }

    func blockSupportAuthor(_ reply: SupportReply, requestId: String) async -> Bool {
        await performSupportAction(key: "\(requestId):block:\(reply.authorUid)") {
            try await backend.blockSupportAuthor(reply, requestId: requestId)
        }
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

    var masterySummary: MasterySummary {
        SpacedRepetitionEngine.summary(records: masteryRecords)
    }

    func dueReviewQuestions(limit: Int = 8) -> [QuestionBankItem] {
        SpacedRepetitionEngine.reviewQuestions(
            records: masteryRecords,
            questionBank: questionBankItems,
            limit: limit,
            rotationSeed: "review-\(UUID().uuidString)"
        )
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
        return Array(missedSkills.uniquedForReporting().prefix(3))
    }

    var progressSnapshot: StudentProgressSnapshot? {
        guard let currentMission else { return nil }
        return StudentProgressSnapshot(
            correctCount: reportingCorrectQuestionIds.count,
            targetCorrectCount: currentMission.targetCorrectCount,
            status: currentMission.status
        )
    }

    var nextMissionQuestion: QuestionBankItem? {
        guard let currentMission else { return nil }
        return currentMission.questions.first { !reportingCorrectQuestionIds.contains($0.id) }
    }

    var teacherQueue: [StudentSupportRequest] {
        supportRequests
            .filter { $0.isVisibleInStaffQueue(for: .teacher) }
            .sorted { reportingPriorityScore($0.priority) > reportingPriorityScore($1.priority) }
    }

    var volunteerQueue: [StudentSupportRequest] {
        supportRequests
            .filter { $0.isVisibleInStaffQueue(for: .volunteer) }
            .sorted { reportingPriorityScore($0.priority) > reportingPriorityScore($1.priority) }
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
        .uniquedForReporting(by: \.studentUid)
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

    private var reportingCorrectQuestionIds: Set<String> {
        Set(missionAttempts.filter(\.isCorrect).map(\.questionId))
    }

    private func reportingPriorityScore(_ riskLevel: RiskLevel) -> Int {
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

private extension Array {
    func uniquedForReporting<ID: Hashable>(by keyPath: KeyPath<Element, ID>) -> [Element] {
        var seen = Set<ID>()
        return filter { element in
            seen.insert(element[keyPath: keyPath]).inserted
        }
    }
}

private extension Array where Element: Hashable {
    func uniquedForReporting() -> [Element] {
        var seen = Set<Element>()
        return filter { element in
            seen.insert(element).inserted
        }
    }
}
