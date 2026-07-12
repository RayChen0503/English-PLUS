import Foundation

enum AppRoute: Equatable {
    case roleSelection
    case demoLogin(UserRole)
    case volunteerApplication
    case privacyConsent(UserRole)
    case home(UserRole)
}
