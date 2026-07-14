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

    func testExistingEmailCollisionLinksProviderAfterOriginalLogin() async {
        let auth = RecordingAuthService()
        auth.providerSignInResult = .failure(.accountLinkRequired)
        auth.emailSignInResult = .success(session(role: .teacher))
        let appState = makeAppState(auth: auth)

        await appState.signIn(with: .google(idToken: "collision", accessToken: "token"), role: .teacher)
        XCTAssertTrue(appState.signInErrorMessage?.contains("原本方式登入") == true)

        await appState.signIn(
            email: "teacher@englishplus.test",
            password: "EnglishPlus2026!",
            role: .teacher
        )

        XCTAssertEqual(auth.linkIdentityCallCount, 1)
        XCTAssertEqual(appState.currentUser?.role, .teacher)
        XCTAssertEqual(appState.route, .privacyConsent(.teacher))
        XCTAssertTrue(appState.authNoticeMessage?.contains("安全連結") == true)
    }

    func testSwitchingRoleDuringFirstUseCancelsAuthenticatedIdentity() async {
        let auth = RecordingAuthService()
        auth.providerSignInResult = .failure(.profileUnavailable)
        let appState = makeAppState(auth: auth)

        await appState.signIn(with: .apple(idToken: "apple-id", rawNonce: "nonce"), role: .student)
        appState.chooseRole(.teacher)

        XCTAssertEqual(auth.signOutCallCount, 1)
        XCTAssertNil(appState.federatedOnboardingProvider(for: .student))
        XCTAssertEqual(appState.route, .demoLogin(.teacher))
    }

    func testPendingVolunteerCannotEnterProtectedHome() async {
        let auth = RecordingAuthService()
        auth.providerSignInResult = .failure(.accountPendingApproval)
        let appState = makeAppState(auth: auth)

        await appState.signIn(with: .google(idToken: "pending", accessToken: "token"), role: .volunteer)

        XCTAssertNil(appState.currentUser)
        XCTAssertNil(appState.federatedOnboardingProvider(for: .volunteer))
        XCTAssertNotEqual(appState.route, .home(.volunteer))
        XCTAssertTrue(appState.signInErrorMessage?.contains("等待") == true)
    }

    func testSignOutClearsAuthenticatedStateAndReturnsToRoleSelection() async {
        let auth = RecordingAuthService()
        auth.providerSignInResult = .success(session(role: .student))
        let appState = makeAppState(auth: auth)

        await appState.signIn(with: .google(idToken: "existing", accessToken: "token"), role: .student)
        appState.signOut()

        XCTAssertEqual(auth.signOutCallCount, 1)
        XCTAssertNil(appState.currentUser)
        XCTAssertNil(appState.currentProfile)
        XCTAssertNil(appState.selectedRole)
        XCTAssertFalse(appState.hasAcceptedConsent)
        XCTAssertEqual(appState.route, .roleSelection)
    }

    func testEmailAlreadyInUseNeverCreatesAnAuthenticatedSession() async {
        let auth = RecordingAuthService()
        auth.emailCreationResult = .failure(.emailAlreadyInUse)
        let appState = makeAppState(auth: auth)

        await appState.createAccount(
            AccountRegistration(
                email: "existing@englishplus.test",
                password: "EnglishPlus2026!",
                displayName: "既有同學",
                role: .student,
                teacherAffiliation: nil,
                volunteerApplication: nil
            )
        )

        XCTAssertNil(appState.currentUser)
        XCTAssertTrue(appState.signInErrorMessage?.contains("已經建立過") == true)
    }

    func testRestoredConsentEntersHomeWithoutShowingAgreementAgain() async throws {
        let auth = RecordingAuthService()
        let restored = session(role: .student)
        auth.restoredSession = restored
        let firestore = MockFirestoreService()
        try await firestore.saveConsent(
            PrivacyConsentRecord.accepted(
                uid: restored.user.id,
                role: .student,
                classId: restored.profile.classId,
                categories: PrivacyPolicyCopy.requiredCategories(for: .student),
                guardianConsentStatus: .notRequired
            )
        )
        let appState = makeAppState(auth: auth, firestore: firestore)

        await appState.restoreSessionIfPossible()

        XCTAssertTrue(appState.hasAcceptedConsent)
        XCTAssertEqual(appState.route, .home(.student))
    }

    func testMembershipListenerOverridesAStaleRestoredProfileAfterClassDeletion() async {
        let auth = RecordingAuthService()
        let classroomService = MockClassroomService()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let membership = ClassMembership(
            classId: "CLASS-DELETED",
            className: "Deleted class",
            role: .student,
            groupId: nil,
            status: .active,
            joinedAt: now,
            visibilityStartsAt: now,
            leftAt: nil
        )
        let profile = AppUserProfile(
            id: "student-listener",
            displayName: "Student",
            role: .student,
            classId: membership.classId,
            groupId: nil,
            consentStatus: .pending,
            isDemo: false,
            createdAt: now,
            updatedAt: now,
            memberships: [membership],
            activeClassId: membership.classId
        )
        let staleSession = AuthSession(
            user: DemoUser(id: profile.id, displayName: profile.displayName, role: .student),
            profile: profile
        )
        auth.restoredSession = staleSession
        let appState = makeAppState(auth: auth, classroomService: classroomService)

        await appState.restoreSessionIfPossible()
        classroomService.simulateMembershipChange(activeClassIds: [])
        for _ in 0..<20 where appState.currentProfile?.activeClassId != nil {
            await Task.yield()
        }

        XCTAssertNil(appState.currentProfile?.activeClassId)
        XCTAssertTrue(appState.currentProfile?.isPersonalMode == true)
        XCTAssertEqual(
            appState.currentProfile?.memberships.first?.status,
            ClassMembershipStatus.left
        )
        XCTAssertTrue(appState.classroomNoticeMessage?.contains("自動回到個人模式") == true)
    }

    func testTeacherSessionStartsTheActiveClassRosterWithoutOpeningTheClassTab() async {
        let auth = RecordingAuthService()
        let classroomService = MockClassroomService()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let classId = "CLASS-TEACHER-ACTIVE"
        let membership = ClassMembership(
            classId: classId,
            className: "八年甲班",
            role: .teacher,
            groupId: nil,
            status: .active,
            joinedAt: now,
            visibilityStartsAt: now,
            leftAt: nil
        )
        let profile = AppUserProfile(
            id: "teacher-roster",
            displayName: "林老師",
            role: .teacher,
            classId: classId,
            groupId: nil,
            consentStatus: .granted,
            isDemo: false,
            createdAt: now,
            updatedAt: now,
            memberships: [membership],
            activeClassId: classId
        )
        auth.restoredSession = AuthSession(
            user: DemoUser(id: profile.id, displayName: profile.displayName, role: .teacher),
            profile: profile
        )
        classroomService.seedStudents(
            [
                ClassroomStudentSummary(
                    id: "student-1",
                    studentUid: "student-1",
                    studentName: "小安",
                    classId: classId,
                    gradeBand: "8",
                    currentLevel: "A2",
                    recommendedTrack: "steady",
                    moodScore: 4,
                    riskLevel: .low,
                    missionStatus: MissionStatus.active.rawValue,
                    lastActivityAt: nil,
                    joinedAt: ISO8601DateFormatter().string(from: now)
                )
            ],
            classId: classId
        )
        let appState = makeAppState(auth: auth, classroomService: classroomService)

        await appState.restoreSessionIfPossible()

        XCTAssertEqual(classroomService.studentListenerStartCount, 0)
        XCTAssertEqual(appState.route, .privacyConsent(.teacher))

        await appState.acceptPrivacyConsent(
            categories: PrivacyConsentCategory.allCases,
            guardianConsentStatus: .notRequired
        )

        XCTAssertEqual(classroomService.studentListenerStartCount, 1)
        XCTAssertEqual(classroomService.lastStudentListenerClassId, classId)
        XCTAssertEqual(appState.classroomStudents.map(\.studentUid), ["student-1"])
        XCTAssertEqual(appState.route, .home(.teacher))

        await appState.loadClassrooms()
        XCTAssertEqual(classroomService.studentListenerStartCount, 1)
    }

    private func makeAppState(
        auth: RecordingAuthService,
        firestore: MockFirestoreService = MockFirestoreService(),
        classroomService: ClassroomService? = nil
    ) -> AppState {
        AppState(
            authService: auth,
            firestoreService: firestore,
            aiService: MockAIService(),
            evidenceUploadService: UnavailableEvidenceUploadService(),
            volunteerReviewService: UnavailableVolunteerReviewService(),
            classroomService: classroomService ?? MockClassroomService(),
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

@MainActor
final class StabilizationDashboardAcceptanceTests: XCTestCase {
    func testAnEmptySupportDatasetReportsZeroStudents() {
        let persistence = MemoryLearningPersistence(
            snapshot: LocalLearningSnapshot(
                currentCheckIn: nil,
                currentMission: nil,
                missionAttempts: [],
                supportRequests: [],
                assignedPracticeTasks: [],
                savedAt: Date(timeIntervalSince1970: 1_800_000_000)
            )
        )
        let store = LearningRepositoryStore(
            backend: MockLearningRepository(localPersistence: persistence)
        )

        XCTAssertEqual(store.staffDashboardMetrics.studentCount, 0)
        XCTAssertEqual(store.staffDashboardMetrics.waitingHelpCount, 0)
        XCTAssertEqual(store.classroomReportExport.classCode, "未選擇班級")
        XCTAssertEqual(
            store.classroomReportExport.metrics.first { $0.id == "students" }?.value,
            "0"
        )
    }

    func testVolunteerCompletedCountTracksThreadsInsteadOfReplyMessages() async {
        let store = LearningRepositoryStore(
            backend: MockLearningRepository(localPersistence: MemoryLearningPersistence())
        )

        XCTAssertEqual(store.volunteerDashboardMetrics.repliedByVolunteerCount, 0)
        let firstReplySucceeded = await store.addVolunteerReply(
            to: "support-seed-volunteer-1",
            body: "先看主詞。"
        )
        let secondReplySucceeded = await store.addVolunteerReply(
            to: "support-seed-volunteer-1",
            body: "再確認動詞形式。"
        )

        XCTAssertTrue(firstReplySucceeded)
        XCTAssertTrue(secondReplySucceeded)
        XCTAssertEqual(store.visibleVolunteerReplies.count, 2)
        XCTAssertEqual(store.volunteerDashboardMetrics.repliedByVolunteerCount, 1)
    }
}

@MainActor
final class LearningRepositoryReliabilityTests: XCTestCase {
    func testDisconnectKeepsLocalDataAndReconnectRestartsListener() async {
        let connectivity = ManualNetworkConnectivityMonitor(initialStatus: .connected)
        let backend = ReliabilityTestLearningBackend(behaviors: [.snapshot, .snapshot])
        let store = LearningRepositoryStore(
            backend: backend,
            connectivityMonitor: connectivity,
            retryDelaysNanoseconds: [1_000_000]
        )

        store.startRealtimeSync(classId: "class-a", user: nil, profile: nil)
        XCTAssertEqual(store.syncStatus, .listening(classId: "class-a"))
        XCTAssertNotNil(store.lastSuccessfulSyncAt)

        connectivity.send(.disconnected)
        try? await Task.sleep(nanoseconds: 1_000_000)
        guard case .offlineFallback = store.syncStatus else {
            return XCTFail("Disconnect must switch to the local-data fallback state")
        }

        connectivity.send(.connected)
        try? await Task.sleep(nanoseconds: 1_000_000)
        XCTAssertEqual(backend.listenerStartCount, 2)
        XCTAssertEqual(store.syncStatus, .listening(classId: "class-a"))
    }

    func testListenerFailureRetriesWithBackoffAndRecovers() async {
        let connectivity = ManualNetworkConnectivityMonitor(initialStatus: .connected)
        let backend = ReliabilityTestLearningBackend(behaviors: [.failure, .snapshot])
        let store = LearningRepositoryStore(
            backend: backend,
            connectivityMonitor: connectivity,
            retryDelaysNanoseconds: [1_000_000]
        )

        store.startRealtimeSync(classId: "class-b", user: nil, profile: nil)
        guard case .offlineFallback = store.syncStatus else {
            return XCTFail("Listener errors must preserve local data and expose recovery")
        }

        try? await Task.sleep(nanoseconds: 25_000_000)
        XCTAssertEqual(backend.listenerStartCount, 2)
        XCTAssertEqual(store.syncStatus, .listening(classId: "class-b"))
    }

    func testStoppingSyncCancelsScheduledRetry() async {
        let connectivity = ManualNetworkConnectivityMonitor(initialStatus: .connected)
        let backend = ReliabilityTestLearningBackend(behaviors: [.failure, .snapshot])
        let store = LearningRepositoryStore(
            backend: backend,
            connectivityMonitor: connectivity,
            retryDelaysNanoseconds: [50_000_000]
        )

        store.startRealtimeSync(classId: "class-c", user: nil, profile: nil)
        store.stopRealtimeSync()
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(backend.listenerStartCount, 1)
        XCTAssertEqual(store.syncStatus, .idle)
    }

    func testRepeatedStartForSameScopeDoesNotRestartListener() {
        let connectivity = ManualNetworkConnectivityMonitor(initialStatus: .connected)
        let backend = ReliabilityTestLearningBackend(behaviors: [.snapshot])
        let store = LearningRepositoryStore(
            backend: backend,
            connectivityMonitor: connectivity,
            retryDelaysNanoseconds: [1_000_000]
        )

        store.startRealtimeSync(classId: "class-d", user: nil, profile: nil)
        store.startRealtimeSync(classId: "class-d", user: nil, profile: nil)

        XCTAssertEqual(backend.listenerStartCount, 1)
        XCTAssertEqual(store.syncStatus, .listening(classId: "class-d"))
    }

    func testSnapshotFromCancelledScopeCannotReplaceCurrentScope() {
        let connectivity = ManualNetworkConnectivityMonitor(initialStatus: .connected)
        let backend = ReliabilityTestLearningBackend(behaviors: [.deferred, .snapshot])
        let store = LearningRepositoryStore(
            backend: backend,
            connectivityMonitor: connectivity,
            retryDelaysNanoseconds: [1_000_000]
        )

        store.startRealtimeSync(classId: "class-old", user: nil, profile: nil)
        store.startRealtimeSync(classId: "class-current", user: nil, profile: nil)
        backend.emitSnapshot(forListenerAt: 0)

        XCTAssertEqual(backend.listenerStartCount, 2)
        XCTAssertEqual(store.syncStatus, .listening(classId: "class-current"))
    }

    func testErrorFromCancelledScopeCannotScheduleRetryForCurrentScope() async {
        let connectivity = ManualNetworkConnectivityMonitor(initialStatus: .connected)
        let backend = ReliabilityTestLearningBackend(behaviors: [.deferred, .snapshot])
        let store = LearningRepositoryStore(
            backend: backend,
            connectivityMonitor: connectivity,
            retryDelaysNanoseconds: [1_000_000]
        )

        store.startRealtimeSync(classId: "class-old", user: nil, profile: nil)
        store.startRealtimeSync(classId: "class-current", user: nil, profile: nil)
        backend.emitError(forListenerAt: 0)
        try? await Task.sleep(nanoseconds: 10_000_000)

        XCTAssertEqual(backend.listenerStartCount, 2)
        XCTAssertEqual(store.syncStatus, .listening(classId: "class-current"))
    }
}

private final class ManualNetworkConnectivityMonitor: NetworkConnectivityMonitoring, @unchecked Sendable {
    private(set) var currentStatus: NetworkConnectivityStatus
    private var onChange: (@Sendable (NetworkConnectivityStatus) -> Void)?

    init(initialStatus: NetworkConnectivityStatus) {
        currentStatus = initialStatus
    }

    func start(onChange: @escaping @Sendable (NetworkConnectivityStatus) -> Void) {
        self.onChange = onChange
    }

    func stop() {
        onChange = nil
    }

    func send(_ status: NetworkConnectivityStatus) {
        currentStatus = status
        onChange?(status)
    }
}

@MainActor
private final class ReliabilityTestLearningBackend: LearningRepositoryBackend {
    enum ListenerBehavior {
        case snapshot
        case failure
        case deferred
    }

    private struct ListenerCallbacks {
        let onChange: @MainActor (LearningRepositorySnapshot) -> Void
        let onError: @MainActor (Error) -> Void
    }

    private let base = MockLearningRepository(localPersistence: MemoryLearningPersistence())
    private var behaviors: [ListenerBehavior]
    private var listeners: [ListenerCallbacks] = []
    private(set) var listenerStartCount = 0

    init(behaviors: [ListenerBehavior]) {
        self.behaviors = behaviors
    }

    var snapshot: LearningRepositorySnapshot { base.snapshot }
    var supportedQuestionTypes: [QuestionType] { base.supportedQuestionTypes }
    var defaultPreferredQuestionTypes: [QuestionType] { base.defaultPreferredQuestionTypes }
    var questionBankItems: [QuestionBankItem] { base.questionBankItems }
    var questionPracticeSets: [QuestionPracticeSet] { base.questionPracticeSets }

    func refresh() async throws {}

    func startRealtimeListener(
        classId: String,
        user: DemoUser?,
        profile: AppUserProfile?,
        onChange: @escaping @MainActor (LearningRepositorySnapshot) -> Void,
        onError: @escaping @MainActor (Error) -> Void
    ) -> LearningRepositoryListenerToken {
        listenerStartCount += 1
        listeners.append(ListenerCallbacks(onChange: onChange, onError: onError))
        let behavior = behaviors.isEmpty ? .snapshot : behaviors.removeFirst()
        switch behavior {
        case .snapshot:
            onChange(snapshot)
        case .failure:
            onError(ReliabilityTestError.offline)
        case .deferred:
            break
        }
        return AnyLearningRepositoryListenerToken {}
    }

    func emitSnapshot(forListenerAt index: Int) {
        listeners[index].onChange(snapshot)
    }

    func emitError(forListenerAt index: Int) {
        listeners[index].onError(ReliabilityTestError.offline)
    }

    func generateMission(
        for user: DemoUser?,
        profile: AppUserProfile?,
        moodScore: Int,
        availableTimeLevel: Int,
        wantsChallenge: Bool,
        preferredQuestionTypes: [QuestionType],
        aiMission: AiMissionOutput?
    ) {
        base.generateMission(
            for: user,
            profile: profile,
            moodScore: moodScore,
            availableTimeLevel: availableTimeLevel,
            wantsChallenge: wantsChallenge,
            preferredQuestionTypes: preferredQuestionTypes,
            aiMission: aiMission
        )
    }

    func startNewLearningRound(for user: DemoUser?, profile: AppUserProfile?) {
        base.startNewLearningRound(for: user, profile: profile)
    }

    func continueLearningFlow() { base.continueLearningFlow() }
    func enterFreePracticeMode() { base.enterFreePracticeMode() }
    func returnToMissionFlow() { base.returnToMissionFlow() }
    func completeFreePracticeSession(correctCount: Int, totalCount: Int) {
        base.completeFreePracticeSession(correctCount: correctCount, totalCount: totalCount)
    }
    func submitMissionAnswer(_ answer: String) -> MissionAttempt? {
        base.submitMissionAnswer(answer)
    }
    func recordPracticeAnswer(
        studentUid: String,
        questionItem: QuestionBankItem,
        isCorrect: Bool,
        source: LearningAttemptSource
    ) {
        base.recordPracticeAnswer(
            studentUid: studentUid,
            questionItem: questionItem,
            isCorrect: isCorrect,
            source: source
        )
    }
    func supportRequests(forStudentUid studentUid: String?) -> [StudentSupportRequest] {
        base.supportRequests(forStudentUid: studentUid)
    }
    func sendSupportRequest(
        from user: DemoUser?,
        profile: AppUserProfile?,
        option: SupportOption,
        message: String?
    ) async throws {
        try await base.sendSupportRequest(from: user, profile: profile, option: option, message: message)
    }
    func sendQuestionSupportRequest(
        from user: DemoUser?,
        profile: AppUserProfile?,
        option: SupportOption,
        questionItem: QuestionBankItem,
        selectedAnswer: String?,
        message: String
    ) async throws {
        try await base.sendQuestionSupportRequest(
            from: user,
            profile: profile,
            option: option,
            questionItem: questionItem,
            selectedAnswer: selectedAnswer,
            message: message
        )
    }
    func addTeacherReply(to requestId: String, body: String) async throws {
        try await base.addTeacherReply(to: requestId, body: body)
    }
    func addVolunteerReply(to requestId: String, body: String) async throws {
        try await base.addVolunteerReply(to: requestId, body: body)
    }
    func markSupportThreadReadByStudent(_ requestId: String) async throws {
        try await base.markSupportThreadReadByStudent(requestId)
    }
    func archiveSupportThreadForStudent(_ requestId: String) async throws {
        try await base.archiveSupportThreadForStudent(requestId)
    }
    func withdrawSupportRequest(_ requestId: String) async throws {
        try await base.withdrawSupportRequest(requestId)
    }
    func markSupportThreadHandledWithoutReply(_ requestId: String, by staffUser: DemoUser?) async throws {
        try await base.markSupportThreadHandledWithoutReply(requestId, by: staffUser)
    }
    func archiveSupportThreadForStaff(_ requestId: String, by staffUser: DemoUser?) async throws {
        try await base.archiveSupportThreadForStaff(requestId, by: staffUser)
    }
    func assignPracticeSet(_ set: QuestionPracticeSet, to student: StaffStudentSummary, by teacher: DemoUser?) {
        base.assignPracticeSet(set, to: student, by: teacher)
    }
    func startAssignedPracticeTask(_ assignment: TeacherAssignedPracticeTask) {
        base.startAssignedPracticeTask(assignment)
    }
    func withdrawAssignedPracticeTask(_ assignmentId: String) {
        base.withdrawAssignedPracticeTask(assignmentId)
    }
    func eraseLocalData(for uid: String) { base.eraseLocalData(for: uid) }
}

private enum ReliabilityTestError: LocalizedError {
    case offline

    var errorDescription: String? {
        "測試網路暫時無法使用。"
    }
}

private final class MemoryLearningPersistence: LocalLearningPersistence {
    private var snapshot: LocalLearningSnapshot?

    init(snapshot: LocalLearningSnapshot? = nil) {
        self.snapshot = snapshot
    }

    func loadSnapshot() -> LocalLearningSnapshot? {
        snapshot
    }

    func saveSnapshot(_ snapshot: LocalLearningSnapshot) {
        self.snapshot = snapshot
    }

    func clearSnapshot() {
        snapshot = nil
    }

    func clearAllScopes(for uid: String) {
        snapshot = nil
    }

    func scoped(for uid: String) -> any LocalLearningPersistence {
        self
    }
}

final class SupportLifecycleAcceptanceTests: XCTestCase {
    func testStaffReplyIsUnreadUntilStudentReadTimestampPassesReply() {
        let replyAt = Date(timeIntervalSince1970: 2_000)
        var request = makeRequest(
            status: .waitingForStaff,
            replies: [staffReply(at: replyAt)]
        )

        XCTAssertTrue(request.hasStudentUnreadReply)
        XCTAssertEqual(request.reconciledStatus, .replied)

        request.studentLastReadAt = Date(timeIntervalSince1970: 2_001)
        XCTAssertFalse(request.hasStudentUnreadReply)
        XCTAssertEqual(request.reconciledStatus, .readByStudent)
    }

    func testStudentRequestMessageNeverCountsAsAStaffReply() {
        let studentMessage = SupportReply(
            id: "student-message",
            authorUid: "student-1",
            authorName: "Student",
            authorRole: .student,
            body: "Please help.",
            visibleToStudent: true,
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
        let request = makeRequest(status: .waitingForStaff, replies: [studentMessage])

        XCTAssertTrue(request.visibleStaffRepliesToStudent.isEmpty)
        XCTAssertFalse(request.hasStudentUnreadReply)
        XCTAssertEqual(request.reconciledStatus, .waitingForStaff)
    }

    func testIndependentStaffArchivesBecomeArchivedOnlyAfterBothSidesArchive() {
        var request = makeRequest(status: .waitingForStaff)
        request.teacherArchivedAt = Date(timeIntervalSince1970: 2_000)
        XCTAssertEqual(request.reconciledStatus, .waitingForStaff)

        request.volunteerArchivedAt = Date(timeIntervalSince1970: 2_001)
        XCTAssertEqual(request.reconciledStatus, .archived)
        XCTAssertTrue(request.reconcilingLifecycle().canStudentArchiveAfterStaffArchivedWithoutReply)
    }

    func testWithdrawAlwaysClosesAndHidesStudentThread() {
        var request = makeRequest(status: .waitingForStaff)
        request.withdrawnAt = Date(timeIntervalSince1970: 2_000)
        request.studentArchivedAt = request.withdrawnAt

        XCTAssertEqual(request.reconciledStatus, .closed)
        XCTAssertFalse(request.isVisibleToStudent)
        XCTAssertFalse(request.isVisibleInStaffQueue(for: .teacher))
        XCTAssertFalse(request.isVisibleInStaffQueue(for: .volunteer))
    }

    func testIncompleteLegacyQuestionIsNotActionable() {
        var request = makeRequest(status: .waitingForStaff)
        request.questionSnapshot = nil
        request.studentMessage = "Old record without a question snapshot"

        XCTAssertFalse(request.hasActionableSupportContent)
        XCTAssertFalse(request.isVisibleInStaffQueue(for: .teacher))
    }

    private func makeRequest(
        status: SupportThreadStatus,
        replies: [SupportReply] = []
    ) -> StudentSupportRequest {
        StudentSupportRequest(
            id: "thread-1",
            studentUid: "student-1",
            studentName: "Student",
            classCode: "class-1",
            reason: .stuckOnQuestion,
            route: .humanHandoff,
            priority: .medium,
            status: status,
            studentMessage: "I need help.",
            moodScore: 3,
            latestQuestionId: "question-1",
            questionSnapshot: SupportQuestionSnapshot(
                questionId: "question-1",
                prompt: "My parents ___ at home.",
                options: ["be", "am", "is", "are"],
                questionTypeTitle: "Grammar",
                levelTitle: "Foundation",
                skill: "be verbs",
                selectedAnswer: "is",
                correctAnswer: "are",
                explanation: "A plural subject uses are.",
                repairHint: "Find the subject first."
            ),
            createdAt: Date(timeIntervalSince1970: 1_900),
            updatedAt: Date(timeIntervalSince1970: 1_900),
            replies: replies
        )
    }

    private func staffReply(at date: Date) -> SupportReply {
        SupportReply(
            id: "teacher-reply",
            authorUid: "teacher-1",
            authorName: "Teacher",
            authorRole: .teacher,
            body: "Find the plural subject first.",
            visibleToStudent: true,
            createdAt: date
        )
    }
}

final class PracticeSessionDraftAcceptanceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var store: PracticeSessionDraftStore!
    private let suiteName = "PracticeSessionDraftAcceptanceTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        store = PracticeSessionDraftStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        store = nil
        super.tearDown()
    }

    func testDraftRoundTripPreservesQuestionPositionAndSubmittedResult() {
        let result = PracticeResult(
            isCorrect: false,
            acceptedAnswer: "are",
            explanation: "A plural subject uses are.",
            repairHint: "Find the subject first."
        )
        let draft = PracticeSessionDraft(
            questionIds: ["q1", "q2", "q3"],
            index: 1,
            answer: "is",
            result: result,
            sourceTitle: "Be verbs",
            selectionNote: "Foundation practice",
            optionOrderByQuestionId: ["q2": ["am", "is", "are", "be"]],
            answeredCount: 2,
            correctCount: 1,
            didCountCurrentAnswer: true
        )

        store.save(draft, ownerId: "student-a")

        XCTAssertEqual(store.load(ownerId: "student-a"), draft)
    }

    func testDraftsAreIsolatedBetweenAccounts() {
        let draft = PracticeSessionDraft(
            questionIds: ["q1"],
            index: 0,
            answer: "",
            result: nil,
            sourceTitle: "Vocabulary",
            selectionNote: nil,
            optionOrderByQuestionId: [:],
            answeredCount: 0,
            correctCount: 0,
            didCountCurrentAnswer: false
        )

        store.save(draft, ownerId: "student-a")

        XCTAssertEqual(store.load(ownerId: "student-a"), draft)
        XCTAssertNil(store.load(ownerId: "student-b"))
    }

    func testClearingOneAccountDoesNotClearAnotherAccountDraft() {
        let draft = PracticeSessionDraft(
            questionIds: ["q1"],
            index: 0,
            answer: "are",
            result: nil,
            sourceTitle: "Grammar",
            selectionNote: nil,
            optionOrderByQuestionId: [:],
            answeredCount: 0,
            correctCount: 0,
            didCountCurrentAnswer: false
        )
        store.save(draft, ownerId: "student-a")
        store.save(draft, ownerId: "student-b")

        store.clear(ownerId: "student-a")

        XCTAssertNil(store.load(ownerId: "student-a"))
        XCTAssertEqual(store.load(ownerId: "student-b"), draft)
    }

    func testMalformedDraftFailsClosed() {
        defaults.set(Data("not-json".utf8), forKey: "englishplus.practice.primary.v1.student-a")

        XCTAssertNil(store.load(ownerId: "student-a"))
        XCTAssertNil(defaults.data(forKey: "englishplus.practice.primary.v1.student-a"))
    }
}

@MainActor
final class ClassroomLifecycleAcceptanceTests: XCTestCase {
    func testDeletingClassroomRemovesItFromEveryActiveMockMembership() async throws {
        let service = MockClassroomService()
        let classroom = try await service.createClassroom(name: "八年級英文 A 班")
        let activeClassrooms = try await service.listClassrooms()

        XCTAssertEqual(activeClassrooms.map(\.classId), [classroom.classId])

        try await service.deleteClassroom(classId: classroom.classId)
        let remainingClassrooms = try await service.listClassrooms()

        XCTAssertTrue(remainingClassrooms.isEmpty)
        do {
            _ = try await service.resetJoinCode(classId: classroom.classId)
            XCTFail("A deleted classroom must not allow join-code rotation.")
        } catch {
            XCTAssertEqual(error as? ClassroomServiceError, .permissionDenied)
        }
    }

    func testDeletedActiveMembershipFallsBackToPersonalModeWithoutErasingOtherClasses() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let deletedMembership = ClassMembership(
            classId: "CLASS-DELETED",
            className: "Deleted class",
            role: .student,
            groupId: nil,
            status: .active,
            joinedAt: now,
            visibilityStartsAt: now,
            leftAt: nil
        )
        let retainedMembership = ClassMembership(
            classId: "CLASS-RETAINED",
            className: "Retained class",
            role: .student,
            groupId: nil,
            status: .active,
            joinedAt: now,
            visibilityStartsAt: now,
            leftAt: nil
        )
        let profile = AppUserProfile(
            id: "student-a",
            displayName: "Student",
            role: .student,
            classId: deletedMembership.classId,
            groupId: nil,
            consentStatus: .granted,
            isDemo: false,
            createdAt: now,
            updatedAt: now,
            memberships: [deletedMembership, retainedMembership],
            activeClassId: deletedMembership.classId
        )

        let reconciled = profile.markingMembershipLeft(
            classId: deletedMembership.classId,
            at: now.addingTimeInterval(60)
        )

        XCTAssertNil(reconciled.activeClassId)
        XCTAssertTrue(reconciled.isPersonalMode)
        XCTAssertEqual(reconciled.memberships.first { $0.classId == "CLASS-DELETED" }?.status, .left)
        XCTAssertTrue(reconciled.memberships.first { $0.classId == "CLASS-RETAINED" }?.isActive == true)
    }
}

