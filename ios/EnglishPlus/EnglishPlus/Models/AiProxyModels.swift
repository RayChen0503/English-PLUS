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

struct AiPracticePlanOutput: Codable, Equatable {
    var title: String
    var targetQuestionCount: Int
    var focusSkills: [String]
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
    var practicePlan: AiPracticePlanOutput?
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

extension AiProxyResponse {
    var userFacingAvailabilityMessage: String {
        guard fallbackUsed else {
            return "已整理成下一個可執行的小步驟。"
        }

        switch errorCode {
        case "AI_DAILY_LIMIT_REACHED":
            return "今天的 AI 協助額度已用完，先用內建提示繼續；額度會在明天自動恢復。"
        case "AI_BURST_LIMIT_REACHED":
            return "剛才的請求比較密集，先用內建提示繼續，稍後就能再請 AI 幫忙。"
        case "AI_ACCOUNT_NOT_ACTIVE", "AI_CLASS_MEMBERSHIP_REQUIRED",
             "AI_PERSONAL_SCOPE_FORBIDDEN", "AI_STUDENT_IDENTITY_MISMATCH",
             "AI_STUDENT_SCOPE_REQUIRED", "AI_TARGET_STUDENT_NOT_ACTIVE",
             "AI_TASK_ROLE_FORBIDDEN", "AI_SUPPORT_THREAD_REQUIRED",
             "AI_SUPPORT_THREAD_FORBIDDEN", "AI_REQUEST_ID_REUSED",
             "AUTH_REQUIRED", "TOKEN_INVALID":
            return "目前無法取得這次的個人化建議，先用內建提示繼續。"
        case "GROQ_TIMEOUT", "GROQ_UNAVAILABLE", "AI_PROXY_TIMEOUT",
             "AI_PROXY_UNAVAILABLE", "AI_QUOTA_UNAVAILABLE",
             "AI_QUOTA_NOT_CONFIGURED", "AI_RATE_LIMITER_NOT_CONFIGURED":
            return "AI 暫時沒有回應，已切換成內建提示，不會影響你繼續學習。"
        default:
            return "先用內建提示幫你整理下一步。"
        }
    }
}

extension QuestionType {
    var aiProxyValue: String {
        switch self {
        case .vocabulary:
            return "vocabulary"
        case .grammar:
            return "multipleChoice"
        case .fillBlank:
            return "fillBlank"
        case .cloze:
            return "cloze"
        case .reading:
            return "reading"
        case .translation:
            return "translation"
        case .dialogue:
            return "dialogue"
        }
    }
}
