import Foundation

enum FirebaseBackendConfig {
    static let displayName = "English+"
    static let fallbackDisplayName = "Englishplus"
    static let projectId = "englishplus-testflight"
    static let bundleId = "tw.edu.englishplus"
    static let configFileName = "GoogleService-Info.plist"
    static let firstClassId = "YILAN-CHENGZHI-8A"
}

enum MissionTrack: String, Codable {
    case repair
    case steady
    case challenge
}

enum MissionStatus: String, Codable {
    case active
    case completed
    case paused
    case abandoned
}

enum RiskLevel: String, Codable {
    case low
    case medium
    case high
}

enum SupportThreadStatus: String, Codable {
    case open
    case waitingForStaff
    case replied
    case readByStudent
    case closed
}

enum SupportReason: String, Codable {
    case stuckOnQuestion = "stuck_on_question"
    case emotionalSupport = "emotional_support"
    case readingHelp = "reading_help"
    case teacherRequested = "teacher_requested"
}

enum MessageVisibility: String, Codable {
    case studentVisible
    case staffOnly
}

enum SupportMessageType: String, Codable {
    case studentRequest
    case aiSuggestion
    case teacherReply
    case volunteerReply
    case staffNote
    case systemStatus
}

struct FirestoreUserDocument: Codable, Equatable {
    let displayName: String
    let preferredName: String
    let primaryRole: UserRole
    let createdAt: Date
    let lastLoginAt: Date
    let active: Bool
}

struct FirestoreMemberDocument: Codable, Equatable {
    let uid: String
    let role: UserRole
    let displayName: String
    let active: Bool
    let joinedAt: Date
}

struct FirestoreStudentDocument: Codable, Equatable {
    let uid: String
    let displayName: String
    let gradeBand: String
    let classCode: String
    let currentLevel: String
    let recommendedTrack: MissionTrack
    let lastMoodScore: Int?
    let lastMissionStatus: MissionStatus
    let lastActivityAt: Date?
    let riskLevel: RiskLevel
    let legacyAndroidId: String?
}

struct FirestoreCheckInDocument: Codable, Equatable {
    let dateKey: String
    let moodScore: Int
    let availableTimeLevel: Int
    let wantsChallenge: Bool
    let preferredQuestionTypes: [QuestionType]
    let aiSummary: String?
    let createdAt: Date
}

struct FirestoreQuestionPlanItem: Codable, Equatable {
    let type: QuestionType
    let difficulty: QuestionLevel
    let targetCorrect: Int
}

struct FirestoreDailyMissionDocument: Codable, Equatable {
    let missionId: String
    let dateKey: String
    let sourceCheckInId: String
    let status: MissionStatus
    let track: MissionTrack
    let targetCorrectCount: Int
    let correctCount: Int
    let progressPercent: Int
    let recommendedMinutes: Int
    let questionPlan: [FirestoreQuestionPlanItem]
    let aiRationale: String?
    let createdAt: Date
    let completedAt: Date?
}

struct FirestoreAnswerEventDocument: Codable, Equatable {
    let eventId: String
    let questionId: String
    let missionId: String?
    let studentAnswer: String
    let isCorrect: Bool
    let attemptNumber: Int
    let aiExplanation: String?
    let createdAt: Date
}

struct FirestoreSupportThreadDocument: Codable, Equatable {
    let threadId: String
    let studentUid: String
    let classId: String
    let status: SupportThreadStatus
    let reason: SupportReason
    let priority: RiskLevel
    let assignedToUid: String?
    let assignedRole: UserRole?
    let studentVisible: Bool
    let latestMessagePreview: String
    let createdAt: Date
    let updatedAt: Date
}

struct FirestoreSupportMessageDocument: Codable, Equatable {
    let messageId: String
    let authorUid: String
    let authorRole: UserRole
    let body: String
    let visibility: MessageVisibility
    let messageType: SupportMessageType
    let createdAt: Date
}

struct FirestoreQuestionSource: Codable, Equatable {
    let kind: String
    let note: String
}

struct FirestoreQuestionBankDocument: Codable, Equatable {
    let questionId: String
    let level: QuestionLevel
    let type: QuestionType
    let skillTags: [String]
    let prompt: String
    let choices: [String]
    let answer: String
    let acceptedAnswers: [String]
    let explanation: String
    let repairHint: String
    let reviewState: ReviewState
    let source: FirestoreQuestionSource
    let updatedAt: Date
}

struct FirestoreStaffAssignmentDocument: Codable, Equatable {
    let assignmentId: String
    let classId: String
    let studentUid: String
    let assignedToUid: String
    let assignedRole: UserRole
    let title: String
    let contextSummary: String
    let nextAction: String
    let priority: RiskLevel
    let status: String
    let createdAt: Date
    let updatedAt: Date
}

struct FirestoreAiUsageDocument: Codable, Equatable {
    let uid: String
    let dateKey: String
    let role: UserRole
    let callCount: Int
    let tokenTotal: Int
    let updatedAt: Date
}

struct FirestoreAiEventDocument: Codable, Equatable {
    let uid: String
    let role: UserRole
    let dateKey: String
    let taskType: AiTaskType
    let ok: Bool
    let fallbackUsed: Bool
    let modelUsed: String?
    let qualityMode: AiQualityMode
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    let source: String
    let createdAt: Date
}
