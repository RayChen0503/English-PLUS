import Foundation

@MainActor
final class MockLearningRepository: ObservableObject {
    @Published private(set) var currentCheckIn: MoodCheckIn?
    @Published private(set) var currentMission: DailyMission?
    @Published private(set) var missionAttempts: [MissionAttempt] = []
    @Published private(set) var supportRequests: [StudentSupportRequest]
    @Published private(set) var assignedPracticeTasks: [TeacherAssignedPracticeTask]
    @Published private(set) var learningFlow: LearningFlowState

    private let seedSnapshot: SeedDataSnapshot
    private let now: () -> Date
    private let localPersistence: any LocalLearningPersistence

    init(
        seedSnapshot: SeedDataSnapshot = SeedData.current,
        now: @escaping () -> Date = Date.init,
        localPersistence: any LocalLearningPersistence = UserDefaultsLearningPersistence()
    ) {
        self.seedSnapshot = seedSnapshot
        self.now = now
        self.localPersistence = localPersistence

        if let restoredSnapshot = localPersistence.loadSnapshot()?.repositorySnapshot {
            currentCheckIn = restoredSnapshot.currentCheckIn
            currentMission = restoredSnapshot.currentMission
            missionAttempts = restoredSnapshot.missionAttempts
            supportRequests = restoredSnapshot.supportRequests
            assignedPracticeTasks = restoredSnapshot.assignedPracticeTasks
            learningFlow = Self.normalizedLearningFlow(
                from: restoredSnapshot,
                todayKey: Self.dateKey(from: now()),
                now: now()
            )
        } else {
            supportRequests = Self.seedSupportRequests(now: now())
            assignedPracticeTasks = []
            learningFlow = LearningFlowState.initial(
                dateKey: Self.dateKey(from: now()),
                updatedAt: now()
            )
        }
    }

    var supportedQuestionTypes: [QuestionType] {
        let seededTypes = Set(seedSnapshot.approvedQuestionBankItems.map(\.question.type))
        return QuestionType.allCases.filter { seededTypes.contains($0) }
    }

    var defaultPreferredQuestionTypes: [QuestionType] {
        let defaults = seedSnapshot.dailyMissionRules.defaultPreferredQuestionTypes
        return defaults.isEmpty ? Array(supportedQuestionTypes.prefix(2)) : defaults
    }

    var questionPracticeSets: [QuestionPracticeSet] {
        QuestionPracticeSet.catalog(from: seedSnapshot.approvedQuestionBankItems)
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
            .filter(\.isWaitingForStaffAction)
            .sorted { priorityScore($0.priority) > priorityScore($1.priority) }
    }

