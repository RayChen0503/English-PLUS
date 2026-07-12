import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore

    var body: some View {
        Group {
            switch appState.route {
            case .roleSelection:
                RoleSelectionView()
            case .demoLogin(let role):
                DemoLoginView(role: role)
            case .volunteerApplication:
                VolunteerApplicationView()
            case .privacyConsent(let role):
                ConsentView(role: role)
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
        .onAppear(perform: startRealtimeSyncIfNeeded)
        .onChange(of: appState.route) { _, _ in
            startRealtimeSyncIfNeeded()
        }
        .onChange(of: appState.currentProfile?.activeClassId) { _, _ in
            startRealtimeSyncIfNeeded()
        }
    }

    private func startRealtimeSyncIfNeeded() {
        guard case .home = appState.route,
              let currentProfile = appState.currentProfile,
              let activeClassId = currentProfile.activeClassId
        else {
            learningRepository.stopRealtimeSync()
            return
        }

        learningRepository.startRealtimeSync(
            classId: activeClassId,
            user: appState.currentUser
        )
    }
}
