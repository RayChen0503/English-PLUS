import XCTest
@testable import EnglishPlus

@MainActor
final class AuthenticationFlowAcceptanceTests: XCTestCase {
    func testFirstGoogleIdentityWithoutProfileStartsStudentOnboarding() async {
        let auth = RecordingAuthService()
        auth.providerSignInResult = .failure(.profileUnavailable)
        let appState = makeAppState(auth: auth)

        appState.chooseRole(.student)
        await appState.signIn(with: .google(idToken: "google-id", accessToken: "google-access"), role: .student)

        XCTAssertEqual(appState.route, .demoLogin(.student))
        XCTAssertEqual(appState.federatedOnboardingProvider(for: .student), .google)
        XCTAssertNil(appState.currentUser)
        XCTAssertNil(appState.signInErrorMessage)
        XCTAssertEqual(auth.providerSignInCallCount, 1)
    }

    func testFirstAppleIdentityCompletesTeacherProfileWithoutReplayingSignIn() async {
        let auth = RecordingAuthService()
        auth.providerSignInResult = .failure(.profileUnavailable)
        auth.providerCreationResult = .success(.authenticated(session(role: .teacher)))
        let appState = makeAppState(auth: auth)

        await appState.signIn(with: .apple(idToken: "apple-id", rawNonce: "nonce"), role: .teacher)
        await appState.completeFederatedOnboarding(profile: teacherProfile)

        XCTAssertEqual(auth.providerSignInCallCount, 1)
        XCTAssertEqual(auth.providerCreationCallCount, 1)
        XCTAssertEqual(auth.lastCreatedProfile, teacherProfile)
        XCTAssertNil(appState.federatedOnboardingProvider(for: .teacher))
        XCTAssertEqual(appState.currentUser?.role, .teacher)
        XCTAssertEqual(appState.route, .privacyConsent(.teacher))
    }

    func testReturningProviderAccountEntersItsRoleDirectly() async {
        let auth = RecordingAuthService()
        auth.providerSignInResult = .success(session(role: .student))
        let appState = makeAppState(auth: auth)

        await appState.signIn(with: .google(idToken: "existing", accessToken: "token"), role: .student)

        XCTAssertEqual(appState.currentUser?.role, .student)
        XCTAssertNil(appState.federatedOnboardingProvider(for: .student))
        XCTAssertEqual(appState.route, .privacyConsent(.student))
        XCTAssertEqual(auth.providerCreationCallCount, 0)
    }

    func testWrongRoleDoesNotCreateAnotherProfile() async {
        let auth = RecordingAuthService()
        auth.providerSignInResult = .failure(.roleMismatch(expected: .teacher, actual: .student))
        let appState = makeAppState(auth: auth)

        await appState.signIn(with: .google(idToken: "existing", accessToken: "token"), role: .teacher)

        XCTAssertNil(appState.currentUser)
        XCTAssertNil(appState.federatedOnboardingProvider(for: .teacher))
        XCTAssertEqual(auth.providerCreationCallCount, 0)
        XCTAssertTrue(appState.signInErrorMessage?.contains("學生") == true)
    }

    func testCancellingFirstUseOnboardingSignsOutAndClearsPendingIdentity() async {
        let auth = RecordingAuthService()
        auth.providerSignInResult = .failure(.profileUnavailable)
        let appState = makeAppState(auth: auth)

        await appState.signIn(with: .apple(idToken: "apple-id", rawNonce: "nonce"), role: .student)
        appState.cancelFederatedOnboarding()

        XCTAssertEqual(auth.signOutCallCount, 1)
        XCTAssertNil(appState.federatedOnboardingProvider(for: .student))
        XCTAssertNil(appState.signInErrorMessage)
    }