@MainActor
final class VolunteerServiceScopeAcceptanceTests: XCTestCase {
    func testVolunteerRequiresTeacherApprovalBeforeServiceBecomesActive() async throws {
        let service = MockClassroomService()
        let classroom = try await service.createClassroom(name: "志工服務測試班")
        let invitation = try await service.resetVolunteerInviteCode(classId: classroom.classId)

        let request = try await service.requestVolunteerService(code: invitation.code)
        XCTAssertEqual(request.status, .pendingApproval)
        let classroomsBeforeApproval = try await service.listClassrooms()
        XCTAssertTrue(classroomsBeforeApproval.allSatisfy { $0.role != .volunteer })

        try await service.reviewVolunteerService(
            classId: classroom.classId,
            volunteerUid: request.volunteerUid,
            approve: true
        )
        let approvedServices = try await service.listClassroomVolunteers(classId: classroom.classId)
        let classroomsAfterApproval = try await service.listClassrooms()
        XCTAssertEqual(approvedServices.first?.status, .active)
        XCTAssertTrue(classroomsAfterApproval.contains { $0.role == .volunteer })
    }

    func testVolunteerCanWithdrawPendingServiceRequestWithoutReceivingClassAccess() async throws {
        let service = MockClassroomService()
        let classroom = try await service.createClassroom(name: "志工申請撤回測試班")
        let invitation = try await service.resetVolunteerInviteCode(classId: classroom.classId)

        let request = try await service.requestVolunteerService(code: invitation.code)
        XCTAssertEqual(request.status, .pendingApproval)
        try await service.leaveVolunteerService(classId: classroom.classId)

        let services = try await service.listVolunteerServices()
        let classrooms = try await service.listClassrooms()
        XCTAssertEqual(services.first?.status, .left)
        XCTAssertTrue(classrooms.allSatisfy { $0.role != .volunteer })
    }

