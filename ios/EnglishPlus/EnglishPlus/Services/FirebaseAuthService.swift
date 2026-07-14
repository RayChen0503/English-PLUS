import Foundation

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct FirebaseAuthService: AuthService, Sendable {
    private let fallback: MockAuthService

    init(fallback: MockAuthService = MockAuthService()) {
        self.fallback = fallback
    }

    private static func isPlausibleEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
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
            throw AuthServiceError.operationUnavailable
        }

        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isPlausibleEmail(cleanedEmail) else {
            throw AuthServiceError.invalidEmail
        }

        do {
            let result = try await signInWithFirebase(email: cleanedEmail, password: password)
            do {
                return try await accountSession(
                    uid: result.user.uid,
                    fallbackDisplayName: result.user.displayName ?? result.user.email ?? cleanedEmail,
                    expectedRole: expectedRole,
                    emailVerified: result.user.isEmailVerified
                )
            } catch {
                try? Auth.auth().signOut()
                throw error
            }
        } catch let error as AuthServiceError {
            throw error
        } catch {
            throw Self.normalizedFirebaseError(error)
        }
        #else
        throw AuthServiceError.operationUnavailable
        #endif
    }

    func createAccount(_ registration: AccountRegistration) async throws -> AccountCreationOutcome {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard FirebaseAppConfigurator.hasBundledConfig else {
            throw AuthServiceError.operationUnavailable
        }

        let cleanedName = registration.normalizedDisplayName
        let cleanedEmail = registration.normalizedEmail
        guard Self.isPlausibleEmail(cleanedEmail) else {
            throw AuthServiceError.invalidEmail
        }
        guard registration.password.count >= 8 else {
            throw AuthServiceError.weakPassword
        }
        guard !cleanedName.isEmpty else {
            throw AuthServiceError.profileUnavailable
        }
        guard registration.hasRequiredRoleDetails else {
            switch registration.role {
            case .student:
                throw AuthServiceError.profileUnavailable
            case .teacher:
                throw AuthServiceError.missingTeacherAffiliation
            case .volunteer:
                throw AuthServiceError.invalidVolunteerApplication
            }
        }

        do {
            let result = try await createUserWithFirebase(
                email: cleanedEmail,
                password: registration.password
            )
            do {
                try await updateFirebaseDisplayName(cleanedName, for: result.user)
                try await createInitialRegistrationDocuments(
                    uid: result.user.uid,
                    registration: registration
                )
            } catch {
                try? await deleteFirebaseUser(result.user)
                throw error
            }

            do {
                try await sendVerificationEmail(to: result.user)
            } catch {
                try? Auth.auth().signOut()
                throw error
            }
            try? Auth.auth().signOut()
            return .emailVerificationRequired(email: cleanedEmail)
        } catch let error as AuthServiceError {
            throw error
        } catch {
            throw Self.normalizedFirebaseError(error)
        }
        #else
        throw AuthServiceError.operationUnavailable
        #endif
    }

    func signIn(
        with credential: FederatedIdentityCredential,
        expectedRole: UserRole
    ) async throws -> AuthSession {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard FirebaseAppConfigurator.hasBundledConfig else {
            throw AuthServiceError.operationUnavailable
        }

        do {
            let result = try await signInWithFirebase(
                credential: firebaseCredential(from: credential)
            )
            do {
                return try await accountSession(
                    uid: result.user.uid,
                    fallbackDisplayName: result.user.displayName ?? result.user.email ?? "English+",
                    expectedRole: expectedRole,
                    emailVerified: result.user.isEmailVerified
                )
            } catch let error as AuthServiceError where error == .profileUnavailable {
                // Keep the just-authenticated Firebase session while the app collects
                // the missing role profile. Apple credentials should not be replayed.
                throw error
            } catch {
                try? Auth.auth().signOut()
                throw error
            }
        } catch let error as AuthServiceError {
            throw error
        } catch {
            throw Self.normalizedFirebaseError(error)
        }
        #else
        throw AuthServiceError.identityProviderUnavailable
        #endif
    }

    func createAccount(
        with credential: FederatedIdentityCredential,
        profile: RoleOnboardingProfile
    ) async throws -> AccountCreationOutcome {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard FirebaseAppConfigurator.hasBundledConfig else {
            throw AuthServiceError.operationUnavailable
        }
        guard !profile.normalizedDisplayName.isEmpty else {
            throw AuthServiceError.profileUnavailable
        }
        guard profile.hasRequiredRoleDetails else {
            switch profile.role {
            case .student:
                throw AuthServiceError.profileUnavailable
            case .teacher:
                throw AuthServiceError.missingTeacherAffiliation
            case .volunteer:
                throw AuthServiceError.invalidVolunteerApplication
            }
        }

        do {
            let signInResult: AuthDataResult?
            let firebaseUser: User
            if let currentUser = Auth.auth().currentUser,
               Self.firebaseUser(currentUser, uses: credential.provider) {
                signInResult = nil
                firebaseUser = currentUser
            } else {
                if Auth.auth().currentUser != nil {
                    try? Auth.auth().signOut()
                }
                let result = try await signInWithFirebase(
                    credential: firebaseCredential(from: credential)
                )
                signInResult = result
                firebaseUser = result.user
            }
            let snapshot = try await documentSnapshot(
                path: FirestorePath.user(uid: firebaseUser.uid)
            )
            if snapshot.exists {
                return .authenticated(
                    try await accountSession(
                        uid: firebaseUser.uid,
                        fallbackDisplayName: firebaseUser.displayName ?? profile.normalizedDisplayName,
                        expectedRole: profile.role,
                        emailVerified: firebaseUser.isEmailVerified
                    )
                )
            }

            do {
                try await updateFirebaseDisplayName(profile.normalizedDisplayName, for: firebaseUser)
                try await createInitialRegistrationDocuments(
                    uid: firebaseUser.uid,
                    profile: profile,
                    fallbackEmail: firebaseUser.email ?? "",
                    emailVerificationRequired: false,
                    identityProviders: [credential.provider]
                )
            } catch {
                if signInResult?.additionalUserInfo?.isNewUser == true {
                    try? await deleteFirebaseUser(firebaseUser)
                } else {
                    try? Auth.auth().signOut()
                }
                throw error
            }

            if profile.role == .volunteer,
               profile.volunteerApplication?.isReadyToSubmit == true {
                try? Auth.auth().signOut()
                return .approvalPending(
                    email: firebaseUser.email ?? "",
                    role: .volunteer
                )
            }

            return .authenticated(
                try await accountSession(
                    uid: firebaseUser.uid,
                    fallbackDisplayName: profile.normalizedDisplayName,
                    expectedRole: profile.role,
                    emailVerified: firebaseUser.isEmailVerified
                )
            )
        } catch let error as AuthServiceError {
            throw error
        } catch {
            throw Self.normalizedFirebaseError(error)
        }
        #else
        throw AuthServiceError.identityProviderUnavailable
        #endif
    }

    func linkIdentity(
        _ credential: FederatedIdentityCredential,
        to session: AuthSession
    ) async throws -> AuthSession {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard let user = Auth.auth().currentUser, user.uid == session.user.id else {
            throw AuthServiceError.invalidCredentials
        }

        do {
            _ = try await linkFirebaseUser(
                user,
                credential: firebaseCredential(from: credential)
            )
            try await setDocument(
                path: FirestorePath.user(uid: user.uid),
                data: [
                    "identityProviders": FieldValue.arrayUnion([credential.provider.rawValue]),
                    "updatedAt": Date(),
                ],
                merge: true
            )
            return try await accountSession(
                uid: user.uid,
                fallbackDisplayName: user.displayName ?? session.user.displayName,
                expectedRole: session.user.role,
                emailVerified: user.isEmailVerified
            )
        } catch let error as AuthServiceError {
            throw error
        } catch {
            throw Self.normalizedFirebaseError(error)
        }
        #else
        throw AuthServiceError.identityProviderUnavailable
        #endif
    }

    func submitVolunteerApplication(
        _ application: VolunteerApplicationInput,
        in session: AuthSession
    ) async throws -> AccountCreationOutcome {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard application.isReadyToSubmit,
              session.user.role == .volunteer,
              session.profile.accountStatus == .pendingApplication,
              let user = Auth.auth().currentUser,
              user.uid == session.user.id else {
            throw AuthServiceError.invalidVolunteerApplication
        }

        let now = Date()
        let firestore = Firestore.firestore()
        let batch = firestore.batch()
        batch.setData(
            [
                "accountStatus": AccountProvisioningStatus.pendingApproval.rawValue,
                "active": false,
                "updatedAt": now,
            ],
            forDocument: firestore.document(FirestorePath.user(uid: user.uid)),
            merge: true
        )
        batch.setData(
            [
                "status": VolunteerApplicationStatus.pendingReview.rawValue,
                "confirmsAge18OrOlder": application.confirmsAge18OrOlder,
                "acceptedConductVersion": application.acceptedConductVersion,
                "motivation": application.motivation,
                "evidence": application.evidence.map { evidence in
                    [
                        "id": evidence.id,
                        "kind": evidence.kind.rawValue,
                        "storageObjectKey": evidence.storageObjectKey,
                        "originalFilename": evidence.originalFilename,
                        "mimeType": evidence.mimeType,
                        "sizeBytes": evidence.sizeBytes,
                        "uploadedAt": evidence.uploadedAt,
                    ] as [String: Any]
                },
                "submittedAt": now,
                "updatedAt": now,
            ],
            forDocument: firestore.document(FirestorePath.volunteerApplication(uid: user.uid)),
            merge: true
        )
        try await commit(batch)
        try? Auth.auth().signOut()
        return .approvalPending(email: user.email ?? "", role: .volunteer)
        #else
        throw AuthServiceError.operationUnavailable
        #endif
    }

    func loadVolunteerApplication(
        in session: AuthSession
    ) async throws -> VolunteerApplicationInput? {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard session.user.role == .volunteer,
              Auth.auth().currentUser?.uid == session.user.id else {
            return nil
        }
        let snapshot = try await documentSnapshot(
            path: FirestorePath.volunteerApplication(uid: session.user.id)
        )
        guard let data = snapshot.data() else { return nil }
        let evidence = (data["evidence"] as? [[String: Any]] ?? []).compactMap {
            evidenceReference(data: $0)
        }
        return VolunteerApplicationInput(
            confirmsAge18OrOlder: data["confirmsAge18OrOlder"] as? Bool ?? false,
            acceptedConductVersion: data["acceptedConductVersion"] as? String ?? "",
            motivation: data["motivation"] as? String ?? "",
            evidence: evidence
        )
        #else
        return nil
        #endif
    }

    func currentUserIsAdministrator() async -> Bool {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser,
              let result = try? await user.getIDTokenResult() else {
            return false
        }
        return result.claims["admin"] as? Bool == true
        #else
        return false
        #endif
    }

    func sendPasswordReset(email: String) async throws {
        #if canImport(FirebaseAuth)
        guard FirebaseAppConfigurator.hasBundledConfig else {
            throw AuthServiceError.operationUnavailable
        }
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isPlausibleEmail(cleanedEmail) else {
            throw AuthServiceError.invalidEmail
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                Auth.auth().sendPasswordReset(withEmail: cleanedEmail) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        } catch {
            throw Self.normalizedFirebaseError(error)
        }
        #else
        throw AuthServiceError.operationUnavailable
        #endif
    }

    func resendVerification(email: String, password: String) async throws {
        #if canImport(FirebaseAuth)
        guard FirebaseAppConfigurator.hasBundledConfig else {
            throw AuthServiceError.operationUnavailable
        }
        let cleanedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isPlausibleEmail(cleanedEmail) else {
            throw AuthServiceError.invalidEmail
        }

        do {
            let result = try await signInWithFirebase(email: cleanedEmail, password: password)
            defer { try? Auth.auth().signOut() }
            guard !result.user.isEmailVerified else { return }
            try await sendVerificationEmail(to: result.user)
        } catch let error as AuthServiceError {
            throw error
        } catch {
            throw Self.normalizedFirebaseError(error)
        }
        #else
        throw AuthServiceError.operationUnavailable
        #endif
    }

    func restorePreviousSession() async throws -> AuthSession? {
        try await currentSession()
    }

    func selectActiveClass(_ classId: String?, in session: AuthSession) async throws -> AuthSession {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore)
        guard FirebaseAppConfigurator.hasBundledConfig else {
            throw AuthServiceError.operationUnavailable
        }
        guard Auth.auth().currentUser?.uid == session.user.id else {
            throw AuthServiceError.invalidCredentials
        }
        guard let profile = session.profile.selectingClass(classId) else {
            throw AuthServiceError.invalidClassSelection
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
            throw AuthServiceError.invalidCredentials
        }
        return try await user.getIDToken()
        #else
        throw AuthServiceError.operationUnavailable
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
            expectedRole: nil,
            emailVerified: user.isEmailVerified
        )
        #else
        throw AuthServiceError.operationUnavailable
        #endif
    }

    #if canImport(FirebaseAuth)
    private func firebaseCredential(
        from credential: FederatedIdentityCredential
    ) -> AuthCredential {
        switch credential {
        case .google(let idToken, let accessToken):
            return GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
        case .apple(let idToken, let rawNonce):
            return OAuthProvider.appleCredential(
                withIDToken: idToken,
                rawNonce: rawNonce,
                fullName: nil
            )
        }
    }

    private func signInWithFirebase(credential: AuthCredential) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            Auth.auth().signIn(with: credential) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: AuthServiceError.invalidCredentials)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func linkFirebaseUser(
        _ user: User,
        credential: AuthCredential
    ) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            user.link(with: credential) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: AuthServiceError.operationUnavailable)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    private func signInWithFirebase(email: String, password: String) async throws -> AuthDataResult {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: AuthServiceError.invalidCredentials)
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
                    continuation.resume(throwing: AuthServiceError.operationUnavailable)
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

    private func sendVerificationEmail(to user: User) async throws {
        Auth.auth().languageCode = "zh-TW"
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.sendEmailVerification { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func deleteFirebaseUser(_ user: User) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private static func normalizedFirebaseError(_ error: Error) -> AuthServiceError {
        guard let code = AuthErrorCode(rawValue: (error as NSError).code) else {
            return .operationUnavailable
        }

        switch code {
        case .invalidEmail:
            return .invalidEmail
        case .invalidCredential, .wrongPassword, .userNotFound:
            return .invalidCredentials
        case .weakPassword:
            return .weakPassword
        case .emailAlreadyInUse:
            return .emailAlreadyInUse
        case .accountExistsWithDifferentCredential:
            return .accountLinkRequired
        case .providerAlreadyLinked, .credentialAlreadyInUse:
            return .identityAlreadyLinked
        case .userDisabled:
            return .accountDisabled
        case .networkError:
            return .networkUnavailable
        case .tooManyRequests:
            return .tooManyRequests
        default:
            return .operationUnavailable
        }
    }

    private static func firebaseUser(
        _ user: User,
        uses provider: AccountIdentityProvider
    ) -> Bool {
        let providerID: String
        switch provider {
        case .emailPassword:
            providerID = "password"
        case .google:
            providerID = "google.com"
        case .apple:
            providerID = "apple.com"
        }
        return user.providerData.contains { $0.providerID == providerID }
    }
    #endif

    #if canImport(FirebaseFirestore)
    private func createInitialRegistrationDocuments(
        uid: String,
        registration: AccountRegistration
    ) async throws {
        try await createInitialRegistrationDocuments(
            uid: uid,
            profile: registration.onboardingProfile,
            fallbackEmail: registration.normalizedEmail,
            emailVerificationRequired: true,
            identityProviders: [.emailPassword]
        )
    }

    private func createInitialRegistrationDocuments(
        uid: String,
        profile: RoleOnboardingProfile,
        fallbackEmail: String,
        emailVerificationRequired: Bool,
        identityProviders: [AccountIdentityProvider]
    ) async throws {
        let now = Date()
        let name = profile.normalizedDisplayName.isEmpty
            ? fallbackEmail.components(separatedBy: "@").first ?? "English+"
            : profile.normalizedDisplayName
        let accountStatus: AccountProvisioningStatus
        if profile.role == .volunteer {
            accountStatus = profile.volunteerApplication?.isReadyToSubmit == true
                ? .pendingApproval
                : .pendingApplication
        } else {
            accountStatus = .active
        }
        let provisioningSource: AccountProvisioningSource
        switch profile.role {
        case .student:
            provisioningSource = .selfServiceStudent
        case .teacher:
            provisioningSource = .selfServiceTeacher
        case .volunteer:
            provisioningSource = .selfServiceVolunteer
        }

        let firestore = Firestore.firestore()
        let batch = firestore.batch()
        batch.setData(
            [
                "displayName": name,
                "preferredName": name,
                "primaryRole": profile.role.rawValue,
                "activeClassId": NSNull(),
                "createdAt": now,
                "updatedAt": now,
                "lastLoginAt": now,
                "active": accountStatus == .active,
                "accountStatus": accountStatus.rawValue,
                "emailVerificationRequired": emailVerificationRequired,
                "provisioningSource": provisioningSource.rawValue,
                "identityProviders": identityProviders.map(\.rawValue),
            ],
            forDocument: firestore.document(FirestorePath.user(uid: uid)),
            merge: false
        )

        if let affiliation = profile.teacherAffiliation {
            batch.setData(
                [
                    "uid": uid,
                    "displayName": name,
                    "institutionId": affiliation.institutionId,
                    "institutionName": affiliation.institutionName,
                    "institutionKind": affiliation.institutionKind.rawValue,
                    "institutionSource": affiliation.institutionSource.rawValue,
                    "claimStatus": affiliation.claimStatus.rawValue,
                    "createdAt": now,
                    "updatedAt": now,
                ],
                forDocument: firestore.document(FirestorePath.teacherProfile(uid: uid)),
                merge: false
            )
        }

        if let application = profile.volunteerApplication {
            batch.setData(
                [
                    "uid": uid,
                    "displayName": name,
                    "status": (
                        application.isReadyToSubmit
                            ? VolunteerApplicationStatus.pendingReview
                            : VolunteerApplicationStatus.draft
                    ).rawValue,
                    "confirmsAge18OrOlder": application.confirmsAge18OrOlder,
                    "acceptedConductVersion": application.acceptedConductVersion,
                    "motivation": application.motivation,
                    "evidence": application.evidence.map { evidence in
                        [
                            "id": evidence.id,
                            "kind": evidence.kind.rawValue,
                            "storageObjectKey": evidence.storageObjectKey,
                            "originalFilename": evidence.originalFilename,
                            "mimeType": evidence.mimeType,
                            "sizeBytes": evidence.sizeBytes,
                            "uploadedAt": evidence.uploadedAt,
                        ] as [String: Any]
                    },
                    "submittedAt": now,
                    "updatedAt": now,
                ],
                forDocument: firestore.document(FirestorePath.volunteerApplication(uid: uid)),
                merge: false
            )
        }

        try await commit(batch)
    }

    private func commit(_ batch: WriteBatch) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            batch.commit { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private func accountSession(
        uid: String,
        fallbackDisplayName: String,
        expectedRole: UserRole?,
        emailVerified: Bool
    ) async throws -> AuthSession {
        let userSnapshot = try await documentSnapshot(path: FirestorePath.user(uid: uid))
        var userData = userSnapshot.data() ?? [:]
        var memberships = try await userMemberships(uid: uid)

        if memberships.isEmpty,
           let legacyMembership = try await legacyMembershipIfPresent(uid: uid) {
            memberships = [legacyMembership]
        }

        guard userSnapshot.exists || !memberships.isEmpty else {
            throw AuthServiceError.profileUnavailable
        }

        let accountStatus = (userData["accountStatus"] as? String)
            .flatMap(AccountProvisioningStatus.init(rawValue:))
            ?? ((userData["active"] as? Bool ?? true) ? .active : .disabled)

        if userData["emailVerificationRequired"] as? Bool == true, !emailVerified {
            throw AuthServiceError.emailNotVerified(
                email: fallbackDisplayName.contains("@") ? fallbackDisplayName : ""
            )
        }

        switch accountStatus {
        case .active:
            break
        case .pendingApplication:
            break
        case .pendingApproval:
            throw AuthServiceError.accountPendingApproval
        case .suspended, .disabled:
            throw AuthServiceError.accountDisabled
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
            throw AuthServiceError.roleMismatch(expected: selectedRole, actual: primaryRole)
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
            accountStatus: accountStatus,
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
                    continuation.resume(throwing: AuthServiceError.operationUnavailable)
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

    private func evidenceReference(data: [String: Any]) -> VolunteerEvidenceReference? {
        guard
            let id = data["id"] as? String,
            let kindRaw = data["kind"] as? String,
            let kind = VolunteerQualificationKind(rawValue: kindRaw),
            let storageObjectKey = data["storageObjectKey"] as? String,
            let originalFilename = data["originalFilename"] as? String,
            let mimeType = data["mimeType"] as? String,
            let sizeBytes = data["sizeBytes"] as? Int
        else {
            return nil
        }
        return VolunteerEvidenceReference(
            id: id,
            kind: kind,
            storageObjectKey: storageObjectKey,
            originalFilename: originalFilename,
            mimeType: mimeType,
            sizeBytes: sizeBytes,
            uploadedAt: firestoreDate(data["uploadedAt"]) ?? Date()
        )
    }
    #endif
}
