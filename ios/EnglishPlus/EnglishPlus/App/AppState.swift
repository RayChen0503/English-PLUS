import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute = .roleSelection
    @Published var selectedRole: UserRole?
    @Published var currentUser: DemoUser?
    @Published var currentProfile: AppUserProfile?
    @Published var hasAcceptedConsent = false
    @Published private(set) var signingInRole: UserRole?
    @Published private(set) var signInErrorMessage: String?
    @Published private(set) var latestAIResponse: AiProxyResponse?

    private let authService: AuthService
    private let firestoreService: FirestoreService
    private let aiService: AIService

    init(
        authService: AuthService,
        firestoreService: FirestoreService,
        aiService: AIService
    ) {
        self.authService = authService
        self.firestoreService = firestoreService
        self.aiService = aiService
    }

    func chooseRole(_ role: UserRole) {
        selectedRole = role
        route = .demoLogin(role)
    }

    func signIn(role: UserRole) async {
        guard signingInRole == nil else { return }
        selectedRole = role
        signingInRole = role
        signInErrorMessage = nil

        do {
            let session = try await authService.signInDemoAccount(for: role)
            currentUser = session.user
            currentProfile = session.profile
            hasAcceptedConsent = firestoreService.hasAcceptedRequiredConsent(uid: session.user.id)
            signingInRole = nil
            route = hasAcceptedConsent ? .home(role) : .privacyConsent(role)
        } catch {
            currentUser = nil
            currentProfile = nil
            hasAcceptedConsent = false
            signingInRole = nil
            signInErrorMessage = "登入失敗，請確認測試帳號、Firebase 設定與班級成員資料已建立。"
        }
    }

    func signInForSelectedRole() async {
        guard let selectedRole else { return }
        await signIn(role: selectedRole)
    }

    func acceptPrivacyConsent(categories: [PrivacyConsentCategory]) {
        guard let currentUser, let currentProfile else { return }
        let record = PrivacyConsentRecord.accepted(
            uid: currentUser.id,
            role: currentUser.role,
            classId: currentProfile.classId,
            categories: categories
        )
        firestoreService.saveConsent(record)
        hasAcceptedConsent = true
        route = .home(currentUser.role)
    }

    func signOut() {
        authService.signOut()
        selectedRole = nil
        currentUser = nil
        currentProfile = nil
        hasAcceptedConsent = false
        signingInRole = nil
        signInErrorMessage = nil
        latestAIResponse = nil
        route = .roleSelection
    }

    func generateDailyMissionWithAI(context: DailyMissionAIContext) async -> AiProxyResponse {
        let response = await aiService.generateDailyMission(context: context, currentUser: currentUser)
        latestAIResponse = response
        return response
    }

    func explainWrongAnswerWithAI(context: WrongAnswerAIContext) async -> AiProxyResponse {
        let response = await aiService.explainWrongAnswer(context: context, currentUser: currentUser)
        latestAIResponse = response
        return response
    }

    func provideEmotionalSupportWithAI(context: SupportAIContext) async -> AiProxyResponse {
        let response = await aiService.provideEmotionalSupport(context: context, currentUser: currentUser)
        latestAIResponse = response
        return response
    }

    func draftTeacherFeedbackWithAI(context: SupportAIContext) async -> AiProxyResponse {
        let response = await aiService.draftTeacherFeedback(context: context, currentUser: currentUser)
        latestAIResponse = response
        return response
    }

    func coachVolunteerReplyWithAI(context: SupportAIContext) async -> AiProxyResponse {
        let response = await aiService.coachVolunteerReply(context: context, currentUser: currentUser)
        latestAIResponse = response
        return response
    }

    func recommendPracticeWithAI(context: PracticeRecommendationAIContext) async -> AiProxyResponse {
        let response = await aiService.recommendPractice(context: context, currentUser: currentUser)
        latestAIResponse = response
        return response
    }
}