    func testLeavingOrDeletingClassRevokesVolunteerService() async throws {
        let service = MockClassroomService()
        let classroom = try await service.createClassroom(name: "志工撤權測試班")
        let invitation = try await service.resetVolunteerInviteCode(classId: classroom.classId)
        let request = try await service.requestVolunteerService(code: invitation.code)
        try await service.reviewVolunteerService(
            classId: classroom.classId,
            volunteerUid: request.volunteerUid,
            approve: true
        )

        try await service.leaveVolunteerService(classId: classroom.classId)
        let servicesAfterLeaving = try await service.listVolunteerServices()
        XCTAssertEqual(servicesAfterLeaving.first?.status, .left)

        let secondRequest = try await service.requestVolunteerService(code: invitation.code)
        try await service.reviewVolunteerService(
            classId: classroom.classId,
            volunteerUid: secondRequest.volunteerUid,
            approve: true
        )
        try await service.deleteClassroom(classId: classroom.classId)
        let servicesAfterDeletion = try await service.listVolunteerServices()
        let invitationAfterDeletion = try await service.volunteerInviteCode(classId: classroom.classId)
        XCTAssertEqual(servicesAfterDeletion.first?.status, .removed)
        XCTAssertNil(invitationAfterDeletion)
    }
}

final class PostSubmissionAssistanceAcceptanceTests: XCTestCase {
    func testAIExplanationIsUnavailableBeforeAnAnswerIsSubmitted() {
        XCTAssertFalse(PostSubmissionAssistancePolicy.canRequestExplanation(
            hasSubmittedResult: false,
            submittedAnswer: nil,
            attemptNumber: 0
        ))
        XCTAssertFalse(PostSubmissionAssistancePolicy.canRequestExplanation(
            hasSubmittedResult: false,
            submittedAnswer: "is",
            attemptNumber: 0
        ))
        XCTAssertFalse(PostSubmissionAssistancePolicy.canRequestExplanation(
            hasSubmittedResult: true,
            submittedAnswer: "尚未作答",
            attemptNumber: 1
        ))
    }

