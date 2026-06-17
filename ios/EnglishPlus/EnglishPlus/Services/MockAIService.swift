import Foundation

struct MockAIService: AIService {
    private let proxyService: AiProxyService

    init(proxyService: AiProxyService = MockAiProxyService()) {
        self.proxyService = proxyService
    }

    func generateDailyMission(
        context: DailyMissionAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse {
        await proxyService.run(.dailyMission(context: context), currentUser: currentUser)
    }

    func explainWrongAnswer(
        context: WrongAnswerAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse {
        await proxyService.run(.wrongAnswerExplanation(context: context), currentUser: currentUser)
    }

    func provideEmotionalSupport(
        context: SupportAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse {
        await proxyService.run(.emotionalSupport(context: context), currentUser: currentUser)
    }

    func draftTeacherFeedback(
        context: SupportAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse {
        await proxyService.run(.teacherFeedbackDraft(context: context), currentUser: currentUser)
    }

    func coachVolunteerReply(
        context: SupportAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse {
        await proxyService.run(.volunteerReplyCoach(context: context), currentUser: currentUser)
    }

    func recommendPractice(
        context: PracticeRecommendationAIContext,
        currentUser: DemoUser?
    ) async -> AiProxyResponse {
        await proxyService.run(.progressSummary(context: context), currentUser: currentUser)
    }
}
