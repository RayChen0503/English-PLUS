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
    @Published private(set) var isSavingConsent = false
    @Published private(set) var consentErrorMessage: String?
    @Published private(set) var latestAIResponse: AiProxyResponse?
    @Published private(set) var volunteerApplicationDraft: VolunteerApplicationInput?
    @Published private(set) var isAdministrator = false
    @Published private(set) var volunteerReviewApplications: [VolunteerReviewApplication] = []
    @Published private(set) var volunteerReviewErrorMessage: String?
    @Published private(set) var isLoadingVolunteerReviews = false
    @Published private(set) var classrooms: [ClassroomSummary] = []
    @Published private(set) var classroomStudents: [ClassroomStudentSummary] = []
    @Published private(set) var isLoadingClassrooms = false
    @Published private(set) var isLoadingClassroomStudents = false
    @Published private(set) var isManagingClassroom = false
    @Published private(set) var classroomErrorMessage: String?
    @Published private(set) var classroomRosterErrorMessage: String?
    @Published private(set) var classroomNoticeMessage: String?
    @Published private(set) var runtimeDiagnostics: RuntimeDiagnosticsSnapshot

    private let authService: AuthService
    private let firestoreService: FirestoreService
    private let aiService: AIService
    private let evidenceUploadService: EvidenceUploadService
    private let volunteerReviewService: VolunteerReviewService
    private let classroomService: ClassroomService
    private let accountLifecycleService: AccountLifecycleService
    private var classroomRosterListener: ClassroomRosterListenerToken?
    private var didAttemptSessionRestore = false
    private var pendingIdentityCredential: FederatedIdentityCredential?
    private var pendingIdentityRole: UserRole?

    init(
        authService: AuthService,
        firestoreService: FirestoreService,
        aiService: AIService,
        evidenceUploadService: EvidenceUploadService,
        volunteerReviewService: VolunteerReviewService,
        classroomService: ClassroomService,
        accountLifecycleService: AccountLifecycleService,
        runtimeDiagnostics: RuntimeDiagnosticsSnapshot
    ) {
        self.authService = authService
        self.firestoreService = firestoreService
        self.aiService = aiService
        self.evidenceUploadService = evidenceUploadService
        self.volunteerReviewService = volunteerReviewService
        self.classroomService = classroomService
        self.accountLifecycleService = accountLifecycleService
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

    func loadAccountDeletionPreview() async throws -> AccountDeletionPreview {
        guard currentUser != nil else {
            throw AccountLifecycleError.unauthenticated
        }
        return try await accountLifecycleService.deletionPreview()
    }

    func deleteCurrentAccount() async throws -> AccountDeletionReceipt {
        guard currentUser != nil, !isManagingAccount else {
            throw AccountLifecycleError.unauthenticated
        }
        isManagingAccount = true
        defer { isManagingAccount = false }
        return try await accountLifecycleService.deleteAccount()
    }

    func completeAccountDeletion() {
        signOut()
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

    func acceptPrivacyConsent(
        categories: [PrivacyConsentCategory],
        guardianConsentStatus: GuardianConsentStatus
    ) async {
        guard let currentUser, let currentProfile, !isSavingConsent else { return }
        isSavingConsent = true
        consentErrorMessage = nil
        defer { isSavingConsent = false }
        let record = PrivacyConsentRecord.accepted(
            uid: currentUser.id,
            role: currentUser.role,
            classId: currentProfile.classId,
            categories: categories,
            guardianConsentStatus: guardianConsentStatus
        )
        do {
            try await firestoreService.saveConsent(record)
            hasAcceptedConsent = true
            route = .home(currentUser.role)
        } catch {
            consentErrorMessage = "資料使用確認尚未保存，請檢查網路後再試一次。你不需要重新勾選。"
        }
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
        isSavingConsent = false
        consentErrorMessage = nil
        latestAIResponse = nil
        volunteerApplicationDraft = nil
        isAdministrator = false
        volunteerReviewApplications = []
        volunteerReviewErrorMessage = nil
        isLoadingVolunteerReviews = false
        classrooms = []
        classroomStudents = []
        isLoadingClassrooms = false
        isLoadingClassroomStudents = false
        isManagingClassroom = false
        classroomErrorMessage = nil
        classroomRosterErrorMessage = nil
        classroomNoticeMessage = nil
        classroomRosterListener?.cancel()
        classroomRosterListener = nil
        pendingIdentityCredential = nil
        pendingIdentityRole = nil
        runtimeDiagnostics = runtimeDiagnostics.clearingSession()
        route = .roleSelection
    }

    func selectActiveClass(_ classId: String?) async {
        guard let currentUser, let currentProfile else { return }
        signInErrorMessage = nil
        clearClassroomFeedback()

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
            classroomNoticeMessage = classId == nil
                ? "已切換到個人學習模式。"
                : "已切換班級。"
            if session.user.role == .teacher, let classId {
                startClassroomRosterSync(classId: classId)
            } else {
                classroomRosterListener?.cancel()
                classroomRosterListener = nil
                classroomStudents = []
                classroomRosterErrorMessage = nil
            }
        } catch {
            signInErrorMessage = "無法切換班級，請確認你仍是該班級的成員。"
            classroomErrorMessage = signInErrorMessage
        }
    }

    func loadClassrooms() async {
        guard currentUser != nil, !isLoadingClassrooms else { return }
        isLoadingClassrooms = true
        classroomErrorMessage = nil
        do {
            classrooms = try await classroomService.listClassrooms()
            if let restored = try? await authService.restorePreviousSession(),
               currentUser?.id == restored.user.id {
                applyClassSession(restored)
            }
            if currentProfile?.role == .teacher,
               let classId = currentProfile?.activeClassId {
                startClassroomRosterSync(classId: classId)
            } else {
                classroomRosterListener?.cancel()
                classroomRosterListener = nil
                classroomStudents = []
            }
        } catch {
            classroomErrorMessage = classroomMessage(for: error)
        }
        isLoadingClassrooms = false
    }

    func loadClassroomStudents(classId: String) async {
        guard currentProfile?.role == .teacher,
              currentProfile?.activeClassId == classId
        else { return }
        isLoadingClassroomStudents = true
        classroomRosterErrorMessage = nil
        do {
            let students = try await classroomService.listStudents(classId: classId)
            guard currentProfile?.activeClassId == classId else {
                isLoadingClassroomStudents = false
                return
            }
            classroomStudents = students
        } catch {
            if currentProfile?.activeClassId == classId,
               classroomStudents.isEmpty {
                classroomRosterErrorMessage = classroomMessage(for: error)
            }
        }
        isLoadingClassroomStudents = false
    }

    private func startClassroomRosterSync(classId: String) {
        classroomRosterListener?.cancel()
        classroomStudents = []
        classroomRosterErrorMessage = nil
        isLoadingClassroomStudents = true
        classroomRosterListener = classroomService.startStudentListener(
            classId: classId
        ) { [weak self] students in
            guard let self, self.currentProfile?.activeClassId == classId else { return }
            self.classroomStudents = students
            self.classroomRosterErrorMessage = nil
            self.isLoadingClassroomStudents = false
        } onError: { [weak self] error in
            guard let self, self.currentProfile?.activeClassId == classId else { return }
            self.classroomRosterErrorMessage = self.classroomMessage(for: error)
            self.isLoadingClassroomStudents = false
        }
        Task { [weak self] in
            await self?.loadClassroomStudents(classId: classId)
        }
    }

    @discardableResult
    func createClassroom(name: String) async -> Bool {
        guard !isManagingClassroom else { return false }
        isManagingClassroom = true
        clearClassroomFeedback()
        do {
            let classroom = try await classroomService.createClassroom(name: name)
            upsertClassroom(classroom)
            await refreshClassSession(fallback: classroom)
            await refreshClassroomListAfterMutation()
            startClassroomRosterSync(classId: classroom.classId)
            classroomNoticeMessage = "班級已建立，可以把代碼分享給學生。"
            isManagingClassroom = false
            return true
        } catch {
            classroomErrorMessage = classroomMessage(for: error)
            isManagingClassroom = false
            return false
        }
    }

    @discardableResult
    func updateClassroom(classId: String, name: String) async -> Bool {
        guard !isManagingClassroom,
              currentProfile?.role == .teacher,
              currentProfile?.activeClassId == classId
        else { return false }
        isManagingClassroom = true
        clearClassroomFeedback()
        do {
            let classroom = try await classroomService.updateClassroom(
                classId: classId,
                name: name
            )
            upsertClassroom(classroom)
            await refreshClassroomListAfterMutation()
            classroomNoticeMessage = "班級名稱已更新。"
            isManagingClassroom = false
            return true
        } catch {
            classroomErrorMessage = classroomMessage(for: error)
            isManagingClassroom = false
            return false
        }
    }

    @discardableResult
    func joinClassroom(code: String) async -> Bool {
        guard !isManagingClassroom else { return false }
        isManagingClassroom = true
        clearClassroomFeedback()
        do {
            let classroom = try await classroomService.joinClassroom(code: code)
            upsertClassroom(classroom)
            await refreshClassSession(fallback: classroom)
            await refreshClassroomListAfterMutation()
            classroomNoticeMessage = "已加入「\(classroom.name)」，老師指派的任務會出現在班級頁。"
            isManagingClassroom = false
            return true
        } catch {
            classroomErrorMessage = classroomMessage(for: error)
            isManagingClassroom = false
            return false
        }
    }

    @discardableResult
    func leaveClassroom(classId: String) async -> Bool {
        guard !isManagingClassroom else { return false }
        isManagingClassroom = true
        clearClassroomFeedback()
        do {
            try await classroomService.leaveClassroom(classId: classId)
            classrooms.removeAll { $0.classId == classId }
            await refreshClassSessionAfterLeaving(classId: classId)
            await refreshClassroomListAfterMutation()
            classroomNoticeMessage = "已離開班級。個人學習紀錄與其他功能不受影響。"
            isManagingClassroom = false
            return true
        } catch {
            classroomErrorMessage = classroomMessage(for: error)
            isManagingClassroom = false
            return false
        }
    }

    @discardableResult
    func resetClassroomCode(classId: String) async -> Bool {
        guard !isManagingClassroom else { return false }
        isManagingClassroom = true
        clearClassroomFeedback()
        do {
            let classroom = try await classroomService.resetJoinCode(classId: classId)
            upsertClassroom(classroom)
            classroomNoticeMessage = "班級代碼已重設；舊代碼已立即失效。"
            isManagingClassroom = false
            return true
        } catch {
            classroomErrorMessage = classroomMessage(for: error)
            isManagingClassroom = false
            return false
        }
    }

    func clearClassroomFeedback() {
        classroomErrorMessage = nil
        classroomNoticeMessage = nil
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

    private func refreshClassSession(fallback classroom: ClassroomSummary) async {
        if let restored = try? await authService.restorePreviousSession() {
            applyClassSession(restored)
            return
        }
        guard let currentUser, let currentProfile else { return }
        let profile = currentProfile.upsertingMembership(
            classroom.membership,
            makeActive: true
        )
        applyClassSession(
            AuthSession(
                user: DemoUser(
                    id: currentUser.id,
                    displayName: currentUser.displayName,
                    role: profile.role
                ),
                profile: profile
            )
        )
    }

    private func refreshClassSessionAfterLeaving(classId: String) async {
        if let restored = try? await authService.restorePreviousSession() {
            applyClassSession(restored)
            return
        }
        guard let currentUser, let currentProfile else { return }
        let profile = currentProfile.markingMembershipLeft(classId: classId, at: Date())
        applyClassSession(
            AuthSession(
                user: DemoUser(
                    id: currentUser.id,
                    displayName: currentUser.displayName,
                    role: profile.role
                ),
                profile: profile
            )
        )
    }

    private func applyClassSession(_ session: AuthSession) {
        currentUser = session.user
        currentProfile = session.profile
        selectedRole = session.user.role
        runtimeDiagnostics = runtimeDiagnostics.withSession(
            user: session.user,
            profile: session.profile
        )
        route = .home(session.user.role)
    }

    private func refreshClassroomListAfterMutation() async {
        if let refreshed = try? await classroomService.listClassrooms() {
            classrooms = refreshed
        }
    }

    private func upsertClassroom(_ classroom: ClassroomSummary) {
        classrooms.removeAll { $0.classId == classroom.classId }
        classrooms.append(classroom)
        classrooms.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func classroomMessage(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription
            ?? "目前無法完成班級操作，請稍後再試。"
    }

    private func clearFailedAuthenticationState() {
        currentUser = nil
        currentProfile = nil
        hasAcceptedConsent = false
        signingInRole = nil
        classrooms = []
        classroomStudents = []
        classroomRosterListener?.cancel()
        classroomRosterListener = nil
        classroomErrorMessage = nil
        classroomRosterErrorMessage = nil
        classroomNoticeMessage = nil
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