    func testAIExplanationBecomesAvailableAfterSubmission() {
        XCTAssertTrue(PostSubmissionAssistancePolicy.canRequestExplanation(
            hasSubmittedResult: true,
            submittedAnswer: "is",
            attemptNumber: 1
        ))
    }
}

final class QuestionBankQualityAcceptanceTests: XCTestCase {
    private var items: [QuestionBankItem] {
        SeedData.approvedQuestionBankItems
    }

    func testCurriculumTaxonomyAndSourceOptionsMeetRound15Contract() {
        XCTAssertEqual(items.count, 1_080)
        XCTAssertGreaterThanOrEqual(Set(items.map(\.skill)).count, 30)
        XCTAssertEqual(Set(items.map(\.level)), Set(QuestionLevel.allCases))
        XCTAssertEqual(Set(items.map(\.question.type)), Set(QuestionType.allCases))

        let semanticFamilies = Dictionary(grouping: items, by: \.semanticKey)
        XCTAssertGreaterThanOrEqual(semanticFamilies.count, 200)
        XCTAssertTrue(semanticFamilies.values.allSatisfy { family in
            Set(family.map(\.curriculumKey)).count == 1
        })

        let sourceAnswerSlots = items.compactMap { item in
            item.question.options.firstIndex { option in
                option.caseInsensitiveCompare(item.question.answer) == .orderedSame
            }
        }
        XCTAssertEqual(sourceAnswerSlots.count, items.count)
        XCTAssertTrue(items.allSatisfy { Set($0.question.options.map { $0.lowercased() }).count == 4 })
        let slotCounts = Dictionary(grouping: sourceAnswerSlots, by: { $0 }).mapValues(\.count)
        XCTAssertLessThanOrEqual((slotCounts.values.max() ?? 0) - (slotCounts.values.min() ?? 0), 1)
    }

