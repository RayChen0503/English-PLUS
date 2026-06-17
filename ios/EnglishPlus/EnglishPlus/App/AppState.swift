import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var route: AppRoute = .roleSelection
    @Published var selectedRole: UserRole?
    @Published var currentUser: DemoUser?
    @Published var currentProfile: AppUserProfile?
    @Published var hasAcceptedConsent = false

    private let authService: AuthService
    private let firestoreService: FirestoreService

    init(authService: AuthService, firestoreService: FirestoreService) {
        self.authService = authService
        self.firestoreService = firestoreService
    }

    func chooseRole(_ role: UserRole) {
        selectedRole = role
        route = .demoLogin(role)
    }

    func signInForSelectedRole() {
        guard let selectedRole else { return }
        let session = authService.demoSession(for: selectedRole)
        currentUser = session.user
        currentProfile = session.profile
        hasAcceptedConsent = firestoreService.hasAcceptedRequiredConsent(uid: session.user.id)
        route = hasAcceptedConsent ? .home(selectedRole) : .privacyConsent(selectedRole)
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
        selectedRole = nil
        currentUser = nil
        currentProfile = nil
        hasAcceptedConsent = false
        route = .roleSelection
    }
}
