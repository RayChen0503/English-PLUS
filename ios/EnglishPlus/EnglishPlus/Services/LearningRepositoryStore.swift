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
        onChange: @escaping @MainActor (LearningRepositorySnapshot) -> Void
    ) -> LearningRepositoryListenerToken

    func generateMission(
        for user: DemoUser?,
        profile: AppUserProfile?,
        moodScore: Int,
        availableTimeLevel: Int,
        wantsChallenge: Bool,
        preferredQuestionTypes: [QuestionType]
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

    func startRealtimeSync(classId: String, user: DemoUser?) {
        listener?.cancel()
        listener = backend.startRealtimeListener(
            classId: classId,
            user: user
        ) { [weak self] snapshot in
            self?.apply(snapshot)
        }
        syncStatus = .listening(classId: classId)
    }

    func refresh() async {
        do {
            try await backend.refresh()
            apply(backend.snapshot)
        } catch {
            syncStatus = .offlineFallback(reason: String(describing: error))
            apply(backend.snapshot)
        }
    }

    func generateMission(
        for user: DemoUser?,
        profile: AppUserProfile?,
        moodScore: Int,
        availableTimeLevel: Int,
        wantsChallenge: Bool,
        preferredQuestionTypes: [QuestionType]
    ) {
        backend.generateMission(
            for: user,
            profile: profile,
            moodScore: moodScore,
            availableTimeLevel: availableTimeLevel,
            wantsChallenge: wantsChallenge,
            preferredQuestionTypes: preferredQuestionTypes
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

    private func apply(_ snapshot: LearningRepositorySnapshot) {
        currentCheckIn = snapshot.currentCheckIn
        currentMission = snapshot.currentMission
        missionAttempts = snapshot.missionAttempts
        supportRequests = snapshot.supportRequests
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
        onChange: @escaping @MainActor (LearningRepositorySnapshot) -> Void
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