    func testBalancedSessionRejectsSemanticDuplicatesAndRepeatedAnswers() {
        let session = QuestionGroupingEngine.balancedItems(
            from: items,
            limit: 50,
            rotationSeed: "round15-semantic-quality"
        )
        XCTAssertEqual(session.count, 50)
        XCTAssertEqual(Set(session.map(\.id)).count, session.count)
        XCTAssertEqual(Set(session.map(\.semanticKey)).count, session.count)

        let grammarItems = items.filter { $0.question.type == .grammar }
        let grammarSession = QuestionGroupingEngine.balancedItems(
            from: grammarItems,
            limit: 12,
            rotationSeed: "round15-be-verb-balance"
        )
        let answerCounts = Dictionary(
            grouping: grammarSession.map { $0.question.answer.lowercased() },
            by: { $0 }
        ).mapValues(\.count)
        XCTAssertEqual(grammarSession.count, 12)
        XCTAssertLessThanOrEqual((answerCounts.values.max() ?? 0) - (answerCounts.values.min() ?? 0), 1)
    }

    func testRuntimeOptionOrderUsesEveryCorrectAnswerSlotEvenly() {
        let session = QuestionGroupingEngine.balancedItems(
            from: items,
            limit: 12,
            rotationSeed: "round15-option-session"
        )
        let slots = session.enumerated().compactMap { index, item in
            QuestionGroupingEngine.balancedOptions(
                for: item,
                sessionIndex: index,
                rotationSeed: "round15-option-session"
            ).firstIndex { option in
                option.caseInsensitiveCompare(item.question.answer) == .orderedSame
            }
        }
        let counts = Dictionary(grouping: slots, by: { $0 }).mapValues(\.count)
        XCTAssertEqual(slots.count, 12)
        XCTAssertEqual(Set(slots), Set(0...3))
        XCTAssertTrue(counts.values.allSatisfy { $0 == 3 })
    }

