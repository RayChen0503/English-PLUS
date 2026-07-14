import Foundation

struct LearningRepositorySnapshot: Equatable {
    var currentCheckIn: MoodCheckIn?
    var currentMission: DailyMission?
    var missionAttempts: [MissionAttempt]
    var supportRequests: [StudentSupportRequest]
    var assignedPracticeTasks: [TeacherAssignedPracticeTask]
    var masteryRecords: [SkillMasteryRecord]
    var learningFlow: LearningFlowState
}

enum LearningRepositorySyncStatus: Equatable {
    case idle
    case connecting(classId: String)
    case listening(classId: String)
    case retrying(classId: String, attempt: Int)
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

enum PracticeAssignmentMutationError: LocalizedError {
    case remoteSyncUnavailable
    case assignmentUnavailable
    case questionSetUnavailable

    var errorDescription: String? {
        switch self {
        case .remoteSyncUnavailable:
            return "班級任務目前無法同步，請確認網路後再試一次。"
        case .assignmentUnavailable:
            return "這組任務已被收回或不存在，列表已重新整理。"
        case .questionSetUnavailable:
            return "這組任務的題目尚未完整載入，請稍後再試。"
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
    func recordPracticeAnswer(
        studentUid: String,
        questionItem: QuestionBankItem,
        isCorrect: Bool,
        source: LearningAttemptSource
    )
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
    func startAssignedPracticeTask(_ assignment: TeacherAssignedPracticeTask) async throws
    func submitAssignedPracticeAnswer(
        _ answer: String,
        assignmentId: String
    ) async throws -> PracticeAssignmentQuestionResult?
    func withdrawAssignedPracticeTask(_ assignmentId: String) async throws
    func eraseLocalData(for uid: String)
}
