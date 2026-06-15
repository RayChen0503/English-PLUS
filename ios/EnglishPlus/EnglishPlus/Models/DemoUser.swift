import Foundation

struct DemoUser: Identifiable, Equatable {
    let id: String
    let displayName: String
    let role: UserRole
}