    func testRepairSetDoesNotRepeatAnyQuestionFromPrimarySession() {
        let primary = QuestionGroupingEngine.balancedItems(
            from: items.filter { $0.question.type == .grammar },
            limit: 12,
            rotationSeed: "round15-primary-repair-source"
        )
        guard let source = primary.first else {
            return XCTFail("Primary session should not be empty")
        }
        let repair = QuestionGroupingEngine.repairSelection(
            after: source,
            from: items,
            excluding: Set(primary.map(\.id)),
            limit: 3,
            rotationSeed: "round15-repair"
        ).items
        let primaryKeys = Set(primary.map(\.semanticKey))
        XCTAssertEqual(repair.count, 3)
        XCTAssertTrue(repair.allSatisfy { !primaryKeys.contains($0.semanticKey) })
        XCTAssertEqual(Set(repair.map(\.semanticKey)).count, repair.count)
    }

    func testRotationSeedChangesQuestionsWithoutChangingQualityContract() {
        let first = QuestionGroupingEngine.balancedItems(
            from: items,
            limit: 12,
            rotationSeed: "round15-rotation-a"
        )
        let second = QuestionGroupingEngine.balancedItems(
            from: items,
            limit: 12,
            rotationSeed: "round15-rotation-b"
        )
        XCTAssertNotEqual(first.map(\.semanticKey), second.map(\.semanticKey))
        XCTAssertEqual(Set(first.map(\.semanticKey)).count, first.count)
        XCTAssertEqual(Set(second.map(\.semanticKey)).count, second.count)
    }

