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