    func testFailedProfileCreationKeepsFirstUseFormAvailableForRetry() async {
        let auth = RecordingAuthService()
        auth.providerSignInResult = .failure(.profileUnavailable)
        auth.providerCreationResult = .failure(.networkUnavailable)
        let appState = makeAppState(auth: auth)

        await appState.signIn(with: .google(idToken: "google-id", accessToken: "token"), role: .student)
        await appState.completeFederatedOnboarding(profile: studentProfile)

        XCTAssertEqual(appState.federatedOnboardingProvider(for: .student), .google)
        XCTAssertNil(appState.currentUser)
        XCTAssertNotNil(appState.signInErrorMessage)
        XCTAssertEqual(auth.providerCreationCallCount, 1)
    }

    func testEmailRegistrationStopsAtVerificationInsteadOfEnteringApp() async {
        let auth = RecordingAuthService()
        auth.emailCreationResult = .success(.emailVerificationRequired(email: "new@englishplus.test"))
        let appState = makeAppState(auth: auth)

        await appState.createAccount(
            AccountRegistration(
                email: "new@englishplus.test",
                password: "EnglishPlus2026!",
                displayName: "新同學",
                role: .student,
                teacherAffiliation: nil,
                volunteerApplication: nil
            )
        )

        XCTAssertNil(appState.currentUser)
        XCTAssertEqual(appState.verificationEmailAddress, "new@englishplus.test")
        XCTAssertEqual(appState.route, .roleSelection)
        XCTAssertTrue(appState.authNoticeMessage?.contains("驗證信") == true)
    }

    func testUnverifiedEmailLoginReturnsToVerificationState() async {
        let auth = RecordingAuthService()
        auth.emailSignInResult = .failure(.emailNotVerified(email: "new@englishplus.test"))
        let appState = makeAppState(auth: auth)

        await appState.signIn(
            email: "new@englishplus.test",
            password: "EnglishPlus2026!",
            role: .student
        )

        XCTAssertNil(appState.currentUser)
        XCTAssertEqual(appState.verificationEmailAddress, "new@englishplus.test")
        XCTAssertNotNil(appState.signInErrorMessage)
    }

    func testNewVolunteerReachesEvidenceUploadBeforeApproval() async {
        let auth = RecordingAuthService()
        auth.providerSignInResult = .failure(.profileUnavailable)
        auth.providerCreationResult = .success(
            .authenticated(session(role: .volunteer, status: .pendingApplication))
        )
        let appState = makeAppState(auth: auth)

        await appState.signIn(with: .google(idToken: "volunteer", accessToken: "token"), role: .volunteer)
        await appState.completeFederatedOnboarding(profile: volunteerProfile)

        XCTAssertEqual(appState.currentUser?.role, .volunteer)
        XCTAssertEqual(appState.route, .volunteerApplication)
        XCTAssertFalse(appState.hasAcceptedConsent)
        XCTAssertEqual(auth.loadVolunteerApplicationCallCount, 1)
    }

    func testRestoredSessionSkipsRoleSelectionButStillHonorsConsent() async {
        let auth = RecordingAuthService()
        auth.restoredSession = session(role: .teacher)
        let appState = makeAppState(auth: auth)

        await appState.restoreSessionIfPossible()

        XCTAssertEqual(appState.currentUser?.role, .teacher)
        XCTAssertEqual(appState.route, .privacyConsent(.teacher))
        XCTAssertEqual(auth.restoreCallCount, 1)
    }

    private func makeAppState(auth: RecordingAuthService) -> AppState {
        AppState(
            authService: auth,
            firestoreService: MockFirestoreService(),
            aiService: MockAIService(),
            evidenceUploadService: UnavailableEvidenceUploadService(),
            volunteerReviewService: UnavailableVolunteerReviewService(),
            classroomService: MockClassroomService(),
            accountLifecycleService: MockAccountLifecycleService(),
            runtimeDiagnostics: RuntimeDiagnosticsSnapshot(
                backendMode: .firebase,
                hasFirebaseConfig: true,
                authProvider: "RecordingAuthService",
                firestoreProvider: "MockFirestoreService",
                learningProvider: "MockLearningRepository",
                aiProvider: "MockAIService",
                aiProxyEndpoint: nil
            )
        )
    }