    func testPracticeCatalogUsesGranularSkillsAndFiniteUniqueSets() {
        let catalog = QuestionPracticeSet.catalog(from: items)
        XCTAssertGreaterThanOrEqual(catalog.count, 40)
        XCTAssertGreaterThanOrEqual(Set(catalog.map(\.skill)).count, 30)
        XCTAssertTrue(catalog.allSatisfy { !$0.items.isEmpty && $0.items.count <= 12 })
        XCTAssertTrue(catalog.allSatisfy { set in
            Set(set.items.map(\.semanticKey)).count == set.items.count
        })
        XCTAssertEqual(
            Set(catalog.flatMap(\.items).map(\.semanticKey)).count,
            Set(items.map(\.semanticKey)).count
        )
    }
}

@MainActor
final class MasteryAndSpacedReviewAcceptanceTests: XCTestCase {
    private let studentUid = "round16-student"

    func testWrongAnswerBecomesDueImmediatelyAndAffectsMasterySummary() throws {
        let item = try XCTUnwrap(SeedData.approvedQuestionBankItems.first)
        let answeredAt = Date(timeIntervalSince1970: 2_000_000_000)
        let record = SpacedRepetitionEngine.recording(
            existing: nil,
            studentUid: studentUid,
            item: item,
            isCorrect: false,
            firstTryCorrect: false,
            source: .freePractice,
            at: answeredAt
        )
        let summary = SpacedRepetitionEngine.summary(records: [record], at: answeredAt)

        XCTAssertEqual(record.attemptCount, 1)
        XCTAssertEqual(record.correctCount, 0)
        XCTAssertEqual(record.band, .needsReview)
        XCTAssertTrue(record.isDue(at: answeredAt))
        XCTAssertEqual(summary.dueReviewCount, 1)
        XCTAssertEqual(summary.strongSkillCount, 0)
    }

    func testCorrectStreakRaisesMasteryAndExtendsReviewInterval() throws {
        let item = try XCTUnwrap(SeedData.approvedQuestionBankItems.first)
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        var record: SkillMasteryRecord?
        for index in 0..<8 {
            let answeredAt = Calendar(identifier: .gregorian)
                .date(byAdding: .day, value: index, to: start) ?? start
            record = SpacedRepetitionEngine.recording(
                existing: record,
                studentUid: studentUid,
                item: item,
                isCorrect: true,
                firstTryCorrect: true,
                source: .dailyMission,
                at: answeredAt
            )
        }
        let mastered = try XCTUnwrap(record)

        XCTAssertEqual(mastered.attemptCount, 8)
        XCTAssertEqual(mastered.firstTryCorrectCount, 8)
        XCTAssertEqual(mastered.band, .mastered)
        XCTAssertGreaterThanOrEqual(mastered.masteryScore, 85)
        XCTAssertGreaterThanOrEqual(
            mastered.nextReviewAt.timeIntervalSince(mastered.lastAnsweredAt),
            29 * 24 * 60 * 60
        )
    }

