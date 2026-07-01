import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

enum FirebaseAuthServiceError: Error, Equatable {
    case firebaseSDKUnavailable
    case notConfigured
    case noAuthenticatedUser
    case missingSeedProfile(String)
    case missingMembership(uid: String, classId: String)
    case inactiveMembership(uid: String, classId: String)
    case invalidMembership(uid: String, classId: String)
    case roleMismatch(expected: UserRole, actual: UserRole)
}

struct FirebaseAuthService: AuthService {
    private let fallback: MockAuthService

    init(fallback: MockAuthService = MockAuthService()) {
        self.fallback = fallback
    }

    func demoSession(for role: UserRole) -> AuthSession {
        fallback.demoSession(for: role)
    }

    func signInDemoAccount(for role: UserRole) async throws -> AuthSession {
        let credential = DemoAccountCredential.credential(for: role)
        return try await signIn(
            email: credential.email,
            password: credential.password,
            expectedRole: credential.role
        )
    }

    func signIn(email: String, password: String, expectedRole: UserRole) async throws -> AuthSession {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard FirebaseAppConfigurator.hasBundledConfig else {
            throw FirebaseAuthServiceError.notConfigured
        }

        let result = try await signInWithFirebase(email: email, password: password)
        return try await membershipSession(
            uid: result.user.uid,
            expectedRole: expectedRole
        )
        #else
        throw FirebaseAuthServiceError.firebaseSDKUnavailable
        #endif
    }

    func restorePreviousSession() async throws -> AuthSession? {
        try await currentSession()
    }

    func signOut() {
        #if canImport(FirebaseAuth)
        try? Auth.auth().signOut()
        #endif
    }

    func currentIdToken() async throws -> String? {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthServiceError.noAuthenticatedUser
        }
        return try await user.getIDToken()
        #else
        throw FirebaseAuthServiceError.firebaseSDKUnavailable
        #endif
    }

    func currentSession() async throws -> AuthSession? {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let user = Auth.auth().currentUser else {
            return nil
        }
        return try await membershipSession(uid: user.uid, expectedRole: nil)
        #else
        throw FirebaseAuthServiceError.firebaseSDKUnavailable
        #endif
    }

    #if canImport(FirebaseAuth)
    private func signInWithFirebase(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let result {
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(throwing: FirebaseAuthServiceError.noAuthenticatedUser)
                }
            }
        }
    }
    #endif

    #if canImport(FirebaseFirestore)
    private func membershipSession(uid: String, expectedRole: UserRole?) async throws -> AuthSession {
        let classId = FirebaseBackendConfig.firstClassId
        let path = FirestorePath.member(classId: classId, uid: uid)
        let snapshot = try await documentSnapshot(path: path)

        guard snapshot.exists, let data = snapshot.data() else {
            throw FirebaseAuthServiceError.missingMembership(uid: uid, classId: classId)
        }

        let profile = try profile(
            uid: uid,
            classId: classId,
            data: data,
            expectedRole: expectedRole
        )
        return AuthSession(
            user: DemoUser(
                id: uid,
                displayName: profile.displayName,
                role: profile.role
            ),
            profile: profile
        )
    }

    private func documentSnapshot(path: String) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            Firestore.firestore().document(path).getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if let snapshot {
                    continuation.resume(returning: snapshot)
                } else {
                    continuation.resume(throwing: FirebaseAuthServiceError.noAuthenticatedUser)
                }
            }
        }
    }

    private func profile(
        uid: String,
        classId: String,
        data: [String: Any],
        expectedRole: UserRole?
    ) throws -> AppUserProfile {
        guard
            let roleRaw = data["role"] as? String,
            let role = UserRole(rawValue: roleRaw),
            let displayName = data["displayName"] as? String
        else {
            throw FirebaseAuthServiceError.invalidMembership(uid: uid, classId: classId)
        }

        if let expectedRole, expectedRole != role {
            throw FirebaseAuthServiceError.roleMismatch(expected: expectedRole, actual: role)
        }

        let active = data["active"] as? Bool ?? false
        guard active else {
            throw FirebaseAuthServiceError.inactiveMembership(uid: uid, classId: classId)
        }

        let joinedAt = firestoreDate(data["joinedAt"]) ?? Date()
        let updatedAt = firestoreDate(data["updatedAt"]) ?? joinedAt
        let consentStatus = (data["consentStatus"] as? String)
            .flatMap(ConsentStatus.init(rawValue:)) ?? .pending

        return AppUserProfile(
            id: uid,
            displayName: displayName,
            role: role,
            classId: classId,
            groupId: data["groupId"] as? String,
            consentStatus: consentStatus,
            isDemo: false,
            createdAt: joinedAt,
            updatedAt: updatedAt
        )
    }

    private func firestoreDate(_ value: Any?) -> Date? {
        if let date = value as? Date {
            return date
        }
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue()
        }
        return nil
    }
    #endif
}
