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
    case invalidMembership(uid: String, classId: String)
    case roleMismatch(expected: UserRole, actual: UserRole)
    case selfServiceRoleNotAllowed(UserRole)
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
        return try await accountSession(
            uid: result.user.uid,
            fallbackDisplayName: result.user.displayName ?? result.user.email ?? email,
            expectedRole: expectedRole
        )
        #else
        throw FirebaseAuthServiceError.firebaseSDKUnavailable
        #endif
    }

    func createAccount(
        email: String,
        password: String,
        displayName: String,
        role: UserRole
    ) async throws -> AuthSession {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard FirebaseAppConfigurator.hasBundledConfig else {
            throw FirebaseAuthServiceError.notConfigured
        }
        guard role == .student else {
            throw FirebaseAuthServiceError.selfServiceRoleNotAllowed(role)
        }

        let cleanedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let result = try await createUserWithFirebase(email: cleanedEmail, password: password)
        try? await updateFirebaseDisplayName(cleanedName, for: result.user)
        try await createInitialProfileDocument(
            uid: result.user.uid,
            email: cleanedEmail,
            displayName: cleanedName,
            role: role
        )
        return try await accountSession(
            uid: result.user.uid,
            fallbackDisplayName: cleanedName,
            expectedRole: role
        )
        #else
        throw FirebaseAuthServiceError.firebaseSDKUnavailable
        #endif
    }

    func restorePreviousSession() async throws -> AuthSession? {
        try await currentSession()
    }

    func selectActiveClass(_ classId: String?, in session: AuthSession) async throws -> AuthSession {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard FirebaseAppConfigurator.hasBundledConfig else {
            throw FirebaseAuthServiceError.notConfigured
        }
        guard Auth.auth().currentUser?.uid == session.user.id else {
            throw FirebaseAuthServiceError.noAuthenticatedUser
        }
        guard let profile = session.profile.selectingClass(classId) else {
            throw FirebaseAuthServiceError.invalidMembership(
                uid: session.user.id,
                classId: classId ?? "personal"
            )
        }

        try await setDocument(
            path: FirestorePath.user(uid: session.user.id),
            data: [
                "activeClassId": classId.map { $0 as Any } ?? NSNull(),
                "updatedAt": Date(),
            ],
            merge: true
        )
        return AuthSession(
            user: DemoUser(
                id: session.user.id,
                displayName: session.user.displayName,
                role: profile.role
            ),
            profile: profile
        )
        #else
        return try await fallback.selectActiveClass(classId, in: session)
        #endif
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
        return try await accountSession(
            uid: user.uid,
            fallbackDisplayName: user.displayName ?? user.email ?? "English+",
            expectedRole: nil
        )
        #else
        throw FirebaseAuthServiceError.firebaseSDKUnavailable
        #endif
    }

    #if canImport(FirebaseAuth)
    private func signInWithFirebase(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: FirebaseAuthServiceError.noAuthenticatedUser)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func createUserWithFirebase(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: FirebaseAuthServiceError.noAuthenticatedUser)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func updateFirebaseDisplayName(_ displayName: String, for user: User) async throws {
        guard !displayName.isEmpty else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let request = user.createProfileChangeRequest()
            request.displayName = displayName
            request.commitChanges { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    #endif

    #if canImport(FirebaseFirestore)
    private func createInitialProfileDocument(
        uid: String,
        email: String,
        displayName: String,
        role: UserRole
    ) async throws {
        let now = Date()
        let name = displayName.isEmpty
            ? email.components(separatedBy: "@").first ?? "English+ Student"
            : displayName

        try await setDocument(
            path: FirestorePath.user(uid: uid),
            data: [
                "displayName": name,
                "preferredName": name,
                "primaryRole": role.rawValue,
                "activeClassId": NSNull(),
                "createdAt": now,
                "updatedAt": now,
                "lastLoginAt": now,
                "active": true,
            ],
            merge: true
        )
    }

    private func accountSession(
        uid: String,
        fallbackDisplayName: String,
        expectedRole: UserRole?
    ) async throws -> AuthSession {
        let userSnapshot = try await documentSnapshot(path: FirestorePath.user(uid: uid))
        var userData = userSnapshot.data() ?? [:]
        var memberships = try await userMemberships(uid: uid)

        if memberships.isEmpty,
           let legacyMembership = try await legacyMembershipIfPresent(uid: uid) {
            memberships = [legacyMembership]
        }

        guard userSnapshot.exists || !memberships.isEmpty else {
            throw FirebaseAuthServiceError.missingSeedProfile(uid)
        }

        let hasExplicitActiveClass = userData.keys.contains("activeClassId")
        let requestedActiveClassId = userData["activeClassId"] as? String
        let requestedMembership = requestedActiveClassId.flatMap { classId in
            memberships.first { $0.classId == classId && $0.isActive }
        }
        let membershipRole = requestedMembership?.role
            ?? memberships.first(where: \.isActive)?.role
        let primaryRole = (userData["primaryRole"] as? String)
            .flatMap(UserRole.init(rawValue:))
            ?? membershipRole
            ?? expectedRole
            ?? .student
        let selectedRole = expectedRole ?? requestedMembership?.role ?? primaryRole
        let selectedRoleIsAllowed = selectedRole == primaryRole
            || memberships.contains { $0.isActive && $0.role == selectedRole }
        guard selectedRoleIsAllowed else {
            throw FirebaseAuthServiceError.roleMismatch(expected: selectedRole, actual: primaryRole)
        }

        let activeMembership: ClassMembership?
        if let requestedMembership, requestedMembership.role == selectedRole {
            activeMembership = requestedMembership
        } else if hasExplicitActiveClass {
            activeMembership = nil
        } else {
            activeMembership = memberships.first { $0.isActive && $0.role == selectedRole }
        }

        let now = Date()
        let displayName = (userData["displayName"] as? String)
            .flatMap { $0.isEmpty ? nil : $0 }
            ?? fallbackDisplayName
        let createdAt = firestoreDate(userData["createdAt"])
            ?? activeMembership?.joinedAt
            ?? now
        let updatedAt = firestoreDate(userData["updatedAt"])
            ?? firestoreDate(userData["lastLoginAt"])
            ?? createdAt

        if userSnapshot.exists {
            userData["lastLoginAt"] = now
            try? await setDocument(
                path: FirestorePath.user(uid: uid),
                data: ["lastLoginAt": now],
                merge: true
            )
        }

        let profile = AppUserProfile(
            id: uid,
            displayName: displayName,
            role: selectedRole,
            classId: activeMembership?.classId ?? FirebaseBackendConfig.personalScopeId(uid: uid),
            groupId: activeMembership?.groupId,
            consentStatus: .pending,
            isDemo: false,
            createdAt: createdAt,
            updatedAt: updatedAt,
            memberships: memberships,
            activeClassId: activeMembership?.classId
        )
        return AuthSession(
            user: DemoUser(id: uid, displayName: displayName, role: selectedRole),
            profile: profile
        )
    }

    private func userMemberships(uid: String) async throws -> [ClassMembership] {
        let snapshots = try await collectionSnapshots(path: FirestorePath.userMemberships(uid: uid))
        return snapshots.compactMap { snapshot in
            membership(classId: snapshot.documentID, data: snapshot.data())
        }
        .sorted { $0.joinedAt < $1.joinedAt }
    }

    private func legacyMembershipIfPresent(uid: String) async throws -> ClassMembership? {
        let classId = FirebaseBackendConfig.firstClassId
        let snapshot = try await documentSnapshot(path: FirestorePath.member(classId: classId, uid: uid))
        guard snapshot.exists, let data = snapshot.data() else { return nil }
        return membership(classId: classId, data: data)
    }

    private func membership(classId: String, data: [String: Any]) -> ClassMembership? {
        guard
            let roleRaw = data["role"] as? String,
            let role = UserRole(rawValue: roleRaw)
        else {
            return nil
        }

        let joinedAt = firestoreDate(data["joinedAt"]) ?? Date()
        let status = (data["status"] as? String)
            .flatMap(ClassMembershipStatus.init(rawValue:))
            ?? ((data["active"] as? Bool ?? false) ? .active : .suspended)
        return ClassMembership(
            classId: classId,
            className: data["className"] as? String,
            role: role,
            groupId: data["groupId"] as? String,
            status: status,
            joinedAt: joinedAt,
            visibilityStartsAt: firestoreDate(data["visibilityStartsAt"]) ?? joinedAt,
            leftAt: firestoreDate(data["leftAt"])
        )
    }

    private func setDocument(path: String, data: [String: Any], merge: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Firestore.firestore().document(path).setData(data, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func documentSnapshot(path: String) async throws -> DocumentSnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentSnapshot, Error>) in
            Firestore.firestore().document(path).getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let snapshot else {
                    continuation.resume(throwing: FirebaseAuthServiceError.noAuthenticatedUser)
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }
    }

    private func collectionSnapshots(path: String) async throws -> [QueryDocumentSnapshot] {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[QueryDocumentSnapshot], Error>) in
            Firestore.firestore().collection(path).getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: snapshot?.documents ?? [])
            }
        }
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
