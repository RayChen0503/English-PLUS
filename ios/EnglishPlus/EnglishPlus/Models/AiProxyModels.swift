import Foundation

enum AiTaskType: String, CaseIterable, Identifiable, Codable {
    case dailyMission
    case wrongAnswerExplanation
    case emotionalSupport
    case teacherFeedbackDraft
    case volunteerReplyCoach
    case progressSummary

    var id: String { rawValue }
}

enum AiQualityMode: String, Codable {
    case free
    case quality
}

enum AiProxyLocale: String, Codable {
    case zhTW = "zh-TW"
    case enUS = "en-US"
}

enum AiMissionTrack: String, Codable {
    case repair
    case steady
    case challenge
}

struct AiProxyContext: Codable, Equatable {
    var moodScore: Int?
    var availableTimeLevel: Int?
    var wantsChallenge: Bool?
    var preferredQuestionTypes: [String]?
    var recentAccuracy: Double?
    var recentWeakSkills: [String]?
    var questionType: String?
    var questionPrompt: String?
    var studentAnswer: String?
    var correctAnswer: String?
    var explanation: String?
    var supportReason: String?
    var supportThreadId: String?
    var attemptCount: Int?
}

struct AiProxyRequest: Codable, Equatable {
    var taskType: AiTaskType
    var classId: String
    var studentUid: String?
    var sessionId: String?
    var qualityMode: AiQualityMode
    var locale: AiProxyLocale
    var context: AiProxyContext
}

struct AiProxyUsage: Codable, Equatable {
    var promptTokens: Int
    var completionTokens: Int
    var totalTokens: Int
}

struct AiQuestionPlanItem: Codable, Equatable {
    var type: String
    var difficulty: String
    var targetCorrect: Int
}

struct AiMissionOutput: Codable, Equatable {
    var track: AiMissionTrack
    var targetCorrectCount: Int
    var recommendedMinutes: Int
    var questionPlan: [AiQuestionPlanItem]
}

struct AiProxyOutput: Codable, Equatable {
    var summary: String?
    var mission: AiMissionOutput?
    var shortFeedback: String?
    var whyWrong: String?
    var nextHint: String?
    var tryAgain: Bool?
    var staffEscalationNeeded: Bool?
    var supportLevel: String?
    var teacherSummary: String?
    var studentFacingFeedback: String?
    var recommendedNextAction: String?
}

struct AiProxyResponse: Codable, Equatable {
    var ok: Bool
    var fallbackUsed: Bool
    var taskType: AiTaskType
    var qualityMode: AiQualityMode
    var modelUsed: String?
    var output: AiProxyOutput
    var usage: AiProxyUsage?
    var requestId: String
    var errorCode: String?
}

extension QuestionType {
    var aiProxyValue: String {
        switch self {
        case .choice:
            return "multipleChoice"
        case .fillBlank:
            return "fillBlank"
        case .cloze:
            return "cloze"
        case .reading:
            return "reading"
        case .translation:
            return "translation"
        }
    }
}