    var volunteerQueue: [StudentSupportRequest] {
        supportRequests
            .filter { request in
                request.isWaitingForStaffAction
                    && (request.route == .humanHandoff || request.reason == .emotionalSupport || request.reason == .readingHelp)
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
        preferredQuestionTypes: [QuestionType],
        aiMission: AiMissionOutput? = nil
    ) {
        let date = now()
        let dateKey = todayKey(from: date)
        let roundNumber = learningFlow.dateKey == dateKey ? max(learningFlow.roundNumber, 1) : 1
        let minutes = aiMission?.recommendedMinutes ?? recommendedMinutes(for: availableTimeLevel)
        let targetCorrectCount = aiMission?.targetCorrectCount ?? questionGoal(for: minutes)
        let aiSelectedTypes = questionTypes(from: aiMission?.questionPlan)
        let selectedTypes = aiSelectedTypes.isEmpty
            ? (preferredQuestionTypes.isEmpty ? defaultPreferredQuestionTypes : preferredQuestionTypes)
            : aiSelectedTypes
        let track = missionTrack(from: aiMission?.track) ?? missionTrack(moodScore: moodScore, wantsChallenge: wantsChallenge)
        let studentUid = user?.id ?? "demo-student"
        let checkIn = MoodCheckIn(
            id: "checkin-\(dateKey)-r\(roundNumber)-\(studentUid)",
            studentUid: studentUid,
            dateKey: dateKey,
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
            id: "mission-\(checkIn.dateKey)-r\(roundNumber)-\(studentUid)",
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
        learningFlow = LearningFlowState(
            dateKey: checkIn.dateKey,
            roundNumber: roundNumber,
            stage: .missionActive,
            activeMissionId: currentMission?.id,
            continuation: nil,
            updatedAt: date
        )
        missionAttempts = []
        persistSnapshot()

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
            markAssignmentCompletedIfNeeded(sourceId: mission.sourceCheckInId)
            learningFlow = LearningFlowState(
                dateKey: mission.dateKey,
                roundNumber: learningFlow.roundNumber,
                stage: .missionCompleted,
                activeMissionId: mission.id,
                continuation: LearningFlowState.continuation(
                    from: mission,
                    missionAttempts: missionAttempts,
                    fallbackRoundNumber: learningFlow.roundNumber
                ),
                updatedAt: now()
            )
        }
        persistSnapshot()
        return attempt
    }

    func assignPracticeSet(_ set: QuestionPracticeSet, to student: StaffStudentSummary, by teacher: DemoUser?) {
        let date = now()
        let assignment = TeacherAssignedPracticeTask(
            id: "practice-assignment-\(date.timeIntervalSince1970)-\(student.studentUid)-\(set.id)",
            classId: student.classCode,
            studentUid: student.studentUid,
            studentName: student.studentName,
            setId: set.id,
            setTitle: set.title,
            questionIds: set.questionIds,
            assignedByUid: teacher?.id ?? "demo-teacher-1",
            assignedByName: teacher?.displayName ?? "Teacher",
            status: .pending,
            createdAt: date,
            updatedAt: date
        )
        assignedPracticeTasks.removeAll {
            $0.studentUid == student.studentUid
                && $0.setId == set.id
                && $0.status != .completed
        }
        assignedPracticeTasks.insert(assignment, at: 0)
        persistSnapshot()
    }

    func startAssignedPracticeTask(_ assignment: TeacherAssignedPracticeTask) {
        let date = now()
        let dateKey = todayKey(from: date)
        let questions = questionBankItems(for: assignment.questionIds)
        guard !questions.isEmpty else { return }
        let targetCount = max(1, min(questions.count, 12))
        let track: MissionTrack = questions.contains { $0.level == .b1 || $0.level == .b2 } ? .challenge : .steady

        if let index = assignedPracticeTasks.firstIndex(where: { $0.id == assignment.id }) {
            assignedPracticeTasks[index].status = .active
            assignedPracticeTasks[index].updatedAt = date
        }

        currentCheckIn = nil
        currentMission = DailyMission(
            id: "mission-assigned-\(dateKey)-r\(max(learningFlow.roundNumber, 1))-\(assignment.studentUid)",
            studentUid: assignment.studentUid,
            dateKey: dateKey,
            sourceCheckInId: assignment.id,
            track: track,
            targetCorrectCount: targetCount,
            recommendedMinutes: max(3, min(18, questions.count * 2)),
            questions: questions,
            createdAt: date,
            completedAt: nil
        )
        missionAttempts = []
        learningFlow = LearningFlowState(
            dateKey: dateKey,
            roundNumber: max(learningFlow.roundNumber, 1),
            stage: .missionActive,
            activeMissionId: currentMission?.id,
            continuation: nil,
            updatedAt: date
        )
        persistSnapshot()
    }

    func startNewLearningRound(for user: DemoUser?, profile: AppUserProfile?) {
        let date = now()
        let dateKey = todayKey(from: date)
        let roundNumber = nextRoundNumber(for: dateKey)
        let continuation = LearningFlowState.continuation(
            from: currentMission,
            missionAttempts: missionAttempts,
            fallbackRoundNumber: learningFlow.roundNumber
        ) ?? learningFlow.continuation

        currentCheckIn = nil
        currentMission = nil
        missionAttempts = []
        learningFlow = LearningFlowState(
            dateKey: dateKey,
            roundNumber: roundNumber,
            stage: .needsCheckIn,
            activeMissionId: nil,
            continuation: continuation,
            updatedAt: date
        )
        persistSnapshot()
    }

    func continueLearningFlow() {
        guard let mission = currentMission else {
            returnToMissionFlow()
            return
        }
        let stage: LearningFlowStage = mission.status == .completed ? .missionCompleted : .missionActive
        learningFlow = LearningFlowState(
            dateKey: mission.dateKey,
            roundNumber: LearningFlowState.roundNumber(fromMissionId: mission.id, fallback: learningFlow.roundNumber),
            stage: stage,
            activeMissionId: mission.id,
            continuation: nil,
            updatedAt: now()
        )
        persistSnapshot()
    }

    func enterFreePracticeMode() {
        learningFlow = LearningFlowState(
            dateKey: learningFlow.dateKey,
            roundNumber: learningFlow.roundNumber,
            stage: .freePractice,
            activeMissionId: currentMission?.id,
            continuation: LearningFlowState.continuation(
                from: currentMission,
                missionAttempts: missionAttempts,
                fallbackRoundNumber: learningFlow.roundNumber
            ) ?? learningFlow.continuation,
            updatedAt: now()
        )
        persistSnapshot()
    }

    func returnToMissionFlow() {
        let date = now()
        guard let mission = currentMission else {
            learningFlow = LearningFlowState(
                dateKey: todayKey(from: date),
                roundNumber: learningFlow.roundNumber,
                stage: .needsCheckIn,
                activeMissionId: nil,
                continuation: learningFlow.continuation,
                updatedAt: date
            )
            persistSnapshot()
            return
        }

        learningFlow = LearningFlowState(
            dateKey: mission.dateKey,
            roundNumber: LearningFlowState.roundNumber(fromMissionId: mission.id, fallback: learningFlow.roundNumber),
            stage: mission.status == .completed ? .missionCompleted : .missionActive,
            activeMissionId: mission.id,
            continuation: LearningFlowState.continuation(
                from: mission,
                missionAttempts: missionAttempts,
                fallbackRoundNumber: learningFlow.roundNumber
            ),
            updatedAt: date
        )
        persistSnapshot()
    }

    func supportRequests(forStudentUid studentUid: String?) -> [StudentSupportRequest] {
        guard let studentUid else { return [] }
        return supportRequests
            .filter { $0.studentUid == studentUid }
            .filter(\.isVisibleToStudent)
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
            questionSnapshot: nil,
            createdAt: date,
            updatedAt: date,
            replies: automaticReplies(for: option, at: date)
        )
        supportRequests.insert(request, at: 0)
        persistSnapshot()
    }

