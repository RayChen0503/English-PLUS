import XCTest
import Combine
@testable import EnglishPlus

@MainActor
final class SessionIsolationRepairTests: XCTestCase {
    func testLateLoginCannotReplaceASecondSessionWithTheSameUID() async {
        let auth = DeferredRepairAuth()
        let app = makeApp(auth: auth)
        let started = expectation(description: "first login is suspended")
        auth.onLogin = { started.fulfill() }
        let first = Task { await app.signIn(email: "old@test.invalid", password: "password", role: .student) }
        await fulfillment(of: [started], timeout: 2)
        app.signOut()
        let generation = app.learningScopeIdentity
        auth.onLogin = nil
        auth.session = session(name: "New session")
        await app.signIn(email: "new@test.invalid", password: "password", role: .student)
        auth.loginContinuation?.resume(returning: session(name: "Old session"))
        await first.value
        XCTAssertEqual(app.currentUser?.displayName, "New session")
        XCTAssertEqual(app.route, .privacyConsent(.student))
        XCTAssertNotEqual(app.learningScopeIdentity, generation)
    }

    func testLateClassSelectionCannotResurrectSignedOutUser() async {
        let auth = DeferredRepairAuth()
        let app = makeApp(auth: auth)
        await app.signIn(email: "test@test.invalid", password: "password", role: .student)
        let started = expectation(description: "class selection is suspended")
        auth.onSelection = { started.fulfill() }
        let selection = Task { await app.selectActiveClass(nil) }
        await fulfillment(of: [started], timeout: 2)
        app.signOut()
        auth.selectionContinuation?.resume(returning: session(name: "Old class response"))
        await selection.value
        XCTAssertNil(app.currentUser)
        XCTAssertNil(app.currentProfile)
        XCTAssertEqual(app.route, .roleSelection)
    }

    func testConsentAcknowledgementAfterSignOutDoesNotEnterHome() async {
        let auth = DeferredRepairAuth()
        let firestore = DeferredRepairFirestore()
        let app = makeApp(auth: auth, firestore: firestore)
        await app.signIn(email: "test@test.invalid", password: "password", role: .student)
        let started = expectation(description: "consent write is suspended")
        firestore.onSave = { started.fulfill() }
        let saving = Task {
            await app.acceptPrivacyConsent(categories: [], guardianConsentStatus: .notRequired)
        }
        await fulfillment(of: [started], timeout: 2)
        app.signOut()
        firestore.continuation?.resume()
        await saving.value
        XCTAssertFalse(app.hasAcceptedConsent)
        XCTAssertFalse(app.isSavingConsent)
        XCTAssertEqual(app.route, .roleSelection)
    }

    func testMembershipReconciliationKeepsConsentRouteAndProcessesNewestSnapshot() async {
        let auth = DeferredRepairAuth()
        auth.session = session(classes: ["A", "B"])
        let classroom = MockClassroomService()
        let app = makeApp(auth: auth, classroom: classroom)
        await app.signIn(email: "test@test.invalid", password: "password", role: .student)
        XCTAssertEqual(app.route, .privacyConsent(.student))
        let started = expectation(description: "first membership restore is suspended")
        auth.onRestore = { started.fulfill() }
        classroom.simulateMembershipChange(activeClassIds: ["A"])
        await fulfillment(of: [started], timeout: 2)
        classroom.simulateMembershipChange(activeClassIds: [])
        // The listener queues onto MainActor. Let that event enter the coalescer
        // before releasing the earlier server read.
        await Task.yield()
        auth.onRestore = nil
        auth.restoreContinuation?.resume(returning: auth.session)
        let drained = expectation(description: "newest membership snapshot applied")
        let subscription = app.$currentProfile.sink { profile in
            if profile?.memberships.filter(\.isActive).isEmpty == true { drained.fulfill() }
        }
        await fulfillment(of: [drained], timeout: 2)
        subscription.cancel()
        XCTAssertNil(app.currentProfile?.activeClassId)
        XCTAssertEqual(app.route, .privacyConsent(.student))
        XCTAssertFalse(app.hasAcceptedConsent)
    }

