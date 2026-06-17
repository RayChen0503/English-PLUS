import Foundation

@MainActor
final class MockLearningRepository: ObservableObject {
    @Published private(set) var currentCheckIn: MoodCheckIn?
    @Published private(set) var currentMission: DailyMission?
    @Published private(set) var missionAttempts: [MissionAttempt] = []
    @Published private(set) var supportRequests: [StudentSupportRequest]

    private let seedSnapshot: SeedDataSnapshot
    private let now: () -> Date

    init(
        seedSnapshot: SeedDataSnapshot = SeedData.current,
        now: @escaping () -> Date = Date.init
    ) {
        self.seedSnapshot = seedSnapshot
        self.now = now
        supportRequests = Self.seedSupportRequests(now: now())
    }

    var supportedQuestionTypes: [QuestionType] {
        let seededTypes = Set(seedSnapshot.approvedQuestionBankItems.map(\.question.type))
        return QuestionType.allCases.filter { seededTypes.contains($0) }
    }

    var defaultPreferredQuestionTypes: [QuestionType] {
        let defaults = seedSnapshot.dailyMissionRules.defaultPreferredQuestionTypes
        return defaults.isEmpty ? Array(supportedQuestionTypes.prefix(2)) : defaults
    }

    var latestMissionAttempt: MissionAttempt? {
        missionAttempts.last
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

    func generateMission(
        for user: DemoUser?,
        profile: AppUserProfile?,
        moodScore: Int,
        availableTimeLevel: Int,
        wantsChallenge: Bool,
        preferredQuestionTypes: [QuestionType]
    ) {
        let date = now()
        let minutes = recommendedMinutes(for: availableTimeLevel)
        let targetCorrectCount = questionGoal(for: minutes)
        let selectedTypes = preferredQuestionTypes.isEmpty ? defaultPreferredQuestionTypes : preferredQuestionTypes
        let track = missionTrack(moodScore: moodScore, wantsChallenge: wantsChallenge)
        let studentUid = user?.id ?? "demo-student"
        let checkIn = MoodCheckIn(
            id: "checkin-\(todayKey(from: date))-\(studentUid)",
            studentUid: studentUid,
            dateKey: todayKey(from: date),
            moodScore: moodScore,
            availableTimeLevel: availableTimeLevel,
            wantsChallenge: wantsChallenge,
            preferredQuestionTypes: selectedTypes,
            recommendedMinutes: minutes,
            createdAt: date
        )
        let missionQuestions = selectMissionQuestions(
            preferredTypes: selectedTypes,
            track: track,
            targetCount: targetCorrectCount
        )

        currentCheckIn = checkIn
        currentMission = DailyMission(
            id: "mission-\(checkIn.dateKey)-\(studentUid)",
            studentUid: studentUid,
            dateKey: checkIn.dateKey,
            sourceCheckInId: checkIn.id,
            track: track,
            targetCorrectCount: max(1, min(targetCorrectCount, missionQuestions.count)),
            recommendedMinutes: minutes,
            questions: missionQuestions,
            createdAt: date,
            completedAt: nil
        )
        missionAttempts = []

        if let profile, moodScore <= 2 {
            sendSupportRequest(
                from: user,
                profile: profile,
                option: recoverySupportOption,
                message: "我今天狀態比較低，想先完成小任務。"
            )
        }
    }

    func submitMissionAnswer(_ answer: String) -> MissionAttempt? {
        guard var mission = currentMission, let questionItem = nextMissionQuestion else { return nil }
        let normalizedAnswer = normalize(answer)
        let acceptedAnswers = ([questionItem.question.answer] + questionItem.question.acceptedAnswers)
            .map(normalize)
        let isCorrect = acceptedAnswers.contains(normalizedAnswer)
        let attemptNumber = missionAttempts.filter { $0.questionId == questionItem.id }.count + 1
        let attempt = MissionAttempt(
            id: "attempt-\(mission.id)-\(questionItem.id)-\(attemptNumber)",
            missionId: mission.id,
            questionId: questionItem.id,
            prompt: questionItem.question.prompt,
            selectedAnswer: answer,
            acceptedAnswer: questionItem.question.answer,
            isCorrect: isCorrect,
            attemptNumber: attemptNumber,
            explanation: questionItem.question.explanation,
            repairHint: questionItem.question.repairHint,
            createdAt: now()
        )

        missionAttempts.append(attempt)
        if isCorrect && uniqueCorrectQuestionIds.count >= mission.targetCorrectCount {
            mission.completedAt = now()
            currentMission = mission
        }
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
        let date = now()
        let studentUid = user?.id ?? profile?.id ?? "demo-student"
        let studentName = user?.displayName ?? profile?.displayName ?? "展示學生"
        let moodScore = currentCheckIn?.moodScore
        let priority = priority(for: option, moodScore: moodScore)
        let request = StudentSupportRequest(
            id: "support-\(date.timeIntervalSince1970)-\(studentUid)",
            studentUid: studentUid,
            studentName: studentName,
            classCode: profile?.classId ?? FirebaseBackendConfig.firstClassId,
            reason: supportReason(for: option),
            route: option.route,
            priority: priority,
            status: .waitingForStaff,
            studentMessage: message ?? option.studentText,
            moodScore: moodScore,
            latestQuestionId: nextMissionQuestion?.id ?? latestMissionAttempt?.questionId,
            createdAt: date,
            updatedAt: date,
            replies: automaticReplies(for: option, at: date)
        )
        supportRequests.insert(request, at: 0)
    }

    func addTeacherReply(to requestId: String, body: String) {
        addReply(
            to: requestId,
            authorUid: "demo-teacher-1",
            authorName: "林老師",
            authorRole: .teacher,
            body: body
        )
    }

    func addVolunteerReply(to requestId: String, body: String) {
        addReply(
            to: requestId,
            authorUid: "demo-volunteer-1",
            authorName: "陪伴志工",
            authorRole: .volunteer,
            body: body
        )
    }

    private var uniqueCorrectQuestionIds: Set<String> {
        Set(missionAttempts.filter(\.isCorrect).map(\.questionId))
    }

    private var recoverySupportOption: SupportOption {
        seedSnapshot.supportOptions.first { $0.route == .recovery }
            ?? SupportOption(
                id: "low-energy",
                reason: "今天狀態不好",
                studentText: "我想先做很小的任務。",
                platformAction: "先完成一小步，再慢慢回到練習。",
                route: .recovery
            )
    }

    private func addReply(
        to requestId: String,
        authorUid: String,
        authorName: String,
        authorRole: UserRole,
        body: String
    ) {
        guard let index = supportRequests.firstIndex(where: { $0.id == requestId }) else { return }
        let date = now()
        let reply = SupportReply(
            id: "reply-\(date.timeIntervalSince1970)-\(requestId)",
            authorUid: authorUid,
            authorName: authorName,
            authorRole: authorRole,
            body: body,
            visibleToStudent: true,
            createdAt: date
        )
        supportRequests[index].replies.append(reply)
        supportRequests[index].status = .replied
        supportRequests[index].updatedAt = date
    }

    private func selectMissionQuestions(
        preferredTypes: [QuestionType],
        track: MissionTrack,
        targetCount: Int
    ) -> [QuestionBankItem] {
        let preferredSet = Set(preferredTypes)
        let approved = seedSnapshot.approvedQuestionBankItems
        let ranked = approved.sorted { lhs, rhs in
            score(item: lhs, preferredTypes: preferredSet, track: track) < score(item: rhs, preferredTypes: preferredSet, track: track)
        }
        return Array(ranked.uniqued(by: \.id).prefix(max(1, targetCount)))
    }

    private func score(
        item: QuestionBankItem,
        preferredTypes: Set<QuestionType>,
        track: MissionTrack
    ) -> Int {
        let preferredScore = preferredTypes.contains(item.question.type) ? 0 : 100
        let levelScore: Int
        switch (track, item.level) {
        case (.repair, .a1):
            levelScore = 0
        case (.repair, .a2):
            levelScore = 10
        case (.repair, .b1):
            levelScore = 30
        case (.repair, .b2):
            levelScore = 40
        case (.steady, .a1):
            levelScore = 10
        case (.steady, .a2):
            levelScore = 0
        case (.steady, .b1):
            levelScore = 12
        case (.steady, .b2):
            levelScore = 24
        case (.challenge, .a1):
            levelScore = 30
        case (.challenge, .a2):
            levelScore = 20
        case (.challenge, .b1):
            levelScore = 0
        case (.challenge, .b2):
            levelScore = 8
        }
        return preferredScore + levelScore
    }

    private func recommendedMinutes(for timeScale: Int) -> Int {
        seedSnapshot.dailyMissionRules.timeScaleRules
            .first { $0.timeScale == timeScale }?
            .minutes ?? 5
    }

    private func questionGoal(for minutes: Int) -> Int {
        seedSnapshot.dailyMissionRules.goalRules
            .first { rule in
                minutes >= rule.minMinutes && (rule.maxMinutes == nil || minutes <= rule.maxMinutes!)
            }?
            .questionGoal ?? 2
    }

    private func missionTrack(moodScore: Int, wantsChallenge: Bool) -> MissionTrack {
        if wantsChallenge {
            return .challenge
        }
        if moodScore <= 2 {
            return .repair
        }
        return .steady
    }

    private func supportReason(for option: SupportOption) -> SupportReason {
        switch option.route {
        case .aiCoach:
            return .stuckOnQuestion
        case .humanHandoff:
            return .teacherRequested
        case .readingBreakdown:
            return .readingHelp
        case .recovery:
            return .emotionalSupport
        }
    }

    private func priority(for option: SupportOption, moodScore: Int?) -> RiskLevel {
        if let moodScore, moodScore <= 2 {
            return .high
        }
        switch option.route {
        case .humanHandoff:
            return .high
        case .readingBreakdown, .recovery:
            return .medium
        case .aiCoach:
            return .low
        }
    }

    private func automaticReplies(for option: SupportOption, at date: Date) -> [SupportReply] {
        guard option.route == .aiCoach || option.route == .readingBreakdown || option.route == .recovery else {
            return []
        }
        return [
            SupportReply(
                id: "reply-auto-\(option.id)",
                authorUid: "englishplus-support",
                authorName: "English+",
                authorRole: .volunteer,
                body: option.platformAction,
                visibleToStudent: true,
                createdAt: date
            )
        ]
    }

    private func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func todayKey(from date: Date) -> String {
        Self.dateFormatter.string(from: date)
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func seedSupportRequests(now: Date) -> [StudentSupportRequest] {
        [
            StudentSupportRequest(
                id: "support-seed-teacher-1",
                studentUid: "demo-student-1",
                studentName: "小安",
                classCode: FirebaseBackendConfig.firstClassId,
                reason: .teacherRequested,
                route: .humanHandoff,
                priority: .high,
                status: .waitingForStaff,
                studentMessage: "我連續卡在 if 條件句，想請老師看一下。",
                moodScore: 2,
                latestQuestionId: "cap-style-0003",
                createdAt: now.addingTimeInterval(-3_600),
                updatedAt: now.addingTimeInterval(-3_600),
                replies: []
            ),
            StudentSupportRequest(
                id: "support-seed-volunteer-1",
                studentUid: "demo-student-2",
                studentName: "小晴",
                classCode: FirebaseBackendConfig.firstClassId,
                reason: .emotionalSupport,
                route: .humanHandoff,
                priority: .medium,
                status: .waitingForStaff,
                studentMessage: "今天想有人陪我把短任務做完。",
                moodScore: 3,
                latestQuestionId: "cap-style-0006",
                createdAt: now.addingTimeInterval(-1_800),
                updatedAt: now.addingTimeInterval(-1_800),
                replies: []
            )
        ]
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
