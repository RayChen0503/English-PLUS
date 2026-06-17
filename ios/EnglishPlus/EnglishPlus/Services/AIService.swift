import Foundation

struct DailyMissionAIContext: Equatable {
    let classId: String
    let studentUid: String?
    let moodScore: Int
    let availableTimeLevel: Int
    let wantsChallenge: Bool
    let preferredQuestionTypes: [QuestionType]
    let recentAccuracy: Double?
    let recentWeakSkills: [String]
}

struct WrongAnswerAIContext: Equatable {
    let classId: String
    let studentUid: String?
    let attempt: MissionAttempt
    let questionItem: QuestionBankItem?
}

struct SupportAIContext: Equatable {
    let request: StudentSupportRequest
}

struct PracticeRecommendationAIContext: Equatable {
    let classId: String
    let studentUid: String?
    let recentAccuracy: Double?
    let recentWeakSkills: [String]
    let preferredQuestionTypes: [QuestionType]
}

protocol AIService {
    func generateDailyMission(
        context: DailyMissionAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse

    func explainWrongAnswer(
        context: WrongAnswerAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse

    func provideEmotionalSupport(
        context: SupportAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse

    func draftTeacherFeedback(
        context: SupportAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse

    func coachVolunteerReply(
        context: SupportAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse

    func recommendPractice(
        context: PracticeRecommendationAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse
}

extension AiProxyRequest {
    static func dailyMission(context: DailyMissionAIContext) -> AiProxyRequest {
        AiProxyRequest(
            taskType: .dailyMission,
            classId: context.classId,
            studentUid: context.studentUid,
            sessionId: "daily-mission-\(context.studentUid ?? "demo")",
            qualityMode: .free,
            locale: .zhTW,
            context: AiProxyContext(
                moodScore: context.moodScore,
                availableTimeLevel: context.availableTimeLevel,
                wantsChallenge: context.wantsChallenge,
                preferredQuestionTypes: context.preferredQuestionTypes.map(\.aiProxyValue),
                recentAccuracy: context.recentAccuracy,
                recentWeakSkills: context.recentWeakSkills,
                questionType: nil,
                questionPrompt: nil,
                studentAnswer: nil,
                correctAnswer: nil,
                explanation: nil,
                supportReason: nil,
                supportThreadId: nil,
                attemptCount: nil
            )
        )
    }

    static func wrongAnswerExplanation(context: WrongAnswerAIContext) -> AiProxyRequest {
        AiProxyRequest(
            taskType: .wrongAnswerExplanation,
            classId: context.classId,
            studentUid: context.studentUid,
            sessionId: "wrong-answer-\(context.attempt.questionId)",
            qualityMode: .free,
            locale: .zhTW,
            context: AiProxyContext(
                moodScore: nil,
                availableTimeLevel: nil,
                wantsChallenge: nil,
                preferredQuestionTypes: nil,
                recentAccuracy: nil,
                recentWeakSkills: nil,
                questionType: context.questionItem?.question.type.aiProxyValue,
                questionPrompt: context.questionItem?.question.prompt ?? context.attempt.prompt,
                studentAnswer: context.attempt.selectedAnswer,
                correctAnswer: context.attempt.acceptedAnswer,
                explanation: context.attempt.explanation,
                supportReason: nil,
                supportThreadId: nil,
                attemptCount: context.attempt.attemptNumber
            )
        )
    }

    static func emotionalSupport(context: SupportAIContext) -> AiProxyRequest {
        supportRequest(
            taskType: .emotionalSupport,
            request: context.request,
            sessionPrefix: "emotional-support"
        )
    }

    static func teacherFeedbackDraft(context: SupportAIContext) -> AiProxyRequest {
        supportRequest(
            taskType: .teacherFeedbackDraft,
            request: context.request,
            sessionPrefix: "teacher-feedback"
        )
    }

    static func volunteerReplyCoach(context: SupportAIContext) -> AiProxyRequest {
        supportRequest(
            taskType: .volunteerReplyCoach,
            request: context.request,
            sessionPrefix: "volunteer-reply"
        )
    }

    static func progressSummary(context: PracticeRecommendationAIContext) -> AiProxyRequest {
        AiProxyRequest(
            taskType: .progressSummary,
            classId: context.classId,
            studentUid: context.studentUid,
            sessionId: "practice-recommendation-\(context.studentUid ?? "demo")",
            qualityMode: .free,
            locale: .zhTW,
            context: AiProxyContext(
                moodScore: nil,
                availableTimeLevel: nil,
                wantsChallenge: nil,
                preferredQuestionTypes: context.preferredQuestionTypes.map(\.aiProxyValue),
                recentAccuracy: context.recentAccuracy,
                recentWeakSkills: context.recentWeakSkills,
                questionType: nil,
                questionPrompt: nil,
                studentAnswer: nil,
                correctAnswer: nil,
                explanation: nil,
                supportReason: "practiceRecommendation",
                supportThreadId: nil,
                attemptCount: nil
            )
        )
    }

    private static func supportRequest(
        taskType: AiTaskType,
        request: StudentSupportRequest,
        sessionPrefix: String
    ) -> AiProxyRequest {
        AiProxyRequest(
            taskType: taskType,
            classId: request.classCode,
            studentUid: request.studentUid,
            sessionId: "\(sessionPrefix)-\(request.id)",
            qualityMode: .free,
            locale: .zhTW,
            context: AiProxyContext(
                moodScore: request.moodScore,
                availableTimeLevel: nil,
                wantsChallenge: nil,
                preferredQuestionTypes: nil,
                recentAccuracy: nil,
                recentWeakSkills: nil,
                questionType: nil,
                questionPrompt: nil,
                studentAnswer: request.studentMessage,
                correctAnswer: nil,
                explanation: request.replies.last?.body,
                supportReason: request.reason.rawValue,
                supportThreadId: request.id,
                attemptCount: request.replies.count
            )
        )
    }
}