    private var studentProfile: RoleOnboardingProfile {
        RoleOnboardingProfile(
            displayName: "新同學",
            role: .student,
            teacherAffiliation: nil,
            volunteerApplication: nil
        )
    }

    private var teacherProfile: RoleOnboardingProfile {
        RoleOnboardingProfile(
            displayName: "林老師",
            role: .teacher,
            teacherAffiliation: TeacherAffiliation(
                institutionId: "school-001",
                institutionName: "測試國中",
                institutionKind: .juniorHighSchool,
                institutionSource: .ministryOfEducation,
                claimStatus: .selfDeclared
            ),
            volunteerApplication: nil
        )
    }

    private var volunteerProfile: RoleOnboardingProfile {
        RoleOnboardingProfile(
            displayName: "志工測試者",
            role: .volunteer,
            teacherAffiliation: nil,
            volunteerApplication: VolunteerApplicationInput(
                confirmsAge18OrOlder: true,
                acceptedConductVersion: "volunteer-conduct-v1",
                motivation: "陪伴學生學習英文",
                evidence: []
            )
        )
    }

    private func session(
        role: UserRole,
        status: AccountProvisioningStatus = .active
    ) -> AuthSession {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let profile = AppUserProfile(
            id: "\(role.rawValue)-uid",
            displayName: role.title,
            role: role,
            classId: FirebaseBackendConfig.personalScopeId(uid: "\(role.rawValue)-uid"),
            groupId: nil,
            consentStatus: .pending,
            isDemo: false,
            accountStatus: status,
            createdAt: now,
            updatedAt: now,
            memberships: [],
            activeClassId: nil
        )
        return AuthSession(
            user: DemoUser(id: profile.id, displayName: profile.displayName, role: role),
            profile: profile
        )
    }
}

private final class RecordingAuthService: AuthService {
    var providerSignInResult: Result<AuthSession, AuthServiceError> = .failure(.profileUnavailable)
    var providerCreationResult: Result<AccountCreationOutcome, AuthServiceError> = .failure(.operationUnavailable)
    var emailCreationResult: Result<AccountCreationOutcome, AuthServiceError> = .failure(.operationUnavailable)
    var emailSignInResult: Result<AuthSession, AuthServiceError> = .failure(.invalidCredentials)
    var restoredSession: AuthSession?

    private(set) var providerSignInCallCount = 0
    private(set) var providerCreationCallCount = 0
    private(set) var signOutCallCount = 0
    private(set) var restoreCallCount = 0
    private(set) var loadVolunteerApplicationCallCount = 0
    private(set) var lastCreatedProfile: RoleOnboardingProfile?

    func demoSession(for role: UserRole) -> AuthSession {
        fatalError("Demo sign-in is outside this acceptance suite")
    }

    func signIn(email: String, password: String, expectedRole: UserRole) async throws -> AuthSession {
        try emailSignInResult.get()
    }

    func createAccount(_ registration: AccountRegistration) async throws -> AccountCreationOutcome {
        try emailCreationResult.get()
    }

    func signIn(
        with credential: FederatedIdentityCredential,
        expectedRole: UserRole
    ) async throws -> AuthSession {
        providerSignInCallCount += 1
        return try providerSignInResult.get()
    }

    func createAccount(
        with credential: FederatedIdentityCredential,
        profile: RoleOnboardingProfile
    ) async throws -> AccountCreationOutcome {
        providerCreationCallCount += 1
        lastCreatedProfile = profile
        return try providerCreationResult.get()
    }

    func loadVolunteerApplication(
        in session: AuthSession
    ) async throws -> VolunteerApplicationInput? {
        loadVolunteerApplicationCallCount += 1
        return VolunteerApplicationInput(
            confirmsAge18OrOlder: true,
            acceptedConductVersion: "volunteer-conduct-v1",
            motivation: "陪伴學生學習英文",
            evidence: []
        )
    }

    func restorePreviousSession() async throws -> AuthSession? {
        restoreCallCount += 1
        return restoredSession
    }

    func signOut() {
        signOutCallCount += 1
    }
}
