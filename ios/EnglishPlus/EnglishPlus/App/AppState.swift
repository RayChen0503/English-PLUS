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
    @Published private(set) var federatedOnboardingProvider: AccountIdentityProvider?
    @Published private(set) var federatedOnboardingRole: UserRole?
    @Published private(set) var isManagingAccount = false
    @Published private(set) var isSavingConsent = false
    @Published private(set) var consentErrorMessage: String?
    @Published private(set) var latestAIResponse: AiProxyResponse?
    @Published private(set) var volunteerApplicationDraft: VolunteerApplicationInput?
    @Published private(set) var volunteerApplicationReviewState: VolunteerApplicationReviewState?
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
    @Published private(set) var volunteerServices: [VolunteerServiceSummary] = []
    @Published private(set) var classroomVolunteerServices: [VolunteerServiceSummary] = []
    @Published private(set) var volunteerInviteCodes: [String: VolunteerInviteCodeSummary] = [:]
    @Published private(set) var isLoadingVolunteerServices = false
    @Published private(set) var isManagingVolunteerService = false
    @Published private(set) var volunteerServiceErrorMessage: String?
    @Published private(set) var volunteerServiceNoticeMessage: String?
    @Published private(set) var runtimeDiagnostics: RuntimeDiagnosticsSnapshot

    private let authService: AuthService
    private let firestoreService: FirestoreService
    private let aiService: AIService
    private let evidenceUploadService: EvidenceUploadService
    private let volunteerReviewService: VolunteerReviewService
    private let classroomService: ClassroomService
    private let accountLifecycleService: AccountLifecycleService
    private var classroomRosterListener: ClassroomRosterListenerToken?
    private var classroomRosterListenerClassId: String?
    private var classroomMembershipListener: ClassroomRosterListenerToken?
    private var classroomMembershipListenerUid: String?
    private var volunteerServiceListener: ClassroomRosterListenerToken?
    private var volunteerServiceListenerUid: String?
    private var classroomVolunteerListener: ClassroomRosterListenerToken?
    private var classroomVolunteerListenerClassId: String?
    private var lastVolunteerServiceListenerErrorMessage: String?
    private var lastClassroomVolunteerListenerErrorMessage: String?
    private var lastMembershipListenerErrorMessage: String?
    private var isReconcilingClassroomMemberships = false
    private var didAttemptSessionRestore = false
    private var pendingIdentityCredential: FederatedIdentityCredential?
    private var pendingIdentityRole: UserRole?
    private var federatedOnboardingCredential: FederatedIdentityCredential?
    @Published private(set) var sessionGeneration = UUID()
    @Published private(set) var classGeneration = UUID()
    private var operationGenerations: [String: UUID] = [:]
    private var pendingMembershipClassIds: Set<String>?
    private var isUploadingVolunteerEvidence = false
    private var isSavingVolunteerDraft = false
    private let volunteerDraftDefaults: UserDefaults

    var learningScopeIdentity: String {
        "\(sessionGeneration):\(classGeneration):\(currentUser?.id ?? "signed-out"):\(currentProfile?.classId ?? "none")"
    }

    private struct OperationContext {
        let session: UUID
        let classroom: UUID?
        let key: String
        let request: UUID
    }

    private func beginOperation(_ key: String = #function, classScoped: Bool = false) -> OperationContext {
        let request = UUID()
        operationGenerations[key] = request
        return OperationContext(session: sessionGeneration, classroom: classScoped ? classGeneration : nil,
                                key: key, request: request)
    }

    private func isCurrent(_ context: OperationContext) -> Bool {
        !Task.isCancelled && ownsOperation(context)
    }

    private func ownsOperation(_ context: OperationContext) -> Bool {
        context.session == sessionGeneration
            && (context.classroom == nil || context.classroom == classGeneration)
            && operationGenerations[context.key] == context.request
    }

    private func invalidateSessionOperations() {
        sessionGeneration = UUID()
        classGeneration = UUID()
        operationGenerations.removeAll()
        pendingMembershipClassIds = nil
        isReconcilingClassroomMemberships = false
        signingInRole = nil
        isManagingAccount = false
        isSavingConsent = false
        isUploadingVolunteerEvidence = false
        isSavingVolunteerDraft = false
        isLoadingVolunteerReviews = false
        isLoadingClassrooms = false
        isLoadingClassroomStudents = false
        isManagingClassroom = false
        isLoadingVolunteerServices = false
        isManagingVolunteerService = false
    }

    private func invalidateClassOperations() {
        classGeneration = UUID()
        classroomRosterListener?.cancel()
        classroomRosterListener = nil
        classroomRosterListenerClassId = nil
        classroomVolunteerListener?.cancel()
        classroomVolunteerListener = nil
        classroomVolunteerListenerClassId = nil
        classroomStudents = []
        classroomVolunteerServices = []
        isLoadingClassrooms = false
        isLoadingClassroomStudents = false
        isLoadingVolunteerServices = false
        isManagingVolunteerService = false
        isManagingClassroom = false
    }

    init(
        authService: AuthService,
        firestoreService: FirestoreService,
        aiService: AIService,
        evidenceUploadService: EvidenceUploadService,
        volunteerReviewService: VolunteerReviewService,
        classroomService: ClassroomService,
        accountLifecycleService: AccountLifecycleService,
        runtimeDiagnostics: RuntimeDiagnosticsSnapshot,
        volunteerDraftDefaults: UserDefaults = .standard
    ) {
        self.authService = authService
        self.firestoreService = firestoreService
        self.aiService = aiService
        self.evidenceUploadService = evidenceUploadService
        self.volunteerReviewService = volunteerReviewService
        self.classroomService = classroomService
        self.accountLifecycleService = accountLifecycleService
        self.runtimeDiagnostics = runtimeDiagnostics
        self.volunteerDraftDefaults = volunteerDraftDefaults
    }

    func chooseRole(_ role: UserRole) {
        invalidateSessionOperations()
        signingInRole = nil
        if let pendingIdentityRole, pendingIdentityRole != role {
            pendingIdentityCredential = nil
            self.pendingIdentityRole = nil
        }
        if let federatedOnboardingRole, federatedOnboardingRole != role {
            authService.signOut()
            clearFederatedOnboardingState()
        }
        selectedRole = role
        signInErrorMessage = nil
        authNoticeMessage = nil
        verificationEmailAddress = nil
        route = .demoLogin(role)
    }

    func signIn(email: String, password: String, role: UserRole) async {
        guard signingInRole == nil else { return }
        let operation = beginOperation(classScoped: false)
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
            guard isCurrent(operation) else { return }
            await finishAuthenticatedSession(session)
            guard isCurrent(operation) else { return }
            signingInRole = nil
        } catch {
            guard isCurrent(operation) else { return }
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

    var currentAccountUsesAppleSignIn: Bool {
        authService.currentUserUses(.apple)
    }

    var currentAccountUsesGoogleSignIn: Bool {
        authService.currentUserUses(.google)
    }

    func signIn(
        with credential: FederatedIdentityCredential,
        role: UserRole
    ) async {
        guard signingInRole == nil else { return }
        let operation = beginOperation(classScoped: false)
        selectedRole = role
        signingInRole = role
        clearAuthFeedback()

        do {
            let session = try await authService.signIn(
                with: credential,
                expectedRole: role
            )
            guard isCurrent(operation) else { return }
            await finishAuthenticatedSession(session)
            guard isCurrent(operation) else { return }
            signingInRole = nil
        } catch {
            guard isCurrent(operation) else { return }
            if let authError = error as? AuthServiceError,
               authError == .profileUnavailable {
                clearFailedAuthenticationState()
                federatedOnboardingCredential = credential
                federatedOnboardingProvider = credential.provider
                federatedOnboardingRole = role
                selectedRole = role
                signInErrorMessage = nil
                authNoticeMessage = "這是你第一次使用\(credential.provider.displayName)。請完成下方資料，就能建立\(role.title)帳號。"
                return
            }

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
        let operation = beginOperation(classScoped: false)
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
        guard isCurrent(operation) else { return }
    }

    func createAccount(_ registration: AccountRegistration) async {
        guard signingInRole == nil else { return }
        let operation = beginOperation(classScoped: false)
        selectedRole = registration.role
        signingInRole = registration.role
        signInErrorMessage = nil
        authNoticeMessage = nil
        verificationEmailAddress = nil

        do {
            let outcome = try await authService.createAccount(registration)
            guard isCurrent(operation) else { return }
            await handleCreationOutcome(outcome)
            guard isCurrent(operation) else { return }
            signingInRole = nil
        } catch {
            guard isCurrent(operation) else { return }
            clearFailedAuthenticationState()
            signInErrorMessage = userMessage(for: error)
        }
    }

    func createAccount(
        with credential: FederatedIdentityCredential,
        profile: RoleOnboardingProfile
    ) async {
        guard signingInRole == nil else { return }
        let operation = beginOperation(classScoped: false)
        selectedRole = profile.role
        signingInRole = profile.role
        clearAuthFeedback()

        do {
            let outcome = try await authService.createAccount(
                with: credential,
                profile: profile
            )
            guard isCurrent(operation) else { return }
            clearFederatedOnboardingState()
            await handleCreationOutcome(outcome)
            guard isCurrent(operation) else { return }
            signingInRole = nil
        } catch {
            guard isCurrent(operation) else { return }
            clearFailedAuthenticationState()
            signInErrorMessage = userMessage(for: error)
        }
    }

    func federatedOnboardingProvider(for role: UserRole) -> AccountIdentityProvider? {
        guard federatedOnboardingRole == role else { return nil }
        return federatedOnboardingProvider
    }

    func completeFederatedOnboarding(profile: RoleOnboardingProfile) async {
        let operation = beginOperation(classScoped: false)
        guard
            profile.role == federatedOnboardingRole,
            let credential = federatedOnboardingCredential
        else {
            signInErrorMessage = "登入驗證已失效，請重新使用 Google 或 Apple 繼續。"
            return
        }
        await createAccount(with: credential, profile: profile)
        guard isCurrent(operation) else { return }
    }

    func cancelFederatedOnboarding() {
        invalidateSessionOperations()
        authService.signOut()
        clearFederatedOnboardingState()
        clearAuthFeedback()
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
        guard let user = currentUser, let profile = currentProfile,
              !isUploadingVolunteerEvidence else { throw AuthServiceError.operationUnavailable }
        let operation = beginOperation()
        isUploadingVolunteerEvidence = true
        defer { if ownsOperation(operation) { isUploadingVolunteerEvidence = false } }
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
        let reference = try await evidenceUploadService.upload(
            data: data,
            filename: values.name ?? fileURL.lastPathComponent,
            mimeType: mimeType,
            kind: kind
        )
        // A completed upload belongs to the captured user even if the screen
        // disappeared or signed out during the network request.
        var pending = pendingEvidence(uid: user.id)
        if !pending.contains(where: { $0.id == reference.id }) { pending.append(reference) }
        try storePendingEvidence(pending, uid: user.id)
        guard isCurrent(operation) else { throw CancellationError() }
        let session = AuthSession(user: user, profile: profile)
        let loadedDraft = try await authService.loadVolunteerApplication(in: session)
        guard isCurrent(operation) else { throw CancellationError() }
        let draft = mergingPendingEvidence(into: volunteerApplicationDraft ?? loadedDraft, uid: user.id)
        volunteerApplicationDraft = draft
        try await saveVolunteerApplicationDraft(draft)
        guard isCurrent(operation) else { throw CancellationError() }
        return reference
    }

    func deleteVolunteerEvidence(_ reference: VolunteerEvidenceReference) async throws {
        guard let user = currentUser else { throw AuthServiceError.invalidCredentials }
        let operation = beginOperation()
        try await evidenceUploadService.delete(reference)
        try storePendingEvidence(pendingEvidence(uid: user.id).filter { $0.id != reference.id }, uid: user.id)
        guard isCurrent(operation) else { throw CancellationError() }
        let draft = volunteerApplicationDraft ?? emptyVolunteerDraft
        try await saveVolunteerApplicationDraft(VolunteerApplicationInput(
            confirmsAge18OrOlder: draft.confirmsAge18OrOlder, acceptedConductVersion: draft.acceptedConductVersion,
            motivation: draft.motivation, evidence: draft.evidence.filter { $0.id != reference.id }
        ))
    }

    func saveVolunteerApplicationDraft(_ draft: VolunteerApplicationInput) async throws {
        guard let user = currentUser, let profile = currentProfile,
              user.role == .volunteer, !isSavingVolunteerDraft else { throw AuthServiceError.operationUnavailable }
        let operation = beginOperation()
        isSavingVolunteerDraft = true
        defer { if ownsOperation(operation) { isSavingVolunteerDraft = false } }
        try await authService.saveVolunteerApplicationDraft(draft, in: AuthSession(user: user, profile: profile))
        guard isCurrent(operation) else { throw CancellationError() }
        volunteerApplicationDraft = draft
        let savedIds = Set(draft.evidence.map(\.id))
        try storePendingEvidence(pendingEvidence(uid: user.id).filter { !savedIds.contains($0.id) }, uid: user.id)
    }

    private var emptyVolunteerDraft: VolunteerApplicationInput {
        VolunteerApplicationInput(confirmsAge18OrOlder: false, acceptedConductVersion: "", motivation: "", evidence: [])
    }

    private func pendingEvidence(uid: String) -> [VolunteerEvidenceReference] {
        guard let data = volunteerDraftDefaults.data(forKey: "englishplus.volunteer.uploaded-evidence.\(uid)") else { return [] }
        return (try? JSONDecoder().decode([VolunteerEvidenceReference].self, from: data)) ?? []
    }

    private func storePendingEvidence(_ evidence: [VolunteerEvidenceReference], uid: String) throws {
        let key = "englishplus.volunteer.uploaded-evidence.\(uid)"
        if evidence.isEmpty { volunteerDraftDefaults.removeObject(forKey: key) }
        else { volunteerDraftDefaults.set(try JSONEncoder().encode(evidence), forKey: key) }
    }

    private func mergingPendingEvidence(into draft: VolunteerApplicationInput?, uid: String) -> VolunteerApplicationInput {
        let draft = draft ?? emptyVolunteerDraft
        var evidence = draft.evidence
        for reference in pendingEvidence(uid: uid) where !evidence.contains(where: { $0.id == reference.id }) {
            evidence.append(reference)
        }
        return VolunteerApplicationInput(confirmsAge18OrOlder: draft.confirmsAge18OrOlder,
                                         acceptedConductVersion: draft.acceptedConductVersion,
                                         motivation: draft.motivation, evidence: evidence)
    }

    func submitVolunteerApplication(_ application: VolunteerApplicationInput) async {
        guard let currentUser, let currentProfile, signingInRole == nil else { return }
        let operation = beginOperation(classScoped: false)
        signingInRole = .volunteer
        clearAuthFeedback()
        do {
            let outcome = try await authService.submitVolunteerApplication(
                application,
                in: AuthSession(user: currentUser, profile: currentProfile)
            )
            guard isCurrent(operation) else { return }
            await handleCreationOutcome(outcome)
            guard isCurrent(operation) else { return }
            route = .demoLogin(.volunteer)
            signingInRole = nil
        } catch {
            guard isCurrent(operation) else { return }
            signingInRole = nil
            signInErrorMessage = userMessage(for: error)
        }
    }

    func loadVolunteerApplicationDraft() async {
        guard let currentUser, let currentProfile else { return }
        let operation = beginOperation(classScoped: false)
        let session = AuthSession(user: currentUser, profile: currentProfile)
        let draft = try? await authService.loadVolunteerApplication(in: session)
        guard isCurrent(operation) else { return }
        volunteerApplicationDraft = mergingPendingEvidence(into: draft, uid: currentUser.id)
        let reviewState = try? await authService.loadVolunteerApplicationReviewState(
            in: session
        )
        guard isCurrent(operation) else { return }
        volunteerApplicationReviewState = reviewState
    }

    func loadVolunteerReviewApplications() async {
        guard isAdministrator, !isLoadingVolunteerReviews else { return }
        let operation = beginOperation(classScoped: false)
        isLoadingVolunteerReviews = true
        defer { if ownsOperation(operation) { isLoadingVolunteerReviews = false } }
        volunteerReviewErrorMessage = nil
        do {
            let applications = try await volunteerReviewService.listApplications()
            guard isCurrent(operation) else { return }
            volunteerReviewApplications = applications
        } catch {
            guard isCurrent(operation) else { return }
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
        let operation = beginOperation(classScoped: false)
        volunteerReviewErrorMessage = nil
        do {
            try await volunteerReviewService.review(uid: uid, action: action, note: note)
            guard isCurrent(operation) else { return false }
            await loadVolunteerReviewApplications()
            guard isCurrent(operation) else { return false }
            return true
        } catch {
            guard isCurrent(operation) else { return false }
            volunteerReviewErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "審核沒有完成。"
            return false
        }
    }

    func downloadVolunteerEvidence(_ evidence: VolunteerReviewEvidence) async throws -> URL {
        let operation = beginOperation()
        let url = try await volunteerReviewService.downloadEvidence(evidence)
        guard isCurrent(operation) else {
            try? FileManager.default.removeItem(at: url)
            throw CancellationError()
        }
        return url
    }

    func sendPasswordReset(email: String) async {
        guard !isManagingAccount else { return }
        let operation = beginOperation(classScoped: false)
        isManagingAccount = true
        defer { if ownsOperation(operation) { isManagingAccount = false } }
        signInErrorMessage = nil
        authNoticeMessage = nil

        do {
            try await authService.sendPasswordReset(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            guard isCurrent(operation) else { return }
            authNoticeMessage = "如果這個 email 已有帳號，重設密碼信會寄到該信箱。"
        } catch {
            guard isCurrent(operation) else { return }
            signInErrorMessage = userMessage(for: error)
        }
        isManagingAccount = false
    }

    func resendVerification(email: String, password: String) async {
        guard !isManagingAccount else { return }
        let operation = beginOperation(classScoped: false)
        isManagingAccount = true
        defer { if ownsOperation(operation) { isManagingAccount = false } }
        signInErrorMessage = nil
        authNoticeMessage = nil

        do {
            try await authService.resendVerification(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            guard isCurrent(operation) else { return }
            verificationEmailAddress = email.trimmingCharacters(in: .whitespacesAndNewlines)
            authNoticeMessage = "新的驗證信已寄出，請到信箱完成驗證。"
        } catch {
            guard isCurrent(operation) else { return }
            signInErrorMessage = userMessage(for: error)
        }
        isManagingAccount = false
    }

    func loadAccountDeletionPreview() async throws -> AccountDeletionPreview {
        guard currentUser != nil else {
            throw AccountLifecycleError.unauthenticated
        }
        let operation = beginOperation(classScoped: false)
        let result = try await accountLifecycleService.deletionPreview()
        guard isCurrent(operation) else { throw CancellationError() }
        return result
    }

    func deleteCurrentAccount(
        classTransfers: [String: String]
    ) async throws -> AccountDeletionReceipt {
        guard currentUser != nil, !isManagingAccount else {
            throw AccountLifecycleError.unauthenticated
        }
        let operation = beginOperation(classScoped: false)
        isManagingAccount = true
        defer { if ownsOperation(operation) { isManagingAccount = false } }
        let result = try await accountLifecycleService.deleteAccount(
            classTransfers: classTransfers
        )
        guard isCurrent(operation) else { throw CancellationError() }
        return result
    }

    func reauthenticateAndRevokeAppleForAccountDeletion(
        using credential: AppleAccountDeletionCredential
    ) async throws {
        guard currentUser != nil, !isManagingAccount else {
            throw AccountLifecycleError.unauthenticated
        }
        let operation = beginOperation(classScoped: false)
        isManagingAccount = true
        defer { if ownsOperation(operation) { isManagingAccount = false } }
        try await authService.reauthenticateAndRevokeAppleToken(using: credential)
        guard isCurrent(operation) else { throw CancellationError() }
    }

    func reauthenticateAndRevokeGoogleForAccountDeletion(
        using credential: GoogleAccountDeletionCredential
    ) async throws {
        guard currentUser != nil, !isManagingAccount else {
            throw AccountLifecycleError.unauthenticated
        }
        let operation = beginOperation(classScoped: false)
        isManagingAccount = true
        defer { if ownsOperation(operation) { isManagingAccount = false } }
        try await authService.reauthenticateAndRevokeGoogleToken(using: credential)
        guard isCurrent(operation) else { throw CancellationError() }
    }

    func completeAccountDeletion() {
        if let uid = currentUser?.id {
            try? storePendingEvidence([], uid: uid)
            UserDefaults.standard.removeObject(forKey: "englishplus.volunteer.pending-draft.\(uid)")
        }
        signOut()
    }

    func restoreSessionIfPossible() async {
        guard !didAttemptSessionRestore else { return }
        let operation = beginOperation(classScoped: false)
        didAttemptSessionRestore = true
        signInErrorMessage = nil
        authNoticeMessage = nil
        verificationEmailAddress = nil
        isManagingAccount = false

        do {
            let restoredSession = try await authService.restorePreviousSession()
            guard isCurrent(operation) else { return }
            guard let session = restoredSession else {
                return
            }
            await finishAuthenticatedSession(session)
            guard isCurrent(operation) else { return }
        } catch {
            guard isCurrent(operation) else { return }
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
        let operation = beginOperation(classScoped: false)
        isSavingConsent = true
        consentErrorMessage = nil
        defer { if ownsOperation(operation) { isSavingConsent = false } }
        let record = PrivacyConsentRecord.accepted(
            uid: currentUser.id,
            role: currentUser.role,
            classId: currentProfile.classId,
            categories: categories,
            guardianConsentStatus: guardianConsentStatus,
            studentAccessPath: currentProfile.studentAccessPath
        )
        do {
            try await firestoreService.saveConsent(record)
            guard isCurrent(operation) else { return }
            hasAcceptedConsent = true
            if let profile = self.currentProfile {
                applyClassSession(AuthSession(user: currentUser, profile: profile))
            }
        } catch {
            guard isCurrent(operation) else { return }
            let reason = (error as? LocalizedError)?.errorDescription
                ?? LearningRepositorySyncFailureClassifier.classify(error).message
            consentErrorMessage = "資料使用確認尚未保存。\(reason) 你不需要重新勾選。"
        }
    }

    func signOut() {
        invalidateSessionOperations()
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
        isUploadingVolunteerEvidence = false
        isSavingVolunteerDraft = false
        consentErrorMessage = nil
        latestAIResponse = nil
        volunteerApplicationDraft = nil
        volunteerApplicationReviewState = nil
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
        volunteerServices = []
        classroomVolunteerServices = []
        volunteerInviteCodes = [:]
        isLoadingVolunteerServices = false
        isManagingVolunteerService = false
        volunteerServiceErrorMessage = nil
        volunteerServiceNoticeMessage = nil
        classroomRosterListener?.cancel()
        classroomRosterListener = nil
        classroomRosterListenerClassId = nil
        classroomMembershipListener?.cancel()
        classroomMembershipListener = nil
        classroomMembershipListenerUid = nil
        volunteerServiceListener?.cancel()
        volunteerServiceListener = nil
        volunteerServiceListenerUid = nil
        classroomVolunteerListener?.cancel()
        classroomVolunteerListener = nil
        classroomVolunteerListenerClassId = nil
        lastVolunteerServiceListenerErrorMessage = nil
        lastClassroomVolunteerListenerErrorMessage = nil
        lastMembershipListenerErrorMessage = nil
        isReconcilingClassroomMemberships = false
        pendingIdentityCredential = nil
        pendingIdentityRole = nil
        clearFederatedOnboardingState()
        runtimeDiagnostics = runtimeDiagnostics.clearingSession()
        route = .roleSelection
    }

    func selectActiveClass(_ classId: String?) async {
        guard let currentUser, let currentProfile else { return }
        invalidateClassOperations()
        let operation = beginOperation(classScoped: false)
        signInErrorMessage = nil
        clearClassroomFeedback()

        do {
            let session = try await authService.selectActiveClass(
                classId,
                in: AuthSession(user: currentUser, profile: currentProfile)
            )
            guard isCurrent(operation) else { return }
            applyClassSession(session)
            classroomNoticeMessage = classId == nil
                ? "已切換到個人學習模式。"
                : "已切換班級。"
        } catch {
            guard isCurrent(operation) else { return }
            synchronizeRoleScopedClassroomData(for: currentProfile)
            signInErrorMessage = "無法切換班級，請確認你仍是該班級的成員。"
            classroomErrorMessage = signInErrorMessage
        }
    }

    func loadClassrooms() async {
        guard currentUser != nil, !isLoadingClassrooms else { return }
        let operation = beginOperation(classScoped: true)
        isLoadingClassrooms = true
        defer { if ownsOperation(operation) { isLoadingClassrooms = false } }
        classroomErrorMessage = nil
        do {
            let refreshedClassrooms = try await classroomService.listClassrooms()
            guard isCurrent(operation) else { return }
            classrooms = refreshedClassrooms
            let restored = try? await authService.restorePreviousSession()
            guard isCurrent(operation) else { return }
            if let restored,
               currentUser?.id == restored.user.id {
                applyClassSession(restored)
            }
            if currentProfile?.role == .teacher,
               let classId = currentProfile?.activeClassId {
                startClassroomRosterSync(classId: classId)
            } else {
                classroomRosterListener?.cancel()
                classroomRosterListener = nil
                classroomRosterListenerClassId = nil
                classroomStudents = []
            }
        } catch {
            guard isCurrent(operation) else { return }
            classroomErrorMessage = classroomMessage(for: error)
        }
        isLoadingClassrooms = false
    }

    func loadClassroomStudents(classId: String) async {
        guard currentProfile?.role == .teacher,
              currentProfile?.activeClassId == classId
        else { return }
        let operation = beginOperation(classScoped: true)
        isLoadingClassroomStudents = true
        defer { if ownsOperation(operation) { isLoadingClassroomStudents = false } }
        classroomRosterErrorMessage = nil
        do {
            let students = try await classroomService.listStudents(classId: classId)
            guard isCurrent(operation) else { return }
            guard currentProfile?.activeClassId == classId else {
                isLoadingClassroomStudents = false
                return
            }
            classroomStudents = students
        } catch {
            guard isCurrent(operation) else { return }
            if currentProfile?.activeClassId == classId,
               classroomStudents.isEmpty {
                classroomRosterErrorMessage = classroomMessage(for: error)
            }
        }
        isLoadingClassroomStudents = false
    }

    private func startClassroomRosterSync(classId: String) {
        guard hasAcceptedConsent, currentProfile?.role == .teacher,
              currentProfile?.activeClassId == classId else { return }
        guard classroomRosterListenerClassId != classId || classroomRosterListener == nil else {
            return
        }
        classroomRosterListener?.cancel()
        classroomRosterListenerClassId = classId
        classroomStudents = []
        classroomRosterErrorMessage = nil
        isLoadingClassroomStudents = true
        let operation = beginOperation(classScoped: true)
        classroomRosterListener = classroomService.startStudentListener(
            classId: classId
        ) { [weak self] students in
            guard let self, self.isCurrent(operation), self.currentProfile?.activeClassId == classId else { return }
            self.classroomStudents = students
            self.classroomRosterErrorMessage = nil
            self.isLoadingClassroomStudents = false
        } onError: { [weak self] error in
            guard let self, self.isCurrent(operation), self.currentProfile?.activeClassId == classId else { return }
            self.classroomRosterErrorMessage = self.classroomMessage(for: error)
            self.isLoadingClassroomStudents = false
        }
        Task { [weak self] in
            guard let self, self.isCurrent(operation) else { return }
            await self.loadClassroomStudents(classId: classId)
        }
    }

    @discardableResult
    func createClassroom(name: String) async -> Bool {
        guard !isManagingClassroom else { return false }
        var operation = beginOperation(classScoped: true)
        isManagingClassroom = true
        defer { if ownsOperation(operation) { isManagingClassroom = false } }
        clearClassroomFeedback()
        do {
            let classroom = try await classroomService.createClassroom(name: name)
            guard isCurrent(operation) else { return false }
            upsertClassroom(classroom)
            guard await refreshClassSession(fallback: classroom) else { return false }
            operation = OperationContext(session: operation.session, classroom: classGeneration, key: operation.key, request: operation.request)
            guard isCurrent(operation) else { return false }
            await refreshClassroomListAfterMutation()
            guard isCurrent(operation) else { return false }
            startClassroomRosterSync(classId: classroom.classId)
            classroomNoticeMessage = "班級已建立，可以把代碼分享給學生。"
            isManagingClassroom = false
            return true
        } catch {
            guard isCurrent(operation) else { return false }
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
        let operation = beginOperation(classScoped: true)
        isManagingClassroom = true
        defer { if ownsOperation(operation) { isManagingClassroom = false } }
        clearClassroomFeedback()
        do {
            let classroom = try await classroomService.updateClassroom(
                classId: classId,
                name: name
            )
            guard isCurrent(operation) else { return false }
            upsertClassroom(classroom)
            await refreshClassroomListAfterMutation()
            guard isCurrent(operation) else { return false }
            classroomNoticeMessage = "班級名稱已更新。"
            isManagingClassroom = false
            return true
        } catch {
            guard isCurrent(operation) else { return false }
            classroomErrorMessage = classroomMessage(for: error)
            isManagingClassroom = false
            return false
        }
    }

    @discardableResult
    func deleteClassroom(classId: String) async -> Bool {
        guard !isManagingClassroom,
              currentProfile?.role == .teacher,
              currentProfile?.activeClassId == classId
        else { return false }
        var operation = beginOperation(classScoped: true)
        isManagingClassroom = true
        defer { if ownsOperation(operation) { isManagingClassroom = false } }
        clearClassroomFeedback()
        let deletedName = classrooms.first { $0.classId == classId }?.name ?? "這個班級"
        do {
            try await classroomService.deleteClassroom(classId: classId)
            guard isCurrent(operation) else { return false }
            classroomRosterListener?.cancel()
            classroomRosterListener = nil
            classroomRosterListenerClassId = nil
            classroomStudents = []
            classroomRosterErrorMessage = nil
            classrooms.removeAll { $0.classId == classId }
            classroomVolunteerServices = []
            volunteerInviteCodes[classId] = nil
            if classroomVolunteerListenerClassId == classId {
                classroomVolunteerListener?.cancel()
                classroomVolunteerListener = nil
                classroomVolunteerListenerClassId = nil
            }
            guard await refreshClassSessionAfterLeaving(classId: classId) else { return false }
            operation = OperationContext(session: operation.session, classroom: classGeneration, key: operation.key, request: operation.request)
            guard isCurrent(operation) else { return false }
            await refreshClassroomListAfterMutation()
            guard isCurrent(operation) else { return false }
            classroomNoticeMessage = "已刪除「\(deletedName)」。所有成員已退出，個人學習紀錄不受影響。"
            isManagingClassroom = false
            return true
        } catch {
            guard isCurrent(operation) else { return false }
            classroomErrorMessage = classroomMessage(for: error)
            isManagingClassroom = false
            return false
        }
    }

    @discardableResult
    func joinClassroom(code: String) async -> Bool {
        guard !isManagingClassroom else { return false }
        var operation = beginOperation(classScoped: true)
        isManagingClassroom = true
        defer { if ownsOperation(operation) { isManagingClassroom = false } }
        clearClassroomFeedback()
        do {
            let classroom = try await classroomService.joinClassroom(code: code)
            guard isCurrent(operation) else { return false }
            upsertClassroom(classroom)
            guard await refreshClassSession(fallback: classroom) else { return false }
            operation = OperationContext(session: operation.session, classroom: classGeneration, key: operation.key, request: operation.request)
            guard isCurrent(operation) else { return false }
            await refreshClassroomListAfterMutation()
            guard isCurrent(operation) else { return false }
            classroomNoticeMessage = "已加入「\(classroom.name)」，老師指派的任務會出現在班級頁。"
            isManagingClassroom = false
            return true
        } catch {
            guard isCurrent(operation) else { return false }
            classroomErrorMessage = classroomMessage(for: error)
            isManagingClassroom = false
            return false
        }
    }

    @discardableResult
    func leaveClassroom(classId: String) async -> Bool {
        guard !isManagingClassroom else { return false }
        var operation = beginOperation(classScoped: true)
        isManagingClassroom = true
        defer { if ownsOperation(operation) { isManagingClassroom = false } }
        clearClassroomFeedback()
        do {
            try await classroomService.leaveClassroom(classId: classId)
            guard isCurrent(operation) else { return false }
            classrooms.removeAll { $0.classId == classId }
            guard await refreshClassSessionAfterLeaving(classId: classId) else { return false }
            operation = OperationContext(session: operation.session, classroom: classGeneration, key: operation.key, request: operation.request)
            guard isCurrent(operation) else { return false }
            await refreshClassroomListAfterMutation()
            guard isCurrent(operation) else { return false }
            classroomNoticeMessage = "已離開班級。個人學習紀錄與其他功能不受影響。"
            isManagingClassroom = false
            return true
        } catch {
            guard isCurrent(operation) else { return false }
            classroomErrorMessage = classroomMessage(for: error)
            isManagingClassroom = false
            return false
        }
    }

    @discardableResult
    func resetClassroomCode(classId: String) async -> Bool {
        guard !isManagingClassroom else { return false }
        let operation = beginOperation(classScoped: true)
        isManagingClassroom = true
        defer { if ownsOperation(operation) { isManagingClassroom = false } }
        clearClassroomFeedback()
        do {
            let classroom = try await classroomService.resetJoinCode(classId: classId)
            guard isCurrent(operation) else { return false }
            upsertClassroom(classroom)
            classroomNoticeMessage = "班級代碼已重設；舊代碼已立即失效。"
            isManagingClassroom = false
            return true
        } catch {
            guard isCurrent(operation) else { return false }
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
        let operation = beginOperation(classScoped: true)
        let response = await aiService.generateDailyMission(context: context, currentUser: currentUser)
        if isCurrent(operation) { recordAIResponse(response) }
        return response
    }

    func explainWrongAnswerWithAI(context: WrongAnswerAIContext) async -> AiProxyResponse? {
        guard context.isEligibleForExplanation else { return nil }
        let operation = beginOperation(classScoped: true)
        let response = await aiService.explainWrongAnswer(context: context, currentUser: currentUser)
        if isCurrent(operation) { recordAIResponse(response) }
        return response
    }

    func provideEmotionalSupportWithAI(context: SupportAIContext) async -> AiProxyResponse {
        let operation = beginOperation(classScoped: true)
        let response = await aiService.provideEmotionalSupport(context: context, currentUser: currentUser)
        if isCurrent(operation) { recordAIResponse(response) }
        return response
    }

    func draftTeacherFeedbackWithAI(context: SupportAIContext) async -> AiProxyResponse {
        let operation = beginOperation(classScoped: true)
        let response = await aiService.draftTeacherFeedback(context: context, currentUser: currentUser)
        if isCurrent(operation) { recordAIResponse(response) }
        return response
    }

    func coachVolunteerReplyWithAI(context: SupportAIContext) async -> AiProxyResponse {
        let operation = beginOperation(classScoped: true)
        let response = await aiService.coachVolunteerReply(context: context, currentUser: currentUser)
        if isCurrent(operation) { recordAIResponse(response) }
        return response
    }

    func recommendPracticeWithAI(context: PracticeRecommendationAIContext) async -> AiProxyResponse {
        let operation = beginOperation(classScoped: true)
        let response = await aiService.recommendPractice(context: context, currentUser: currentUser)
        if isCurrent(operation) { recordAIResponse(response) }
        return response
    }

    private func handleCreationOutcome(_ outcome: AccountCreationOutcome) async {
        switch outcome {
        case .authenticated(let session):
            await finishAuthenticatedSession(session)
        case .emailVerificationRequired(let email):
            clearFailedAuthenticationState()
            if let selectedRole { route = .demoLogin(selectedRole) }
            verificationEmailAddress = email
            authNoticeMessage = "驗證信已寄出。完成信箱驗證後，就可以回來登入。"
        case .approvalPending(_, let role):
            clearFailedAuthenticationState()
            route = .demoLogin(role)
            authNoticeMessage = role == .volunteer
                ? "志工申請已送出，審核通過後即可登入。"
                : "帳號申請已送出，請等待審核。"
        }
    }

    private func finishAuthenticatedSession(_ initialSession: AuthSession) async {
        let operation = beginOperation(classScoped: false)
        var session = initialSession
        if let pendingIdentityCredential,
           pendingIdentityRole == session.user.role {
            do {
                let linkedSession = try await authService.linkIdentity(
                    pendingIdentityCredential,
                    to: session
                )
                guard isCurrent(operation) else { return }
                session = linkedSession
                authNoticeMessage = "登入方式已安全連結；之後可使用任一方式登入同一個帳號。"
                self.pendingIdentityCredential = nil
                pendingIdentityRole = nil
            } catch AuthServiceError.identityAlreadyLinked {
                guard isCurrent(operation) else { return }
                self.pendingIdentityCredential = nil
                pendingIdentityRole = nil
            } catch {
                guard isCurrent(operation) else { return }
                authNoticeMessage = "帳號已登入，但新的登入方式尚未連結。你可以稍後再試一次。"
            }
        }

        currentUser = session.user
        currentProfile = session.profile
        selectedRole = session.user.role
        runtimeDiagnostics = runtimeDiagnostics.withSession(user: session.user, profile: session.profile)
        let administrator = await authService.currentUserIsAdministrator()
        guard isCurrent(operation) else { return }
        isAdministrator = administrator
        if session.user.role == .volunteer {
            let draft = try? await authService.loadVolunteerApplication(in: session)
            guard isCurrent(operation) else { return }
            volunteerApplicationDraft = mergingPendingEvidence(into: draft, uid: session.user.id)
            let reviewState = try? await authService.loadVolunteerApplicationReviewState(
                in: session
            )
            guard isCurrent(operation) else { return }
            volunteerApplicationReviewState = reviewState
            if session.profile.accountStatus == .pendingApplication
                || session.profile.accountStatus == .pendingApproval {
                hasAcceptedConsent = false
                route = .volunteerApplication
                return
            }
        }
        let acceptedConsent = await acceptedConsentStatus(for: session.user.id)
        guard isCurrent(operation) else { return }
        hasAcceptedConsent = acceptedConsent
        applyClassSession(session)
    }

    private func acceptedConsentStatus(for uid: String) async -> Bool {
        if let record = await firestoreService.loadConsentRecord(uid: uid) {
            return record.accepted && record.version == PrivacyConsentRecord.currentVersion
        }
        return firestoreService.hasAcceptedRequiredConsent(uid: uid)
    }

    private func refreshClassSession(fallback classroom: ClassroomSummary) async -> Bool {
        let operation = beginOperation(classScoped: true)
        let restored = try? await authService.restorePreviousSession()
        guard isCurrent(operation) else { return false }
        if let restored {
            applyClassSession(restored)
            return true
        }
        guard let currentUser, let currentProfile else { return false }
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
        return true
    }

    private func refreshClassSessionAfterLeaving(classId: String) async -> Bool {
        let operation = beginOperation(classScoped: true)
        let restored = try? await authService.restorePreviousSession()
        guard isCurrent(operation) else { return false }
        if let restored {
            applyClassSession(restored)
            return true
        }
        guard let currentUser, let currentProfile else { return false }
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
        return true
    }

    private func applyClassSession(_ session: AuthSession) {
        guard currentUser?.id == session.user.id else { return }
        if currentProfile?.classId != session.profile.classId {
            invalidateClassOperations()
        }
        currentUser = session.user
        currentProfile = session.profile
        selectedRole = session.user.role
        startClassroomMembershipSyncIfNeeded(userUid: session.user.id)
        synchronizeRoleScopedClassroomData(for: session.profile)
        startVolunteerServiceSyncIfNeeded(
            userUid: session.user.id,
            role: session.profile.role
        )
        runtimeDiagnostics = runtimeDiagnostics.withSession(
            user: session.user,
            profile: session.profile
        )
        if session.user.role == .volunteer,
           session.profile.accountStatus == .pendingApplication || session.profile.accountStatus == .pendingApproval {
            route = .volunteerApplication
        } else {
            route = hasAcceptedConsent ? .home(session.user.role) : .privacyConsent(session.user.role)
        }
    }

    func loadVolunteerServices() async {
        guard currentProfile?.role == .volunteer, !isLoadingVolunteerServices else { return }
        let operation = beginOperation(classScoped: false)
        isLoadingVolunteerServices = true
        defer { if ownsOperation(operation) { isLoadingVolunteerServices = false } }
        volunteerServiceErrorMessage = nil
        do {
            let services = try await classroomService.listVolunteerServices()
            guard isCurrent(operation) else { return }
            volunteerServices = services
            let refreshedClassrooms = try await classroomService.listClassrooms()
            guard isCurrent(operation) else { return }
            classrooms = refreshedClassrooms
        } catch {
            guard isCurrent(operation) else { return }
            volunteerServiceErrorMessage = classroomMessage(for: error)
        }
        isLoadingVolunteerServices = false
    }

    @discardableResult
    func requestVolunteerService(code: String) async -> Bool {
        guard currentProfile?.role == .volunteer, !isManagingVolunteerService else { return false }
        let operation = beginOperation(classScoped: false)
        isManagingVolunteerService = true
        defer { if ownsOperation(operation) { isManagingVolunteerService = false } }
        clearVolunteerServiceFeedback()
        do {
            let service = try await classroomService.requestVolunteerService(code: code)
            guard isCurrent(operation) else { return false }
            volunteerServices.removeAll { $0.classId == service.classId }
            volunteerServices.append(service)
            volunteerServiceNoticeMessage = "申請已送給「\(service.className)」的老師；核准前不會顯示任何學生資料。"
            isManagingVolunteerService = false
            return true
        } catch {
            guard isCurrent(operation) else { return false }
            volunteerServiceErrorMessage = classroomMessage(for: error)
            isManagingVolunteerService = false
            return false
        }
    }

    @discardableResult
    func leaveVolunteerService(classId: String) async -> Bool {
        guard currentProfile?.role == .volunteer, !isManagingVolunteerService else { return false }
        var operation = beginOperation(classScoped: true)
        isManagingVolunteerService = true
        defer { if ownsOperation(operation) { isManagingVolunteerService = false } }
        clearVolunteerServiceFeedback()
        do {
            try await classroomService.leaveVolunteerService(classId: classId)
            guard isCurrent(operation) else { return false }
            let services = try await classroomService.listVolunteerServices()
            guard isCurrent(operation) else { return false }
            volunteerServices = services
            let refreshedClassrooms = try await classroomService.listClassrooms()
            guard isCurrent(operation) else { return false }
            classrooms = refreshedClassrooms
            guard await refreshClassSessionAfterLeaving(classId: classId) else { return false }
            operation = OperationContext(session: operation.session, classroom: classGeneration, key: operation.key, request: operation.request)
            guard isCurrent(operation) else { return false }
            volunteerServiceNoticeMessage = "已離開服務班級，學生求助與通知已立即停止。"
            isManagingVolunteerService = false
            return true
        } catch {
            guard isCurrent(operation) else { return false }
            volunteerServiceErrorMessage = classroomMessage(for: error)
            isManagingVolunteerService = false
            return false
        }
    }

    func loadClassroomVolunteers(classId: String) async {
        guard currentProfile?.role == .teacher,
              currentProfile?.activeClassId == classId,
              !isLoadingVolunteerServices
        else { return }
        let operation = beginOperation(classScoped: true)
        startClassroomVolunteerSyncIfNeeded(classId: classId)
        isLoadingVolunteerServices = true
        defer { if ownsOperation(operation) { isLoadingVolunteerServices = false } }
        volunteerServiceErrorMessage = nil
        do {
            let services = try await classroomService.listClassroomVolunteers(classId: classId)
            guard isCurrent(operation) else { return }
            classroomVolunteerServices = services
            let invitation = try await classroomService.volunteerInviteCode(classId: classId)
            guard isCurrent(operation) else { return }
            volunteerInviteCodes[classId] = invitation
        } catch {
            guard isCurrent(operation) else { return }
            volunteerServiceErrorMessage = classroomMessage(for: error)
        }
        isLoadingVolunteerServices = false
    }

    @discardableResult
    func resetVolunteerInviteCode(classId: String) async -> Bool {
        guard currentProfile?.role == .teacher, currentProfile?.activeClassId == classId,
              !isManagingVolunteerService else { return false }
        let operation = beginOperation(classScoped: true)
        isManagingVolunteerService = true
        defer { if ownsOperation(operation) { isManagingVolunteerService = false } }
        clearVolunteerServiceFeedback()
        do {
            let invitation = try await classroomService.resetVolunteerInviteCode(classId: classId)
            guard isCurrent(operation) else { return false }
            volunteerInviteCodes[classId] = invitation
            volunteerServiceNoticeMessage = "已建立新的志工邀請碼；舊碼已失效。"
            isManagingVolunteerService = false
            return true
        } catch {
            guard isCurrent(operation) else { return false }
            volunteerServiceErrorMessage = classroomMessage(for: error)
            isManagingVolunteerService = false
            return false
        }
    }

    @discardableResult
    func reviewVolunteerService(
        classId: String,
        volunteerUid: String,
        approve: Bool
    ) async -> Bool {
        guard currentProfile?.role == .teacher, currentProfile?.activeClassId == classId,
              !isManagingVolunteerService else { return false }
        let operation = beginOperation(classScoped: true)
        isManagingVolunteerService = true
        defer { if ownsOperation(operation) { isManagingVolunteerService = false } }
        clearVolunteerServiceFeedback()
        do {
            try await classroomService.reviewVolunteerService(
                classId: classId,
                volunteerUid: volunteerUid,
                approve: approve
            )
            guard isCurrent(operation) else { return false }
            let services = try await classroomService.listClassroomVolunteers(classId: classId)
            guard isCurrent(operation) else { return false }
            classroomVolunteerServices = services
            volunteerServiceNoticeMessage = approve
                ? "已核准志工加入；對方現在只能看到本班學生主動送出的求助。"
                : "已拒絕這筆服務申請。"
            isManagingVolunteerService = false
            return true
        } catch {
            guard isCurrent(operation) else { return false }
            volunteerServiceErrorMessage = classroomMessage(for: error)
            isManagingVolunteerService = false
            return false
        }
    }

    @discardableResult
    func removeVolunteerService(classId: String, volunteerUid: String) async -> Bool {
        guard currentProfile?.role == .teacher, currentProfile?.activeClassId == classId,
              !isManagingVolunteerService else { return false }
        let operation = beginOperation(classScoped: true)
        isManagingVolunteerService = true
        defer { if ownsOperation(operation) { isManagingVolunteerService = false } }
        clearVolunteerServiceFeedback()
        do {
            try await classroomService.removeVolunteerService(
                classId: classId,
                volunteerUid: volunteerUid
            )
            guard isCurrent(operation) else { return false }
            let services = try await classroomService.listClassroomVolunteers(classId: classId)
            guard isCurrent(operation) else { return false }
            classroomVolunteerServices = services
            volunteerServiceNoticeMessage = "已移除志工；學生求助權限與通知已立即撤回。"
            isManagingVolunteerService = false
            return true
        } catch {
            guard isCurrent(operation) else { return false }
            volunteerServiceErrorMessage = classroomMessage(for: error)
            isManagingVolunteerService = false
            return false
        }
    }

    func clearVolunteerServiceFeedback() {
        volunteerServiceErrorMessage = nil
        volunteerServiceNoticeMessage = nil
    }

    private func synchronizeRoleScopedClassroomData(for profile: AppUserProfile) {
        guard hasAcceptedConsent, profile.role == .teacher,
              let classId = profile.activeClassId
        else {
            classroomRosterListener?.cancel()
            classroomRosterListener = nil
            classroomRosterListenerClassId = nil
            classroomStudents = []
            classroomRosterErrorMessage = nil
            isLoadingClassroomStudents = false

            classroomVolunteerListener?.cancel()
            classroomVolunteerListener = nil
            classroomVolunteerListenerClassId = nil
            classroomVolunteerServices = []
            if volunteerServiceErrorMessage == lastClassroomVolunteerListenerErrorMessage {
                volunteerServiceErrorMessage = nil
            }
            lastClassroomVolunteerListenerErrorMessage = nil
            return
        }

        if classroomVolunteerListenerClassId != classId {
            classroomVolunteerServices = []
        }
        startClassroomRosterSync(classId: classId)
        startClassroomVolunteerSyncIfNeeded(classId: classId)
    }

    private func startVolunteerServiceSyncIfNeeded(userUid: String, role: UserRole) {
        guard role == .volunteer else {
            volunteerServiceListener?.cancel()
            volunteerServiceListener = nil
            volunteerServiceListenerUid = nil
            if volunteerServiceErrorMessage == lastVolunteerServiceListenerErrorMessage {
                volunteerServiceErrorMessage = nil
            }
            lastVolunteerServiceListenerErrorMessage = nil
            return
        }
        guard volunteerServiceListenerUid != userUid else { return }
        volunteerServiceListener?.cancel()
        if volunteerServiceErrorMessage == lastVolunteerServiceListenerErrorMessage {
            volunteerServiceErrorMessage = nil
        }
        lastVolunteerServiceListenerErrorMessage = nil
        volunteerServiceListenerUid = userUid
        let operation = beginOperation(classScoped: false)
        volunteerServiceListener = classroomService.startVolunteerServiceListener(
            userUid: userUid
        ) { [weak self] services in
            guard let self, self.isCurrent(operation) else { return }
            self.volunteerServices = services
            if self.volunteerServiceErrorMessage == self.lastVolunteerServiceListenerErrorMessage {
                self.volunteerServiceErrorMessage = nil
            }
            self.lastVolunteerServiceListenerErrorMessage = nil
        } onError: { [weak self] error in
            guard let self, self.isCurrent(operation) else { return }
            let message = "服務班級：\(self.realtimeListenerMessage(for: error))"
            self.lastVolunteerServiceListenerErrorMessage = message
            if self.volunteerServiceErrorMessage != message {
                self.volunteerServiceErrorMessage = message
            }
        }
    }

    private func startClassroomVolunteerSyncIfNeeded(classId: String) {
        guard classroomVolunteerListenerClassId != classId else { return }
        classroomVolunteerListener?.cancel()
        if volunteerServiceErrorMessage == lastClassroomVolunteerListenerErrorMessage {
            volunteerServiceErrorMessage = nil
        }
        lastClassroomVolunteerListenerErrorMessage = nil
        classroomVolunteerListenerClassId = classId
        let operation = beginOperation(classScoped: true)
        classroomVolunteerListener = classroomService.startClassroomVolunteerListener(
            classId: classId
        ) { [weak self] services in
            guard let self, self.isCurrent(operation), self.currentProfile?.activeClassId == classId else { return }
            self.classroomVolunteerServices = services
            if self.volunteerServiceErrorMessage == self.lastClassroomVolunteerListenerErrorMessage {
                self.volunteerServiceErrorMessage = nil
            }
            self.lastClassroomVolunteerListenerErrorMessage = nil
        } onError: { [weak self] error in
            guard let self, self.isCurrent(operation) else { return }
            let message = "班級志工：\(self.realtimeListenerMessage(for: error))"
            self.lastClassroomVolunteerListenerErrorMessage = message
            if self.volunteerServiceErrorMessage != message {
                self.volunteerServiceErrorMessage = message
            }
        }
    }

    private func startClassroomMembershipSyncIfNeeded(userUid: String) {
        guard classroomMembershipListenerUid != userUid else { return }
        classroomMembershipListener?.cancel()
        if classroomErrorMessage == lastMembershipListenerErrorMessage {
            classroomErrorMessage = nil
        }
        lastMembershipListenerErrorMessage = nil
        classroomMembershipListenerUid = userUid
        let operation = beginOperation(classScoped: false)
        classroomMembershipListener = classroomService.startMembershipListener(
            userUid: userUid
        ) { [weak self] activeClassIds in
            Task { @MainActor [weak self] in
                guard let self, self.isCurrent(operation) else { return }
                if self.classroomErrorMessage == self.lastMembershipListenerErrorMessage {
                    self.classroomErrorMessage = nil
                }
                self.lastMembershipListenerErrorMessage = nil
                await self.reconcileClassroomMemberships(activeClassIds: Set(activeClassIds))
            }
        } onError: { [weak self] error in
            guard let self, self.isCurrent(operation) else { return }
            if self.currentProfile?.activeClassId != nil {
                let message = "班級狀態：\(self.realtimeListenerMessage(for: error))"
                self.lastMembershipListenerErrorMessage = message
                if self.classroomErrorMessage != message {
                    self.classroomErrorMessage = message
                }
            }
        }
    }

    private func reconcileClassroomMemberships(activeClassIds: Set<String>) async {
        pendingMembershipClassIds = activeClassIds
        guard !isReconcilingClassroomMemberships else { return }
        let generation = sessionGeneration
        isReconcilingClassroomMemberships = true
        defer {
            if sessionGeneration == generation { isReconcilingClassroomMemberships = false }
        }
        while generation == sessionGeneration, let latest = pendingMembershipClassIds {
            pendingMembershipClassIds = nil
            await applyMembershipSnapshot(activeClassIds: latest, generation: generation)
        }
    }

    private func applyMembershipSnapshot(activeClassIds: Set<String>, generation: UUID) async {
        guard let currentUser, let currentProfile else { return }
        let localActiveClassIds = Set(
            currentProfile.memberships.filter(\.isActive).map(\.classId)
        )
        guard localActiveClassIds != activeClassIds else { return }

        let removedClassIds = localActiveClassIds.subtracting(activeClassIds)
        let previousActiveClassId = currentProfile.activeClassId
        let previousActiveClassName = previousActiveClassId.flatMap { classId in
            classrooms.first { $0.classId == classId }?.name
        }

        let restored = try? await authService.restorePreviousSession()
        guard generation == sessionGeneration, pendingMembershipClassIds == nil else { return }
        let baseSession = restored?.user.id == currentUser.id ? restored : nil
        var reconciledProfile = baseSession?.profile ?? currentProfile
        for classId in removedClassIds {
            reconciledProfile = reconciledProfile.markingMembershipLeft(
                classId: classId,
                at: Date()
            )
        }

        let refreshedClassrooms = try? await classroomService.listClassrooms()
        guard generation == sessionGeneration, pendingMembershipClassIds == nil else { return }
        // A user's class selection during the fetch remains authoritative.
        let selectedClassId = self.currentProfile?.activeClassId
        for classroom in refreshedClassrooms ?? [] where activeClassIds.contains(classroom.classId) {
            reconciledProfile = reconciledProfile.upsertingMembership(
                classroom.membership,
                makeActive: reconciledProfile.activeClassId == classroom.classId
            )
        }
        if selectedClassId != previousActiveClassId,
           let selectedProfile = reconciledProfile.selectingClass(selectedClassId) {
            reconciledProfile = selectedProfile
        }
        let reconciledUser = baseSession?.user ?? DemoUser(
            id: currentUser.id,
            displayName: currentUser.displayName,
            role: reconciledProfile.role
        )
        applyClassSession(
            AuthSession(user: reconciledUser, profile: reconciledProfile)
        )

        if let refreshedClassrooms {
            classrooms = refreshedClassrooms.filter { activeClassIds.contains($0.classId) }
        } else {
            classrooms.removeAll { removedClassIds.contains($0.classId) }
        }
        if let previousActiveClassId,
           !activeClassIds.contains(previousActiveClassId),
           self.currentProfile?.activeClassId == nil {
            classroomRosterListener?.cancel()
            classroomRosterListener = nil
            classroomRosterListenerClassId = nil
            classroomStudents = []
            classroomRosterErrorMessage = nil
            let className = previousActiveClassName.map { "「\($0)」" } ?? "原班級"
            classroomNoticeMessage = "\(className)已結束，你已自動回到個人模式；個人學習紀錄仍會保留。"
        }
    }

    private func refreshClassroomListAfterMutation() async {
        let operation = beginOperation(classScoped: true)
        let refreshed = try? await classroomService.listClassrooms()
        guard isCurrent(operation) else { return }
        if let refreshed {
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

    private func realtimeListenerMessage(for error: Error) -> String {
        if let classroomError = error as? ClassroomServiceError,
           let message = classroomError.errorDescription {
            return message
        }
        return LearningRepositorySyncFailureClassifier.classify(error).message
    }

    private func clearFailedAuthenticationState() {
        invalidateSessionOperations()
        currentUser = nil
        currentProfile = nil
        hasAcceptedConsent = false
        isAdministrator = false
        latestAIResponse = nil
        volunteerApplicationDraft = nil
        volunteerApplicationReviewState = nil
        volunteerReviewApplications = []
        volunteerReviewErrorMessage = nil
        signingInRole = nil
        classrooms = []
        classroomStudents = []
        volunteerServices = []
        classroomVolunteerServices = []
        volunteerInviteCodes = [:]
        isLoadingVolunteerServices = false
        isManagingVolunteerService = false
        volunteerServiceErrorMessage = nil
        volunteerServiceNoticeMessage = nil
        classroomRosterListener?.cancel()
        classroomRosterListener = nil
        classroomRosterListenerClassId = nil
        classroomMembershipListener?.cancel()
        classroomMembershipListener = nil
        classroomMembershipListenerUid = nil
        volunteerServiceListener?.cancel()
        volunteerServiceListener = nil
        volunteerServiceListenerUid = nil
        classroomVolunteerListener?.cancel()
        classroomVolunteerListener = nil
        classroomVolunteerListenerClassId = nil
        lastVolunteerServiceListenerErrorMessage = nil
        lastClassroomVolunteerListenerErrorMessage = nil
        lastMembershipListenerErrorMessage = nil
        isReconcilingClassroomMemberships = false
        classroomErrorMessage = nil
        classroomRosterErrorMessage = nil
        classroomNoticeMessage = nil
        runtimeDiagnostics = runtimeDiagnostics.clearingSession()
    }

    private func clearFederatedOnboardingState() {
        federatedOnboardingCredential = nil
        federatedOnboardingProvider = nil
        federatedOnboardingRole = nil
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
        if !response.ok {
            AppDiagnostics.shared.record(.aiProxy)
        }
    }
}