    func testClassRoundTripAndSameUIDReloginHaveDistinctScopeIdentity() async {
        let auth = DeferredRepairAuth()
        auth.session = session(classes: ["A", "B"])
        let app = makeApp(auth: auth)
        await app.signIn(email: "test@test.invalid", password: "password", role: .student)
        let firstA = app.learningScopeIdentity
        await app.selectActiveClass("B")
        await app.selectActiveClass("A")
        XCTAssertEqual(app.currentProfile?.activeClassId, "A")
        XCTAssertNotEqual(firstA, app.learningScopeIdentity)
        let secondA = app.learningScopeIdentity
        app.signOut()
        await app.signIn(email: "test@test.invalid", password: "password", role: .student)
        XCTAssertNotEqual(secondA, app.learningScopeIdentity)
    }

    func testUploadCompletingAfterLogoutIsRecoveredByNewAppState() async throws {
        let auth = DeferredRepairAuth()
        auth.session = session(role: .volunteer, status: .pendingApplication)
        let uploader = DeferredRepairUploader()
        let suite = "SessionIsolationRepairTests.\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let app = makeApp(auth: auth, uploader: uploader, defaults: defaults)
        await app.signIn(email: "test@test.invalid", password: "password", role: .volunteer)
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".pdf")
        try Data("synthetic evidence".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let started = expectation(description: "upload is suspended")
        uploader.onUpload = { started.fulfill() }
        let upload = Task { try await app.uploadVolunteerEvidence(from: file, kind: .other) }
        await fulfillment(of: [started], timeout: 2)
        app.signOut()
        let reference = VolunteerEvidenceReference(id: "evidence", kind: .other, storageObjectKey: "synthetic/key",
            originalFilename: "proof.pdf", mimeType: "application/pdf", sizeBytes: 10, uploadedAt: Date())
        uploader.continuation?.resume(returning: reference)
        do { _ = try await upload.value; XCTFail("A stale upload must not update the old view") }
        catch is CancellationError {} catch { XCTFail("Unexpected error: \(error)") }
        let recovered = makeApp(auth: auth, defaults: defaults)
        await recovered.signIn(email: "test@test.invalid", password: "password", role: .volunteer)
        XCTAssertEqual(recovered.volunteerApplicationDraft?.evidence, [reference])
        XCTAssertNil(app.volunteerApplicationDraft)
    }

    func testIncompleteVolunteerDraftCanBeSavedAndLoadedBeforeSubmission() async throws {
        let auth = DeferredRepairAuth()
        auth.session = session(role: .volunteer, status: .pendingApplication)
        let app = makeApp(auth: auth)
        await app.signIn(email: "test@test.invalid", password: "password", role: .volunteer)
        let draft = VolunteerApplicationInput(confirmsAge18OrOlder: false, acceptedConductVersion: "", motivation: "", evidence: [])
        try await app.saveVolunteerApplicationDraft(draft)
        app.signOut()
        let next = makeApp(auth: auth)
        await next.signIn(email: "test@test.invalid", password: "password", role: .volunteer)
        XCTAssertEqual(next.volunteerApplicationDraft, draft)
        XCTAssertEqual(next.route, .volunteerApplication)
    }

    private func makeApp(auth: DeferredRepairAuth,
                         firestore: FirestoreService = MockFirestoreService(),
                         classroom: ClassroomService = UnavailableClassroomService(),
                         uploader: EvidenceUploadService = UnavailableEvidenceUploadService(),
                         defaults: UserDefaults = .standard) -> AppState {
        AppState(authService: auth, firestoreService: firestore, aiService: MockAIService(),
                 evidenceUploadService: uploader, volunteerReviewService: UnavailableVolunteerReviewService(),
                 classroomService: classroom, accountLifecycleService: MockAccountLifecycleService(),
                 runtimeDiagnostics: RuntimeDiagnosticsSnapshot(backendMode: .firebase, hasFirebaseConfig: true,
                     authProvider: "test", firestoreProvider: "test", learningProvider: "test", aiProvider: "test", aiProxyEndpoint: nil),
                 volunteerDraftDefaults: defaults)
    }