    func sendQuestionSupportRequest(
        from user: DemoUser?,
        profile: AppUserProfile?,
        option: SupportOption,
        questionItem: QuestionBankItem,
        selectedAnswer: String?,
        message: String
    ) {
        let date = now()
        let studentUid = user?.id ?? profile?.id ?? "demo-student"
        let studentName = user?.displayName ?? profile?.displayName ?? "學生"
        let moodScore = currentCheckIn?.moodScore
        let request = StudentSupportRequest(
            id: "support-question-\(date.timeIntervalSince1970)-\(studentUid)-\(questionItem.id)",
            studentUid: studentUid,
            studentName: studentName,
            classCode: profile?.classId ?? FirebaseBackendConfig.firstClassId,
            reason: supportReason(for: option),
            route: option.route,
            priority: priority(for: option, moodScore: moodScore),
            status: .waitingForStaff,
            studentMessage: message,
            moodScore: moodScore,
            latestQuestionId: questionItem.id,
            questionSnapshot: SupportQuestionSnapshot(questionItem: questionItem, selectedAnswer: selectedAnswer),
            createdAt: date,
            updatedAt: date,
            replies: []
        )
        supportRequests.insert(request, at: 0)
        persistSnapshot()
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

    func markSupportThreadReadByStudent(_ requestId: String) {
        guard let index = supportRequests.firstIndex(where: { $0.id == requestId }) else { return }
        guard supportRequests[index].status == .replied else { return }
        supportRequests[index].status = .readByStudent
        let date = now()
        supportRequests[index].studentLastReadAt = date
        supportRequests[index].updatedAt = date
        persistSnapshot()
    }

    func archiveSupportThreadForStudent(_ requestId: String) {
        guard let index = supportRequests.firstIndex(where: { $0.id == requestId }) else { return }
        let date = now()
        supportRequests[index].studentArchivedAt = date
        if supportRequests[index].status == .replied {
            supportRequests[index].status = .readByStudent
            supportRequests[index].studentLastReadAt = date
        }
        supportRequests[index].updatedAt = date
        persistSnapshot()
    }

    func markSupportThreadHandledWithoutReply(_ requestId: String, by staffUser: DemoUser?) {
        guard let index = supportRequests.firstIndex(where: { $0.id == requestId }) else { return }
        let date = now()
        supportRequests[index].status = .staffHandledNoReply
        supportRequests[index].handledWithoutReplyAt = date
        supportRequests[index].handledByUid = staffUser?.id
        supportRequests[index].handledByName = staffUser?.displayName
        supportRequests[index].handledByRole = staffUser?.role
        supportRequests[index].updatedAt = date
        persistSnapshot()
    }

    func archiveSupportThreadForStaff(_ requestId: String, by staffUser: DemoUser?) {
        guard let index = supportRequests.firstIndex(where: { $0.id == requestId }) else { return }
        let date = now()
        supportRequests[index].status = .archived
        supportRequests[index].staffArchivedAt = date
        supportRequests[index].handledByUid = staffUser?.id
        supportRequests[index].handledByName = staffUser?.displayName
        supportRequests[index].handledByRole = staffUser?.role
        supportRequests[index].updatedAt = date
        persistSnapshot()
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
        persistSnapshot()
    }

    private func persistSnapshot() {
        localPersistence.saveSnapshot(LocalLearningSnapshot(snapshot: snapshot))
    }

    private func markAssignmentCompletedIfNeeded(sourceId: String) {
        guard let index = assignedPracticeTasks.firstIndex(where: { $0.id == sourceId }) else { return }
        assignedPracticeTasks[index].status = .completed
        assignedPracticeTasks[index].updatedAt = now()
    }

    private func questionBankItems(for questionIds: [String]) -> [QuestionBankItem] {
        let ids = Set(questionIds)
        return seedSnapshot.approvedQuestionBankItems.filter { ids.contains($0.id) }
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

    private func missionTrack(from aiTrack: AiMissionTrack?) -> MissionTrack? {
        switch aiTrack {
        case .repair:
            return .repair
        case .steady:
            return .steady
        case .challenge:
            return .challenge
        case nil:
            return nil
        }
    }

    private func questionTypes(from plan: [AiQuestionPlanItem]?) -> [QuestionType] {
        guard let plan else { return [] }
        let types = plan.compactMap { questionType(from: $0.type) }
        return types.uniqued(by: \.self)
    }

    private func questionType(from aiValue: String) -> QuestionType? {
        switch aiValue {
        case "vocabulary":
            return .vocabulary
        case "multipleChoice", "grammar", "choice":
            return .grammar
        case "fillBlank":
            return .fillBlank
        case "cloze":
            return .cloze
        case "reading":
            return .reading
        case "translation", "sentenceReorder":
            return .translation
        case "dialogue":
            return .dialogue
        default:
            return nil
        }
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

    private func nextRoundNumber(for dateKey: String) -> Int {
        guard learningFlow.dateKey == dateKey else { return 1 }
        guard currentCheckIn != nil || currentMission != nil || learningFlow.stage != .needsCheckIn else {
            return max(learningFlow.roundNumber, 1)
        }
        return max(learningFlow.roundNumber + 1, 1)
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

    private static func dateKey(from date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private static func normalizedLearningFlow(
        from snapshot: LearningRepositorySnapshot,
        todayKey: String,
        now: Date
    ) -> LearningFlowState {
        LearningFlowState.normalizedForToday(
            todayKey: todayKey,
            currentMission: snapshot.currentMission,
            missionAttempts: snapshot.missionAttempts,
            storedFlow: snapshot.learningFlow,
            updatedAt: now
        )
    }

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
                questionSnapshot: nil,
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
                questionSnapshot: nil,
                createdAt: now.addingTimeInterval(-1_800),
                updatedAt: now.addingTimeInterval(-1_800),
                replies: []
            )
        ]
    }
}

protocol LocalLearningPersistence {
    func loadSnapshot() -> LocalLearningSnapshot?
    func saveSnapshot(_ snapshot: LocalLearningSnapshot)
    func clearSnapshot()
}

struct UserDefaultsLearningPersistence: LocalLearningPersistence {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "englishplus.learning.snapshot.v1"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadSnapshot() -> LocalLearningSnapshot? {
        guard let data = defaults.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(LocalLearningSnapshot.self, from: data)
    }

    func saveSnapshot(_ snapshot: LocalLearningSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    func clearSnapshot() {
        defaults.removeObject(forKey: key)
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
