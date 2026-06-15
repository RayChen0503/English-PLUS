import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            switch appState.route {
            case .roleSelection:
                RoleSelectionView()
            case .demoLogin(let role):
                DemoLoginView(role: role)
            case .home(let role):
                switch role {
                case .student:
                    StudentShellView()
                case .teacher:
                    TeacherShellView()
                case .volunteer:
                    VolunteerShellView()
                }
            }
        }
    }
}
