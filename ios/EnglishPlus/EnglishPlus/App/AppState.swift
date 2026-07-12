import Foundation
import UniformTypeIdentifiers

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
    @Published private(set) var volunteerApplicationDraft: VolunteerApplicationInput?
    @Published private(set) var isAdministrator = false
    @Published private(set) var volunteerReviewApplications: [VolunteerReviewApplication] = []
    @Published private(set) var volunteerReviewErrorMessage: String?
    @Published private(set) var isLoadingVolunteerReviews = false
    @Published private(set) var runtimeDiagnostics: RuntimeDiagnosticsSnapshot

    private let authService: AuthService
    private let firestoreService: FirestoreService
    private let aiService: AIService
    private let evidenceUploadService: EvidenceUploadService
    private let volunteerReviewService: VolunteerReviewService
    private var didAttemptSessionRestore = false
    private var pendingIdentityCredential: FederatedIdentityCredential?
    private var pendingIdentityRole: UserRole?

    init(
        authService: AuthService,
        firestoreService: FirestoreService,
        aiService: AIService,
        evidenceUploadService: EvidenceUploadService,
        volunteerReviewService: VolunteerReviewService,
        runtimeDiagnostics: RuntimeDiagnosticsSnapshot
    ) {
        self.authService = authService
        self.firestoreService = firestoreService
        self.aiService = aiService
        self.evidenceUploadService = evidenceUploadService
        self.volunteerReviewService = volunteerReviewService
        self.runtimeDiagnostics = runtimeDiagnostics
    }

    func chooseRole(_ role: UserRole) {
        if let pendingIdentityRole, pendingIdentityRole != role {
            pendingIdentityCredential = nil
            self.pendingIdentityRole = nil
        }
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

    var canUseFederatedSignIn: Bool {
        runtimeDiagnostics.backendMode == .firebase
            && runtimeDiagnostics.hasFirebaseConfig
    }

    func signIn(
        with credential: FederatedIdentityCredential,
        role: UserRole
    ) async {
        guard signingInRole == nil else { return }
        selectedRole = role
        signingInRole = role
        clearAuthFeedback()

        do {
            let session = try await authService.signIn(
                with: credential,
                expectedRole: role
            )
            await finishAuthenticatedSession(session)
            signingInRole = nil
        } catch {
            clearFailedAuthenticationState()
            if let authError = error as? AuthServiceError,
               authError == .accountLinkRequired {
                pendingIdentityCredential = credential
                pendingIdentityRole = role
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
            await handleCreationOutcome(outcome)
            signingInRole = nil
        } catch {
            clearFailedAuthenticationState()
            signInErrorMessage = userMessage(for: error)
        }
    }

    func createAccount(
        with credential: FederatedIdentityCredential,
        profile: RoleOnboardingProfile
    ) async {
        guard signingInRole == nil else { return }
        selectedRole = profile.role
        signingInRole = profile.role
        clearAuthFeedback()

        do {
            let outcome = try await authService.createAccount(
                with: credential,
                profile: profile
            )
            await handleCreationOutcome(outcome)
            signingInRole = nil
        } catch {
            clearFailedAuthenticationState()
            signInErrorMessage = userMessage(for: error)
        }
    }

    func presentAuthenticationError(_ error: Error) {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription {
            signInErrorMessage = description
        } else {
            signInErrorMessage = "登入沒有完成，請再試一次。"
        }
    }

    func clearAuthFeedback() {
        signInErrorMessage = nil
        authNoticeMessage = nil
        verificationEmailAddress = nil
    }

    func uploadVolunteerEvidence(
        from fileURL: URL,
        kind: VolunteerQualificationKind
    ) async throws -> VolunteerEvidenceReference {
        let accessingSecurityScopedResource = fileURL.startAccessingSecurityScopedResource()
        defer {
            if accessingSecurityScopedResource {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .nameKey])
        if let fileSize = values.fileSize, fileSize > 10 * 1024 * 1024 {
            throw EvidenceUploadError.fileTooLarge
        }
        let data = try Data(contentsOf: fileURL, options: [.mappedIfSafe])
        let mimeType = UTType(filenameExtension: fileURL.pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        return try await evidenceUploadService.upload(
            data: data,
            filename: values.name ?? fileURL.lastPathComponent,
            mimeType: mimeType,
            kind: kind
        )
    }

    func deleteVolunteerEvidence(_ reference: VolunteerEvidenceReference) async throws {
        try await evidenceUploadService.delete(reference)
    }

    func submitVolunteerApplication(_ application: VolunteerApplicationInput) async {
        guard let currentUser, let currentProfile, signingInRole == nil else { return }
        signingInRole = .volunteer
        clearAuthFeedback()
        do {
            let outcome = try await authService.submitVolunteerApplication(
                application,
                in: AuthSession(user: currentUser, profile: currentProfile)
            )
            await handleCreationOutcome(outcome)
            route = .demoLogin(.volunteer)
            signingInRole = nil
        } catch {
            signingInRole = nil
            signInErrorMessage = userMessage(for: error)
        }
    }

    func loadVolunteerApplicationDraft() async {
        guard let currentUser, let currentProfile else { return }
        volunteerApplicationDraft = try? await authService.loadVolunteerApplication(
            in: AuthSession(user: currentUser, profile: currentProfile)
        )
    }

    func loadVolunteerReviewApplications() async {
        guard isAdministrator, !isLoadingVolunteerReviews else { return }
        isLoadingVolunteerReviews = true
        volunteerReviewErrorMessage = nil
        do {
            volunteerReviewApplications = try await volunteerReviewService.listApplications()
        } catch {
            volunteerReviewErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "無法載入志工申請。"
        }
        isLoadingVolunteerReviews = false
    }

    func reviewVolunteer(
        uid: String,
        action: VolunteerReviewAction,
        note: String
    ) async -> Bool {
        guard isAdministrator else { return false }
        volunteerReviewErrorMessage = nil
        do {
            try await volunteerReviewService.review(uid: uid, action: action, note: note)
            await loadVolunteerReviewApplications()
            return true
        } catch {
            volunteerReviewErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "審核沒有完成。"
            return false
        }
    }

    func downloadVolunteerEvidence(_ evidence: VolunteerReviewEvidence) async throws -> URL {
        try await volunteerReviewService.downloadEvidence(evidence)
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
        volunteerApplicationDraft = nil
        isAdministrator = false
        volunteerReviewApplications = []
        volunteerReviewErrorMessage = nil
        isLoadingVolunteerReviews = false
        pendingIdentityCredential = nil
        pendingIdentityRole = nil
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

    private func handleCreationOutcome(_ outcome: AccountCreationOutcome) async {
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
    }

    private func finishAuthenticatedSession(_ initialSession: AuthSession) async {
        var session = initialSession
        if let pendingIdentityCredential,
           pendingIdentityRole == session.user.role {
            do {
                session = try await authService.linkIdentity(
                    pendingIdentityCredential,
                    to: session
                )
                authNoticeMessage = "登入方式已安全連結；之後可使用任一方式登入同一個帳號。"
                self.pendingIdentityCredential = nil
                pendingIdentityRole = nil
            } catch AuthServiceError.identityAlreadyLinked {
                self.pendingIdentityCredential = nil
                pendingIdentityRole = nil
            } catch {
                authNoticeMessage = "帳號已登入，但新的登入方式尚未連結。你可以稍後再試一次。"
            }
        }

        currentUser = session.user
        currentProfile = session.profile
        selectedRole = session.user.role
        runtimeDiagnostics = runtimeDiagnostics.withSession(user: session.user, profile: session.profile)
        isAdministrator = await authService.currentUserIsAdministrator()
        if session.user.role == .volunteer,
           session.profile.accountStatus == .pendingApplication {
            hasAcceptedConsent = false
            volunteerApplicationDraft = try? await authService.loadVolunteerApplication(
                in: session
            )
            route = .volunteerApplication
            return
        }
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
