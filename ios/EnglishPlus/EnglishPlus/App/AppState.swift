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
    @Published private(set) var runtimeDiagnostics: RuntimeDiagnosticsSnapshot

    private let authService: AuthService
    private let firestoreService: FirestoreService
    private let aiService: AIService
    private var didAttemptSessionRestore = false

    init(
        authService: AuthService,
        firestoreService: FirestoreService,
        aiService: AIService,
        runtimeDiagnostics: RuntimeDiagnosticsSnapshot
    ) {
        self.authService = authService
        self.firestoreService = firestoreService
        self.aiService = aiService
        self.runtimeDiagnostics = runtimeDiagnostics
    }

    func chooseRole(_ role: UserRole) {
        selectedRole = role
        route = .demoLogin(role)
    }

    func signIn(role: UserRole) async {
        let credential = DemoAccountCredential.credential(for: role)
        await signIn(email: credential.email, password: credential.password, role: role)
    }

    func signIn(email: String, password: String, role: UserRole) async {
        guard signingInRole == nil else { return }
        selectedRole = role
        signingInRole = role
        signInErrorMessage = nil

        do {
            let session = try await authService.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                expectedRole: role
            )
            currentUser = session.user
            currentProfile = session.profile
            runtimeDiagnostics = runtimeDiagnostics.withSession(user: session.user, profile: session.profile)
            hasAcceptedConsent = firestoreService.hasAcceptedRequiredConsent(uid: session.user.id)
            signingInRole = nil
            route = hasAcceptedConsent ? .home(role) : .privacyConsent(role)
        } catch {
            currentUser = nil
            currentProfile = nil
            hasAcceptedConsent = false
            signingInRole = nil
            signInErrorMessage = "登入失敗。請確認帳號密碼、Firebase 設定檔，以及 Firestore 班級成員資料是否正確。"
        }
    }

    func signInForSelectedRole() async {
        guard let selectedRole else { return }
        await signIn(role: selectedRole)
    }

    func restoreSessionIfPossible() async {
        guard !didAttemptSessionRestore else { return }
        didAttemptSessionRestore = true
        signInErrorMessage = nil

        do {
            guard let session = try await authService.restorePreviousSession() else {
                return
            }
            currentUser = session.user
            currentProfile = session.profile
            selectedRole = session.user.role
            runtimeDiagnostics = runtimeDiagnostics.withSession(user: session.user, profile: session.profile)
            hasAcceptedConsent = firestoreService.hasAcceptedRequiredConsent(uid: session.user.id)
            route = hasAcceptedConsent ? .home(session.user.role) : .privacyConsent(session.user.role)
        } catch {
            currentUser = nil
            currentProfile = nil
            hasAcceptedConsent = false
            runtimeDiagnostics = runtimeDiagnostics.clearingSession()
        }
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
        runtimeDiagnostics = runtimeDiagnostics.clearingSession()
        route = .roleSelection
    }

    func generateDailyMissionWithAI(context: DailyMissionAIContext) async -> AiProxyResponse {
        let response = await aiService.generateDailyMission(context: context, currentUser: currentUser)
        recordAIResponse(response)
        return response
    }

    func explainWrongAnswerWithAI(context: WrongAnswerAIContext) async -> AiProxyResponse {
        let response = await aiService.explainWrongAnswer(context: context, currentUser: currentUser)
        recordAIResponse(response)
        return response
    }

    func provideEmotionalSupportWithAI(context: SupportAIContext) async -> AiProxyResponse {
        let response = await aiService.provideEmotionalSupport(context: context, currentUser: currentUser)
        recordAIResponse(response)
        return response
    }

    func draftTeacherFeedbackWithAI(context: SupportAIContext) async -> AiProxyResponse {
        let response = await aiService.draftTeacherFeedback(context: context, currentUser: currentUser)
        recordAIResponse(response)
        return response
    }

    func coachVolunteerReplyWithAI(context: SupportAIContext) async -> AiProxyResponse {
        let response = await aiService.coachVolunteerReply(context: context, currentUser: currentUser)
        recordAIResponse(response)
        return response
    }

    func recommendPracticeWithAI(context: PracticeRecommendationAIContext) async -> AiProxyResponse {
        let response = await aiService.recommendPractice(context: context, currentUser: currentUser)
        recordAIResponse(response)
        return response
    }

    private func recordAIResponse(_ response: AiProxyResponse) {
        latestAIResponse = response
        runtimeDiagnostics = runtimeDiagnostics.recordingAIResponse(response)
    }
}