    private func session(name: String = "Current", classes: [String] = [], role: UserRole = .student,
                         status: AccountProvisioningStatus = .active) -> AuthSession {
        repairSession(name: name, classes: classes, role: role, status: status)
    }
}

private func repairSession(name: String = "Current", classes: [String] = [], role: UserRole = .student,
                           status: AccountProvisioningStatus = .active) -> AuthSession {
    let uid = "session-isolation-repair-\(role.rawValue)"
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let memberships = classes.map {
        ClassMembership(classId: $0, className: $0, role: role, groupId: nil, status: .active,
                        joinedAt: now, visibilityStartsAt: now, leftAt: nil)
    }
    let profile = AppUserProfile(id: uid, displayName: name, role: role,
        classId: classes.first ?? FirebaseBackendConfig.personalScopeId(uid: uid), groupId: nil,
        consentStatus: .pending, isDemo: false, accountStatus: status, createdAt: now, updatedAt: now,
        memberships: memberships, activeClassId: classes.first)
    return AuthSession(user: DemoUser(id: uid, displayName: name, role: role), profile: profile)
}

private final class DeferredRepairAuth: AuthService {
    var session = repairSession()
    var draft: VolunteerApplicationInput?
    var onLogin: (() -> Void)?
    var onSelection: (() -> Void)?
    var onRestore: (() -> Void)?
    var loginContinuation: CheckedContinuation<AuthSession, Never>?
    var selectionContinuation: CheckedContinuation<AuthSession, Never>?
    var restoreContinuation: CheckedContinuation<AuthSession?, Never>?
    func demoSession(for role: UserRole) -> AuthSession { session }
    func signIn(email: String, password: String, expectedRole: UserRole) async throws -> AuthSession {
        if let onLogin {
            return await withCheckedContinuation { loginContinuation = $0; onLogin() }
        }
        return session
    }
    func createAccount(_ registration: AccountRegistration) async throws -> AccountCreationOutcome { .authenticated(session) }
    func selectActiveClass(_ classId: String?, in current: AuthSession) async throws -> AuthSession {
        if let onSelection {
            return await withCheckedContinuation { selectionContinuation = $0; onSelection() }
        }
        guard let profile = current.profile.selectingClass(classId) else { throw AuthServiceError.invalidClassSelection }
        return AuthSession(user: current.user, profile: profile)
    }
    func restorePreviousSession() async throws -> AuthSession? {
        if let onRestore {
            return await withCheckedContinuation { restoreContinuation = $0; onRestore() }
        }
        return session
    }
    func saveVolunteerApplicationDraft(_ draft: VolunteerApplicationInput, in session: AuthSession) async throws { self.draft = draft }
    func loadVolunteerApplication(in session: AuthSession) async throws -> VolunteerApplicationInput? { draft }
}

private final class DeferredRepairFirestore: FirestoreService {
    var onSave: (() -> Void)?
    var continuation: CheckedContinuation<Void, Never>?
    func hasAcceptedRequiredConsent(uid: String) -> Bool { false }
    func loadConsentRecord(uid: String) async -> PrivacyConsentRecord? { nil }
    func consentRecord(uid: String) -> PrivacyConsentRecord? { nil }
    func saveConsent(_ record: PrivacyConsentRecord) async throws {
        await withCheckedContinuation { continuation = $0; onSave?() }
    }
}

private final class DeferredRepairUploader: EvidenceUploadService {
    var onUpload: (() -> Void)?
    var continuation: CheckedContinuation<VolunteerEvidenceReference, Never>?
    func upload(data: Data, filename: String, mimeType: String, kind: VolunteerQualificationKind) async throws -> VolunteerEvidenceReference {
        await withCheckedContinuation { continuation = $0; onUpload?() }
    }
    func delete(_ reference: VolunteerEvidenceReference) async throws {}
}
