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
        .alert(
            "同步未完成",
            isPresented: Binding(
                get: { learningRepository.supportActionErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        learningRepository.dismissSupportActionError()
                    }
                }
            )
        ) {
            Button("好") {
                learningRepository.dismissSupportActionError()
            }
        } message: {
            Text(learningRepository.supportActionErrorMessage ?? "請稍後再試一次。")
        }
    }

    private func startRealtimeSyncIfNeeded() {
        guard case .home = appState.route,
              let currentProfile = appState.currentProfile
        else {
            learningRepository.stopRealtimeSync()
            return
        }

        learningRepository.startRealtimeSync(
            classId: currentProfile.classId,
            user: appState.currentUser,
            profile: currentProfile
        )
    }
}