    func testReviewSelectionAvoidsTheLastQuestionAndItsSemanticDuplicates() throws {
        let items = SeedData.approvedQuestionBankItems
        let group = try XCTUnwrap(
            Dictionary(grouping: items, by: \.curriculumKey).values.first { candidates in
                Set(candidates.map(\.semanticKey)).count >= 3
            }
        )
        let source = try XCTUnwrap(group.first)
        let answeredAt = Date(timeIntervalSince1970: 2_000_000_000)
        let record = SpacedRepetitionEngine.recording(
            existing: nil,
            studentUid: studentUid,
            item: source,
            isCorrect: false,
            firstTryCorrect: false,
            source: .repairPractice,
            at: answeredAt
        )
        let review = SpacedRepetitionEngine.reviewQuestions(
            records: [record],
            questionBank: items,
            limit: 2,
            at: answeredAt,
            rotationSeed: "round16-no-immediate-repeat"
        )

        XCTAssertFalse(review.isEmpty)
        XCTAssertTrue(review.allSatisfy { $0.id != source.id })
        XCTAssertTrue(review.allSatisfy { $0.semanticKey != source.semanticKey })
        XCTAssertEqual(Set(review.map(\.semanticKey)).count, review.count)
    }

    func testFreeAndRepairPracticeUpdateOneSharedMasteryRecord() throws {
        var clock = Date(timeIntervalSince1970: 2_000_000_000)
        let repository = MockLearningRepository(
            now: { clock },
            localPersistence: MemoryLearningPersistence()
        )
        let item = try XCTUnwrap(repository.questionBankItems.first)

        repository.recordPracticeAnswer(
            studentUid: studentUid,
            questionItem: item,
            isCorrect: false,
            source: .freePractice
        )
        clock = clock.addingTimeInterval(60)
        repository.recordPracticeAnswer(
            studentUid: studentUid,
            questionItem: item,
            isCorrect: true,
            source: .repairPractice
        )

        let record = try XCTUnwrap(repository.masteryRecords.first)
        XCTAssertEqual(repository.masteryRecords.count, 1)
        XCTAssertEqual(record.attemptCount, 2)
        XCTAssertEqual(record.correctCount, 1)
        XCTAssertEqual(record.lastAttemptSource, .repairPractice)
    }

    func testTeacherAssignmentPublishesPartialProgressAndRetryHistory() throws {
        var clock = Date(timeIntervalSince1970: 2_000_000_000)
        let repository = MockLearningRepository(
            now: { clock },
            localPersistence: MemoryLearningPersistence()
        )
        let set = try XCTUnwrap(repository.questionPracticeSets.first { $0.items.count >= 3 })
        let student = StaffStudentSummary(
            id: studentUid,
            studentUid: studentUid,
            studentName: "Round 16 Student",
            classCode: "ROUND16-CLASS",
            moodScore: nil,
            riskLevel: .low,
            missionProgress: "0 / 12",
            nextAction: "Practice"
        )
        let teacher = DemoUser(id: "round16-teacher", displayName: "Teacher", role: .teacher)

        repository.assignPracticeSet(set, to: student, by: teacher)
        let assignment = try XCTUnwrap(repository.assignedPracticeTasks.first)
        repository.startAssignedPracticeTask(assignment)
        let firstQuestion = try XCTUnwrap(repository.nextMissionQuestion)
        let wrongAnswer = try XCTUnwrap(
            firstQuestion.question.options.first {
                $0.caseInsensitiveCompare(firstQuestion.question.answer) != .orderedSame
            }
        )

        clock = clock.addingTimeInterval(1)
        XCTAssertFalse(try XCTUnwrap(repository.submitMissionAnswer(wrongAnswer)).isCorrect)
        var tracked = try XCTUnwrap(repository.assignedPracticeTasks.first { $0.id == assignment.id })
        XCTAssertEqual(tracked.status, .active)
        XCTAssertEqual(tracked.questionResults?.count, 1)
        XCTAssertEqual(tracked.questionResults?.first?.attemptCount, 1)
        XCTAssertEqual(tracked.questionResults?.first?.firstAttemptCorrect, false)

        clock = clock.addingTimeInterval(1)
        XCTAssertTrue(try XCTUnwrap(
            repository.submitMissionAnswer(firstQuestion.question.answer)
        ).isCorrect)
        tracked = try XCTUnwrap(repository.assignedPracticeTasks.first { $0.id == assignment.id })
        XCTAssertEqual(tracked.questionResults?.first?.attemptCount, 2)
        XCTAssertEqual(tracked.questionResults?.first?.firstAttemptCorrect, false)

        var safetyCounter = 0
        while let question = repository.nextMissionQuestion, safetyCounter < 20 {
            clock = clock.addingTimeInterval(1)
            _ = repository.submitMissionAnswer(question.question.answer)
            safetyCounter += 1
        }
        tracked = try XCTUnwrap(repository.assignedPracticeTasks.first { $0.id == assignment.id })
        XCTAssertEqual(tracked.status, .completed)
        XCTAssertEqual(tracked.questionResults?.count, assignment.questionIds.count)
        XCTAssertEqual(
            repository.masteryRecords.first { $0.lastAttemptSource == .teacherAssignment }?.studentUid,
            studentUid
        )
    }

    func testLegacyLocalSnapshotDefaultsMasteryToEmpty() throws {
        let snapshot = LocalLearningSnapshot(
            currentCheckIn: nil,
            currentMission: nil,
            missionAttempts: [],
            supportRequests: [],
            assignedPracticeTasks: [],
            savedAt: Date(timeIntervalSince1970: 2_000_000_000)
        )
        let encoded = try JSONEncoder().encode(snapshot)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "masteryRecords")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(LocalLearningSnapshot.self, from: legacyData)

        XCTAssertTrue(decoded.masteryRecords.isEmpty)
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
    private(set) var linkIdentityCallCount = 0
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

    func linkIdentity(
        _ credential: FederatedIdentityCredential,
        to session: AuthSession
    ) async throws -> AuthSession {
        linkIdentityCallCount += 1
        return session
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
