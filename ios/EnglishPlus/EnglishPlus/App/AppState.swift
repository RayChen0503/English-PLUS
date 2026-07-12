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
    @Published private(set) var authNoticeMessage: String?
    @Published private(set) var verificationEmailAddress: String?
    @Published private(set) var isManagingAccount = false
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
        signInErrorMessage = nil
        authNoticeMessage = nil
        verificationEmailAddress = nil
        route = .demoLogin(role)
    }

    func signIn(email: String, password: String, role: UserRole) async {
        guard signingInRole == nil else { return }
        selectedRole = role
        signingInRole = role
        signInErrorMessage = nil
        authNoticeMessage = nil
        verificationEmailAddress = nil

        do {
            let session = try await authService.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password,
                expectedRole: role
            )
            await finishAuthenticatedSession(session)
            signingInRole = nil
        } catch {
            clearFailedAuthenticationState()
            if let authError = error as? AuthServiceError,
               case .emailNotVerified = authError {
                verificationEmailAddress = email.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            signInErrorMessage = userMessage(for: error)
        }
    }

    func createAccount(
        email: String,
        password: String,
        displayName: String,
        role: UserRole
    ) async {
        await createAccount(
            AccountRegistration(
                email: email,
                password: password,
                displayName: displayName,
                role: role,
                teacherAffiliation: nil,
                volunteerApplication: nil
            )
        )
    }

    func createAccount(_ registration: AccountRegistration) async {
        guard signingInRole == nil else { return }
        selectedRole = registration.role
        signingInRole = registration.role
        signInErrorMessage = nil
        authNoticeMessage = nil
        verificationEmailAddress = nil

        do {
            let outcome = try await authService.createAccount(registration)
            switch outcome {
            case .authenticated(let session):
                await finishAuthenticatedSession(session)
            case .emailVerificationRequired(let email):
                clearFailedAuthenticationState()
                verificationEmailAddress = email
                authNoticeMessage = "驗證信已寄出。完成信箱驗證後，就可以回來登入。"
            case .approvalPending(_, let role):
                clearFailedAuthenticationState()
                authNoticeMessage = role == .volunteer
                    ? "志工申請已送出，審核通過後即可登入。"
                    : "帳號申請已送出，請等待審核。"
            }
            signingInRole = nil
        } catch {
            clearFailedAuthenticationState()
            signInErrorMessage = userMessage(for: error)
        }
    }

    func sendPasswordReset(email: String) async {
        guard !isManagingAccount else { return }
        isManagingAccount = true
        signInErrorMessage = nil
        authNoticeMessage = nil

        do {
            try await authService.sendPasswordReset(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            authNoticeMessage = "如果這個 email 已有帳號，重設密碼信會寄到該信箱。"
        } catch {
            signInErrorMessage = userMessage(for: error)
        }
        isManagingAccount = false
    }

    func resendVerification(email: String, password: String) async {
        guard !isManagingAccount else { return }
        isManagingAccount = true
        signInErrorMessage = nil
        authNoticeMessage = nil

        do {
            try await authService.resendVerification(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            verificationEmailAddress = email.trimmingCharacters(in: .whitespacesAndNewlines)
            authNoticeMessage = "新的驗證信已寄出，請到信箱完成驗證。"
        } catch {
            signInErrorMessage = userMessage(for: error)
        }
        isManagingAccount = false
    }

    func restoreSessionIfPossible() async {
        guard !didAttemptSessionRestore else { return }
        didAttemptSessionRestore = true
        signInErrorMessage = nil
        authNoticeMessage = nil
        verificationEmailAddress = nil
        isManagingAccount = false

        do {
            guard let session = try await authService.restorePreviousSession() else {
                return
            }
            await finishAuthenticatedSession(session)
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
        authNoticeMessage = nil
        verificationEmailAddress = nil
        isManagingAccount = false
        latestAIResponse = nil
        runtimeDiagnostics = runtimeDiagnostics.clearingSession()
        route = .roleSelection
    }

    func selectActiveClass(_ classId: String?) async {
        guard let currentUser, let currentProfile else { return }
        signInErrorMessage = nil

        do {
            let session = try await authService.selectActiveClass(
                classId,
                in: AuthSession(user: currentUser, profile: currentProfile)
            )
            self.currentUser = session.user
            self.currentProfile = session.profile
            selectedRole = session.user.role
            runtimeDiagnostics = runtimeDiagnostics.withSession(
                user: session.user,
                profile: session.profile
            )
            route = .home(session.user.role)
        } catch {
            signInErrorMessage = "無法切換班級，請確認你仍是該班級的成員。"
        }
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

    private func finishAuthenticatedSession(_ session: AuthSession) async {
        currentUser = session.user
        currentProfile = session.profile
        selectedRole = session.user.role
        runtimeDiagnostics = runtimeDiagnostics.withSession(user: session.user, profile: session.profile)
        hasAcceptedConsent = await acceptedConsentStatus(for: session.user.id)
        route = hasAcceptedConsent ? .home(session.user.role) : .privacyConsent(session.user.role)
    }

    private func acceptedConsentStatus(for uid: String) async -> Bool {
        if let record = await firestoreService.loadConsentRecord(uid: uid) {
            return record.accepted && record.version == PrivacyConsentRecord.currentVersion
        }
        return firestoreService.hasAcceptedRequiredConsent(uid: uid)
    }

    private func clearFailedAuthenticationState() {
        currentUser = nil
        currentProfile = nil
        hasAcceptedConsent = false
        signingInRole = nil
        runtimeDiagnostics = runtimeDiagnostics.clearingSession()
    }

    private func userMessage(for error: Error) -> String {
        if let authError = error as? AuthServiceError {
            return authError.userMessage
        }
        return "目前無法完成這個操作，請稍後再試。"
    }

    private func recordAIResponse(_ response: AiProxyResponse) {
        latestAIResponse = response
        runtimeDiagnostics = runtimeDiagnostics.recordingAIResponse(response)
    }
}
