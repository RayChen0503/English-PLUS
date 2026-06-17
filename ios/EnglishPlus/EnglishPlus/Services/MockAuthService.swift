import Foundation

struct MockAuthService: AuthService {
    func demoUser(for role: UserRole) -> DemoUser {
        if let account = SeedData.demoAccount(for: role) {
            return DemoUser(id: account.id, displayName: account.displayName, role: account.role)
        }

        switch role {
        case .student:
            return DemoUser(id: "student-demo", displayName: "小安", role: .student)
        case .teacher:
            return DemoUser(id: "teacher-demo", displayName: "林老師", role: .teacher)
        case .volunteer:
            return DemoUser(id: "volunteer-demo", displayName: "陪伴志工", role: .volunteer)
        }
    }
}
