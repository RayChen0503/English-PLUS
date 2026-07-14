import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var learningRepository: LearningRepositoryStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .tint(EPTheme.primary)
        .background(EPTheme.background.ignoresSafeArea())
        .onAppear(perform: handleRouteContext)
        .onChange(of: appState.route) { _, _ in
            handleRouteContext()
        }
        .onChange(of: appState.currentProfile?.activeClassId) { _, _ in
            startRealtimeSyncIfNeeded()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            RepositorySyncBanner(
                status: learningRepository.syncStatus,
                lastSuccessfulSyncAt: learningRepository.lastSuccessfulSyncAt,
                onRetry: learningRepository.retryRealtimeSync
            )
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: learningRepository.syncStatus)
        .onChange(of: learningRepository.syncStatus) { _, status in
            switch status {
            case .listening:
                AppDiagnostics.shared.log(.realtimeSyncConnected)
            case .offlineFallback:
                AppDiagnostics.shared.log(.realtimeSyncOffline)
            default:
                break
            }
        }
        .onChange(of: learningRepository.supportActionErrorMessage) { _, message in
            recordIfPresent(message, category: .supportMutation)
        }
        .onChange(of: learningRepository.assignmentActionErrorMessage) { _, message in
            recordIfPresent(message, category: .assignmentMutation)
        }
        .onChange(of: appState.signInErrorMessage) { _, message in
            recordIfPresent(message, category: .authentication)
        }
        .onChange(of: appState.consentErrorMessage) { _, message in
            recordIfPresent(message, category: .consent)
        }
        .onChange(of: appState.classroomErrorMessage) { _, message in
            recordIfPresent(message, category: .classroom)
        }
        .onChange(of: appState.classroomRosterErrorMessage) { _, message in
            recordIfPresent(message, category: .roster)
        }
        .onChange(of: appState.volunteerServiceErrorMessage) { _, message in
            recordIfPresent(message, category: .volunteerService)
        }
        .onChange(of: appState.volunteerReviewErrorMessage) { _, message in
            recordIfPresent(message, category: .volunteerReview)
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

    private func handleRouteContext() {
        AppDiagnostics.shared.configure()
        AppDiagnostics.shared.updateContext(
            route: appState.route,
            role: appState.currentProfile?.role ?? appState.currentUser?.role
        )
        startRealtimeSyncIfNeeded()
    }

    private func recordIfPresent(_ message: String?, category: AppDiagnosticCategory) {
        guard message != nil else { return }
        AppDiagnostics.shared.record(category)
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
